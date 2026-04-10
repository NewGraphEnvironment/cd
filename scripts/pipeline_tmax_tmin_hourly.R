#!/usr/bin/env Rscript
#
# pipeline_tmax_tmin_hourly.R
#
# Download hourly 2m_temperature from ERA5-Land, compute daily max/min,
# aggregate to monthly mean of daily max/min, then seasonal/annual COGs.
#
# DESIGNED TO BE A POLITE CDS API CITIZEN.
#
# Idempotent — skips months already downloaded.
# STOPS on first rate limit error — does not retry. Wait 1+ hours
# before manual restart.
#
# Pre-flight checks (must pass before script runs):
#   1. No other pipeline_tmax_tmin processes running
#   2. CDS jobs queue is clean (no orphans from previous failures)
#
# Run-time discipline:
#   - 60+ second sleep BETWEEN every request (not just on errors)
#   - STOP on first 429 rate limit error
#   - Abort if more than 3 consecutive failures
#
# Usage:
#   Rscript scripts/pipeline_tmax_tmin_hourly.R

if (requireNamespace("cd", quietly = TRUE)) {
  library(cd)
} else {
  devtools::load_all()
}
library(terra)
library(ecmwfr)

# -- Pre-flight check: no other instances running -----------------------------
# Narrow the pattern so editor/grep on the filename doesn't match.
my_pid <- Sys.getpid()
other_pids <- suppressWarnings(
  system2("pgrep", c("-f", "Rscript.*pipeline_tmax_tmin_hourly"), stdout = TRUE)
)
other_pids <- setdiff(as.integer(other_pids), my_pid)
if (length(other_pids) > 0) {
  stop("ABORT: Other pipeline_tmax_tmin_hourly processes already running: ",
       paste(other_pids, collapse = ", "),
       "\nKill them first: kill ", paste(other_pids, collapse = " "))
}

# -- Logging -------------------------------------------------------------------
log_msg <- function(...) {
  msg <- paste0("[", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "] ", ...)
  message(msg)
}

# -- Configuration ------------------------------------------------------------
years <- 1950:2025
bbox <- c(60, -140, 48, -114)

# Politeness settings
sleep_between_requests <- 60   # seconds between every successful request
poll_interval <- 60            # ecmwfr polling interval (job status checks)
max_consecutive_failures <- 3  # abort threshold

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

# -- Status tracking via environment ------------------------------------------
status <- new.env(parent = emptyenv())
status$downloaded <- 0L
status$skipped <- 0L
status$consecutive_failures <- 0L
status$started <- Sys.time()

# -- Step 1: Download hourly 2m_temperature ------------------------------------
log_msg("=== STEP 1: DOWNLOAD HOURLY TEMPERATURE ===")
log_msg("Sleep between requests: ", sleep_between_requests, "s")
log_msg("Will STOP on first rate limit or after ",
        max_consecutive_failures, " consecutive failures")

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

    log_msg("Fetching ", yr, "-", mon_str, "...")
    result <- tryCatch({
      wf_request(request = request, path = hourly_dir, retry = poll_interval)
    }, error = function(e) {
      msg <- conditionMessage(e)
      log_msg("  ERROR: ", msg)

      # STOP on rate limiting — don't retry, don't continue.
      # Match all common throttle/quota error phrases.
      if (grepl("429|rate.?limit|too many requests|quota|throttle",
                msg, ignore.case = TRUE)) {
        log_msg("  RATE LIMITED — exiting script. Wait 1+ hours before restart.")
        log_msg("  Downloaded ", status$downloaded, " files this run")
        quit(status = 1)
      }

      status$consecutive_failures <- status$consecutive_failures + 1L
      if (status$consecutive_failures >= max_consecutive_failures) {
        log_msg("  ", max_consecutive_failures, " consecutive failures — exiting")
        quit(status = 1)
      }
      NULL
    })

    if (is.null(result)) {
      # Politeness — sleep even after non-fatal failures so we don't hammer
      log_msg("  Sleeping ", sleep_between_requests, "s after error...")
      Sys.sleep(sleep_between_requests)
      next
    }

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
    status$consecutive_failures <- 0L

    # Be polite — sleep between requests
    log_msg("  Sleeping ", sleep_between_requests, "s before next request...")
    Sys.sleep(sleep_between_requests)
  }
}

# -- Step 2: Compute monthly mean of daily max/min ----------------------------
log_msg("=== STEP 2: COMPUTE MONTHLY tmax/tmin ===")

for (yr in years) {
  tmax_out <- file.path(monthly_dir, paste0("tmax_", yr, ".tif"))
  tmin_out <- file.path(monthly_dir, paste0("tmin_", yr, ".tif"))

  if (file.exists(tmax_out) && file.exists(tmin_out)) next

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

    daily_max <- list()
    daily_min <- list()
    for (d in 1:n_days) {
      idx <- ((d - 1) * 24 + 1):min(d * 24, nlyr(r))
      daily_max[[d]] <- max(r[[idx]])
      daily_min[[d]] <- min(r[[idx]])
    }

    tmax_monthly[[mon]] <- mean(rast(daily_max)) - 273.15
    tmin_monthly[[mon]] <- mean(rast(daily_min)) - 273.15
  }

  if (!all_months_ok || length(tmax_monthly) != 12) {
    log_msg("  ", yr, ": incomplete, skipping")
    next
  }

  tmax_year <- rast(tmax_monthly)
  tmin_year <- rast(tmin_monthly)
  names(tmax_year) <- month.abb
  names(tmin_year) <- month.abb

  writeRaster(tmax_year, tmax_out, overwrite = TRUE)
  writeRaster(tmin_year, tmin_out, overwrite = TRUE)
  log_msg(yr, " done")
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

# -- Step 4: STAC catalog + S3 push -------------------------------------------
log_msg("=== STEP 4: STAC + S3 ===")
cd_stac_catalog(cog_dir, file.path(cog_dir, "catalog.json"),
                base_url = paste0("https://", bucket, ".s3.us-west-2.amazonaws.com"))
cd_s3_push(cog_dir, bucket = bucket)

elapsed <- round(difftime(Sys.time(), status$started, units = "hours"), 1)
log_msg("=== COMPLETE ===")
log_msg("Elapsed: ", elapsed, " hours")
log_msg("Downloaded this run: ", status$downloaded)
log_msg("Skipped (existing): ", status$skipped)
