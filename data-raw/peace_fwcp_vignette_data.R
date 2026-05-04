# Pre-compute all heavy data for vignettes/peace-fwcp.Rmd
#
# Generates:
#   inst/vignette-data/peace_fwcp.rds                    (lists of ts/bl/ano/trn/cmp)
#   inst/vignette-data/peace_fwcp_departure_tmean.tif    (pre-cropped tmean departure)
#
# Run interactively when the underlying STAC catalog updates. The
# vignette reads these files via system.file(...) and renders without
# touching the network (apart from the small catalog JSON read demo).
#
# Total bundled output should be <1 MB.

# GDAL retry env vars — the regen pulls ~144 COG range requests from
# S3, so we want resilience to transient network blips even when not
# in CI.
Sys.setenv(
  GDAL_HTTP_MAX_RETRY = "3",
  GDAL_HTTP_RETRY_DELAY = "2",
  VSI_CACHE = "TRUE"
)

library(cd)
library(sf)
library(terra)

aoi <- st_read(
  system.file("extdata", "example_aoi_fwcp_peace.gpkg", package = "cd"),
  quiet = TRUE
)
ecoregions <- st_read(
  system.file("extdata", "context_fwcp_peace.gpkg", package = "cd"),
  layer = "ecoregions", quiet = TRUE
)
ecoregions <- ecoregions[ecoregions$area_km2 > 100, ]
ecoregions <- ecoregions[order(-ecoregions$area_km2), ]

catalog <- cd_catalog()

# -- Regional ----------------------------------------------------------------
message("Regional cd_extract ...")
regional_ts  <- cd_extract(catalog, aoi)
regional_bl  <- cd_baseline(regional_ts, baseline_years = 1951:1980)
regional_ano <- cd_anomaly(regional_ts, regional_bl)
regional_trn <- cd_trend(regional_ano, trend_start = c(1951, 1981))
regional_cmp <- cd_compare(regional_ts,
                           window_a = 2015:2025, window_b = 1951:1980,
                           method = "mean_diff")
# pct_change for vars with pct_normal anomaly type (#48 added swe / snowfall /
# snowmelt to this list; snow_cover and snowfall_fraction are pct_point_diff so
# mean_diff is the right comparison method for those — already in regional_cmp).
pct_normal_vars <- c("prcp", "soil_moisture", "swe", "snowfall", "snowmelt")
regional_cmp_pct <- cd_compare(
  regional_ts[regional_ts$variable %in% pct_normal_vars, ],
  window_a = 2015:2025, window_b = 1951:1980, method = "pct_change"
)

# -- Per-ecoregion -----------------------------------------------------------
ecoregion_results <- lapply(seq_len(nrow(ecoregions)), function(i) {
  er <- ecoregions[i, ]
  message("Ecoregion ", er$code, " (", i, "/", nrow(ecoregions), ") cd_extract ...")
  ts <- cd_extract(catalog, er)
  ano <- cd_anomaly(ts, cd_baseline(ts, baseline_years = 1951:1980))
  trn <- cd_trend(ano, trend_start = c(1951, 1981))
  cmp_pct <- cd_compare(
    ts[ts$variable %in% pct_normal_vars, ],
    window_a = 2015:2025, window_b = 1951:1980, method = "pct_change"
  )
  list(ts = ts, ano = ano, trn = trn, cmp_pct = cmp_pct)
})
names(ecoregion_results) <- ecoregions$code

# -- Spatial pattern raster (pre-cropped, masked, departure) -----------------
message("Spatial pattern raster ...")
tmean_row <- catalog[catalog$variable == "tmean" & catalog$period == "annual", ]
r_tmean <- cd_crop(tmean_row$href, aoi)
years <- as.integer(names(r_tmean))
recent_idx     <- which(years >= 2015 & years <= 2025)
historical_idx <- which(years >= 1951 & years <= 1980)
departure <- mean(r_tmean[[recent_idx]]) - mean(r_tmean[[historical_idx]])
departure <- terra::mask(departure, aoi)
names(departure) <- "tmean_departure"

# -- Write -------------------------------------------------------------------
out_dir <- "inst/vignette-data"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

saveRDS(
  list(
    regional = list(
      ts = regional_ts, bl = regional_bl, ano = regional_ano,
      trn = regional_trn, cmp = regional_cmp, cmp_pct = regional_cmp_pct
    ),
    ecoregion = ecoregion_results,
    ecoregion_codes = ecoregions$code
  ),
  file.path(out_dir, "peace_fwcp.rds"),
  compress = "xz"
)

terra::writeRaster(
  departure,
  file.path(out_dir, "peace_fwcp_departure_tmean.tif"),
  overwrite = TRUE,
  gdal = c("COMPRESS=DEFLATE", "TILED=YES")
)

cat("\nWrote:\n")
cat("  ", file.path(out_dir, "peace_fwcp.rds"),
    " (", round(file.size(file.path(out_dir, "peace_fwcp.rds")) / 1024, 1), " KB)\n", sep = "")
cat("  ", file.path(out_dir, "peace_fwcp_departure_tmean.tif"),
    " (", round(file.size(file.path(out_dir, "peace_fwcp_departure_tmean.tif")) / 1024, 1), " KB)\n", sep = "")
