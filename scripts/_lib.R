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
#   required_years years every COG must hold: the live years, plus any this
#                  run appended.
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
# Returns list(common, ahead, problems):
#   common    integer years every COG holds: the shared first year through the
#             earliest last year.
#   ahead     named list, COG -> the years it holds beyond `common`, for the COGs
#             a partial sync left ahead; empty when they all agree.
#   problems  why the set cannot be repaired by appending, or character(0). A
#             COG that is unreadable, holds a band that is not a year, or is not
#             one contiguous ascending run, or COGs that start in different
#             years, all need stage 3.
live_spans <- function(cog_years) {
  out <- list(common = integer(), ahead = list(), problems = character())
  show <- function(x) {
    paste0(paste(utils::head(x, 5), collapse = ", "),
           if (length(x) > 5) ", ..." else "")
  }
  if (length(cog_years) == 0) {
    out$problems <- "no live COGs were read"
    return(out)
  }

  unread <- names(cog_years)[vapply(cog_years, is.null, logical(1))]
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
# which carry their years in their band names. A COG that is itself missing or
# short needs scripts/pipeline_stage3_edh.R instead.
catalog_repair_hint <- function(bucket) {
  paste0(
    "aws s3 sync s3://", bucket, "/ <dir> --exclude '*' --include '*.tif' ",
    "--exclude 'daily/*' --exclude '_backup/*' --exclude '_healthcheck/*'; ",
    "then in R cd::cd_stac_catalog('<dir>', output_path = '<dir>.json'); ",
    "then aws s3 cp <dir>.json s3://", bucket, "/catalog.json. ",
    "If a COG is missing or short, rebuild with scripts/pipeline_stage3_edh.R."
  )
}
