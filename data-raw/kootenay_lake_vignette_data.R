# Pre-compute heavy data for vignettes/kootenay-lake.Rmd
#
# Mirrors data-raw/peace_fwcp_vignette_data.R for the 4-WSG Kootenay
# Lake AOI. Generates:
#   inst/vignette-data/kootenay_lake.rds                  (regional + per-WSG +
#                                                         per-ecoregion lists)
#   inst/vignette-data/kootenay_lake_departure_tmean.tif  (pre-cropped tmean
#                                                         departure raster)
#
# Run interactively when the underlying STAC catalog updates. The
# vignette reads these files via system.file(...) and renders without
# touching the network (apart from the small catalog JSON read demo).
#
# Total bundled output should be <500 KB.

# GDAL retry env vars — the regen pulls many COG range requests from
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
  system.file("extdata", "example_aoi_kootenay_lake.gpkg", package = "cd"),
  quiet = TRUE
)
ctx <- system.file("extdata", "context_kootenay_lake.gpkg", package = "cd")
ecoregions <- st_read(ctx, layer = "ecoregions", quiet = TRUE)
ecoregions <- ecoregions[order(-ecoregions$area_km2), ]
wsgs <- st_read(ctx, layer = "wsgs", quiet = TRUE)
wsgs <- wsgs[order(wsgs$code), ]

catalog <- cd_catalog()

# pct_change for the variables the vignette's percent tables read. Mirrors
# peace_fwcp_vignette_data.R. These were the pct_normal variables until #139
# made swe_max pct_normal too; the vignette tables do not read swe_max.
pct_normal_vars <- c("prcp", "soil_moisture", "swe", "snowfall", "snowmelt")

# -- Regional ----------------------------------------------------------------
message("Regional cd_extract ...")
regional_ts  <- cd_extract(catalog, aoi)
regional_bl  <- cd_baseline(regional_ts, baseline_years = 1951:1980)
regional_ano <- cd_anomaly(regional_ts, regional_bl)
regional_trn <- cd_trend(regional_ano, trend_start = c(1951, 1981))
regional_cmp <- cd_compare(regional_ts, method = "mean_diff")  # defaults: 2015:2025 vs 1951:1980, Welch t
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

# -- Per-WSG (4 watershed groups: KOTL, LARL, DUNC, SLOC) --------------------
# Same shape as ecoregion_results — used by the snow per-WSG facet plot.
wsg_results <- lapply(seq_len(nrow(wsgs)), function(i) {
  w <- wsgs[i, ]
  message("WSG ", w$code, " (", i, "/", nrow(wsgs), ") cd_extract ...")
  ts <- cd_extract(catalog, w)
  ano <- cd_anomaly(ts, cd_baseline(ts, baseline_years = 1951:1980))
  trn <- cd_trend(ano, trend_start = c(1951, 1981))
  cmp_pct <- cd_compare(
    ts[ts$variable %in% pct_normal_vars, ],
    method = "pct_change"
  )
  list(ts = ts, ano = ano, trn = trn, cmp_pct = cmp_pct)
})
names(wsg_results) <- wsgs$code

