#!/usr/bin/env Rscript
#
# pipeline_update_edh.R
#
# Incremental monthly update via DestinE Earth Data Hub.
# Replaces the CDS-based pipeline_update.R.
#
# Flow:
#   1. Read STAC catalog from S3 → find latest year already published
#   2. Determine target year (latest complete year available on EDH)
#   3. If behind, call scripts/backfill_edh_all.py AND backfill_edh_snow.py
#      for each missing year (both idempotent — Python scripts skip files
#      that already exist).
#   4. For each variable × period, read existing COG from S3 via /vsicurl,
#      append the new year (cd_aggregate for monthly natives; direct stack
#      for annual-derived snow scalars), write locally, push to S3.
#   5. Rebuild catalog, push to S3.
#
# Designed for the monthly GitHub Action (climate-update.yml). Exits
# cleanly with status 0 if nothing new is available.
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
# rebuild, no S3 publish. climate-update.yml runs it weekly as a heartbeat (#78).

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

log_msg("Mode: ", if (dry_run) "DRY RUN (no fetch, no write, no publish)" else "LIVE")

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
edh_res <- tryCatch(
  curl::curl_fetch_memory(
    edh_probe_url,
    # httpauth = 1L is CURLAUTH_BASIC. Without it libcurl waits for a
    # WWW-Authenticate challenge that EDH does not send, and the probe 401s
    # against an endpoint that plain `curl -u` reaches fine.
    handle = curl::new_handle(
      nobody = TRUE, username = "edh", password = edh_token, httpauth = 1L
    )
  ),
  error = function(e) {
    log_msg("ERROR: could not reach data.earthdatahub.destine.eu — ", conditionMessage(e))
    quit(status = 1)
  }
)
if (edh_res$status_code >= 400) {
  log_msg("ERROR: EDH rejected the token (HTTP ", edh_res$status_code, ").")
  quit(status = 1)
}
log_msg("  EDH: OK (HTTP ", edh_res$status_code, ")")

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
run_id <- Sys.getenv("GITHUB_RUN_ID", unset = as.character(Sys.getpid()))
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

# -- Step 1: determine state ---------------------------------------------------
log_msg("=== STEP 1: Check S3 catalog for latest year ===")

catalog <- tryCatch(
  cd_catalog(catalog_url),
  error = function(e) {
    log_msg("No catalog at ", catalog_url, " — run full backfill first (scripts/backfill_edh_all.py + pipeline_stage3_edh.R)")
    quit(status = 1)
  }
)

# Read one COG to find latest year
tmean_row <- catalog[catalog$variable == "tmean" & catalog$period == "annual", ]
if (nrow(tmean_row) == 0) {
  log_msg("No tmean_annual in catalog — run full backfill first")
  quit(status = 1)
}
r_current <- rast(paste0("/vsicurl/", tmean_row$href))
current_years <- as.integer(names(r_current))
latest_year <- max(current_years, na.rm = TRUE)
log_msg("Latest year on S3: ", latest_year)

# -- Step 2: target year ------------------------------------------------------
# ERA5-Land has ~2-3 month latency. Try the current year — if EDH has all
# 12 months, backfill_edh_all.py writes; otherwise it skips cleanly and we
# move on. Also try latest_year + 1 in case we're behind for another reason.
current_year <- as.integer(format(Sys.Date(), "%Y"))
if (latest_year >= current_year) {
  log_msg("Already at or past current year (", latest_year, " >= ", current_year, ")")
  log_msg("Nothing to do.")
  quit(status = 0)
}
candidate_years <- seq(latest_year + 1, current_year)
log_msg("Candidate years to fetch: ", paste(candidate_years, collapse = ", "))

if (dry_run) {
  log_msg("=== DRY RUN COMPLETE ===")
  log_msg("Credentials, catalog read and target-year computation all succeeded.")
  log_msg("A live run would now fetch ", paste(candidate_years, collapse = ", "),
          " via EDH, append any complete years to the ",
          length(agg_methods) + length(annual_vars),
          " variable COGs, and publish to s3://", bucket, ".")
  quit(status = 0)
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
  # scripts skip incomplete years (n_months != 12); a missing file means the
  # year wasn't ready on EDH yet.
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

if (length(new_years_written) == 0) {
  if (any_fetch_errored) {
    log_msg("ERROR: attempted fetch(es) errored and no new years were written.")
    log_msg("Exiting non-zero so the run is visibly failed.")
    quit(status = 1)
  }
  log_msg("No new complete years available on EDH yet (latency is normal).")
  quit(status = 0)
}
log_msg("New years to integrate: ", paste(new_years_written, collapse = ", "))

# -- Step 4: rebuild COGs (existing from S3 + new years) ----------------------
log_msg("=== STEP 4: Append new years to existing COGs ===")

# Helper: append the new years to an existing S3 COG and write locally.
# Used for both monthly natives (after cd_aggregate) and annual derived
# (1-band straight read) — caller computes new_layers, this checks grid
# alignment and writes.
append_to_cog <- function(var, period, new_layers, existing_row) {
  if (length(new_layers) == 0) return(invisible(NULL))
  cog_name <- paste0(var, "_", period, ".tif")
  cog_path <- file.path(cog_dir, cog_name)
  existing_rast <- tryCatch(
    rast(paste0("/vsicurl/", existing_row$href)),
    error = function(e) stop("Failed to read existing COG: ",
                             existing_row$href, "\nError: ", e$message,
                             call. = FALSE)
  )
  new_rast <- rast(new_layers)
  names(new_rast) <- names(new_layers)
  if (!isTRUE(all.equal(as.vector(ext(existing_rast)),
                        as.vector(ext(new_rast)), tolerance = 1e-6)) ||
      !isTRUE(all.equal(res(existing_rast), res(new_rast), tolerance = 1e-6))) {
    stop("Grid mismatch between existing COG (", existing_row$href,
         ") and new ", var, "_", period,
         ". Extent/res differ. Aborting.", call. = FALSE)
  }
  combined <- c(existing_rast, new_rast)
  cd_cog_write(combined, cog_path, overwrite = TRUE)
  log_msg("  Updated: ", cog_name, " (", nlyr(combined), " years total)")
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
      if (!file.exists(mf)) next
      r_m <- rast(mf)
      if (nlyr(r_m) != 12) next
      periods <- cd_aggregate(r_m, method = method, seasons = seasons)
      if (period %in% names(periods)) {
        new_layers[[as.character(yr)]] <- periods[[period]]
      }
    }
    append_to_cog(var, period, new_layers, existing_row)
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
    if (!file.exists(af)) next
    r <- rast(af)
    if (nlyr(r) != 1) next
    new_layers[[as.character(yr)]] <- r
  }
  append_to_cog(var, "annual", new_layers, existing_row)
}

# -- Step 5: rebuild catalog + push -------------------------------------------
log_msg("=== STEP 5: Rebuild catalog + push to S3 ===")
cd_stac_catalog(
  cog_dir,
  output_path = file.path(cog_dir, "catalog.json"),
  base_url = paste0("https://", bucket, ".s3.us-west-2.amazonaws.com")
)
cd_s3_push(cog_dir, bucket = bucket, dry_run = FALSE)

log_msg("=== UPDATE COMPLETE ===")
log_msg("Years added: ", paste(new_years_written, collapse = ", "))
