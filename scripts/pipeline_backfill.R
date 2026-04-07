#!/usr/bin/env Rscript
#
# pipeline_backfill.R
#
# Full backfill: download all ERA5-Land data (1950-2025), derive variables,
# aggregate to seasonal/annual periods, write COGs, generate STAC catalog,
# push to S3.
#
# Idempotent — skips years already downloaded. Safe to re-run after interruption.
# CDS polling interval set to 120s to avoid rate limits on long runs.
#
# Prerequisites:
#   - CDS API key in macOS keyring (run wf_set_key() once)
#   - AWS CLI configured for stac-era5-land bucket
#   - ~10 hours for full backfill (mostly CDS queue time)
#
# Usage:
#   Rscript scripts/pipeline_backfill.R
#
# Configuration: edit the variables below.

if (requireNamespace("cd", quietly = TRUE)) {
  library(cd)
} else {
  devtools::load_all()
}
library(terra)

# -- Configuration ------------------------------------------------------------

# Date range
years <- 1950:2025

# Variables to fetch from CDS monthly means
# (tmean comes from 2m_temperature, vpd/rh derived from temp+dewpoint)
fetch_variables <- c("tmean", "vpd", "rh", "prcp", "soil_moisture")

# Include tmax/tmin from daily statistics product
include_tmax_tmin <- TRUE

# Bounding box (N, W, S, E) — BC
bbox <- c(60, -140, 48, -114)

# S3 bucket
bucket <- "stac-era5-land"

# Directories
raw_dir <- "data/backfill/raw"
derived_dir <- "data/backfill/derived"
monthly_dir <- "data/backfill/monthly"
cog_dir <- "data/backfill/cogs"

# CDS polling interval (seconds) — higher = less rate limiting risk
retry_interval <- 120

# Season definitions (configurable)
seasons <- cd_seasons()

# Aggregation methods per variable
# Precip is summed, everything else is averaged
agg_methods <- c(
  tmean = "mean", tmax = "mean", tmin = "mean",
  prcp = "sum", vpd = "mean", rh = "mean", soil_moisture = "mean"
)

# -- Setup directories ---------------------------------------------------------
for (d in c(raw_dir, derived_dir, monthly_dir, cog_dir)) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

# -- Step 1: Fetch monthly means -----------------------------------------------
message("\n=== STEP 1: FETCH MONTHLY MEANS ===")
message("Years: ", min(years), "-", max(years))
message("Retry interval: ", retry_interval, "s")

monthly_files <- cd_fetch(
  years = years,
  months = 1:12,
  variables = fetch_variables,
  bbox = bbox,
  output_dir = raw_dir,
  retry = retry_interval
)
message("Monthly means: ", length(monthly_files), " files")

# -- Step 2: Fetch daily stats for tmax/tmin -----------------------------------
if (include_tmax_tmin) {
  message("\n=== STEP 2: FETCH DAILY STATS (tmax/tmin) ===")
  tmax_tmin_files <- cd_fetch(
    years = years,
    months = 1:12,
    variables = c("tmax", "tmin"),
    bbox = bbox,
    output_dir = raw_dir,
    retry = retry_interval
  )
  message("Daily stats: ", length(tmax_tmin_files), " files")
}

# -- Step 3: Derive VPD, RH, soil moisture -------------------------------------
message("\n=== STEP 3: DERIVE VARIABLES ===")
derived_files <- cd_derive(raw_dir, derived_dir, variables = c("vpd", "rh", "soil_moisture"))
message("Derived: ", length(derived_files), " files")

# -- Step 4: Build monthly rasters per variable --------------------------------
message("\n=== STEP 4: BUILD MONTHLY RASTERS ===")

