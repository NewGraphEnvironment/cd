# Pre-compute the data for vignettes/northern-bc.Rmd (#137)
#
# Generates:
#   inst/vignette-data/northern_bc.rds          (series, window comparisons,
#                                                map colours, summaries)
#   inst/vignette-data/northern_bc_bulkley.tif  (BULK: normal peak snowpack and
#                                                10-year temperature change)
#
# Run from the package root when the STAC catalog updates. The vignette reads
# these files via system.file() and renders offline. Bundled output < 1 MB.
#
# Prerequisites: network access to the live catalog; the gq package (GitHub
# only, so it is read here, never by the vignette).

Sys.setenv(
  GDAL_HTTP_MAX_RETRY = "3",
  GDAL_HTTP_RETRY_DELAY = "2",
  VSI_CACHE = "TRUE"
)

# The checkout's cd, not an installed one (#135).
pkgload::load_all(export_all = FALSE, quiet = TRUE)
library(sf)
library(terra)

aoi <- st_read(
  system.file("extdata", "example_aoi_northern_bc.gpkg", package = "cd"),
  quiet = TRUE
)

# How each variable's change is expressed, and which direction is the warm /
# dry one. Chosen here, not read from cd_variables()$anomaly_type: a percent
# change of a temperature in degrees C is meaningless, and the registry calls
# swe_max "absolute" where a percent of the normal snowpack is the
# plain-language number. Every sign and tint in the vignette reads `warm_if`.
lookup <- data.frame(
  variable = c("tmean", "tmax", "snowmelt_doy_50", "snowfall_fraction",
               "prcp", "swe_max", "vpd", "soil_moisture"),
  method   = c("mean_diff", "mean_diff", "mean_diff", "mean_diff",
               "pct_change", "pct_change", "pct_change", "pct_change"),
  unit     = c("degC", "degC", "days", "points", "pct", "pct", "pct", "pct"),
  warm_if  = c("up", "up", "down", "down", "down", "down", "up", "down")
)
compare_method <- setNames(lookup$method, lookup$variable)

catalog <- cd_catalog()
stopifnot(all(names(compare_method) %in% catalog$variable))

# -- Series for every area ----------------------------------------------------
ts <- lapply(seq_len(nrow(aoi)), function(i) {
  message("cd_extract ", aoi$code[i], " (", i, "/", nrow(aoi), ") ...")
  x <- cd_extract(catalog, aoi[i, ], variables = names(compare_method))
  x$code <- aoi$code[i]
  x
})
ts <- dplyr::bind_rows(ts)

# Windows end at the last year every area and variable holds. The catalog
# publishes whole years only, so that year is complete.
last_year <- min(tapply(ts$year, paste(ts$code, ts$variable), max))
windows <- list(
  normal = 1951:1980,
  last10 = (last_year - 9):last_year,
  last3  = (last_year - 2):last_year
)
message("Windows: last 10 = ", min(windows$last10), "-", last_year,
        ", last 3 = ", min(windows$last3), "-", last_year)

# -- Window comparisons -------------------------------------------------------
compare_window <- function(x, window_a, label) {
  out <- lapply(unique(compare_method), function(m) {
    vars <- names(compare_method)[compare_method == m]
    cd_compare(x[x$variable %in% vars, ], window_a = window_a,
               window_b = windows$normal, method = m, test = NULL)
  })
  out <- dplyr::bind_rows(out)
  out$window <- label
  out
}
cmp <- lapply(split(ts, ts$code), function(x) {
  cmp_code <- dplyr::bind_rows(
    compare_window(x, windows$last10, "last10"),
    compare_window(x, windows$last3, "last3")
  )
  cmp_code$code <- x$code[1]
  cmp_code
})
cmp <- dplyr::bind_rows(cmp)

