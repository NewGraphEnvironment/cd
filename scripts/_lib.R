# Shared helpers for the cd producer-side R pipeline scripts.
#
# Mirrors scripts/_lib.py on the Python side. These are producer-side
# operational concerns, not consumer API, so they live here rather than in R/.
#
# Everything here is a pure function of its arguments — no network, no I/O — so
# it can be asserted offline. See scripts/test_lib.R.

# Which EDH probe outcomes are worth another attempt.
#
# Status 0 stands for a connection-level failure (DNS, TLS, timeout).
#
# 401 is deliberately absent: retrying a rejected credential only delays the
# report. 403 IS present, which is not the textbook reading — a 403 normally
# means "and it will still be 403 next time". EDH has been observed refusing
# transiently: run 34119315556 died on a 403 at 12:00 UTC on 2026-09-07, and a
# re-dispatch on the same commit and the same secret returned 200 five hours
# later (#82). One blip should not cost a red run and an auto-filed issue.
edh_retryable <- function(status) {
  status == 0L || status %in% c(403L, 408L, 429L) || status >= 500L
}

# What a terminal status actually means.
#
# This is the substance of #83: the probe used to collapse every status >= 400
# into "EDH rejected the token", so a 403 sent the reader off to rotate a secret
# that was in perfect health. The three 4xx cases need three different actions,
# and the message is the only place that difference can be expressed.
edh_diagnosis <- function(status) {
  if (status == 0L) {
    "could not reach the host (DNS, TLS or timeout)."
  } else if (status == 401L) {
    "credential rejected. Rotate the EDH_TOKEN secret."
  } else if (status == 403L) {
    paste0("authenticated but refused — this is NOT a bad token. Check the ",
           "free-tier download quota (it resets at midnight on the 1st) before ",
           "rotating anything. This status has also been transient before, so ",
           "a re-run is worth one attempt.")
  } else if (status == 404L) {
    paste0("not found. The probe URL pins a specific .zarr/.zmetadata path on ",
           "EDH, which may have moved.")
  } else if (status >= 500L) {
    "EDH server error — their side, not ours."
  } else {
    "unexpected status."
  }
}

# The COGs a published catalog must list: every monthly-native variable at every
# aggregation period, plus the annual-only derived snow variables. Both pipeline
# scripts publish exactly this set (59 files with the default config), so both
# derive it here rather than each keeping a copy.
cog_expected <- function(agg_methods, seasons, annual_vars) {
  c(
    as.vector(outer(names(agg_methods), c("annual", names(seasons)),
                    paste, sep = "_")),
    paste0(annual_vars, "_annual")
  ) |> paste0(".tif")
}

