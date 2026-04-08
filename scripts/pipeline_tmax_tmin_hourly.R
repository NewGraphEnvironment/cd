#!/usr/bin/env Rscript
#
# pipeline_tmax_tmin_hourly.R
#
# Download hourly 2m_temperature from ERA5-Land, compute daily max/min,
# aggregate to monthly mean of daily max/min, then seasonal/annual COGs.
#
# This bypasses the slow `derived-era5-land-daily-statistics` product
# by doing the max/min computation locally instead of on CDS servers.
#
# Idempotent — skips months already downloaded.
#
# Usage:
#   Rscript scripts/pipeline_tmax_tmin_hourly.R
#
# Output:
#   data/backfill/raw/hourly/  — raw hourly GRIB files (month-by-month)
#   data/backfill/monthly/     — tmax_YYYY.tif, tmin_YYYY.tif (12 monthly layers each)
#   data/backfill/cogs/        — tmax_annual.tif, tmin_summer.tif, etc.

if (requireNamespace("cd", quietly = TRUE)) {
  library(cd)
} else {
  devtools::load_all()
}
library(terra)
library(ecmwfr)

# -- Logging -------------------------------------------------------------------
log_msg <- function(...) {
  msg <- paste0("[", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "] ", ...)
  message(msg)
}

status <- new.env(parent = emptyenv())
status$downloaded <- 0L
status$skipped <- 0L
status$failed <- character()
status$started <- Sys.time()

# -- Configuration ------------------------------------------------------------
years <- 1950:2025
bbox <- c(60, -140, 48, -114)
retry_interval <- 60
bucket <- "stac-era5-land"

hourly_dir <- "data/backfill/raw/hourly"
monthly_dir <- "data/backfill/monthly"
cog_dir <- "data/backfill/cogs"
seasons <- cd_seasons()