# -- Warmer than any normal year ----------------------------------------------
tmean_annual <- ts[ts$variable == "tmean" & ts$period == "annual", ]
warm <- lapply(split(tmean_annual, tmean_annual$code), function(x) {
  normal <- x[x$year %in% windows$normal, ]
  recent <- x[x$year %in% windows$last10, ]
  data.frame(
    code = x$code[1],
    normal_mean = mean(normal$value),
    warmest_normal = max(normal$value),
    warmest_normal_year = normal$year[which.max(normal$value)],
    n_last10_warmer = sum(recent$value > max(normal$value)),
    # Is the first of the last 3 years carrying the 3-year result? The change
    # without it, beside the change with it.
    change_last3 = mean(x$value[x$year %in% windows$last3]) - mean(normal$value),
    change_last3_without_first =
      mean(x$value[x$year %in% windows$last3[-1]]) - mean(normal$value)
  )
})
warm <- dplyr::bind_rows(warm)

# Snow: the text must not imply record-low snowpack, so record whether any
# recent year fell below the lowest normal-period peak.
swe <- ts[ts$variable == "swe_max", ]
snow_low <- lapply(split(swe, swe$code), function(x) {
  data.frame(
    code = x$code[1],
    lowest_normal = min(x$value[x$year %in% windows$normal]),
    n_last10_below = sum(x$value[x$year %in% windows$last10] <
                           min(x$value[x$year %in% windows$normal]))
  )
})
snow_low <- dplyr::bind_rows(snow_low)
# The vignette says the snowpack shifted on average, not at the extremes.
# A regen that breaks that must stop here, not ship a wrong sentence.
stopifnot(all(snow_low$n_last10_below == 0))

# -- Upper vs lower Bulkley ---------------------------------------------------
value_of <- function(code, variable, period, window) {
  d <- cmp[cmp$code == code & cmp$variable == variable & cmp$period == period &
             cmp$window == window, ]
  stopifnot(nrow(d) == 1)
  d$difference
}
normal_of <- function(code, variable, period) {
  x <- ts[ts$code == code & ts$variable == variable & ts$period == period &
            ts$year %in% windows$normal, ]
  mean(x$value)
}
bulkley_parts <- data.frame(code = c("BULK_UPPER", "BULK_LOWER"))
bulkley_parts$prcp_normal_mm <- sapply(bulkley_parts$code, normal_of, "prcp", "annual")
bulkley_parts$swe_max_normal_mm <- sapply(bulkley_parts$code, normal_of, "swe_max", "annual")
bulkley_parts$tmean_change_last10 <- sapply(bulkley_parts$code, value_of, "tmean", "annual", "last10")
bulkley_parts$swe_max_pct_last10 <- sapply(bulkley_parts$code, value_of, "swe_max", "annual", "last10")
bulkley_parts$prcp_summer_pct_last3 <- sapply(bulkley_parts$code, value_of, "prcp", "summer", "last3")
# "The same change on a drier starting point" holds only while the two halves
# warmed alike, lost a like share of snowpack, and the upper one starts with
# less water.
stopifnot(
  abs(diff(bulkley_parts$tmean_change_last10)) < 0.2,
  abs(diff(bulkley_parts$swe_max_pct_last10)) < 3,
  bulkley_parts$prcp_normal_mm[1] < bulkley_parts$prcp_normal_mm[2],
  bulkley_parts$swe_max_normal_mm[1] < bulkley_parts$swe_max_normal_mm[2]
)

# -- Scorecard ----------------------------------------------------------------
signals <- data.frame(
  signal = c("Average temperature", "Total precipitation", "Summer rain",
             "Peak snowpack", "Date half the snow has melted",
             "Summer air dryness", "Summer soil moisture"),
  variable = c("tmean", "prcp", "prcp", "swe_max", "snowmelt_doy_50", "vpd",
               "soil_moisture"),
  period = c("annual", "annual", "summer", "annual", "annual", "summer", "summer")
)
signals <- merge(signals, lookup, by = "variable", sort = FALSE)
scorecard <- merge(
  signals,
  cmp[cmp$code %in% c("BULK", "NECR", "PARS"),
      c("code", "variable", "period", "window", "difference")],
  by = c("variable", "period")
)
scorecard <- tidyr::pivot_wider(scorecard, names_from = window,
                                values_from = difference)
