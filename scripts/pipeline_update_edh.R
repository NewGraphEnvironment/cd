#!/usr/bin/env Rscript
#
# pipeline_update_edh.R
#
# Incremental monthly update via DestinE Earth Data Hub.
# Replaces the CDS-based pipeline_update.R.
#
# Flow:
#   1. Read the band names of all 59 live COGs → the years every one holds.
#      A sync that died partway leaves some a year ahead; the run targets the
#      years they all hold and step 4 appends to each only what it lacks, so
#      the next run repairs it (#119). Then check the live STAC catalog.
#   2. Determine target year (latest complete year available on EDH),
#      capped at the latest complete *local* year: tmax/tmin use local days
#      (#37), so a year is not ready until 07:00 UTC on 1 Jan of the next.
#   3. If behind, call scripts/backfill_edh_all.py AND backfill_edh_snow.py
#      for each missing year (both idempotent — Python scripts skip files
#      that already exist).
#   4. For each variable × period, read existing COG from S3 via /vsicurl,
#      append the new year (cd_aggregate for monthly natives; direct stack
#      for annual-derived snow scalars), write locally, push to S3.
#   5. Rebuild catalog, push to S3. Refused unless step 4 rewrote every COG
#      the catalog lists, each holding the live years plus the new one: the
#      catalog is built from this run's directory and replaces the live one,
#      so anything step 4 skipped would vanish from it (#89).
#
# Before step 1, STEP D extends the daily air-temperature cube (#116) under
# s3://<bucket>/daily/, one COG per variable-year from backfill_edh_daily.py.
# A local-time year needs the first 8 hours of the next UTC year. Since #37
# the annual path waits for that too (monthly tmax/tmin use the same local
# days), so the cube and the annual COGs advance together, about a month
# after the year's last UTC month lands; steps 1-3 exit early on most runs.
# A daily failure does not stop the annual path; it turns the run's exit
# status non-zero at the end.
#
# Designed for the monthly GitHub Action (climate-update.yml). Exits
# cleanly with status 0 if nothing new is available, unless a live run found
# the COGs out of step (step 1) and has not yet published the repair.
#
# Prerequisites:
#   - EDH_TOKEN in env or ~/.Renviron
#   - AWS CLI configured (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY,
#     AWS_DEFAULT_REGION=us-west-2)
#   - uv installed (for running the Python backfill)
#
# Usage:
#   Rscript scripts/pipeline_update_edh.R
#   Rscript scripts/pipeline_update_edh.R --dry-run   # probes + STEP 1-2 only
#
# Dry run (--dry-run, or CD_DRY_RUN=true in the environment) proves the whole
# plumbing — package load, EDH auth, AWS read AND write, STAC catalog read,
# target-year computation — then exits 0 before STEP 3. No EDH pull, no COG
# rebuild, no catalog publish. It is NOT a no-write mode: STEP 0 round-trips a
# sentinel object under s3://<bucket>/_healthcheck/ (written then deleted), which
# is the only way to prove the bucket is actually writable.
# climate-update.yml runs it weekly as a heartbeat (#78).

# Prefer the installed package (what CI does — see extra-packages: local::. in
# climate-update.yml). devtools::load_all() is the local-dev fallback. Fail with
# a readable message rather than a bare "no package called 'devtools'" from
# loadNamespace, which is how #78 presented on every scheduled run.
if (requireNamespace("cd", quietly = TRUE)) {
  library(cd)
} else if (requireNamespace("devtools", quietly = TRUE)) {
  devtools::load_all()
} else {
  stop("cd is not installed and devtools is unavailable to load_all() it. ",
       "Install cd (or devtools) before running this pipeline.", call. = FALSE)
}
suppressMessages(library(terra))

# Producer-side helpers (mirrors scripts/_lib.py). Repo-root cwd, same
# assumption the `uv run scripts/...` calls below already make.
source("scripts/_lib.R")

args <- commandArgs(trailingOnly = TRUE)
# Same --dry-run flag as pipeline_stage3_edh.R, plus CD_DRY_RUN so the GitHub
# Action can select the mode without rewriting the command line.
dry_run <- "--dry-run" %in% args ||
  tolower(Sys.getenv("CD_DRY_RUN")) %in% c("true", "1", "yes")

# -- Config --------------------------------------------------------------------
bucket <- "stac-era5-land"
catalog_url <- paste0("https://", bucket, ".s3.us-west-2.amazonaws.com/catalog.json")
monthly_dir <- "data/backfill/monthly"
annual_dir  <- "data/backfill/annual"
cog_dir <- "data/update/cogs"
# Outside cog_dir, so the COG sync never carries it: it is uploaded on its own,
# after the COGs it points at (#89).
catalog_path <- "data/update/catalog.json"
seasons <- cd_seasons()

agg_methods <- c(
  tmean = "mean", tmax = "mean", tmin = "mean",
  prcp = "sum", vpd = "mean", rh = "mean", soil_moisture = "mean",
  # Snow monthly natives (#48): same shape as existing 7 vars (12-band/year),
  # flow through cd_aggregate identically. snowfall and snowmelt are monthly
  # water-equivalent totals so annual aggregation is sum.
  swe = "mean", snowfall = "sum", snowmelt = "sum", snow_cover = "mean"
)

# Annual-only derived vars (#48): no monthly schema; one band per year per file
# in annual_dir. These bypass cd_aggregate and just have the new year stacked
# onto the existing multi-year COG read from S3.
annual_vars <- c("swe_max", "snowfall_fraction",
                 "snowmelt_doy_50", "snowmelt_rate_peak")

