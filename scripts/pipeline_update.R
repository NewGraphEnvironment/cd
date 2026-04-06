#!/usr/bin/env Rscript
#
# pipeline_update.R
#
# Incremental update: check what's on S3, fetch only new data from CDS,
# rebuild affected COGs, update STAC catalog, push to S3.
#
# Designed to run in < 6 hours (GitHub Action limit).
# Idempotent — safe to re-run.
#
# Prerequisites:
#   - CDS API key in macOS keyring or env var
#   - AWS CLI configured for stac-era5-land bucket
#   - Existing data on S3 from pipeline_backfill.R
#
# Usage:
#   Rscript scripts/pipeline_update.R

if (requireNamespace("cd", quietly = TRUE)) {
  library(cd)
} else {
  devtools::load_all()
}
library(terra)

# -- Configuration ------------------------------------------------------------

bucket <- "stac-era5-land"
catalog_url <- paste0("https://", bucket, ".s3.us-west-2.amazonaws.com/catalog.json")

# Variables to update
fetch_variables <- c("tmean", "vpd", "rh", "prcp", "soil_moisture")
include_tmax_tmin <- TRUE

bbox <- c(60, -140, 48, -114)
retry_interval <- 120

seasons <- cd_seasons()
agg_methods <- c(
  tmean = "mean", tmax = "mean", tmin = "mean",
  prcp = "sum", vpd = "mean", rh = "mean", soil_moisture = "mean"
)

# Working directories
raw_dir <- "data/update/raw"
derived_dir <- "data/update/derived"
monthly_dir <- "data/update/monthly"
cog_dir <- "data/update/cogs"

for (d in c(raw_dir, derived_dir, monthly_dir, cog_dir)) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

# -- Step 1: Determine what's current -----------------------------------------
message("\n=== STEP 1: CHECK CURRENT STATE ===")

catalog <- tryCatch(
  cd_catalog(catalog_url),
  error = function(e) {
    message("No catalog found at ", catalog_url, " — run pipeline_backfill.R first")
    quit(status = 1)
  }
)

# Find the latest year in existing data
# Read one COG to check band names
tmean_row <- catalog[catalog$variable == "tmean" & catalog$period == "annual", ]
if (nrow(tmean_row) == 0) {
  message("No tmean_annual COG found — run pipeline_backfill.R first")
  quit(status = 1)
}

r_current <- rast(paste0("/vsicurl/", tmean_row$href))
current_years <- as.integer(names(r_current))
latest_year <- max(current_years, na.rm = TRUE)
message("Latest year on S3: ", latest_year)

# ERA5-Land has ~2 month lag. Current complete year is likely current_year - 1
# but check if current year has enough months
current_year <- as.integer(format(Sys.Date(), "%Y"))
target_year <- current_year  # Try to get current year data

if (target_year <= latest_year) {
  message("Data is up to date (latest: ", latest_year, ", target: ", target_year, ")")
  message("Nothing to do.")
  quit(status = 0)
}

new_years <- (latest_year + 1):target_year
message("New years to fetch: ", paste(new_years, collapse = ", "))

# -- Step 2: Fetch new data ---------------------------------------------------
message("\n=== STEP 2: FETCH NEW DATA ===")

new_files <- cd_fetch(
  years = new_years,
  months = 1:12,
  variables = fetch_variables,
  bbox = bbox,
  output_dir = raw_dir,
  retry = retry_interval
)

if (include_tmax_tmin) {
  tmax_tmin_files <- cd_fetch(
    years = new_years,
    months = 1:12,
    variables = c("tmax", "tmin"),
    bbox = bbox,
    output_dir = raw_dir,
    retry = retry_interval
  )
}

# -- Step 3: Derive new variables ----------------------------------------------
message("\n=== STEP 3: DERIVE ===")
cd_derive(raw_dir, derived_dir, variables = c("vpd", "rh", "soil_moisture"))

# -- Step 4: Build monthly rasters for new years ------------------------------
message("\n=== STEP 4: BUILD MONTHLY RASTERS ===")