# Why a catalog built from this run's COGs must not be published, or
# character(0) when it may be.
#
# The catalog is built from the files in the run's COG directory, and the push
# replaces the live catalog.json outright, so anything this run did not write
# drops out of the published catalog. The COG itself stays on S3 with nothing
# pointing at it (#89). Rather than patching the new catalog together with the
# live one, which would let a skipped variable fall a year behind with nothing
# to say so, refuse unless the run wrote the whole set.
#
#   written        named list, one entry per COG written THIS run (file name ->
#                  band names, which are years). A file merely present in the
#                  directory may be stale from an earlier run, so the caller
#                  passes what it wrote, not what it can list.
#   expected       cog_expected().
#   on_disk        the .tif names actually in the COG directory: what
#                  cd_stac_catalog() will list and cd_s3_push() will upload.
#                  Checked against `expected` as well as `written`, since a
#                  record of a write is not the file.
#   live_keys      "{variable}_{period}" for every item in the live catalog.
#   required_years years every COG must hold: every year any live COG holds
#                  (#119), plus any this run appended.
publish_problems <- function(written, expected, on_disk, live_keys,
                             required_years) {
  problems <- character()
  show <- function(x) {
    paste0(paste(utils::head(x, 5), collapse = ", "),
           if (length(x) > 5) ", ..." else "")
  }

  missing <- setdiff(expected, names(written))
  if (length(missing) > 0) {
    problems <- c(problems, paste0(
      length(missing), " of ", length(expected),
      " COGs not written by this run (", show(missing), ")"
    ))
  }
  extra <- setdiff(names(written), expected)
  if (length(extra) > 0) {
    problems <- c(problems, paste0(
      "COGs written that the catalog does not expect (", show(extra), ")"
    ))
  }
  stale <- setdiff(on_disk, names(written))
  if (length(stale) > 0) {
    problems <- c(problems, paste0(
      length(stale), " .tif file(s) in the COG directory not written by this ",
      "run would be catalogued and pushed (", show(stale), ")"
    ))
  }
  absent <- setdiff(expected, on_disk)
  if (length(absent) > 0) {
    problems <- c(problems, paste0(
      length(absent), " expected COG(s) not in the COG directory, so not ",
      "catalogued (", show(absent), ")"
    ))
  }
  dropped_keys <- setdiff(paste0(live_keys, ".tif"), expected)
  if (length(dropped_keys) > 0) {
    problems <- c(problems, paste0(
      "the live catalog lists item(s) this run cannot publish (",
      show(sub("\\.tif$", "", dropped_keys)), ")"
    ))
  }

  if (length(written) > 0) {
    spans <- unique(lapply(written, function(x) suppressWarnings(as.integer(x))))
    if (length(spans) != 1) {
      problems <- c(problems, "the COGs written this run do not share one span of years")
    } else {
      yrs <- spans[[1]]
      contiguous <- length(yrs) > 0 && !anyNA(yrs) &&
        identical(yrs, seq(min(yrs), max(yrs)))
      if (!contiguous) {
        problems <- c(problems, paste0(
          "the years written this run are not one contiguous, ascending run ",
          "of years (a year was skipped, or a band is not a year)"
        ))
      }
      short <- setdiff(as.integer(required_years), yrs)
      if (length(short) > 0) {
        problems <- c(problems, paste0(
          "the COGs written this run lack ", length(short), " required year(s) (",
          show(sort(short)), "); publishing would drop them"
        ))
      }
    }
  }
  problems
}

# Why a catalog's items are not the set it should list, or character(0).
#
# Run twice per publish: on the LIVE catalog before any work, so a key the
# catalog lacks fails in seconds rather than after hours of fetching, and on
# the catalog just BUILT, before the push, so the check reads the artifact
# rather than the inputs it was built from.
#
#   keys      "{variable}_{period}" per catalog item, in item order.
#   expected  the same form, e.g. sub("\\.tif$", "", cog_expected(...)).
#   start, end  optional: per-item first and last year (from the items'
#             start_datetime / end_datetime); when given, every item must span
#             exactly min(years) to max(years).
catalog_problems <- function(keys, expected, start = NULL, end = NULL,
                             years = NULL) {
  problems <- character()
  show <- function(x) {
    paste0(paste(utils::head(x, 5), collapse = ", "),
           if (length(x) > 5) ", ..." else "")
  }
  dup <- unique(keys[duplicated(keys)])
  if (length(dup) > 0) {
    problems <- c(problems, paste0("duplicate item(s) (", show(dup), ")"))
  }
  missing <- setdiff(expected, keys)
  if (length(missing) > 0) {
    problems <- c(problems, paste0(
      length(missing), " of ", length(expected), " expected item(s) absent (",
      show(missing), ")"
    ))
  }
  extra <- setdiff(keys, expected)
  if (length(extra) > 0) {
    problems <- c(problems, paste0(
      "item(s) outside the expected set (", show(extra), ")"
    ))
  }
  if (!is.null(years)) {
    lo <- min(as.integer(years))
    hi <- max(as.integer(years))
    start <- suppressWarnings(as.integer(start))
    end <- suppressWarnings(as.integer(end))
    if (length(start) != length(keys) || length(end) != length(keys)) {
      problems <- c(problems, "item years do not line up with the items")
    } else if (any(off <- is.na(start) | is.na(end) | start != lo | end != hi)) {
      problems <- c(problems, paste0(
        sum(off), " item(s) do not span ", lo, "-", hi, " (",
        show(keys[off]), ")"
      ))
    }
  }
  problems
}

