#!/usr/bin/env Rscript
#
# pipeline_stage3_edh.R
#
# Stage 3 of the EDH-based backfill: take the unified monthly TIFs in
# data/backfill/monthly/, aggregate to seasonal/annual COGs, write a STAC
# catalog, and push everything to S3.
#
# Assumes Stage 2 has produced:
#
#   data/backfill/monthly/ — 12-band/year monthly natives
#     {tmax,tmin,tmean,prcp,vpd,rh,soil_moisture}_YYYY.tif (from backfill_edh_all.py)
#     {swe,snowfall,snowmelt,snow_cover}_YYYY.tif          (from backfill_edh_snow.py)
#
#   data/backfill/annual/ — 1-band/year annual-derived (snow only, #48)
#     {swe_max,snowfall_fraction,snowmelt_doy_50,snowmelt_rate_peak}_YYYY.tif
#
# Usage:
#   Rscript scripts/pipeline_stage3_edh.R
#   Rscript scripts/pipeline_stage3_edh.R --dry-run   # no S3 push

if (requireNamespace("cd", quietly = TRUE)) library(cd) else devtools::load_all()
suppressMessages(library(terra))

args <- commandArgs(trailingOnly = TRUE)
dry_run <- "--dry-run" %in% args

# -- Config --------------------------------------------------------------------
bucket <- "stac-era5-land"
monthly_dir <- "data/backfill/monthly"
annual_dir <- "data/backfill/annual"
cog_dir <- "data/backfill/cogs"
seasons <- cd_seasons()

agg_methods <- c(
  tmean = "mean", tmax = "mean", tmin = "mean",
  prcp = "sum", vpd = "mean", rh = "mean", soil_moisture = "mean",
  # Snow monthly natives (#48). swe is monthly mean SWE; snow_cover is monthly
  # mean of fraction-cover. snowfall and snowmelt are monthly water-equivalent
  # totals — annual aggregation is sum, not mean.
  swe = "mean", snowfall = "sum", snowmelt = "sum", snow_cover = "mean"
)

# Annual-only derived vars (#48): no monthly schema; one band per year per file.
annual_vars <- c("swe_max", "snowfall_fraction",
                 "snowmelt_doy_50", "snowmelt_rate_peak")

dir.create(cog_dir, recursive = TRUE, showWarnings = FALSE)

log_msg <- function(...) {
  cat(sprintf("[%s] %s\n", format(Sys.time(), "%H:%M:%S"), paste0(...)))
}

# -- Step 1: Aggregate to seasonal/annual COGs --------------------------------
log_msg("=== STEP 1: Aggregate monthly -> seasonal/annual COGs ===")

all_vars <- names(agg_methods)

for (var in all_vars) {
  method <- agg_methods[[var]]

  # Find all monthly files for this variable
  monthly_files <- list.files(
    monthly_dir,
    pattern = paste0("^", var, "_\\d{4}\\.tif$"),
    full.names = TRUE
  )
  if (length(monthly_files) == 0) {
    log_msg("  ", var, ": no monthly files, skipping")
    next
  }
  years <- sort(as.integer(
    sub(paste0(var, "_(\\d{4})\\.tif"), "\\1", basename(monthly_files))
  ))

  log_msg(sprintf("  %s: %d years (%d-%d), method=%s",
                  var, length(years), min(years), max(years), method))

  for (period in c("annual", names(seasons))) {
    cog_path <- file.path(cog_dir, paste0(var, "_", period, ".tif"))
    year_layers <- list()

    for (yr in years) {
      mf <- file.path(monthly_dir, paste0(var, "_", yr, ".tif"))
      r_m <- rast(mf)
      if (nlyr(r_m) != 12) {
        warning(sprintf("%s %d: has %d layers, need 12, skipping",
                        var, yr, nlyr(r_m)), call. = FALSE)
        next
      }
      periods <- cd_aggregate(r_m, method = method, seasons = seasons)
      if (period %in% names(periods)) {
        year_layers[[as.character(yr)]] <- periods[[period]]
      }
    }

    if (length(year_layers) == 0) next

    multi <- rast(year_layers)
    names(multi) <- names(year_layers)
    cd_cog_write(multi, cog_path, overwrite = TRUE)
    log_msg(sprintf("    wrote %s (%d years)", basename(cog_path), nlyr(multi)))
  }
}

# -- Step 1b: Stack annual-derived vars into multi-year COGs ------------------
# These bypass cd_aggregate (no monthly input, no seasonal layer) and just
# concatenate the per-year 1-band TIFs from data/backfill/annual/ into a
# single multi-band COG, year-named, written as {var}_annual.tif.
log_msg("=== STEP 1b: Stack annual-derived COGs (#48 snow scalars) ===")

for (var in annual_vars) {
  annual_files <- list.files(
    annual_dir,
    pattern = paste0("^", var, "_\\d{4}\\.tif$"),
    full.names = TRUE
  )
  if (length(annual_files) == 0) {
    log_msg("  ", var, ": no annual files, skipping")
    next
  }
  years <- sort(as.integer(
    sub(paste0(var, "_(\\d{4})\\.tif"), "\\1", basename(annual_files))
  ))
  log_msg(sprintf("  %s (annual-derived): %d years (%d-%d)",
                  var, length(years), min(years), max(years)))

  cog_path <- file.path(cog_dir, paste0(var, "_annual.tif"))
  year_layers <- list()
  for (yr in years) {
    af <- file.path(annual_dir, paste0(var, "_", yr, ".tif"))
    r <- rast(af)
    if (nlyr(r) != 1) {
      warning(sprintf("%s %d: has %d layers, expected 1, skipping",
                      var, yr, nlyr(r)), call. = FALSE)
      next
    }
    year_layers[[as.character(yr)]] <- r
  }
  if (length(year_layers) == 0) next

  multi <- rast(year_layers)
  names(multi) <- names(year_layers)
  cd_cog_write(multi, cog_path, overwrite = TRUE)
  log_msg(sprintf("    wrote %s (%d years)", basename(cog_path), nlyr(multi)))
}

# -- Step 2: STAC catalog ------------------------------------------------------
log_msg("=== STEP 2: Build STAC catalog ===")
cd_stac_catalog(
  cog_dir,
  output_path = file.path(cog_dir, "catalog.json"),
  base_url = paste0("https://", bucket, ".s3.us-west-2.amazonaws.com")
)
log_msg("  wrote ", file.path(cog_dir, "catalog.json"))

# -- Step 3: S3 push -----------------------------------------------------------
log_msg("=== STEP 3: Push to S3 ===")
if (dry_run) {
  log_msg("  DRY RUN — showing what would be uploaded:")
  cd_s3_push(cog_dir, bucket = bucket, dry_run = TRUE)
} else {
  cd_s3_push(cog_dir, bucket = bucket, dry_run = FALSE)
}

log_msg("=== DONE ===")