for (yr in new_years) {
  yr_str <- as.character(yr)
  grib_file <- file.path(raw_dir, paste0("era5land_monthly_", yr_str, ".grib"))

  if (file.exists(grib_file)) {
    r <- rast(grib_file)
    temp_idx <- grep("2 metre temperature", names(r))
    prcp_idx <- grep("Total precipitation", names(r))

    if (length(temp_idx) > 0) {
      tmean <- r[[temp_idx]] - 273.15
      names(tmean) <- month.abb[seq_along(temp_idx)]
      writeRaster(tmean, file.path(monthly_dir, paste0("tmean_", yr_str, ".tif")),
                  overwrite = TRUE)
    }

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

  # tmax/tmin from daily stats
  for (var in c("tmax", "tmin")) {
    daily_file <- file.path(raw_dir, paste0("era5land_", var, "_", yr_str, ".nc"))
    if (!file.exists(daily_file)) daily_file <- file.path(raw_dir, paste0("era5land_", var, "_", yr_str, ".grib"))
    if (file.exists(daily_file)) {
      r_daily <- rast(daily_file) - 273.15
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
        if (start <= n_days) monthly_layers[[m]] <- mean(r_daily[[start:end]])
        start <- end + 1
      }
      var_monthly <- rast(monthly_layers)
      names(var_monthly) <- month.abb[1:nlyr(var_monthly)]
      writeRaster(var_monthly, file.path(monthly_dir, paste0(var, "_", yr_str, ".tif")),
                  overwrite = TRUE)
    }
  }

  # VPD, RH, soil moisture from derived
  for (var in c("vpd", "rh", "soil_moisture")) {
    src <- file.path(derived_dir, paste0(var, "_", yr_str, ".tif"))
    if (file.exists(src)) {
      file.copy(src, file.path(monthly_dir, paste0(var, "_", yr_str, ".tif")),
                overwrite = TRUE)
    }
  }

  message("  Monthly rasters for ", yr_str, " done")
}

# -- Step 5: Download existing COGs, append new year, re-upload ----------------
message("\n=== STEP 5: REBUILD COGS WITH NEW YEARS ===")

all_vars <- c("tmean", "tmax", "tmin", "prcp", "vpd", "rh", "soil_moisture")
if (!include_tmax_tmin) all_vars <- setdiff(all_vars, c("tmax", "tmin"))

for (var in all_vars) {
  method <- agg_methods[var]

  for (period in c("annual", names(seasons))) {
    cog_name <- paste0(var, "_", period, ".tif")
    cog_path <- file.path(cog_dir, cog_name)

    # Download existing COG from S3
    existing_row <- catalog[catalog$variable == var & catalog$period == period, ]
    existing_rast <- NULL
    if (nrow(existing_row) > 0) {
      existing_rast <- tryCatch(
        rast(paste0("/vsicurl/", existing_row$href)),
        error = function(e) {
          stop("Failed to read existing COG from S3: ", existing_row$href,
               "\nAborting to prevent data loss. Error: ", e$message,
               call. = FALSE)
        }
      )
    }

    # Aggregate new years
    new_layers <- list()
    for (yr in new_years) {
      monthly_file <- file.path(monthly_dir, paste0(var, "_", yr, ".tif"))
      if (!file.exists(monthly_file)) next
      r_monthly <- rast(monthly_file)
      if (nlyr(r_monthly) != 12) {
        warning(var, " ", yr, ": skipping (", nlyr(r_monthly), " months, need 12)", call. = FALSE)
        next
      }
      periods <- cd_aggregate(r_monthly, method = method, seasons = seasons)
      if (period %in% names(periods)) {
        new_layers[[as.character(yr)]] <- periods[[period]]
      }
    }

    if (length(new_layers) == 0) next

    # Combine existing + new
    new_rast <- rast(new_layers)
    names(new_rast) <- names(new_layers)

    if (!is.null(existing_rast)) {
      combined <- c(existing_rast, new_rast)
    } else {
      combined <- new_rast
    }

    cd_cog_write(combined, cog_path, overwrite = TRUE)
    message("  Updated: ", cog_name, " (", nlyr(combined), " years)")
  }
}

# -- Step 6: STAC catalog + S3 push -------------------------------------------
message("\n=== STEP 6: STAC CATALOG + S3 PUSH ===")

cd_stac_catalog(
  cog_dir,
  output_path = file.path(cog_dir, "catalog.json"),
  base_url = paste0("https://", bucket, ".s3.us-west-2.amazonaws.com")
)

cd_s3_push(cog_dir, bucket = bucket)

message("\n=== UPDATE COMPLETE ===")
message("Added years: ", paste(new_years, collapse = ", "))
message("Bucket: s3://", bucket)