# The years each live COG holds, reconciled across all of them (#119).
#
# `aws s3 sync` uploads one object at a time, so a STEP 5 sync that dies
# partway leaves some COGs a year ahead of the rest; cd_s3_push() aborts before
# catalog.json goes up, so the catalog still spans the years they all held.
# Reading tmean_annual alone took its end year as everyone's. Instead the update
# targets the years every COG holds, and appends to each only what it lacks.
#
#   cog_years  named list, COG file name -> its band names; NULL for a COG that
#              could not be read.
#
# Returns list(common, ahead, unread, problems):
#   common    integer years every COG holds: the shared first year through the
#             earliest last year.
#   ahead     named list, COG -> the years it holds beyond `common`, for the COGs
#             a partial sync left ahead; empty when they all agree.
#   unread    names of the COGs that could not be read. A separate field because
#             the remedy differs: re-run first, since a read can fail transiently.
#   problems  why the set cannot be repaired by appending, or character(0): a
#             COG that is unreadable, holds a band that is not a year, or is not
#             one contiguous ascending run, or COGs that start in different
#             years. All but the first need stage 3.
live_spans <- function(cog_years) {
  out <- list(common = integer(), ahead = list(), unread = character(),
              problems = character())
  show <- function(x) {
    paste0(paste(utils::head(x, 5), collapse = ", "),
           if (length(x) > 5) ", ..." else "")
  }
  if (length(cog_years) == 0) {
    out$problems <- "no live COGs were read"
    return(out)
  }

  unread <- names(cog_years)[vapply(cog_years, is.null, logical(1))]
  out$unread <- unread
  if (length(unread) > 0) {
    out$problems <- c(out$problems, paste0(
      "could not read ", length(unread), " live COG(s) (", show(unread), ")"
    ))
  }
  read <- cog_years[!vapply(cog_years, is.null, logical(1))]
  years <- lapply(read, function(x) {
    x <- as.character(x)
    if (length(x) == 0 || !all(grepl("^[0-9]{4}$", x))) return(NULL)
    y <- as.integer(x)
    if (!identical(y, seq(min(y), max(y)))) return(NULL)
    y
  })
  bad <- names(years)[vapply(years, is.null, logical(1))]
  if (length(bad) > 0) {
    out$problems <- c(out$problems, paste0(
      length(bad), " live COG(s) do not hold one contiguous, ascending run of ",
      "years (", show(bad), ")"
    ))
  }
  years <- years[!vapply(years, is.null, logical(1))]
  # One start year across all 59 holds because seasonal bands are named for the
  # calendar year their months fall in, winter (DJF) for its January (#89's
  # findings); a convention naming DJF for its December would fail here.
  starts <- vapply(years, min, integer(1))
  if (length(unique(starts)) > 1) {
    # Name the odd ones out: listing every COG would bury them past show()'s 5.
    usual <- as.integer(names(which.max(table(starts))))
    odd <- starts[starts != usual]
    out$problems <- c(out$problems, paste0(
      length(odd), " live COG(s) start in a different year from the other ",
      length(starts) - length(odd), " (", usual, "): ",
      show(paste0(names(odd), " ", odd))
    ))
  }
  if (length(out$problems) > 0) return(out)

  floor_year <- min(vapply(years, max, integer(1)))
  out$common <- seq(starts[[1]], floor_year)
  extra <- lapply(years, function(y) y[y > floor_year])
  out$ahead <- extra[lengths(extra) > 0]
  out
}

# The BC grid every published COG is on (#123): 121 x 261 cells of 0.1 deg,
# the same box `bc_slice()` in scripts/_lib.py cuts from EDH.
bc_grid <- list(nrow = 121L, ncol = 261L,
                ext = c(-140.05, -113.95, 47.95, 60.05))