# Tint a cell only when both windows moved the same way.
scorecard$direction <- with(scorecard, ifelse(
  sign(last10) != sign(last3), "mixed",
  ifelse((last10 > 0) == (warm_if == "up"), "warm_dry", "cool_wet")
))
scorecard <- scorecard[order(match(scorecard$signal, signals$signal),
                             scorecard$code), ]

# -- Sentences the vignette states as fact ------------------------------------
# The vignette prints the size of a change and lets its words carry the
# direction ("% less", "days earlier"), so each direction it names is checked
# here. A regen that turns one false stops before it writes.
wsg_codes <- c("BULK", "NECR", "PARS")
d_ <- function(variable, period, window, codes = wsg_codes) {
  vapply(codes, value_of, numeric(1), variable, period, window)
}
claims <- c(
  # intro, scorecard caption, temperature heading
  warmer_both          = all(d_("tmean", "annual", "last10") > 0,
                             d_("tmean", "annual", "last3") > 0),
  every_recent_year_warm = all(sapply(wsg_codes, function(code) {
    x <- tmean_annual[tmean_annual$code == code, ]
    # "almost every": at most one of the last 10 at or below normal
    sum(x$value[x$year %in% windows$last10] >
          warm$normal_mean[warm$code == code]) >= length(windows$last10) - 1
  })),
  smaller_snowpack     = all(d_("swe_max", "annual", "last10") < 0,
                             d_("swe_max", "annual", "last3") < 0),
  melt_earlier         = all(d_("snowmelt_doy_50", "annual", "last10") < 0,
                             d_("snowmelt_doy_50", "annual", "last3") < 0),
  drier_summer_air     = all(d_("vpd", "summer", "last10") > 0,
                             d_("vpd", "summer", "last3") > 0),
  drier_summer_soil    = all(d_("soil_moisture", "summer", "last10") < 0,
                             d_("soil_moisture", "summer", "last3") < 0),
  prcp_moved_little    = all(abs(d_("prcp", "annual", "last10")) < 6),
  last3_drier          = all(d_("prcp", "annual", "last3") < 0),
  # seasons heading and caption
  every_season_warmer  = all(sapply(c("winter", "spring", "summer", "fall"),
                                    function(p) d_("tmean", p, "last10") > 0)),
  winter_warmed_most_last3 = all(sapply(wsg_codes, function(code) {
    s <- sapply(c("winter", "spring", "summer", "fall"),
                function(p) value_of(code, "tmean", p, "last3"))
    names(which.max(s)) == "winter"
  })),
  winter_wetter_last3  = all(d_("prcp", "winter", "last3") > 0),
  spring_summer_drier_last3 = all(d_("prcp", "spring", "last3") < 0,
                                  d_("prcp", "summer", "last3") < 0),
  # Bulkley paragraph: "both lost", "% less than normal"
  bulkley_both_lost_snow = all(bulkley_parts$swe_max_pct_last10 < 0),
  bulkley_summer_rain_less = all(bulkley_parts$prcp_summer_pct_last3 < 0)
)
if (!all(claims)) {
  stop("Vignette sentences no longer true of the data: ",
       paste(names(claims)[!claims], collapse = ", "))
}

# -- BULK rasters for the Bulkley maps ----------------------------------------
message("Bulkley rasters ...")
bulk <- aoi[aoi$code == "BULK", ]
href <- function(v) catalog$href[catalog$variable == v & catalog$period == "annual"]
window_mean <- function(r, yrs) mean(r[[as.integer(names(r)) %in% yrs]])

