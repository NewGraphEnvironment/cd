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
#   3. If behind, call scripts/backfill_edh_all.py for each missing year
#      (idempotent — Python script skips files that already exist)
#   4. For each variable × period, read existing COG from S3 via /vsicurl,
#      aggregate the new year's monthly TIFs, append to the COG, write
#      locally, push to S3
#   5. Rebuild catalog, push to S3
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

if (requireNamespace("cd", quietly = TRUE)) library(cd) else devtools::load_all()
suppressMessages(library(terra))

# -- Config --------------------------------------------------------------------
bucket <- "stac-era5-land"
catalog_url <- paste0("https://", bucket, ".s3.us-west-2.amazonaws.com/catalog.json")
monthly_dir <- "data/backfill/monthly"
cog_dir <- "data/update/cogs"
seasons <- cd_seasons()

agg_methods <- c(
  tmean = "mean", tmax = "mean", tmin = "mean",
  prcp = "sum", vpd = "mean", rh = "mean", soil_moisture = "mean"
)

dir.create(monthly_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(cog_dir, recursive = TRUE, showWarnings = FALSE)

log_msg <- function(...) {
  cat(sprintf("[%s] %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), paste0(...)))
}

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

# -- Step 3: fetch via EDH ----------------------------------------------------
log_msg("=== STEP 3: Fetch missing years via EDH ===")

new_years_written <- c()
any_fetch_errored <- FALSE
for (yr in candidate_years) {
  log_msg("  Fetching ", yr, " via backfill_edh_all.py...")
  # Pass through Python stdout/stderr so a failure is debuggable from logs.
  status <- system2(
    "uv", c("run", "scripts/backfill_edh_all.py", "--year", as.character(yr))
  )
  if (status != 0) {
    log_msg("  FAILED for ", yr, " (exit ", status, ") — continuing to next year")
    any_fetch_errored <- TRUE
    next
  }
  # Check all 7 variables wrote (backfill_edh_all.py skips partial years)
  all_vars <- names(agg_methods)
  wrote_all <- all(vapply(all_vars, function(v) {
    file.exists(file.path(monthly_dir, paste0(v, "_", yr, ".tif")))
  }, logical(1)))
  if (wrote_all) {
    log_msg("  ", yr, ": wrote all 7 variables")
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

all_vars <- names(agg_methods)
for (var in all_vars) {
  method <- agg_methods[[var]]

  for (period in c("annual", names(seasons))) {
    cog_name <- paste0(var, "_", period, ".tif")
    cog_path <- file.path(cog_dir, cog_name)

    # Read existing COG from S3 (via /vsicurl)
    existing_row <- catalog[catalog$variable == var & catalog$period == period, ]
    if (nrow(existing_row) == 0) {
      log_msg("  ", var, "_", period, ": not in catalog, skipping")
      next
    }
    existing_rast <- tryCatch(
      rast(paste0("/vsicurl/", existing_row$href)),
      error = function(e) {
        stop("Failed to read existing COG: ", existing_row$href,
             "\nError: ", e$message, call. = FALSE)
      }
    )

    # Aggregate new years
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
    if (length(new_layers) == 0) next

    new_rast <- rast(new_layers)
    names(new_rast) <- names(new_layers)
    # Sanity: existing COG from S3 must share grid with freshly aggregated
    # layers. Floating-point epsilon differences in ext()/res() would break
    # c() stacking — catch it explicitly rather than produce a cryptic error.
    if (!isTRUE(all.equal(as.vector(ext(existing_rast)),
                          as.vector(ext(new_rast)), tolerance = 1e-6)) ||
        !isTRUE(all.equal(res(existing_rast), res(new_rast), tolerance = 1e-6))) {
      stop("Grid mismatch between existing COG (", existing_row$href, ") and new ",
           var, "_", period, ". Extent/res differ. Aborting.", call. = FALSE)
    }
    combined <- c(existing_rast, new_rast)
    cd_cog_write(combined, cog_path, overwrite = TRUE)
    log_msg("  Updated: ", cog_name, " (", nlyr(combined), " years total)")
  }
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
