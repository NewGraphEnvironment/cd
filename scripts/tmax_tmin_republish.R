#!/usr/bin/env Rscript
#
# tmax_tmin_republish.R
#
# One-off republish of the 10 tmax/tmin COGs on local days (#37). Replaces
# s3://stac-era5-land/{tmax,tmin}_{annual,winter,spring,summer,fall}.tif, built
# until #37 from UTC-day max/min, with the same COGs built from
# data/backfill/monthly/{tmax,tmin}_YYYY.tif (scripts/backfill_edh_tmax_tmin.py,
# local days at UTC-8). Nothing else in the bucket is touched.
#
# Why not pipeline_stage3_edh.R: it rebuilds catalog.json from the local COG
# directory, so with only tmax/tmin present it would publish a 10-item
# catalog, and cd_s3_push() syncs --size-only, which skips a rebuilt file
# whose byte size happens to match. Here catalog.json is left alone: the
# script asserts the years, extent and resolution are unchanged, which is all
# the catalog records about these files.
#
# Steps:
#   1. Build the 10 COGs locally (cd_aggregate + cd_cog_write, as stage 3).
#   2. Back up the live 10 (bucket versioning is suspended, so an overwrite is
#      otherwise final): locally, and to s3://<bucket>/_backup/tmax_tmin_utc_day/.
#      Neither backup is ever overwritten, so a re-run cannot replace the UTC
#      originals with already-republished files.
#   3. Assert each new COG matches its live counterpart's grid and band names,
#      and write the old -> new difference per COG to diff_summary.csv.
#   4. Upload with `aws s3 cp`, verify each object's ETag against the local
#      MD5, then read one back over /vsicurl/.
#
# Run the live publish when the code that writes local-day tmax/tmin is on
# main, not before: from the publish on, CI must append local-day years.
# To restore the UTC-day originals, copy s3://<bucket>/_backup/tmax_tmin_utc_day/*
# back over the 10 keys.
#
# Usage:
#   Rscript scripts/tmax_tmin_republish.R --dry-run   # steps 1, 3 and the local backup
#   Rscript scripts/tmax_tmin_republish.R

if (requireNamespace("cd", quietly = TRUE)) {
  library(cd)
} else if (requireNamespace("devtools", quietly = TRUE)) {
  devtools::load_all()
} else {
  stop("cd is not installed and devtools is unavailable to load_all() it.",
       call. = FALSE)
}
suppressMessages(library(terra))

args <- commandArgs(trailingOnly = TRUE)
dry_run <- "--dry-run" %in% args

bucket <- "stac-era5-land"
base_url <- paste0("https://", bucket, ".s3.us-west-2.amazonaws.com")
backup_prefix <- "_backup/tmax_tmin_utc_day"
monthly_dir <- "data/backfill/monthly"
work_dir <- "data/backfill/republish_37"
new_dir <- file.path(work_dir, "local_day")
old_dir <- file.path(work_dir, "utc_day_backup")
vars <- c("tmax", "tmin")
seasons <- cd_seasons()
periods <- c("annual", names(seasons))

log_msg <- function(...) {
  cat(sprintf("[%s] %s\n", format(Sys.time(), "%H:%M:%S"), paste0(...)))
}

# Exit status of an aws call, with its output kept for the log.
aws <- function(...) {
  out <- suppressWarnings(system2("aws", c(...), stdout = TRUE, stderr = TRUE))
  st <- attr(out, "status")
  list(ok = is.null(st), out = out)
}

s3_exists <- function(key) {
  aws("s3api", "head-object", "--bucket", bucket, "--key", key)$ok
}

s3_etag <- function(key) {
  res <- aws("s3api", "head-object", "--bucket", bucket, "--key", key,
             "--query", "ETag", "--output", "text")
  if (!res$ok) return(NA_character_)
  gsub('"', "", res$out[length(res$out)])
}

md5 <- function(path) unname(tools::md5sum(path))