for (yr in years) {
  yr_str <- as.character(yr)

  # tmean from monthly means GRIB
  grib_file <- file.path(raw_dir, paste0("era5land_monthly_", yr_str, ".grib"))
  if (file.exists(grib_file)) {
    r <- rast(grib_file)
    temp_idx <- grep("2 metre temperature", names(r))
    if (length(temp_idx) > 0) {
      tmean_monthly <- r[[temp_idx]] - 273.15
      names(tmean_monthly) <- month.abb[seq_along(temp_idx)]
      writeRaster(tmean_monthly, file.path(monthly_dir, paste0("tmean_", yr_str, ".tif")),
                  overwrite = TRUE)
    }

    # prcp from same GRIB — convert m/day to mm/month
    prcp_idx <- grep("Total precipitation", names(r))
    if (length(prcp_idx) > 0) {
      prcp <- r[[prcp_idx]]
      is_leap <- (yr %% 4 == 0 & yr %% 100 != 0) | (yr %% 400 == 0)
      days_per_month <- c(31, 28 + is_leap, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
      for (m in seq_along(prcp_idx)) {
        prcp[[m]] <- prcp[[m]] * 1000 * days_per_month[m]
      }
      names(prcp) <- month.abb[seq_along(prcp_idx)]
      writeRaster(prcp, file.path(monthly_dir, paste0("prcp_", yr_str, ".tif")),
                  overwrite = TRUE)
    }
  }

  # tmax/tmin from daily stats — compute monthly mean of daily values
  for (var in c("tmax", "tmin")) {
    daily_file <- file.path(raw_dir, paste0("era5land_", var, "_", yr_str, ".nc"))
    if (!file.exists(daily_file)) daily_file <- file.path(raw_dir, paste0("era5land_", var, "_", yr_str, ".grib"))
    if (file.exists(daily_file)) {
      r_daily <- rast(daily_file) - 273.15
      # Group by month and compute mean
      # Daily file has ~365 layers, need to split by month
      n_days <- nlyr(r_daily)
      is_leap <- (yr %% 4 == 0 & yr %% 100 != 0) | (yr %% 400 == 0)
      days_per_month <- c(31, 28 + is_leap, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
      if (n_days != sum(days_per_month)) {
        warning(var, " ", yr, ": expected ", sum(days_per_month),
                " daily layers, got ", n_days, call. = FALSE)
      }
      monthly_layers <- list()
      start <- 1
      for (m in 1:12) {
        end <- min(start + days_per_month[m] - 1, n_days)
        if (start <= n_days) {
          monthly_layers[[m]] <- mean(r_daily[[start:end]])
        }
        start <- end + 1
      }
      var_monthly <- rast(monthly_layers)
      names(var_monthly) <- month.abb[1:nlyr(var_monthly)]
      writeRaster(var_monthly, file.path(monthly_dir, paste0(var, "_", yr_str, ".tif")),
                  overwrite = TRUE)
    }
  }

  # VPD and RH from derived files
  for (var in c("vpd", "rh")) {
    derived_file <- file.path(derived_dir, paste0(var, "_", yr_str, ".tif"))
    if (file.exists(derived_file)) {
      file.copy(derived_file, file.path(monthly_dir, paste0(var, "_", yr_str, ".tif")),
                overwrite = TRUE)
    }
  }

  # soil_moisture from derived
  sm_file <- file.path(derived_dir, paste0("soil_moisture_", yr_str, ".tif"))
  if (file.exists(sm_file)) {
    file.copy(sm_file, file.path(monthly_dir, paste0("soil_moisture_", yr_str, ".tif")),
              overwrite = TRUE)
  }

  message("  Monthly rasters for ", yr_str, " done")
}

# -- Step 5: Aggregate to periods and build multi-year COGs --------------------
message("\n=== STEP 5: AGGREGATE TO PERIODS ===")

all_vars <- c("tmean", "tmax", "tmin", "prcp", "vpd", "rh", "soil_moisture")
if (!include_tmax_tmin) all_vars <- setdiff(all_vars, c("tmax", "tmin"))

for (var in all_vars) {
  method <- agg_methods[var]

  for (period in c("annual", names(seasons))) {
    cog_path <- file.path(cog_dir, paste0(var, "_", period, ".tif"))

    # Collect one layer per year for this period
    year_layers <- list()
    for (yr in years) {
      monthly_file <- file.path(monthly_dir, paste0(var, "_", yr, ".tif"))
      if (!file.exists(monthly_file)) next

      r_monthly <- rast(monthly_file)
      if (nlyr(r_monthly) != 12) {
        warning(var, " ", yr, ": skipping aggregation (", nlyr(r_monthly),
                " months, need 12)", call. = FALSE)
        next
      }

      periods <- cd_aggregate(r_monthly, method = method, seasons = seasons)
      if (period %in% names(periods)) {
        year_layers[[as.character(yr)]] <- periods[[period]]
      }
    }

    if (length(year_layers) > 0) {
      multi_year <- rast(year_layers)
      names(multi_year) <- names(year_layers)
      cd_cog_write(multi_year, cog_path, overwrite = TRUE)
      message("  COG: ", basename(cog_path), " (", nlyr(multi_year), " years)")
    }
  }
}

# -- Step 6: STAC catalog + S3 push -------------------------------------------
message("\n=== STEP 6: STAC CATALOG + S3 PUSH ===")

catalog_path <- file.path(cog_dir, "catalog.json")
cd_stac_catalog(
  cog_dir,
  output_path = catalog_path,
  base_url = paste0("https://", bucket, ".s3.us-west-2.amazonaws.com")
)

cd_s3_push(cog_dir, bucket = bucket)

message("\n=== BACKFILL COMPLETE ===")
message("COGs: ", length(list.files(cog_dir, pattern = "\\.tif$")))
message("Bucket: s3://", bucket)