r_swe <- cd_crop(href("swe_max"), bulk)
r_tmean <- cd_crop(href("tmean"), bulk)
# ERA5-Land holds glacier points at a fixed, very deep snowpack; one such cell
# would dominate the snowpack map. Every cell must vary from year to year and
# stay below a depth no seasonal snowpack reaches.
swe_normal <- r_swe[[as.integer(names(r_swe)) %in% windows$normal]]
stopifnot(
  all(terra::values(terra::app(swe_normal, sd)) > 0, na.rm = TRUE),
  terra::global(swe_normal, "max", na.rm = TRUE)$max < 5000
)

# Grid cells behind each area's numbers (cells the polygon touches).
cells <- vapply(seq_len(nrow(aoi)), function(i) {
  r <- cd_crop(href("tmean"), aoi[i, ])[[1]]
  as.integer(terra::global(!is.na(r), "sum")$sum)
}, integer(1))
names(cells) <- aoi$code
print(cells)
bulkley <- c(
  window_mean(r_swe, windows$normal),
  window_mean(r_tmean, windows$last10) - window_mean(r_tmean, windows$normal)
)
names(bulkley) <- c("swe_max_normal", "tmean_change_last10")

# -- Map colours from the gq registry -----------------------------------------
reg <- gq::gq_reg_main()
style <- list(
  lake_fill    = reg$layers$lake$fill$color,
  lake_stroke  = reg$layers$lake$stroke$color,
  river        = reg$layers$rivers_poly$fill$color,
  wsg_fill     = reg$layers$watershed_group_boundary$fill$color,
  wsg_stroke   = reg$layers$watershed_group_boundary$stroke$color
)
stopifnot(all(vapply(style, function(x) is.character(x) && nzchar(x), logical(1))))

# -- Write --------------------------------------------------------------------
out_dir <- "inst/vignette-data"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
rds <- file.path(out_dir, "northern_bc.rds")
tif <- file.path(out_dir, "northern_bc_bulkley.tif")

saveRDS(
  list(
    aoi = sf::st_drop_geometry(aoi),
    windows = windows,
    lookup = lookup,
    cells = cells,
    ts = ts,
    cmp = cmp,
    warm = warm,
    snow_low = snow_low,
    bulkley_parts = bulkley_parts,
    scorecard = scorecard,
    style = style
  ),
  rds,
  compress = "xz"
)
terra::writeRaster(bulkley, tif, overwrite = TRUE,
                   gdal = c("COMPRESS=DEFLATE", "TILED=YES"))

# -- Report: the numbers #137 was planned on ----------------------------------
key <- data.frame(
  signal = c("tmean annual", "tmean winter", "tmax summer", "prcp annual",
             "prcp summer", "swe_max", "snowmelt_doy_50", "snowfall_fraction",
             "vpd summer", "soil_moisture summer"),
  variable = c("tmean", "tmean", "tmax", "prcp", "prcp", "swe_max",
               "snowmelt_doy_50", "snowfall_fraction", "vpd", "soil_moisture"),
  period = c("annual", "winter", "summer", "annual", "summer", "annual",
             "annual", "annual", "summer", "summer")
)
for (code in aoi$code) {
  cat("\n", code, "  (10 yr / 3 yr)\n", sep = "")
  for (i in seq_len(nrow(key))) {
    d <- cmp[cmp$code == code & cmp$variable == key$variable[i] &
               cmp$period == key$period[i], ]
    cat(sprintf("  %-22s %7.1f / %7.1f\n", key$signal[i],
                d$difference[d$window == "last10"],
                d$difference[d$window == "last3"]))
  }
}
cat("\nLast-10 years warmer than the warmest normal year:\n")
print(warm)
cat("\nPeak snowpack below the lowest normal year:\n")
print(snow_low)
cat("\nUpper vs lower Bulkley:\n")
print(bulkley_parts)

cat("\nWrote:\n")
for (f in c(rds, tif)) cat("  ", f, " (", round(file.size(f) / 1024, 1), " KB)\n", sep = "")