dir.create(hourly_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(monthly_dir, recursive = TRUE, showWarnings = FALSE)

days_in_month <- function(year, month) {
  is_leap <- (year %% 4 == 0 & year %% 100 != 0) | (year %% 400 == 0)
  c(31, 28 + is_leap, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)[month]
}

# -- Step 1: Download hourly 2m_temperature month by month ---------------------
log_msg("=== STEP 1: DOWNLOAD HOURLY TEMPERATURE ===")

for (yr in years) {
  for (mon in 1:12) {
    mon_str <- sprintf("%02d", mon)
    out_file <- file.path(hourly_dir, paste0("hourly_t2m_", yr, "_", mon_str, ".grib"))

    if (file.exists(out_file)) {
      status$skipped <- status$skipped + 1L
      next
    }

    n_days <- days_in_month(yr, mon)

    request <- list(
      product_type = "reanalysis",
      variable = "2m_temperature",
      year = as.character(yr),
      month = mon_str,
      day = sprintf("%02d", 1:n_days),
      time = sprintf("%02d:00", 0:23),
      area = bbox,
      format = "grib",
      dataset_short_name = "reanalysis-era5-land",
      target = basename(out_file)
    )

    # Small delay between requests to stay under rate limits
    Sys.sleep(5)

    log_msg("Fetching ", yr, "-", mon_str, "...")
    tryCatch({
      result <- wf_request(request = request, path = hourly_dir, retry = retry_interval)

      # Handle zip wrapping
      if (grepl("\\.zip$", result)) {
        tmp_dir <- tempfile("cd_hourly_", tmpdir = hourly_dir)
        dir.create(tmp_dir)
        utils::unzip(result, exdir = tmp_dir)
        grib <- list.files(tmp_dir, pattern = "\\.grib$", full.names = TRUE)
        if (length(grib) > 0) file.rename(grib[1], out_file)
        unlink(result)
        unlink(tmp_dir, recursive = TRUE)
      } else if (result != out_file) {
        file.rename(result, out_file)
      }

      log_msg("  Saved: ", basename(out_file),
              " (", round(file.size(out_file) / 1e6, 1), " MB)")
      status$downloaded <- status$downloaded + 1L
    }, error = function(e) {
      log_msg("  FAILED: ", yr, "-", mon_str, ": ", conditionMessage(e))
      status$failed <- c(status$failed, paste(yr, mon_str))
      # Back off on rate limit errors
      if (grepl("rate limit", conditionMessage(e), ignore.case = TRUE)) {
        log_msg("  Rate limited — sleeping 60 seconds")
        Sys.sleep(60)
      }
    })
  }
}

# -- Step 2: Compute monthly mean of daily max/min ----------------------------
log_msg("=== STEP 2: COMPUTE MONTHLY tmax/tmin ===")

for (yr in years) {
  tmax_out <- file.path(monthly_dir, paste0("tmax_", yr, ".tif"))
  tmin_out <- file.path(monthly_dir, paste0("tmin_", yr, ".tif"))

  if (file.exists(tmax_out) && file.exists(tmin_out)) {
    next
  }

  tmax_monthly <- list()
  tmin_monthly <- list()

  all_months_ok <- TRUE
  for (mon in 1:12) {
    mon_str <- sprintf("%02d", mon)
    grib_file <- file.path(hourly_dir, paste0("hourly_t2m_", yr, "_", mon_str, ".grib"))

    if (!file.exists(grib_file)) {
      log_msg("  Missing: ", basename(grib_file))
      all_months_ok <- FALSE
      next
    }

    r <- rast(grib_file)
    n_days <- days_in_month(yr, mon)
    n_hours <- n_days * 24

    if (nlyr(r) != n_hours) {
      warning(yr, "-", mon_str, ": expected ", n_hours, " layers, got ", nlyr(r), call. = FALSE)
    }

    # Compute daily max and min, then monthly mean
    daily_max <- list()
    daily_min <- list()
    for (d in 1:n_days) {
      idx <- ((d - 1) * 24 + 1):min(d * 24, nlyr(r))
      daily_max[[d]] <- max(r[[idx]])
      daily_min[[d]] <- min(r[[idx]])
    }

    # Monthly mean of daily max/min, convert K to C
    tmax_monthly[[mon]] <- mean(rast(daily_max)) - 273.15
    tmin_monthly[[mon]] <- mean(rast(daily_min)) - 273.15
  }

  if (!all_months_ok || length(tmax_monthly) != 12) {
    warning(yr, ": incomplete, skipping", call. = FALSE)
    next
  }

  tmax_year <- rast(tmax_monthly)
  tmin_year <- rast(tmin_monthly)
  names(tmax_year) <- month.abb
  names(tmin_year) <- month.abb

  writeRaster(tmax_year, tmax_out, overwrite = TRUE)
  writeRaster(tmin_year, tmin_out, overwrite = TRUE)
  log_msg(yr, " done (tmax range: ",
          round(min(values(tmax_year), na.rm = TRUE), 1), " to ",
          round(max(values(tmax_year), na.rm = TRUE), 1), " C)")
}

# -- Step 3: Aggregate to seasonal/annual COGs --------------------------------
log_msg("=== STEP 3: BUILD MULTI-YEAR COGS ===")

for (var in c("tmax", "tmin")) {
  for (period in c("annual", names(seasons))) {
    cog_path <- file.path(cog_dir, paste0(var, "_", period, ".tif"))

    year_layers <- list()
    for (yr in years) {
      mf <- file.path(monthly_dir, paste0(var, "_", yr, ".tif"))
      if (!file.exists(mf)) next
      r_m <- rast(mf)
      if (nlyr(r_m) != 12) next
      periods <- cd_aggregate(r_m, method = "mean", seasons = seasons)
      if (period %in% names(periods)) {
        year_layers[[as.character(yr)]] <- periods[[period]]
      }
    }

    if (length(year_layers) > 0) {
      multi <- rast(year_layers)
      names(multi) <- names(year_layers)
      cd_cog_write(multi, cog_path, overwrite = TRUE)
      log_msg(basename(cog_path), ": ", nlyr(multi), " years")
    }
  }
}

# -- Step 4: Regenerate STAC catalog + push to S3 ----------------------------
log_msg("=== STEP 4: STAC + S3 ===")
cd_stac_catalog(cog_dir, file.path(cog_dir, "catalog.json"),
                base_url = paste0("https://", bucket, ".s3.us-west-2.amazonaws.com"))
cd_s3_push(cog_dir, bucket = bucket)

elapsed <- round(difftime(Sys.time(), status$started, units = "hours"), 1)
log_msg("=== tmax/tmin BACKFILL COMPLETE ===")
log_msg("Elapsed: ", elapsed, " hours")
log_msg("Downloaded: ", status$downloaded, " month files")
log_msg("Skipped (existing): ", status$skipped)
if (length(status$failed) > 0) {
  log_msg("FAILED (", length(status$failed), "): ", paste(status$failed, collapse = ", "))
} else {
  log_msg("No failures")
}