# Why a set of COGs is not on the BC grid, or character(0) when it is. Reads
# headers only. publish_problems() checks names and years, not geometry, so a
# variable rebuilt on another grid, or one left over from before #123, would
# otherwise be catalogued beside the rest.
grid_problems <- function(paths) {
  bad <- character()
  for (f in paths) {
    r <- tryCatch(terra::rast(f), error = function(e) NULL)
    if (is.null(r)) {
      bad <- c(bad, paste0(basename(f), ": could not be opened"))
      next
    }
    e <- as.vector(terra::ext(r))
    if (terra::nrow(r) != bc_grid$nrow || terra::ncol(r) != bc_grid$ncol ||
        any(abs(e - bc_grid$ext) > 1e-6)) {
      bad <- c(bad, sprintf("%s: %d x %d, extent %s", basename(f),
                            terra::nrow(r), terra::ncol(r),
                            paste(signif(e, 7), collapse = " ")))
    }
  }
  if (length(bad) == 0L) return(character(0))
  paste0(length(bad), " COG(s) not on the BC grid (", bc_grid$nrow, " x ",
         bc_grid$ncol, ", extent ", paste(bc_grid$ext, collapse = " "), "): ",
         paste(utils::head(bad, 5), collapse = "; "),
         if (length(bad) > 5) "; ..." else "")
}

# First and last year of each item in a STAC catalog written by
# cd_stac_catalog(), read from the JSON itself; NA where a date is absent.
catalog_item_years <- function(catalog_json) {
  yr <- function(x) if (is.null(x)) NA_integer_ else as.integer(substr(x, 1, 4))
  items <- catalog_json$items
  key <- function(i) {
    paste(i$properties$`cd:variable`, i$properties$`cd:period`, sep = "_")
  }
  list(
    keys = vapply(items, key, character(1)),
    start = vapply(items, function(i) yr(i$properties$start_datetime), integer(1)),
    end = vapply(items, function(i) yr(i$properties$end_datetime), integer(1))
  )
}

# How to rebuild the live catalog from the live COGs, for a run that finds it
# out of step with them. Needs no backfill data: only the 59 published COGs,
# which carry their years in their band names. Only when they all end in the
# same year: built from COGs a partial sync left out of step, the catalog
# would list mixed spans (#119). A COG that is itself missing or short needs
# scripts/pipeline_stage3_edh.R instead.
catalog_repair_hint <- function(bucket) {
  paste0(
    "if every live COG ends in the same year: ",
    "aws s3 sync s3://", bucket, "/ <dir> --exclude '*' --include '*.tif' ",
    "--exclude 'daily/*' --exclude '_backup/*' --exclude '_healthcheck/*'; ",
    "then in R cd::cd_stac_catalog('<dir>', output_path = '<dir>.json'); ",
    "then aws s3 cp <dir>.json s3://", bucket, "/catalog.json. ",
    "If a COG is missing or short, or they end in different years, rebuild ",
    "with scripts/pipeline_stage3_edh.R."
  )
}