# -- Sentences the prcp captions state (#102) ---------------------------------
# kootenay-lake.Rmd's captions are static text, so refuse to save data they
# no longer describe. Significance is Mann-Kendall p < 0.05.
# The ecoregions the vignette shows: it filters by area in its load-context
# chunk, so read its threshold rather than restate it here. This reads source
# text, so it refuses any shape it was not written for: `ecoregions` assigned
# only by st_read() and one bare area filter, and `results` subset only by
# `results[ecoregions$code]`. The rendered page is still the final check.
vignette_min_km2 <- function(rmd) {
  lines <- readLines(rmd)
  filt <- "^\\s*ecoregions\\s*<-\\s*ecoregions\\[ecoregions\\$area_km2 > ([0-9.]+), \\]\\s*$"
  stopifnot(
    sum(grepl(filt, lines)) == 1,
    sum(grepl("^\\s*ecoregions\\s*<-", lines)) == 2,
    sum(grepl("^\\s*ecoregions\\s*<-\\s*st_read\\(", lines)) == 1,
    sum(grepl("^\\s*results\\s*<-\\s*results\\[", lines)) == 1,
    sum(grepl("^\\s*results\\s*<-\\s*results\\[ecoregions\\$code\\]\\s*$", lines)) == 1
  )
  as.numeric(sub(filt, "\\1", grep(filt, lines, value = TRUE)))
}
shown <- ecoregions$code[
  ecoregions$area_km2 > vignette_min_km2("vignettes/kootenay-lake.Rmd")
]
prcp_trend <- function(start) {
  do.call(rbind, lapply(shown, function(code) {
    t <- ecoregion_results[[code]]$trn
    r <- t[t$variable == "prcp" & t$period == "annual" & t$trend_start == start, ]
    stopifnot(NROW(r) == 1)
    data.frame(code = code, slope = r$slope, p = r$mk_pvalue)
  }))
}
p51 <- prcp_trend(1951)
p81 <- prcp_trend(1981)
# The roll-up's `prcp %/yr` header: its slopes are trends of pct_normal anomalies
prcp_rows <- do.call(rbind, lapply(ecoregion_results[shown], function(x) {
  x$trn[x$trn$variable == "prcp", ]
}))
claims <- c(
  prcp_trend_pct_of_baseline = all(prcp_rows$trend_on == "anomaly" &
                                     prcp_rows$anomaly_type == "pct_normal"),
  # "all three ecoregions shown", and the caption names each of them
  shown_are_ncm_sbf_ptr = setequal(shown, c("NCM", "SBF", "PTR")),
  ncm_ptr_names = setequal(
    toupper(ecoregions$name[ecoregions$code %in% c("NCM", "PTR")]),
    c("NORTHERN COLUMBIA MOUNTAINS", "PURCELL TRANSITIONAL RANGES")
  ),
  # "Precipitation declines in all three ecoregions shown over the full record"
  prcp_declines_everywhere = all(p51$slope < 0),
  # "significant in ... (NCM) and ... (PTR), not in SBF"
  prcp_significant_ncm_ptr = setequal(p51$code[p51$p < 0.05], c("NCM", "PTR")),
  # "None of the 45-year trends is significant"
  prcp_none_significant_1981 = all(p81$p >= 0.05)
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

# -- WSG x ecoregion overlap (4 WSGs x 4 ecoregions = 16 cells, hand-buildable) -
message("WSG x ecoregion overlap ...")
wsgs_3005 <- st_transform(wsgs, 3005)
ecoregions_3005 <- st_transform(ecoregions, 3005)
wsg_eco_overlap <- do.call(rbind, lapply(seq_len(nrow(wsgs_3005)), function(i) {
  w <- wsgs_3005[i, ]
  total_area <- as.numeric(st_area(w)) / 1e6
  do.call(rbind, lapply(seq_len(nrow(ecoregions_3005)), function(j) {
    er <- ecoregions_3005[j, ]
    inter <- suppressWarnings(st_intersection(w, er))
    if (nrow(inter) == 0) return(NULL)
    area_km2 <- as.numeric(sum(st_area(inter))) / 1e6
    if (area_km2 < 0.5) return(NULL)
    data.frame(
      wsg_code = w$code, wsg_name = w$name,
      ecoregion_code = er$code, ecoregion_name = er$name,
      area_km2 = round(area_km2, 1),
      pct_of_wsg = round(100 * area_km2 / total_area, 1)
    )
  }))
}))

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
    ecoregion_codes = ecoregions$code,
    wsg = wsg_results,
    wsg_codes = wsgs$code,
    wsg_eco_overlap = wsg_eco_overlap
  ),
  file.path(out_dir, "kootenay_lake.rds"),
  compress = "xz"
)

terra::writeRaster(
  departure,
  file.path(out_dir, "kootenay_lake_departure_tmean.tif"),
  overwrite = TRUE,
  gdal = c("COMPRESS=DEFLATE", "TILED=YES")
)

cat("\nWrote:\n")
cat("  ", file.path(out_dir, "kootenay_lake.rds"),
    " (", round(file.size(file.path(out_dir, "kootenay_lake.rds")) / 1024, 1),
    " KB)\n", sep = "")
cat("  ", file.path(out_dir, "kootenay_lake_departure_tmean.tif"),
    " (", round(file.size(file.path(out_dir, "kootenay_lake_departure_tmean.tif")) / 1024, 1),
    " KB)\n", sep = "")