dir.create(new_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(old_dir, recursive = TRUE, showWarnings = FALSE)

# -- 1. Build ------------------------------------------------------------------
log_msg("=== 1. Build local-day COGs from ", monthly_dir, " ===")
new_paths <- character()
for (var in vars) {
  files <- list.files(monthly_dir, pattern = paste0("^", var, "_\\d{4}\\.tif$"),
                      full.names = TRUE)
  years <- sort(as.integer(sub(paste0("^", var, "_(\\d{4})\\.tif$"), "\\1",
                               basename(files))))
  if (length(years) == 0) stop("No monthly ", var, " files in ", monthly_dir,
                               "; run scripts/backfill_edh_tmax_tmin.py", call. = FALSE)
  if (!identical(years, seq(min(years), max(years)))) {
    stop(var, ": monthly years are not contiguous: ",
         paste(setdiff(seq(min(years), max(years)), years), collapse = ", "),
         " missing", call. = FALSE)
  }
  per_year <- lapply(years, function(yr) {
    r <- rast(file.path(monthly_dir, paste0(var, "_", yr, ".tif")))
    if (nlyr(r) != 12) stop(var, " ", yr, ": ", nlyr(r), " layers, need 12", call. = FALSE)
    cd_aggregate(r, method = "mean", seasons = seasons)
  })
  for (period in periods) {
    multi <- rast(lapply(per_year, `[[`, period))
    names(multi) <- as.character(years)
    path <- file.path(new_dir, paste0(var, "_", period, ".tif"))
    cd_cog_write(multi, path, overwrite = TRUE)
    new_paths[[paste0(var, "_", period)]] <- path
  }
  log_msg("  ", var, ": ", length(years), " years (", min(years), "-", max(years),
          ") x ", length(periods), " periods")
}

# -- 2. Back up the live COGs (local copy) -------------------------------------
log_msg("=== 2. Back up live COGs ===")
catalog <- cd_catalog()
for (nm in names(new_paths)) {
  key <- basename(new_paths[[nm]])
  row <- catalog[paste0(catalog$variable, "_", catalog$period) == nm, ]
  if (nrow(row) != 1) stop(nm, ": expected 1 catalog row, found ", nrow(row), call. = FALSE)
  if (!identical(row$href, paste0(base_url, "/", key))) {
    stop(nm, ": catalog href ", row$href, " is not ", base_url, "/", key, call. = FALSE)
  }
  local_old <- file.path(old_dir, key)
  if (file.exists(local_old)) {
    log_msg("  ", key, ": local backup exists, kept")
    next
  }
  # A live object that already carries the S3 backup's twin would mean the
  # live one was republished; never take a local backup from it.
  if (s3_exists(file.path(backup_prefix, key))) {
    res <- aws("s3", "cp", "--only-show-errors",
               paste0("s3://", bucket, "/", backup_prefix, "/", key), local_old)
  } else {
    res <- aws("s3", "cp", "--only-show-errors", paste0("s3://", bucket, "/", key),
               local_old)
  }
  if (!res$ok) stop(key, ": backup download failed:\n", paste(res$out, collapse = "\n"),
                    call. = FALSE)
  log_msg("  ", key, ": backed up locally")
}

# -- 3. Compare ----------------------------------------------------------------
log_msg("=== 3. Compare grid, years and values ===")
band_mean <- function(r) global(r, "mean", na.rm = TRUE)$mean
summary_rows <- list()
for (nm in names(new_paths)) {
  key <- basename(new_paths[[nm]])
  new <- rast(new_paths[[nm]])
  old <- rast(file.path(old_dir, key))
  if (!identical(names(new), names(old))) {
    stop(key, ": band names differ (new ", names(new)[1], "..", tail(names(new), 1),
         ", live ", names(old)[1], "..", tail(names(old), 1), ")", call. = FALSE)
  }
  if (!isTRUE(compareGeom(new, old, stopOnError = FALSE))) {
    stop(key, ": grid differs from the live COG", call. = FALSE)
  }
  na_new <- global(is.na(new[[1]]), "sum")$sum
  na_old <- global(is.na(old[[1]]), "sum")$sum
  if (na_new != na_old) stop(key, ": NA cells differ (", na_new, " vs ", na_old, ")",
                             call. = FALSE)
  d <- new - old
  shift <- band_mean(d)
  summary_rows[[nm]] <- data.frame(
    cog = key,
    years = nlyr(new),
    mean_shift_c = mean(shift),
    min_year_shift_c = min(shift),
    max_year_shift_c = max(shift),
    max_abs_cell_c = max(abs(unlist(global(d, range, na.rm = TRUE)))),
    old_mean_c = mean(band_mean(old)),
    new_mean_c = mean(band_mean(new))
  )
}
diff_summary <- do.call(rbind, summary_rows)
rownames(diff_summary) <- NULL
write.csv(diff_summary, file.path(work_dir, "diff_summary.csv"), row.names = FALSE)
print(format(diff_summary, digits = 3), row.names = FALSE)

if (dry_run) {
  log_msg("=== DRY RUN: nothing uploaded. New COGs in ", new_dir, " ===")
  quit(status = 0)
}

# -- 2b. Back up to S3 (never overwritten) -------------------------------------
log_msg("=== 2b. Back up live COGs to s3://", bucket, "/", backup_prefix, "/ ===")
for (nm in names(new_paths)) {
  key <- basename(new_paths[[nm]])
  bkey <- file.path(backup_prefix, key)
  if (s3_exists(bkey)) {
    log_msg("  ", bkey, ": exists, kept")
    next
  }
  local_old <- file.path(old_dir, key)
  # The local backup must still be what is live, or it is not a backup of it.
  if (!identical(md5(local_old), s3_etag(key))) {
    stop(key, ": local backup does not match the live object; refusing to back it up",
         call. = FALSE)
  }
  res <- aws("s3", "cp", "--only-show-errors", local_old, paste0("s3://", bucket, "/", bkey))
  if (!res$ok || !identical(s3_etag(bkey), md5(local_old))) {
    stop(bkey, ": backup upload failed or does not verify", call. = FALSE)
  }
  log_msg("  ", bkey, ": uploaded and verified")
}

# -- 4. Upload and verify ------------------------------------------------------
log_msg("=== 4. Upload local-day COGs ===")
# ETag equals the MD5 only for a single-part upload, i.e. under the CLI's
# 8 MiB multipart threshold; above it every check below would fail spuriously.
too_big <- new_paths[file.size(new_paths) >= 8 * 1024^2]
if (length(too_big) > 0) {
  stop("Over the 8 MiB multipart threshold, so ETag != MD5: ",
       paste(basename(too_big), collapse = ", "), call. = FALSE)
}
for (nm in names(new_paths)) {
  path <- new_paths[[nm]]
  key <- basename(path)
  if (identical(s3_etag(key), md5(path))) {
    log_msg("  ", key, ": live object already identical, skipped")
    next
  }
  res <- aws("s3", "cp", "--only-show-errors", "--content-type", "image/tiff",
             path, paste0("s3://", bucket, "/", key))
  if (!res$ok) stop(key, ": upload failed:\n", paste(res$out, collapse = "\n"), call. = FALSE)
  if (!identical(s3_etag(key), md5(path))) {
    stop(key, ": uploaded object's ETag does not match the local MD5", call. = FALSE)
  }
  log_msg("  ", key, ": uploaded, ETag verified")
}

# One read back the way consumers read it, through /vsicurl/.
probe <- new_paths[["tmax_summer"]]
remote <- rast(paste0("/vsicurl/", base_url, "/", basename(probe)))
if (!isTRUE(all.equal(values(remote[[nlyr(remote)]]), values(rast(probe)[[nlyr(remote)]])))) {
  stop("Read-back over /vsicurl/ does not match ", basename(probe), call. = FALSE)
}
log_msg("  /vsicurl/ read-back of ", basename(probe), " matches")
log_msg("=== DONE: 10 COGs republished on local days; catalog.json unchanged ===")
