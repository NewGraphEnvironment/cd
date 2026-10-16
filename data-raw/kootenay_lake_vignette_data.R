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

# -- Sentences the vignette states (#102, #146) ------------------------------
# kootenay-lake.Rmd's captions and prose carry static words (significant, every,
# only), so refuse to save data they no longer describe. The numbers beside
# them are computed inline at render. Significance is p < 0.05.
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
min_km2 <- vignette_min_km2("vignettes/kootenay-lake.Rmd")
shown <- ecoregions$code[ecoregions$area_km2 > min_km2]
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
annual_trend <- function(trn, var, start) {
  r <- trn[trn$variable == var & trn$period == "annual" & trn$trend_start == start, ]
  stopifnot(NROW(r) == 1)
  r
}
er_p <- function(var, start, col = "mk_pvalue") {
  vapply(shown, function(code) {
    annual_trend(ecoregion_results[[code]]$trn, var, start)[[col]]
  }, numeric(1))
}
er_slope <- function(var, start) er_p(var, start, col = "slope")
sm51 <- annual_trend(regional_trn, "soil_moisture", 1951)
sm81 <- annual_trend(regional_trn, "soil_moisture", 1981)
sm_window_p <- regional_cmp$p_value[regional_cmp$variable == "soil_moisture" &
                                      regional_cmp$period == "annual"]
sm_window_pct <- regional_cmp_pct$difference[
  regional_cmp_pct$variable == "soil_moisture" & regional_cmp_pct$period == "annual"
]
temp_window <- regional_cmp[regional_cmp$variable %in% c("tmean", "tmax", "tmin") &
                              regional_cmp$period == "annual", ]
temp_trend <- do.call(rbind, lapply(c("tmean", "tmax", "tmin"), function(v) {
  annual_trend(regional_trn, v, 1951)
}))
stopifnot(length(sm_window_p) == 1, length(sm_window_pct) == 1,
          nrow(temp_window) == 3)
wsg_prcp <- do.call(rbind, lapply(names(wsg_results), function(code) {
  r <- annual_trend(wsg_results[[code]]$trn, "prcp", 1951)
  data.frame(code = code, slope = r$slope, p = r$mk_pvalue)
}))
# The seasonal snow table's rows (variables as in its snow_monthly; snow_cover
# has no pct_change row)
snow_season <- regional_cmp_pct[
  regional_cmp_pct$variable %in% c("swe", "snowfall", "snowmelt") &
    regional_cmp_pct$period %in% c("winter", "spring", "summer", "fall"),
]
snow_season_pct <- setNames(snow_season$difference,
                            paste(snow_season$variable, snow_season$period))
stopifnot(length(snow_season_pct) == 12)
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
  prcp_none_significant_1981 = all(p81$p >= 0.05),
  # Soil moisture: "the trend test finds a steady decline" from 1951 and 1981
  soil_declines_both_starts = sm51$slope < 0 && sm81$slope < 0 &&
    sm51$mk_pvalue < 0.05 && sm81$mk_pvalue < 0.05,
  # "too small a step for the window test"
  soil_window_not_significant = sm_window_p >= 0.05,
  # "Soil moisture is down <x> %" (twice)
  soil_window_down = sm_window_pct < 0,
  # "when the decline is significant in every ecoregion shown"
  soil_significant_every_shown_1981 = all(er_p("soil_moisture", 1981) < 0.05 &
                                            er_slope("soil_moisture", 1981) < 0),
  # Trends: "The recent decade was between <x> °C warmer ... for annual mean,
  # daytime maximum, and overnight minimum, with both window and trend p-values
  # below 0.001" (trend = the table's 75-yr column)
  regional_temperature_warmer_p_below_0.001 = all(temp_window$difference > 0) &&
    all(temp_window$p_value < 0.001) && all(temp_trend$slope > 0) &&
    all(temp_trend$mk_pvalue < 0.001),
  # "Mann-Kendall p-values below 0.001 in every ecoregion", and the roll-up's
  # "All temperature p-values are below 0.001"
  temperature_p_below_0.001_every_shown = all(
    c(er_p("tmean", 1951), er_p("tmax", 1951), er_p("tmin", 1951)) < 0.001
  ) && all(c(er_slope("tmean", 1951), er_slope("tmax", 1951),
             er_slope("tmin", 1951)) > 0),
  # "points down in all four, but only in KOTL is it statistically significant"
  wsg_prcp_declines_everywhere = nrow(wsg_prcp) == 4 && all(wsg_prcp$slope < 0),
  wsg_prcp_significant_kotl_only = setequal(wsg_prcp$code[wsg_prcp$p < 0.05], "KOTL"),
  # "Spatially the decline is consistent across the three ecoregions shown,
  # down between ..." (window percent change)
  prcp_window_down_every_shown = all(vapply(shown, function(code) {
    x <- ecoregion_results[[code]]$cmp_pct
    d <- x$difference[x$variable == "prcp" & x$period == "annual"]
    length(d) == 1 && d < 0
  }, logical(1))),
  # The Per-Ecoregion intro states the filter: "Ecoregions under <N> km²"
  prose_states_filter = sum(grepl(
    paste0("Ecoregions under ", format(min_km2), " km"),
    readLines("vignettes/kootenay-lake.Rmd"), fixed = TRUE
  )) == 1,
  # Seasonal snow caption: summer SWE and summer snowmelt "carry the largest
  # losses"; "winter and spring snowmelt rose"
  snow_summer_largest_losses = setequal(
    names(sort(snow_season_pct))[1:2], c("swe summer", "snowmelt summer")
  ),
  snowmelt_winter_spring_rose = all(snow_season_pct[c("snowmelt winter",
                                                      "snowmelt spring")] > 0)
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
