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

# The checkout's cd, not an installed one: library(cd) would compute with
# whatever version is installed, and its registry's units and anomaly types
# would land in inst/vignette-data/ (#135). Run from the package root, since
# the outputs below are written to root-relative paths.
pkgload::load_all(export_all = FALSE, quiet = TRUE)
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
regional_cmp <- cd_compare(regional_ts, method = "mean_diff")  # defaults: 2015:2025 vs 1951:1980, Welch t
# pct_change for the variables the vignette's percent tables read (#48 added
# swe / snowfall / snowmelt to this list; snow_cover and snowfall_fraction are
# pct_point_diff so mean_diff is the right comparison method for those —
# already in regional_cmp). These were the pct_normal variables until #139 made
# swe_max pct_normal too; the vignette tables do not read swe_max.
pct_normal_vars <- c("prcp", "soil_moisture", "swe", "snowfall", "snowmelt")
regional_cmp_pct <- cd_compare(
  regional_ts[regional_ts$variable %in% pct_normal_vars, ],
  method = "pct_change"
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
    method = "pct_change"
  )
  list(ts = ts, ano = ano, trn = trn, cmp_pct = cmp_pct)
})
names(ecoregion_results) <- ecoregions$code

# -- Sentences the prcp captions state (#102) ---------------------------------
# peace-fwcp.Rmd's captions are static text, so refuse to save data they no
# longer describe. Significance is Mann-Kendall p < 0.05.
# The ecoregions the vignette shows: it filters by area in its load-context
# chunk, so read its threshold rather than restate it here.
vignette_min_km2 <- function(rmd) {
  lines <- readLines(rmd)
  hit <- regmatches(lines, regexpr("ecoregions\\$area_km2 > [0-9.]+", lines))
  stopifnot(length(hit) == 1)
  as.numeric(sub(".*> ", "", hit))
}
shown <- ecoregions$code[
  ecoregions$area_km2 > vignette_min_km2("vignettes/peace-fwcp.Rmd")
]
p51 <- do.call(rbind, lapply(shown, function(code) {
  t <- ecoregion_results[[code]]$trn
  r <- t[t$variable == "prcp" & t$period == "annual" & t$trend_start == 1951, ]
  stopifnot(NROW(r) == 1)
  data.frame(code = code, slope = r$slope, p = r$mk_pvalue)
}))
# The roll-up's `prcp %/yr` header: its slopes are trends of pct_normal anomalies
prcp_rows <- do.call(rbind, lapply(ecoregion_results[shown], function(x) {
  x$trn[x$trn$variable == "prcp", ]
}))
centroid_lat <- suppressWarnings(
  st_coordinates(st_centroid(st_transform(ecoregions, 4326)))
)[, 2]
claims <- c(
  prcp_trend_pct_of_baseline = all(prcp_rows$trend_on == "anomaly" &
                                     prcp_rows$anomaly_type == "pct_normal"),
  # "The two northernmost ecoregions (BMP, NRM) show statistically significant
  # precipitation increases over the full record; the others do not."
  bmp_nrm_northernmost = setequal(
    head(shown[order(-centroid_lat[match(shown, ecoregions$code)])], 2),
    c("BMP", "NRM")
  ),
  prcp_significant_bmp_nrm = setequal(p51$code[p51$p < 0.05], c("BMP", "NRM")),
  prcp_bmp_nrm_increase = all(p51$slope[p51$code %in% c("BMP", "NRM")] > 0)
)
if (!all(claims %in% TRUE)) {
  stop("Vignette sentences no longer true of the data: ",
       paste(names(claims)[!claims %in% TRUE], collapse = ", "))
}

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