dir.create(monthly_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(cog_dir, recursive = TRUE, showWarnings = FALSE)

log_msg <- function(...) {
  cat(sprintf("[%s] %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), paste0(...)))
}

log_msg("Mode: ", if (dry_run) {
  "DRY RUN (probes only; no EDH fetch, no COG rebuild, no catalog publish)"
} else {
  "LIVE"
})

# -- Step 0: auth probes -------------------------------------------------------
# Runs on every path, including the live run. STEP 1/2 can exit 0 early when
# already current, and the live run does not touch S3 until STEP 5 — six hours
# in. Probing here turns a credential problem into an immediate, legible
# failure instead of one buried at the end of a long job (#78).
log_msg("=== STEP 0: Verify credentials ===")

# EDH: HEAD the consolidated Zarr metadata. Cheap, and a 401/403 distinguishes
# a bad token from an unreachable host. The token is never logged.
edh_token <- Sys.getenv("EDH_TOKEN")
if (!nzchar(edh_token)) {
  log_msg("ERROR: EDH_TOKEN is not set (env or ~/.Renviron).")
  quit(status = 1)
}
edh_probe_url <- paste0(
  "https://data.earthdatahub.destine.eu/",
  "era5/reanalysis-era5-land-no-antartica-v0.zarr/.zmetadata"
)
# Credentials go on the handle, not in the URL. The token is 100+ chars and can
# contain characters libcurl will not accept unencoded in a userinfo field —
# embedding it the way the Python fsspec calls do yields a spurious 401 here.
# It also keeps the token out of any string that might get logged.
# Retry the statuses that can clear on their own, and only those. A single
# transient refusal should not cost a red run plus an auto-filed issue: run
# 34119315556 died on a 403 that returned 200 from the same secret and commit
# five hours later (#82, #83). edh_retryable() holds which is which.
edh_attempts <- 3L
edh_status <- 0L
edh_err <- ""
edh_tries <- 0L
for (i in seq_len(edh_attempts)) {
  edh_tries <- i
  # Reset per attempt. Without this, a curl error from an earlier attempt is
  # still set when a LATER attempt fails with an HTTP status, and the report
  # prints a connection-timeout message beside a "rotate the secret"
  # diagnosis — the mixed signal this whole change exists to remove.
  edh_err <- ""
  edh_res <- tryCatch(
    curl::curl_fetch_memory(
      edh_probe_url,
      # httpauth = 1L is CURLAUTH_BASIC. Without it libcurl waits for a
      # WWW-Authenticate challenge that EDH does not send, and the probe 401s
      # against an endpoint that plain `curl -u` reaches fine.
      # timeout bounds the whole transfer. new_handle() bounds only the
      # CONNECT phase (10s), so a server that completes the handshake and then
      # stalls hangs here indefinitely — and the job's timeout-minutes CANCELS
      # rather than fails, which skips the if: failure() alarm entirely.
      handle = curl::new_handle(
        nobody = TRUE, username = "edh", password = edh_token, httpauth = 1L,
        timeout = 30L
      )
    ),
    error = function(e) {
      edh_err <<- conditionMessage(e)
      NULL
    }
  )
  # Status 0 is the connection-level failure case edh_retryable() expects.
  edh_status <- if (is.null(edh_res)) 0L else as.integer(edh_res$status_code)
  if (edh_status >= 200L && edh_status < 400L) break
  if (i < edh_attempts && edh_retryable(edh_status)) {
    edh_wait <- 5L * i
    log_msg("  EDH probe ", i, "/", edh_attempts, ": ",
            if (edh_status == 0L) "connection error" else paste0("HTTP ", edh_status),
            " — retrying in ", edh_wait, "s")
    Sys.sleep(edh_wait)
  } else {
    break
  }
}
if (edh_status < 200L || edh_status >= 400L) {
  log_msg("ERROR: EDH probe failed after ", edh_tries, " attempt(s).")
  # Say what the status means, not what it is. Collapsing every 4xx into
  # "rejected the token" is what sent #82 toward a needless secret rotation.
  log_msg("  HTTP ", edh_status, ": ", edh_diagnosis(edh_status))
  if (nzchar(edh_err)) log_msg("  curl: ", edh_err)
  # The probe is a HEAD, so it carries no body. Fetch EDH's own wording once,
  # only on the terminal failure path, so the auto-filed issue quotes them
  # rather than our guess.
  #
  # Skipped when the server never answered (status 0, a connection failure).
  # The reason is NOT a recovered 200 — the r$status_code check below already
  # returns "" for that, and nzchar() then suppresses the line. It is a recovered
  # 4xx/5xx: without this guard, a probe that failed three times at the
  # connection level and then got a 403 would print
  # "EDH said: Quota exceeded..." underneath a "could not reach the host"
  # diagnosis, attributing a message to a request the diagnosis says never
  # arrived.
  #
  # It still runs for every 4xx/5xx, including 403 — that is the case whose
  # wording is most worth having, since EDH names a quota refusal in the body.
  # So this does NOT avoid the extra request on a quota refusal, and on a
  # recovered 200 the body is still downloaded before r$status_code discards it.
  # The status check below prevents mis-REPORTING, not the transfer.
  edh_reason <- if (edh_status < 400L) "" else tryCatch({
    r <- curl::curl_fetch_memory(
      edh_probe_url,
      handle = curl::new_handle(
        username = "edh", password = edh_token, httpauth = 1L, timeout = 30L
      )
    )
    if (r$status_code < 400L) {
      # Recovered between the probe and this call: it has no error to report,
      # and its 200 body is data, not an explanation.
      ""
    } else {
      # Collapse to one line: EDH errors come back as multi-line HTML, and this
      # string is quoted into the auto-filed failure issue.
      trimws(substr(gsub("[[:space:]]+", " ", rawToChar(r$content)), 1, 200))
    }
  }, error = function(e) "")
  if (nzchar(edh_reason)) log_msg("  EDH said: ", edh_reason)
  quit(status = 1)
}
log_msg("  EDH: OK (HTTP ", edh_status, ")")

# AWS: identity first, so a missing/expired key reports as such rather than as
# an opaque S3 error.
aws_identity <- suppressWarnings(system2(
  "aws", c("sts", "get-caller-identity", "--output", "text", "--query", "Arn"),
  stdout = TRUE, stderr = TRUE
))
if (!is.null(attr(aws_identity, "status")) && attr(aws_identity, "status") != 0) {
  log_msg("ERROR: aws sts get-caller-identity failed — ",
          paste(aws_identity, collapse = " "))
  quit(status = 1)
}
log_msg("  AWS identity: ", paste(aws_identity, collapse = " "))

# AWS write proof. get-caller-identity only shows the credentials parse; it says
# nothing about whether this principal may write to the bucket, which is exactly
# the class of failure that took this workflow down. Round-trip a sentinel object
# and delete it. Keyed by run id so concurrent runs cannot clobber each other.
# nzchar, not Sys.getenv(unset=): unset= only fires when the variable is absent,
# so a set-but-empty GITHUB_RUN_ID would yield the bare prefix
# s3://<bucket>/_healthcheck/ — writable, but not removable by the paired rm.
run_id <- Sys.getenv("GITHUB_RUN_ID")
if (!nzchar(run_id)) run_id <- as.character(Sys.getpid())
sentinel_key <- paste0("s3://", bucket, "/_healthcheck/", run_id)
sentinel_put <- suppressWarnings(system2(
  "aws", c("s3", "cp", "-", shQuote(sentinel_key)),
  input = paste0("cd pipeline_update_edh healthcheck ", format(Sys.time())),
  stdout = TRUE, stderr = TRUE
))
if (!is.null(attr(sentinel_put, "status")) && attr(sentinel_put, "status") != 0) {
  log_msg("ERROR: cannot write to ", sentinel_key, " — ",
          paste(sentinel_put, collapse = " "))
  log_msg("The pipeline publishes to this bucket in STEP 5; aborting now.")
  quit(status = 1)
}
sentinel_rm <- suppressWarnings(system2(
  "aws", c("s3", "rm", shQuote(sentinel_key)), stdout = TRUE, stderr = TRUE
))
if (!is.null(attr(sentinel_rm, "status")) && attr(sentinel_rm, "status") != 0) {
  # Not fatal: the write succeeded, which is what STEP 5 needs. Surface the
  # orphan so it can be swept rather than silently accumulating.
  log_msg("  WARNING: sentinel written but not deleted — clean up ", sentinel_key)
}
log_msg("  AWS write to s3://", bucket, ": OK")

# -- Step D: daily air-temperature cube (#116) --------------------------------
# Self-contained: its own target, its own dry-run report, its own push. It
# sits before step 1 because steps 1-3 exit early on most runs, and the CI
# runner starts empty, so a daily year built after them would never be
# pushed.
log_msg("=== STEP D: Daily air-temperature cube (#116) ===")

daily_dir <- "data/backfill/daily"
daily_base <- paste0("https://", bucket, ".s3.us-west-2.amazonaws.com/daily")
daily_vars <- c("tmean", "tmax", "tmin")
daily_failed <- FALSE
# Set in STEP 1 when an earlier sync left some live COGs ahead of the rest,
# cleared once STEP 5 has published the repair (#119).
partial_live <- FALSE

# Every later exit goes through here, so a daily failure is never reported
# as a green run by an annual path that had nothing to do, and a live run that
# found the COGs out of step is never green until it has put them back.
finish <- function(status = 0L) {
  if (daily_failed) {
    log_msg("Daily cube step failed (see STEP D above); exiting non-zero.")
    status <- 1L
  }
  # Not on a dry run: it reports the state, and the next live run repairs it.
  if (partial_live && !dry_run) {
    log_msg("The live COGs are still out of step (see STEP 1); exiting non-zero.")
    status <- 1L
  }
  quit(status = status)
}

# 200 = published, 403/404 = absent (S3 answers 403 for a missing key on a
# bucket that does not grant anonymous ListBucket), anything else = unknown.
daily_published <- function(year) {
  codes <- vapply(daily_vars, function(v) {
    url <- paste0(daily_base, "/", v, "_daily_", year, ".tif")
    res <- tryCatch(
      # timeout bounds the whole transfer; new_handle() alone bounds only the
      # connect, and a stalled HEAD here would also block the annual path.
      curl::curl_fetch_memory(
        url, handle = curl::new_handle(nobody = TRUE, timeout = 30L)
      ),
      error = function(e) NULL
    )
    if (is.null(res)) 0L else as.integer(res$status_code)
  }, integer(1))
  if (all(codes == 200L)) return(TRUE)
  if (all(codes %in% c(200L, 403L, 404L))) return(FALSE)
  NA
}

# Latest complete local year, from the store's time coordinate only, or NA
# when the probe fails. Read twice: STEP D's target, and STEP 2's cap on the
# annual path (#37).
latest_local_year <- function() {
  out <- suppressWarnings(system2(
    "uv", c("run", "--quiet", "scripts/backfill_edh_daily.py", "--check"),
    stdout = TRUE
  ))
  line <- grep("^latest_complete=[0-9]{4}$", out, value = TRUE)
  if (!is.null(attr(out, "status")) || length(line) != 1L) {
    log_msg("  ERROR: backfill_edh_daily.py --check failed (exit ",
            if (is.null(attr(out, "status"))) 0L else attr(out, "status"), ")")
    return(NA_integer_)
  }
  as.integer(sub("^latest_complete=", "", line))
}

latest_local <- tryCatch(latest_local_year(), error = function(e) {
  log_msg("  ERROR: ", conditionMessage(e))
  NA_integer_
})

daily_step <- function() {
  if (is.na(latest_local)) return(FALSE)
  target <- latest_local
  log_msg("  Latest complete local year on EDH: ", target)

  # Walk back from the target to the newest published year. A few years is
  # the most a healthy cube can be behind; finding none means the cube was
  # never built, and 76 years is a local backfill, not a CI job.
  newest <- NA_integer_
  for (y in seq(target, target - 3L)) {
    pub <- daily_published(y)
    if (is.na(pub)) {
      log_msg("  ERROR: could not tell whether ", y, " is published (HEAD failed)")
      return(FALSE)
    }
    if (pub) {
      newest <- y
      break
    }
  }
  if (is.na(newest)) {
    log_msg("  ERROR: no daily cube published for ", target - 3L, "-", target,
            ". Build it locally: uv run scripts/backfill_edh_daily.py, then ",
            "cd_s3_push('", daily_dir, "', prefix = 'daily').")
    return(FALSE)
  }
  log_msg("  Newest year on S3: ", newest)
  if (newest >= target) {
    log_msg("  Daily cube current.")
    return(TRUE)
  }
  missing <- seq(newest + 1L, target)
  if (dry_run) {
    log_msg("  A live run would build and publish ", paste(missing, collapse = ", "), ".")
    return(TRUE)
  }

  for (y in missing) {
    log_msg("  Building ", y, " via backfill_edh_daily.py...")
    status <- system2(
      "uv", c("run", "scripts/backfill_edh_daily.py", "--year", as.character(y))
    )
    files <- file.path(daily_dir, paste0(daily_vars, "_daily_", y, ".tif"))
    n_days <- if (y %% 4L == 0L && (y %% 100L != 0L || y %% 400L == 0L)) 366L else 365L
    ok <- status == 0L && all(file.exists(files)) &&
      all(vapply(files, function(f) nlyr(rast(f)) == n_days, logical(1)))
    if (!ok) {
      log_msg("  ERROR: ", y, " did not build completely (exit ", status, ")")
      return(FALSE)
    }
  }
  cd_s3_push(daily_dir, bucket = bucket, prefix = "daily", dry_run = FALSE)
  log_msg("  Published ", paste(missing, collapse = ", "), " to s3://", bucket, "/daily/")
  TRUE
}

daily_failed <- !isTRUE(tryCatch(daily_step(), error = function(e) {
  log_msg("  ERROR: ", conditionMessage(e))
  FALSE
}))

# -- Step 1: determine state ---------------------------------------------------
log_msg("=== STEP 1: Check S3 catalog for latest year ===")

catalog <- tryCatch(
  cd_catalog(catalog_url),
  error = function(e) {
    log_msg("No catalog at ", catalog_url, " — run full backfill first (scripts/backfill_edh_all.py + pipeline_stage3_edh.R)")
    quit(status = 1)
  }
)

# The years every live COG holds, not tmean_annual's alone (#119). A STEP 5
# sync that dies partway leaves some COGs a year ahead, and the catalog behind
# with the rest (cd_s3_push() aborts before it goes up). Reading one COG took
# its end year as everyone's: either the run failed against the catalog, or it
# fetched for hours and appended the year a second time to the COGs that had
# it. The target is now the earliest end year, and STEP 4 appends to each COG
# only what it lacks. Read from the bucket by name, not via the catalog's
# hrefs, which are the same URLs (cd_stac_catalog() builds them from base_url).
expected_cogs <- cog_expected(agg_methods, seasons, annual_vars)
cog_base <- paste0("https://", bucket, ".s3.us-west-2.amazonaws.com")

# 59 reads where there was one, on every run including the weekly dry run, so
# bound each request and retry: GDAL puts no total timeout on a /vsicurl/ read
# by default, and one stalled request would run until the job's
# timeout-minutes cancels it six hours later. This bounds requests, not the
# step: GDAL 3.8 also retries timeouts, so a bucket that stalls every request
# costs ~13 min per COG and the job is still cancelled, which the alarm reports. EMPTY_DIR stops the per-file sidecar probes (.aux.xml,
# .ovr), which this bucket answers 403; it halved the read (41 s to 20 s).
setGDALconfig("GDAL_HTTP_TIMEOUT", "60")
setGDALconfig("GDAL_HTTP_MAX_RETRY", "3")
setGDALconfig("GDAL_HTTP_RETRY_DELAY", "2")
setGDALconfig("GDAL_DISABLE_READDIR_ON_OPEN", "EMPTY_DIR")
# GDAL caches /vsicurl/ per process, failures included: GDAL 3.8 (what CI's
# terra links) answers a URL whose first open failed with that failure again,
# sending no request, so a plain retry retries nothing (code-check round 2).
# CPL_VSIL_CURL_NON_CACHED gets past it, though on 3.8 not by bypassing the
# cache: a handle on a matching URL clears that URL's entries when it closes,
# and GDAL stats a /vsicurl/ path before opening it, so the stat clears the
# failure and the open goes to the network (code-check round 3, from the
# 3.8.4 source; probed with a 503 and with a rewritten object). A read with no
# stat before it would still meet the stale entry. GDAL splits the value on
# ":", so "/vsicurl/https://..." matches every https read, which took the 59
# reads from 20 s to 236 s. So it goes on only after a read fails, and stays
# on, so STEP 4 does not meet the cached failure either.
uncache <- function() {
  setGDALconfig("CPL_VSIL_CURL_NON_CACHED", paste0("/vsicurl/", cog_base))
}
# Band names per live COG, NULL for one still unreadable after 3 attempts.
# GDAL's own retry covers 429, 502-504 and timeouts; this one covers what it
# does not, such as a reset connection or a 501.
read_live_years <- function() {
  lapply(stats::setNames(nm = expected_cogs), function(f) {
    for (i in 1:3) {
      bands <- tryCatch(names(rast(paste0("/vsicurl/", cog_base, "/", f))),
                        error = function(e) NULL)
      if (!is.null(bands)) return(bands)
      uncache()
      if (i < 3) Sys.sleep(5 * i)
    }
    NULL
  })
}
log_msg("Reading the band names of the ", length(expected_cogs), " live COGs...")
read_start <- Sys.time()
live_years <- read_live_years()
log_msg("  Read in ", round(as.numeric(Sys.time() - read_start, units = "secs")), "s")
spans <- live_spans(live_years)
if (length(spans$problems) > 0) {
  log_msg("ERROR: could not establish the years the live COGs hold.")
  for (p in spans$problems) log_msg("  - ", p)
  if (length(spans$unread) > 0) {
    log_msg("  Unreadable COGs: re-run first, since a read can fail transiently. ",
            "One that is missing from s3://", bucket, "/ needs ",
            "scripts/pipeline_stage3_edh.R.")
  }
  if (length(spans$problems) > (length(spans$unread) > 0)) {
    log_msg("  Years out of shape: appending cannot fix that; rebuild all ",
            length(expected_cogs), " COGs with scripts/pipeline_stage3_edh.R.")
  }
  finish(1L)
}
current_years <- spans$common
latest_year <- max(current_years)
log_msg("Latest year every live COG holds: ", latest_year)
partial_live <- length(spans$ahead) > 0
if (partial_live) {
  ahead_by <- vapply(spans$ahead, function(y) paste(y, collapse = ", "), character(1))
  log_msg("WARNING: ", length(spans$ahead), " of ", length(expected_cogs),
          " live COGs hold years the others lack; an earlier STEP 5 sync ",
          "stopped partway (#119). ",
          if (dry_run) "A live run would append" else "This run appends",
          " those years to the rest.")
  for (y in unique(ahead_by)) {
    cogs <- names(ahead_by)[ahead_by == y]
    log_msg("  also holding ", y, ": ", length(cogs), " COG(s) (",
            paste(utils::head(cogs, 5), collapse = ", "),
            if (length(cogs) > 5) ", ..." else "", ")")
  }
}

# STEP 5 publishes only the full set, so a live catalog that is not the full
# set can never be updated; say so now rather than after hours of fetching.
# Its years are checked against the COGs too: if a run's catalog upload failed
# after its COG sync, every COG already holds the new year, every later run
# would find nothing to do, and the catalog would stay a year behind, green.
# After a sync that died partway, the catalog spans `common`, the years every
# COG holds, so it passes and the run repairs the COGs.
# Before the dry-run exit, so the weekly heartbeat reports either (#89).
live_keys <- paste(catalog$variable, catalog$period, sep = "_")
live_items <- tryCatch(catalog_item_years(jsonlite::read_json(catalog_url)),
                       error = function(e) NULL)
key_problems <- if (is.null(live_items)) {
  "could not read the live catalog's item years"
} else {
  catalog_problems(live_items$keys, sub("\\.tif$", "", expected_cogs),
                   live_items$start, live_items$end, current_years)
}
if (length(key_problems) > 0) {
  log_msg("ERROR: the live catalog does not describe the live COGs (",
          length(expected_cogs), " items spanning ", min(current_years), "-",
          latest_year, "), and an incremental run cannot repair it.")
  for (p in key_problems) log_msg("  - ", p)
  # A catalog rebuilt from COGs that are themselves out of step would list
  # mixed spans; those need every COG rebuilt.
  log_msg("  Repair: ", if (partial_live) {
    paste0("the COGs are out of step as well, so rebuild all ",
           length(expected_cogs), " with scripts/pipeline_stage3_edh.R.")
  } else {
    catalog_repair_hint(bucket)
  })
  finish(1L)
}
log_msg("Live catalog: the expected ", length(expected_cogs), " items, ",
        min(current_years), "-", latest_year)

# -- Step 2: target year ------------------------------------------------------
# ERA5-Land has ~2-3 month latency. Try the current year — if EDH has all
# 12 months, backfill_edh_all.py writes; otherwise it skips cleanly and we
# move on. Also try latest_year + 1 in case we're behind for another reason.
current_year <- as.integer(format(Sys.Date(), "%Y"))
if (latest_year >= current_year) {
  log_msg("Already at or past current year (", latest_year, " >= ", current_year, ")")
  log_msg("Nothing to do.")
  finish(0L)
}
candidate_years <- seq(latest_year + 1, current_year)
# tmax/tmin use local days (#37), so a year whose last local day is not yet on
# EDH cannot write them, and STEP 3 would fetch the other 13 variables only to
# discard the year. Skip it here instead. When the probe failed, skip STEP 3
# altogether: without it every candidate risks that discarded fetch, and the
# run already exits non-zero through finish() because STEP D failed with it.
if (is.na(latest_local)) {
  log_msg("Latest complete local year unknown (STEP D probe failed); ",
          "not fetching this run.")
  finish(0L)
}
later <- candidate_years[candidate_years > latest_local]
if (length(later) > 0) {
  log_msg("Not yet complete in local time (needs 07:00 UTC on 1 Jan of the ",
          "next year): ", paste(later, collapse = ", "))
}
candidate_years <- candidate_years[candidate_years <= latest_local]
# Every year a COG is ahead by must be fetched, or STEP 5 would refuse the
# publish after the whole fetch. Published years were complete when they went
# up, so this should never fire; when it does, say so before fetching, and
# before the exit below would call it "nothing to do".
unfetched <- setdiff(unlist(spans$ahead), candidate_years)
if (length(unfetched) > 0) {
  log_msg("ERROR: live COGs hold ", paste(sort(unfetched), collapse = ", "),
          ", which this run cannot fetch (not complete in local time on EDH), ",
          "so it cannot bring the rest up to them. Rebuild all ",
          length(expected_cogs), " with scripts/pipeline_stage3_edh.R.")
  finish(1L)
}
if (length(candidate_years) == 0) {
  log_msg("No year complete in local time beyond ", latest_year, " yet.")
  log_msg("Nothing to do.")
  finish(0L)
}
log_msg("Candidate years to fetch: ", paste(candidate_years, collapse = ", "))

# Appending local-day tmax/tmin years (#37) onto UTC-day history would put a
# 0.5-0.8 degC step into every tmax COG. The history is local-day once
# scripts/tmax_tmin_republish.R has run: each live key then differs from its
# UTC-day backup. Checked against the live objects, before any fetch.
tmaxmin_local_history <- function() {
  keys <- as.vector(outer(c("tmax", "tmin"), c("annual", names(seasons)),
                          paste, sep = "_"))
  head_etag <- function(url) {
    res <- tryCatch(
      curl::curl_fetch_memory(
        url, handle = curl::new_handle(nobody = TRUE, timeout = 30L)
      ),
      error = function(e) NULL
    )
    if (is.null(res)) return(list(code = 0L, etag = NA_character_))
    h <- curl::parse_headers_list(res$headers)
    list(code = as.integer(res$status_code),
         etag = if (is.null(h$etag)) NA_character_ else gsub('"', "", h$etag))
  }
  base <- paste0("https://", bucket, ".s3.us-west-2.amazonaws.com")
  all(vapply(keys, function(k) {
    live <- head_etag(paste0(base, "/", k, ".tif"))
    bak <- head_etag(paste0(base, "/_backup/tmax_tmin_utc_day/", k, ".tif"))
    live$code == 200L && bak$code == 200L && !is.na(live$etag) &&
      !identical(live$etag, bak$etag)
  }, logical(1)))
}
if (!isTRUE(tmaxmin_local_history())) {
  log_msg("ERROR: the live tmax/tmin history is not confirmed local-day ",
          "(no UTC-day backup, or a live key still equals it). Run ",
          "scripts/tmax_tmin_republish.R first (#37); not appending.")
  finish(1L)
}

if (dry_run) {
  log_msg("=== DRY RUN COMPLETE ===")
  log_msg("Credentials, catalog read and target-year computation all succeeded.")
  log_msg("A live run would now fetch ", paste(candidate_years, collapse = ", "),
          " via EDH, append any complete years to the ",
          length(agg_methods) + length(annual_vars),
          " variable COGs, and publish to s3://", bucket, ".")
  if (partial_live) {
    log_msg("WARNING: that includes ",
            paste(sort(unique(unlist(spans$ahead))), collapse = ", "),
            ", which some live COGs already hold; each COG gets only the years ",
            "it lacks, repairing the partial sync found in STEP 1.")
  }
  finish(0L)
}

# -- Step 3: fetch via EDH ----------------------------------------------------
log_msg("=== STEP 3: Fetch missing years via EDH ===")

new_years_written <- c()
any_fetch_errored <- FALSE
core_vars <- c("tmean", "tmax", "tmin", "prcp", "vpd", "rh", "soil_moisture")
snow_monthly_vars <- c("swe", "snowfall", "snowmelt", "snow_cover")

for (yr in candidate_years) {
  log_msg("  Fetching ", yr, " via backfill_edh_all.py...")
  status <- system2(
    "uv", c("run", "scripts/backfill_edh_all.py", "--year", as.character(yr))
  )
  if (status != 0) {
    log_msg("  FAILED backfill_edh_all for ", yr, " (exit ", status, ")")
    any_fetch_errored <- TRUE
    next
  }
  log_msg("  Fetching ", yr, " via backfill_edh_snow.py...")
  status <- system2(
    "uv", c("run", "scripts/backfill_edh_snow.py", "--year", as.character(yr))
  )
  if (status != 0) {
    log_msg("  FAILED backfill_edh_snow for ", yr, " (exit ", status, ")")
    any_fetch_errored <- TRUE
    next
  }

  # Verify all 7 core + 4 monthly-snow + 4 annual-snow files wrote. The Python
  # scripts check completeness from the store's time coordinate *before*
  # fetching (#84), so an unready year costs one metadata read rather than a
  # full download; a missing file means the year wasn't ready on EDH yet.
  wrote_core <- all(vapply(core_vars, function(v) {
    file.exists(file.path(monthly_dir, paste0(v, "_", yr, ".tif")))
  }, logical(1)))
  wrote_snow_monthly <- all(vapply(snow_monthly_vars, function(v) {
    file.exists(file.path(monthly_dir, paste0(v, "_", yr, ".tif")))
  }, logical(1)))
  wrote_snow_annual <- all(vapply(annual_vars, function(v) {
    file.exists(file.path(annual_dir, paste0(v, "_", yr, ".tif")))
  }, logical(1)))

  if (wrote_core && wrote_snow_monthly && wrote_snow_annual) {
    log_msg("  ", yr, ": wrote all 15 variables")
    new_years_written <- c(new_years_written, yr)
  } else {
    log_msg("  ", yr, ": partial or unavailable on EDH yet, skipping")
  }
}

# A year some live COGs already hold that this run failed to write leaves the
# partial sync unrepaired; stop before STEP 4 rewrites 59 COGs only for STEP 5
# to refuse them, and before the message below blames EDH latency (#119).
unrepaired <- setdiff(unlist(spans$ahead), new_years_written)
if (length(unrepaired) > 0) {
  log_msg("ERROR: could not write ", paste(sort(unrepaired), collapse = ", "),
          ", which ", length(spans$ahead), " live COG(s) already hold (STEP 1); ",
          "the partial sync stays unrepaired. See the STEP 3 output above.")
  finish(1L)
}

if (length(new_years_written) == 0) {
  if (any_fetch_errored) {
    log_msg("ERROR: attempted fetch(es) errored and no new years were written.")
    log_msg("Exiting non-zero so the run is visibly failed.")
    quit(status = 1)
  }
  log_msg("No new complete years available on EDH yet (latency is normal).")
  finish(0L)
}
log_msg("New years to integrate: ", paste(new_years_written, collapse = ", "))

# -- Step 4: rebuild COGs (existing from S3 + new years) ----------------------
log_msg("=== STEP 4: Append new years to existing COGs ===")

# COGs written by THIS run, with their band names (years), for the guard
# before STEP 5. Same shape as stage 3's.
written <- list()

# Helper: append the new years to an existing S3 COG and write locally.
# Used for both monthly natives (after cd_aggregate) and annual derived
# (1-band straight read) — caller computes new_layers, this checks grid
# alignment and writes. Years the COG already holds are skipped (#119).
# Returns the written COG's band names, or NULL when there was nothing to write.
append_to_cog <- function(var, period, new_layers) {
  if (length(new_layers) == 0) {
    log_msg("  ", var, "_", period, ": no new layers, not rewritten")
    return(NULL)
  }
  cog_name <- paste0(var, "_", period, ".tif")
  cog_path <- file.path(cog_dir, cog_name)
  # The object STEP 1 read, by the same URL, not the catalog's href.
  cog_url <- paste0(cog_base, "/", cog_name)
  existing_rast <- tryCatch(
    rast(paste0("/vsicurl/", cog_url)),
    error = function(e) stop("Failed to read existing COG: ",
                             cog_url, "\nError: ", e$message,
                             call. = FALSE)
  )
  # A sync that died partway left this COG holding some of the new years
  # already (#119). Appending them again would duplicate the band, so skip
  # them, but only once the held band matches what this run computed: a
  # method change between the two runs would otherwise mix methods within
  # one year across the 59 COGs, with nothing to show it.
  held <- intersect(names(new_layers), names(existing_rast))
  for (y in held) {
    if (!isTRUE(all.equal(as.vector(values(existing_rast[[y]])),
                          as.vector(values(new_layers[[y]])),
                          tolerance = 1e-5))) {
      stop(var, "_", period, ": the live COG already holds ", y,
           " (an earlier partial sync) and it differs from the ", y,
           " computed this run. Rebuild with scripts/pipeline_stage3_edh.R.",
           call. = FALSE)
    }
  }
  if (length(held) > 0) {
    log_msg("  ", var, "_", period, ": already holds ",
            paste(held, collapse = ", "),
            " (an earlier partial sync, matching this run's); not appended again")
    new_layers <- new_layers[setdiff(names(new_layers), held)]
  }
  # Nothing left to append: still put the COG in cog_dir, because STEP 5
  # publishes only when every COG was written this run (#89). A byte copy, not
  # a rewrite, so nothing is re-encoded, and the size-only sync then skips it.
  if (length(new_layers) == 0) {
    # Retried: this runs at the end of a fetch measured in hours. A failure
    # leaves no file (curl_download writes to a temp file first).
    for (i in 1:3) {
      ok <- tryCatch({
        curl::curl_download(cog_url, cog_path, quiet = TRUE,
                            handle = curl::new_handle(timeout = 600L))
        TRUE
      }, error = function(e) {
        log_msg("  ", cog_name, ": copy attempt ", i, " failed: ", conditionMessage(e))
        FALSE
      })
      if (ok) break
      if (i == 3) stop("Could not copy ", cog_url, " after 3 attempts.", call. = FALSE)
      Sys.sleep(5 * i)
    }
    copied <- names(rast(cog_path))
    if (!identical(copied, names(existing_rast))) {
      stop("Copy of ", cog_url, " does not hold the bands STEP 1 read.",
           call. = FALSE)
    }
    log_msg("  Copied unchanged: ", cog_name, " (", length(copied), " years total)")
    return(copied)
  }
  new_rast <- rast(new_layers)
  names(new_rast) <- names(new_layers)
  if (!isTRUE(all.equal(as.vector(ext(existing_rast)),
                        as.vector(ext(new_rast)), tolerance = 1e-6)) ||
      !isTRUE(all.equal(res(existing_rast), res(new_rast), tolerance = 1e-6))) {
    stop("Grid mismatch between existing COG (", cog_url,
         ") and new ", var, "_", period,
         ". Extent/res differ. Aborting.", call. = FALSE)
  }
  combined <- c(existing_rast, new_rast)
  cd_cog_write(combined, cog_path, overwrite = TRUE)
  log_msg("  Updated: ", cog_name, " (", nlyr(combined), " years total)")
  names(combined)
}

# Monthly natives + 7 core: cd_aggregate from 12-band monthly TIFs.
all_monthly_vars <- names(agg_methods)
for (var in all_monthly_vars) {
  method <- agg_methods[[var]]
  for (period in c("annual", names(seasons))) {
    existing_row <- catalog[catalog$variable == var & catalog$period == period, ]
    if (nrow(existing_row) == 0) {
      log_msg("  ", var, "_", period, ": not in catalog, skipping")
      next
    }
    new_layers <- list()
    for (yr in new_years_written) {
      mf <- file.path(monthly_dir, paste0(var, "_", yr, ".tif"))
      if (!file.exists(mf)) {
        log_msg("  ", var, "_", period, ": ", mf, " missing, ", yr, " skipped")
        next
      }
      r_m <- rast(mf)
      if (nlyr(r_m) != 12) {
        log_msg("  ", var, "_", period, ": ", mf, " has ", nlyr(r_m),
                " layers, not 12; ", yr, " skipped")
        next
      }
      periods <- cd_aggregate(r_m, method = method, seasons = seasons)
      if (period %in% names(periods)) {
        new_layers[[as.character(yr)]] <- periods[[period]]
      } else {
        log_msg("  ", var, "_", period, ": cd_aggregate() returned no ",
                period, " layer; ", yr, " skipped")
      }
    }
    bands <- append_to_cog(var, period, new_layers)
    if (!is.null(bands)) written[[paste0(var, "_", period, ".tif")]] <- bands
  }
}

# Annual derived snow vars (#48): 1-band-per-year files in annual_dir, no
# cd_aggregate, only "annual" period.
for (var in annual_vars) {
  existing_row <- catalog[catalog$variable == var & catalog$period == "annual", ]
  if (nrow(existing_row) == 0) {
    log_msg("  ", var, "_annual: not in catalog, skipping")
    next
  }
  new_layers <- list()
  for (yr in new_years_written) {
    af <- file.path(annual_dir, paste0(var, "_", yr, ".tif"))
    if (!file.exists(af)) {
      log_msg("  ", var, "_annual: ", af, " missing, ", yr, " skipped")
      next
    }
    r <- rast(af)
    if (nlyr(r) != 1) {
      log_msg("  ", var, "_annual: ", af, " has ", nlyr(r),
              " layers, not 1; ", yr, " skipped")
      next
    }
    new_layers[[as.character(yr)]] <- r
  }
  bands <- append_to_cog(var, "annual", new_layers)
  if (!is.null(bands)) written[[paste0(var, "_annual.tif")]] <- bands
}

# -- Step 5: rebuild catalog + push -------------------------------------------
log_msg("=== STEP 5: Rebuild catalog + push to S3 ===")

# The catalog is built from cog_dir and replaces the live one outright, so a
# COG step 4 skipped would drop out of it while its .tif stayed on S3 with
# nothing pointing at it (#89). No COG or catalog has been pushed yet.
log_msg("  COGs written this run: ", length(written), " of ", length(expected_cogs))
# Every year any live COG holds, not just the years they all hold: a year a
# partial sync left on some COGs must reach all of them, never be dropped (#119).
required_years <- sort(unique(c(as.integer(unlist(live_years)),
                                as.integer(new_years_written))))
problems <- publish_problems(
  written,
  expected = expected_cogs,
  on_disk = list.files(cog_dir, pattern = "\\.tif$"),
  live_keys = live_keys,
  required_years = required_years
)
if (length(problems) > 0) {
  log_msg("ERROR: refusing to build the catalog; no COG or catalog was published.")
  for (p in problems) log_msg("  - ", p)
  finish(1L)
}

cd_stac_catalog(
  cog_dir,
  output_path = catalog_path,
  base_url = paste0("https://", bucket, ".s3.us-west-2.amazonaws.com")
)
# Check the catalog that was written, not only the inputs it was built from.
built <- catalog_item_years(jsonlite::read_json(catalog_path))
problems <- catalog_problems(built$keys, sub("\\.tif$", "", expected_cogs),
                             built$start, built$end, required_years)
if (length(problems) > 0) {
  log_msg("ERROR: the catalog built this run is not the full set; no COG or ",
          "catalog was published.")
  for (p in problems) log_msg("  - ", p)
  unlink(catalog_path)
  finish(1L)
}

# A catalog.json left in cog_dir by a run from before #89 would ride the sync.
unlink(file.path(cog_dir, "catalog.json"))
cd_s3_push(cog_dir, bucket = bucket, dry_run = FALSE)
# On its own and last, for two reasons: the sync is --size-only, and a
# healthy update changes the catalog only from end year 2025 to 2026, the same
# byte count, so the sync would skip it; and uploaded after the COGs, it never
# points at a COG that is not up yet.
cat_put <- suppressWarnings(system2(
  "aws", c("s3", "cp", shQuote(catalog_path),
           shQuote(paste0("s3://", bucket, "/catalog.json"))),
  stdout = TRUE, stderr = TRUE
))
if (!is.null(attr(cat_put, "status"))) {
  log_msg("ERROR: COGs pushed but catalog.json upload failed (exit ",
          attr(cat_put, "status"), "): ", paste(cat_put, collapse = " "))
  log_msg("The live catalog still lists the previous years; the next run's ",
          "STEP 1 will refuse until it is repaired.")
  log_msg("Repair: ", catalog_repair_hint(bucket))
  finish(1L)
}
live_after <- tryCatch(catalog_item_years(jsonlite::read_json(catalog_url)),
                       error = function(e) NULL)
if (!identical(live_after, built)) {
  log_msg("ERROR: catalog.json uploaded, but the live catalog read back does ",
          "not match the one built this run.")
  log_msg("Repair: ", catalog_repair_hint(bucket))
  finish(1L)
}
log_msg("  Live catalog: ", length(built$keys), " items, ",
        min(required_years), "-", max(required_years))
# The catalog is a proxy for the COGs; read the COGs too, uncached, or GDAL
# answers with the headers STEP 1 cached (probed on 3.8.5 and 3.13; each read
# here opens, so stats, first). Every publish, not only a
# repair: it is the one check that the sync put up the whole set. Uncached
# reads are slow (~4 min for 59), and this runs about once a year.
uncache()
after <- live_spans(read_live_years())
if (length(after$problems) > 0 || length(after$ahead) > 0 ||
    !identical(after$common, required_years)) {
  log_msg("ERROR: catalog.json is live, but the COGs read back do not all span ",
          min(required_years), "-", max(required_years), ".")
  for (p in after$problems) log_msg("  - ", p)
  if (length(after$ahead) > 0) {
    log_msg("  - ", length(after$ahead), " COG(s) still ahead of the rest")
  }
  log_msg("  The next run's STEP 1 reports what it finds.")
  finish(1L)
}
log_msg("  Live COGs read back: all ", length(expected_cogs), " span ",
        min(required_years), "-", max(required_years))
partial_live <- FALSE

log_msg("=== UPDATE COMPLETE ===")
log_msg("Years added: ", paste(new_years_written, collapse = ", "))
finish(0L)
