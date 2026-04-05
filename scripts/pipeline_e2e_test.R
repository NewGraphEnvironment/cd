#!/usr/bin/env Rscript
#
# pipeline_e2e_test.R
#
# End-to-end test of the full cd pipeline:
#   CDS fetch → derive → COG write → STAC catalog → S3 push → consumer read
#
# Prerequisites:
#   - CDS API key in ~/.cdsapirc or macOS keyring
#   - AWS CLI configured with access to stac-era5-land bucket
#   - R packages: cd (devtools::load_all() or installed)
#
# Usage:
#   Rscript scripts/pipeline_e2e_test.R
#
# Output:
#   data/e2e_raw/      — raw GRIB downloads from CDS
#   data/e2e_derived/  — derived variables (VPD, RH, soil moisture)
#   data/e2e_cogs/     — Cloud-Optimized GeoTIFFs
#   data/e2e_cogs/catalog.json — STAC catalog
#   S3: stac-era5-land bucket

if (requireNamespace("cd", quietly = TRUE)) {
  library(cd)
} else {
  devtools::load_all()
}
library(terra)
library(sf)

raw_dir <- "data/e2e_raw"
derived_dir <- "data/e2e_derived"
cog_dir <- "data/e2e_cogs"

# -- Step 1: Fetch from CDS ---------------------------------------------------
message("\n=== STEP 1: FETCH ===")
files <- cd_fetch(
  years = 2024,
  months = 1,
  variables = c("tmean", "vpd", "rh"),
  output_dir = raw_dir
)
message("Downloaded: ", paste(basename(files), collapse = ", "))

# -- Step 2: Derive VPD and RH ------------------------------------------------
message("\n=== STEP 2: DERIVE ===")
derived <- cd_derive(raw_dir, derived_dir, variables = c("vpd", "rh"))
message("Derived: ", paste(basename(derived), collapse = ", "))

# -- Step 3: Convert raw tmean to COG -----------------------------------------
message("\n=== STEP 3: WRITE COGS ===")
r <- rast(files[grep("monthly", files)])
temp_idx <- grep("2 metre temperature", names(r))
tmean_c <- r[[temp_idx]] - 273.15
names(tmean_c) <- "2024"
cd_cog_write(tmean_c, file.path(cog_dir, "tmean_annual.tif"), overwrite = TRUE)

# Copy derived files as COGs — add "annual" to filenames for STAC parsing
for (f in derived) {
  # vpd_2024.tif → vpd_annual.tif
  new_name <- sub("_\\d{4}\\.tif$", "_annual.tif", basename(f))
  out <- file.path(cog_dir, new_name)
  r_d <- rast(f)
  names(r_d) <- "2024"
  cd_cog_write(r_d, out, overwrite = TRUE)
}
message("COGs: ", paste(list.files(cog_dir, pattern = "\\.tif$"), collapse = ", "))

# -- Step 4: Generate STAC catalog --------------------------------------------
message("\n=== STEP 4: STAC CATALOG ===")
catalog_path <- file.path(cog_dir, "catalog.json")
cd_stac_catalog(
  cog_dir,
  output_path = catalog_path,
  base_url = "https://stac-era5-land.s3.us-west-2.amazonaws.com"
)

# -- Step 5: Push to S3 -------------------------------------------------------
message("\n=== STEP 5: S3 PUSH ===")
cd_s3_push(cog_dir, bucket = "stac-era5-land", dry_run = FALSE)

# -- Step 6: Consumer — read back from S3 catalog -----------------------------
message("\n=== STEP 6: CONSUMER READ ===")
catalog <- cd_catalog(
  "https://stac-era5-land.s3.us-west-2.amazonaws.com/catalog.json"
)
cat("Catalog:\n")
print(catalog)

# -- Step 7: Extract for an AOI -----------------------------------------------
message("\n=== STEP 7: EXTRACT ===")
aoi <- st_read(
  system.file("extdata", "example_aoi.gpkg", package = "cd"),
  quiet = TRUE
)
ts <- cd_extract(catalog, aoi)
cat("Time series:\n")
print(ts)

# -- Step 8: Analyze ----------------------------------------------------------
message("\n=== STEP 8: ANALYZE ===")
bl <- cd_baseline(ts, baseline_years = 2024)
ano <- cd_anomaly(ts, bl)
cat("Anomalies:\n")
print(ano)

message("\n=== END-TO-END COMPLETE ===")
message("Pipeline: CDS -> derive -> COG -> STAC -> S3 -> catalog -> extract -> analyze")