# The provenance every published COG carries as GDAL tags (#124): which cd
# built it, from which commit, in which run. Read from the environment and the
# working tree, so unlike the helpers above it is not a pure function.
#
#   CD_VERSION   Version: in DESCRIPTION (cwd is the repo root, as for every
#                pipeline script).
#   CD_SHA       GITHUB_SHA in CI; locally `git rev-parse HEAD`, with "-dirty"
#                when the tree has uncommitted changes, since a local build
#                from an edited tree is not the commit it names. "unknown"
#                when neither is available.
#   CD_RUN_TIME  CD_RUN_TIME from the environment when set, else now. The
#                pipelines set it once at start, so every COG of one run, and
#                the daily cube's Python children, carry the same time.
#   CD_RUN_ID    GITHUB_RUN_ID in CI, else "local".
#
# The same keys and the same environment contract as run_provenance() in
# scripts/_lib.py.
run_provenance <- function() {
  env <- function(x) {
    v <- Sys.getenv(x)
    if (nzchar(v)) v else NA_character_
  }
  sha <- env("GITHUB_SHA")
  if (is.na(sha)) {
    head <- suppressWarnings(system2("git", c("rev-parse", "HEAD"),
                                     stdout = TRUE, stderr = FALSE))
    is_sha <- is.null(attr(head, "status")) && length(head) == 1L &&
      grepl("^[0-9a-f]{40}$", head)
    if (is_sha) {
      dirty <- suppressWarnings(system2("git", c("status", "--porcelain"),
                                        stdout = TRUE, stderr = FALSE))
      # A failed status is not a clean tree; _lib.py says "unknown" too.
      sha <- if (!is.null(attr(dirty, "status"))) {
        "unknown"
      } else {
        paste0(head, if (length(dirty) > 0) "-dirty" else "")
      }
    } else {
      sha <- "unknown"
    }
  }
  run_time <- env("CD_RUN_TIME")
  if (is.na(run_time)) {
    run_time <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  }
  c(
    CD_VERSION = unname(read.dcf("DESCRIPTION", fields = "Version")[1, 1]),
    CD_SHA = sha,
    CD_RUN_TIME = run_time,
    CD_RUN_ID = if (is.na(env("GITHUB_RUN_ID"))) "local" else env("GITHUB_RUN_ID")
  )
}

# The provenance tags every published file must carry (#124).
prov_keys <- c("CD_VERSION", "CD_SHA", "CD_RUN_TIME", "CD_RUN_ID")

# sha256 of a file as a hex multihash, "1220" + digest: the form
# file:checksum takes. Computed here rather than through cd's internal
# file_multihash(), so the check does not share the code it checks.
multihash <- function(path) {
  con <- file(path, open = "rb")
  on.exit(close(con))
  paste0("1220", as.character(openssl::sha256(con)))
}

# Whether a value is one sha256 multihash, the shape file:checksum must have.
is_multihash <- function(x) {
  is.character(x) && length(x) == 1L && grepl("^1220[0-9a-f]{64}$", x)
}

# Why a set of published entries does not describe the files on disk, or
# character(0) when every one does. Recomputes each hash from the bytes.
#
#   entries  named list, file name -> list(`file:checksum`, `file:size`):
#            catalog_entries() of a catalog, or a daily manifest's `files`.
#   dir      where those files are.
#   names    the file names to check; default all of them. A daily manifest
#            carries every published year, while a CI runner holds only the
#            ones it built, so STEP D checks the local ones.
checksum_problems <- function(entries, dir, names = base::names(entries)) {
  bad <- character()
  for (n in names) {
    e <- entries[[n]]
    f <- file.path(dir, n)
    ck <- e$`file:checksum`
    if (is.null(e)) {
      bad <- c(bad, paste0(n, ": no entry"))
    } else if (!file.exists(f)) {
      bad <- c(bad, paste0(n, ": not on disk"))
    } else if (!is_multihash(ck)) {
      bad <- c(bad, paste0(n, ": file:checksum is not a sha256 multihash (",
                           paste(ck, collapse = " "), ")"))
    } else if (!identical(as.numeric(e$`file:size`), as.numeric(file.size(f)))) {
      bad <- c(bad, paste0(n, ": file:size ", paste(e$`file:size`, collapse = " "),
                           ", file is ", file.size(f)))
    } else if (!identical(ck, multihash(f))) {
      bad <- c(bad, paste0(n, ": file:checksum does not match the file"))
    }
  }
  if (length(bad) == 0L) return(character(0))
  paste0(length(bad), " of ", length(names), " file(s) not as published: ",
         paste(utils::head(bad, 5), collapse = "; "),
         if (length(bad) > 5) "; ..." else "")
}

# A catalog's data assets as checksum_problems() entries, keyed by file name.
catalog_entries <- function(catalog_json) {
  stats::setNames(
    lapply(catalog_json$items, function(i) i$assets$data),
    vapply(catalog_json$items, function(i) basename(i$assets$data$href), character(1))
  )
}

