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

# Prefer the installed package; devtools::load_all() is the local-dev fallback.
# Fail with a readable message rather than a bare "no package called 'devtools'"
# from loadNamespace (see #78).
if (requireNamespace("cd", quietly = TRUE)) {
  library(cd)
} else if (requireNamespace("devtools", quietly = TRUE)) {
  devtools::load_all()
} else {
  stop("cd is not installed and devtools is unavailable to load_all() it. ",
       "Install cd (or devtools) before running this pipeline.", call. = FALSE)
}
suppressMessages(library(terra))

# Producer-side helpers, shared with pipeline_update_edh.R (repo-root cwd).
source("scripts/_lib.R")

args <- commandArgs(trailingOnly = TRUE)
dry_run <- "--dry-run" %in% args

# -- Config --------------------------------------------------------------------
bucket <- "stac-era5-land"
monthly_dir <- "data/backfill/monthly"
annual_dir <- "data/backfill/annual"
cog_dir <- "data/backfill/cogs"
# Outside cog_dir, so the COG sync never carries it: it is uploaded on its own,
# after the COGs it points at (#89).
catalog_path <- "data/backfill/catalog.json"
catalog_url <- paste0("https://", bucket, ".s3.us-west-2.amazonaws.com/catalog.json")
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

# COGs written by THIS run, with their band names (years). cog_dir persists
# between runs, so a file merely present there may be a stale copy from an
# earlier run, and the guard before the catalog must not count it.
written <- list()

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
      # tmax/tmin use local days since #37 and the files carry units=degC; a
      # pre-#37 UTC-day file (units=K) is skipped by the backfills' existence
      # check, so it would otherwise be published silently.
      if (var %in% c("tmax", "tmin")) {
        tags <- metags(r_m)
        if (!identical(tags$value[tags$name == "units"], "degC")) {
          stop(var, " ", yr, ": not a local-day file (no units=degC tag); ",
               "delete it and re-run scripts/backfill_edh_tmax_tmin.py",
               call. = FALSE)
        }
      }
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
    written[[basename(cog_path)]] <- names(multi)
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
  written[[basename(cog_path)]] <- names(multi)
  log_msg(sprintf("    wrote %s (%d years)", basename(cog_path), nlyr(multi)))
}

# -- Step 2: STAC catalog ------------------------------------------------------
# The catalog lists every COG in cog_dir and the push syncs all of them, so a
# partial monthly_dir would publish a partial catalog, or stale COGs left in
# cog_dir by an earlier run over newer live ones. A partial monthly_dir is the
# normal state after a single-variable regen (#37 left only tmax and tmin
# there; scripts/tmax_tmin_republish.R is the tool for that case). So every
# COG must have been written by this run, cog_dir must hold nothing else, and
# every COG must carry one contiguous span of years that keeps every live
# year: the push cannot be undone. pipeline_update_edh.R runs the same guard
# before its publish (#89).
expected_cogs <- cog_expected(agg_methods, seasons, annual_vars)
live <- tryCatch(cd_catalog(catalog_url), error = function(e) {
  stop("Refusing to build the catalog: could not read the live catalog (",
       conditionMessage(e), ").", call. = FALSE)
})
live_years <- tryCatch({
  href <- live$href[live$variable == "tmean" & live$period == "annual"]
  as.integer(names(rast(paste0("/vsicurl/", href))))
}, error = function(e) {
  stop("Refusing to build the catalog: could not read the live tmean_annual ",
       "COG to check its years (", conditionMessage(e), ").", call. = FALSE)
})
problems <- publish_problems(
  written,
  expected = expected_cogs,
  on_disk = list.files(cog_dir, pattern = "\\.tif$"),
  live_keys = paste(live$variable, live$period, sep = "_"),
  required_years = live_years
)
problems <- c(problems,
              grid_problems(file.path(cog_dir, list.files(cog_dir, pattern = "\\.tif$"))))
if (length(problems) > 0) {
  stop("Refusing to build the catalog; publishing would replace live data ",
       "with a partial or stale set:\n  - ",
       paste(problems, collapse = "\n  - "), call. = FALSE)
}
years_written <- as.integer(written[[1]])

log_msg("=== STEP 2: Build STAC catalog ===")
cd_stac_catalog(
  cog_dir,
  output_path = catalog_path,
  base_url = paste0("https://", bucket, ".s3.us-west-2.amazonaws.com")
)
log_msg("  wrote ", catalog_path)
# Check the catalog that was written, not only the inputs it was built from.
built <- catalog_item_years(jsonlite::read_json(catalog_path))
problems <- catalog_problems(built$keys, sub("\\.tif$", "", expected_cogs),
                             built$start, built$end, years_written)
if (length(problems) > 0) {
  unlink(catalog_path)
  stop("Refusing to push: the catalog built this run is not the full set:\n  - ",
       paste(problems, collapse = "\n  - "), call. = FALSE)
}

# -- Step 3: S3 push -----------------------------------------------------------
log_msg("=== STEP 3: Push to S3 ===")
# A catalog.json left in cog_dir by a run from before #89 would ride the sync.
unlink(file.path(cog_dir, "catalog.json"))
if (dry_run) log_msg("  DRY RUN — showing what would be uploaded:")
cd_s3_push(cog_dir, bucket = bucket, dry_run = dry_run)
# On its own and last: the sync is --size-only, and a rebuilt catalog can
# differ from the live one without differing in size (an end year moving from
# 2025 to 2026), so the sync would skip it; and uploaded after the COGs, it
# never points at a COG that is not up yet.
cat_put <- suppressWarnings(system2(
  "aws", c("s3", "cp", shQuote(catalog_path),
           shQuote(paste0("s3://", bucket, "/catalog.json")),
           if (dry_run) "--dryrun"),
  stdout = TRUE, stderr = TRUE
))
if (!is.null(attr(cat_put, "status"))) {
  stop("COGs pushed but catalog.json upload failed (exit ",
       attr(cat_put, "status"), "): ", paste(cat_put, collapse = " "),
       call. = FALSE)
}
log_msg("  ", paste(cat_put, collapse = " "))
if (!dry_run) {
  live_after <- tryCatch(catalog_item_years(jsonlite::read_json(catalog_url)),
                         error = function(e) NULL)
  if (!identical(live_after, built)) {
    stop("catalog.json uploaded, but the live catalog read back does not ",
         "match the one built this run.", call. = FALSE)
  }
}

log_msg("=== DONE ===")