# Why a set of files does not all carry run provenance, or character(0). An
# absent or empty tag fails: a file from before #124, or one written without
# tags=, would publish a checksum with nothing saying what made the bytes.
provenance_problems <- function(paths) {
  bad <- character()
  for (f in paths) {
    r <- tryCatch(terra::rast(f), error = function(e) NULL)
    if (is.null(r)) {
      bad <- c(bad, paste0(basename(f), ": could not be opened"))
      next
    }
    # NULL, not a zero-row frame, for a raster with no tags at all.
    m <- terra::metags(r)
    if (is.null(m)) m <- data.frame(name = character(), value = character())
    v <- as.character(m$value)[match(prov_keys, as.character(m$name))]
    missing <- prov_keys[is.na(v) | !nzchar(v)]
    if (length(missing) > 0) {
      bad <- c(bad, paste0(basename(f), " (", paste(missing, collapse = ", "), ")"))
    }
  }
  if (length(bad) == 0L) return(character(0))
  paste0(length(bad), " file(s) lack run provenance tags: ",
         paste(utils::head(bad, 5), collapse = "; "),
         if (length(bad) > 5) "; ..." else "")
}

# A run's provenance, with its time fixed once for this process and for every
# child it starts (the daily cube's Python backfill reads CD_RUN_TIME), so one
# run's files all carry one time.
run_start <- function() {
  if (!nzchar(Sys.getenv("CD_RUN_TIME"))) {
    Sys.setenv(CD_RUN_TIME = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  }
  run_provenance()
}

# Why a run may not publish under this provenance, or character(0). A SHA
# that is "unknown", or "-dirty", names no commit that holds the code that
# made the bytes. Checked before a live push only: a dry run publishes nothing.
sha_problems <- function(prov) {
  sha <- prov[["CD_SHA"]]
  if (identical(sha, "unknown") || grepl("-dirty$", sha)) {
    return(paste0("CD_SHA is ", sha, ": commit the working tree (or run from ",
                  "CI) so the published files name the commit that made them"))
  }
  character(0)
}

# Why a publish directory holds something no catalog or manifest entry names,
# or character(0). The sync uploads every file but the ones it excludes
# (hidden files and *.aux.json, as cd_s3_push() does), so anything else would
# reach S3 described by nothing.
stray_problems <- function(dir, names) {
  on_disk <- list.files(dir, recursive = TRUE)
  on_disk <- on_disk[!grepl("\\.aux\\.json$", on_disk)]
  stray <- setdiff(on_disk, names)
  if (length(stray) == 0L) return(character(0))
  paste0(length(stray), " file(s) in ", dir, " that nothing published ",
         "describes would be uploaded (",
         paste(utils::head(stray, 5), collapse = ", "),
         if (length(stray) > 5) ", ..." else "", ")")
}

# Whether a file is the object S3 reports by `etag`. A single-part upload's
# ETag is the MD5 of the bytes (SSE-S3, as on this bucket); a multipart one is
# the MD5 of the concatenated part MD5s, then "-<parts>". The part size is the
# uploading machine's `multipart_chunksize` (8 MiB by default; this machine's
# ~/.aws/config says 128 MB), so every size that gives that many parts is
# tried. Measured: daily/tmax_daily_2000.tif, 9,263,371 bytes, is "-2" at
# 8 MiB and matches the local file.
s3_etag_matches <- function(path, etag) {
  etag <- gsub('"', "", etag)
  if (is.na(etag) || !nzchar(etag)) return(FALSE)
  md5_file <- function(f) {
    con <- file(f, open = "rb")
    on.exit(close(con))
    # as.character() keeps openssl's "hash" attributes, which identical() sees.
    as.vector(as.character(openssl::md5(con)))
  }
  if (!grepl("-", etag, fixed = TRUE)) return(identical(etag, md5_file(path)))
  n <- as.integer(sub(".*-", "", etag))
  size <- file.size(path)
  mib <- 1024^2
  chunks <- c(5 * mib, 2^(3:12) * mib, 8e6, 16e6, 64e6, 128e6)
  chunks <- unique(chunks[ceiling(size / chunks) == n])
  for (chunk in chunks) {
    con <- file(path, open = "rb")
    parts <- list()
    repeat {
      b <- readBin(con, "raw", chunk)
      if (length(b) == 0L) break
      parts[[length(parts) + 1L]] <- as.raw(openssl::md5(b))
    }
    close(con)
    if (identical(paste0(as.character(openssl::md5(do.call(c, parts))), "-", n), etag)) {
      return(TRUE)
    }
  }
  FALSE
}

# -- Daily cube manifest (#124) -------------------------------------------------
# The daily cube is not in catalog.json, so s3://<bucket>/daily/manifest.json
# carries what the catalog carries for the monthly COGs: per file, its size,
# sha256 multihash and the provenance tags of the run that wrote it.

# Manifest entries for local files, keyed by file name.
manifest_entries <- function(paths) {
  out <- lapply(paths, function(f) {
    m <- terra::metags(terra::rast(f))
    tag <- function(key) {
      v <- as.character(m$value)[as.character(m$name) == key]
      if (length(v) == 1L && nzchar(v)) v else NULL
    }
    Filter(Negate(is.null), list(
      `file:checksum` = multihash(f),
      `file:size` = file.size(f),
      `cd:version` = tag("CD_VERSION"),
      `cd:sha` = tag("CD_SHA"),
      `cd:run_time` = tag("CD_RUN_TIME"),
      `cd:run_id` = tag("CD_RUN_ID")
    ))
  })
  stats::setNames(out, basename(paths))
}

# The live manifest's entries with this run's local ones laid over them, keys
# in a locale-independent order so the file does not reorder between a Mac
# and CI.
manifest_merge <- function(live, local) {
  merged <- if (is.null(live)) list() else live
  for (n in names(local)) merged[[n]] <- local[[n]]
  merged[sort(names(merged), method = "radix")]
}

# Why a manifest's entries are not one whole cube, or character(0): every
# variable for every year of one contiguous span, nothing else, each entry
# shaped as published.
manifest_problems <- function(entries, vars = c("tmean", "tmax", "tmin")) {
  problems <- character()
  keys <- names(entries)
  if (length(keys) == 0L) return("the manifest lists no files")
  pat <- paste0("^(", paste(vars, collapse = "|"), ")_daily_([0-9]{4})\\.tif$")
  odd <- keys[!grepl(pat, keys)]
  if (length(odd) > 0) {
    problems <- c(problems, paste0("entries that are not daily cube files (",
                                   paste(utils::head(odd, 5), collapse = ", "), ")"))
  }
  years <- as.integer(sub(pat, "\\2", keys[grepl(pat, keys)]))
  if (length(years) > 0) {
    want <- as.vector(outer(vars, seq(min(years), max(years)),
                            function(v, y) paste0(v, "_daily_", y, ".tif")))
    missing <- setdiff(want, keys)
    if (length(missing) > 0) {
      problems <- c(problems, paste0(
        length(missing), " file(s) missing from the span ", min(years), "-",
        max(years), " (", paste(utils::head(missing, 5), collapse = ", "),
        if (length(missing) > 5) ", ..." else "", ")"
      ))
    }
  }
  bad <- keys[!vapply(entries, function(e) {
    ck <- e$`file:checksum`
    sz <- e$`file:size`
    is.character(ck) && length(ck) == 1L && grepl("^1220[0-9a-f]{64}$", ck) &&
      is.numeric(sz) && length(sz) == 1L && sz > 0
  }, logical(1))]
  if (length(bad) > 0) {
    problems <- c(problems, paste0("entries without a sha256 multihash and size (",
                                   paste(utils::head(bad, 5), collapse = ", "), ")"))
  }
  problems
}

# The last year a manifest holds every variable for, or NA.
manifest_last_year <- function(entries) {
  keys <- names(entries)
  y <- suppressWarnings(as.integer(sub("^.*_daily_([0-9]{4})\\.tif$", "\\1", keys)))
  if (length(y) == 0L || all(is.na(y))) NA_integer_ else max(y, na.rm = TRUE)
}
