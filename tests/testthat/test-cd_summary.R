test_that("cd_summary returns expected structure", {
  trend <- tibble::tibble(
    variable = "tmean",
    period = "annual",
    trend_start = 1951,
    slope = 0.03,
    intercept = -50,
    mk_pvalue = 0.001,
    n_years = 70
  )
  smry <- cd_summary(trend)

  expect_s3_class(smry, "tbl_df")
  expect_named(smry, c("Parameter", "Period", "Slope", "Years", "Total Change", "Unit", "p-value"))
  expect_equal(smry$Parameter, "Mean temperature")
  expect_equal(smry$Period, "Annual")
  expect_equal(smry$Slope, 0.03)
  expect_equal(smry$Years, 70)
  expect_equal(smry$`Total Change`, 2.1)
})

test_that("cd_summary adds Region column when provided", {
  trend <- tibble::tibble(
    variable = "tmean", period = "annual", trend_start = 1951,
    slope = 0.03, intercept = -50, mk_pvalue = 0.001, n_years = 70
  )
  smry <- cd_summary(trend, region_name = "Test Region")

  expect_true("Region" %in% names(smry))
  expect_equal(smry$Region, "Test Region")
})

test_that("cd_summary handles multiple rows", {
  trend <- tibble::tibble(
    variable = c("tmean", "prcp"),
    period = c("annual", "summer"),
    trend_start = c(1951, 1951),
    slope = c(0.03, 0.5),
    intercept = c(-50, 100),
    mk_pvalue = c(0.001, 0.5),
    n_years = c(70, 70)
  )
  smry <- cd_summary(trend)

  expect_equal(nrow(smry), 2)
  expect_equal(smry$Parameter, c("Mean temperature", "Precipitation"))
  expect_equal(smry$`Total Change`, c(2.1, 35))
})

# Series outside cd_variables() (#92) -------------------------------------

test_that("cd_summary uses long_name and unit carried on the trend", {
  trend <- tibble::tibble(
    variable = "q_mean", period = "spawn", trend_start = 2000,
    slope = 0.5, intercept = 0, mk_pvalue = 0.01, n_years = 20,
    unit = "%", long_name = "Mean discharge"
  )
  smry <- cd_summary(trend)
  expect_equal(smry$Parameter, "Mean discharge")
  expect_equal(smry$Unit, "%")
  expect_equal(smry$Period, "Spawn")
})

test_that("cd_summary labels an unregistered variable by name with no unit", {
  trend <- tibble::tibble(
    variable = "q_mean", period = "spawn", trend_start = 2000,
    slope = 0.5, intercept = 0, mk_pvalue = 0.01, n_years = 20
  )
  smry <- cd_summary(trend)
  expect_equal(smry$Parameter, "q_mean")
  expect_true(is.na(smry$Unit))
})

test_that("cd_summary falls back to cd_variables() where carried columns are NA", {
  trend <- tibble::tibble(
    variable = c("tmean", "q_mean"), period = "annual", trend_start = 2000,
    slope = 0.1, intercept = 0, mk_pvalue = 0.01, n_years = 20,
    unit = c(NA, "%"), long_name = c(NA, "Mean discharge")
  )
  smry <- cd_summary(trend)
  expect_equal(smry$Parameter, c("Mean temperature", "Mean discharge"))
  expect_equal(smry$Unit, c("°C", "%"))
})

test_that("a series outside cd_variables() runs the whole chain (#92)", {
  skip_if_not_installed("Kendall")
  skip_if_not_installed("zyp")
  set.seed(92)
  x <- tibble::tibble(
    variable = "q_mean", period = "spawn", year = 1991:2020,
    value = 20 - 0.2 * (0:29) + stats::rnorm(30, sd = 0.5),
    anomaly_type = "pct_normal", unit = "%", long_name = "Mean discharge"
  )
  bl <- cd_baseline(x, baseline_years = 1991:2000)
  ano <- cd_anomaly(x, bl)
  expect_false(anyNA(ano$anomaly))
  trn <- cd_trend(ano, trend_start = 1991)
  expect_lt(trn$slope, 0)
  smry <- cd_summary(trn)
  expect_equal(smry$Parameter, "Mean discharge")
  expect_equal(smry$Unit, "%")
  expect_equal(smry$Period, "Spawn")

  cmp <- cd_compare(x, window_a = 2011:2020, window_b = 1991:2000)
  expect_lt(cmp$difference, 0)
  expect_false(is.na(cmp$p_value))
})

test_that("cd_summary keeps a registry unit off an overridden type through the chain", {
  skip_if_not_installed("Kendall")
  skip_if_not_installed("zyp")
  # prcp as "absolute" is mm, not the registry's "%" for pct_normal.
  x <- tibble::tibble(
    variable = "prcp", period = "annual", year = 2000:2009,
    value = seq(100, 190, by = 10), anomaly_type = "absolute"
  )
  ano <- cd_anomaly(x, cd_baseline(x, 2000:2004))
  smry <- cd_summary(cd_trend(ano, trend_start = 2000))
  expect_equal(smry$Parameter, "Precipitation")
  expect_true(is.na(smry$Unit))
})

test_that("the whole chain accepts grouped input (#92)", {
  skip_if_not_installed("Kendall")
  skip_if_not_installed("zyp")
  x <- tibble::tibble(
    variable = rep(c("q_mean", "q_min"), each = 10), period = "spawn",
    year = rep(2000:2009, 2), value = c(1:10, 10:1),
    anomaly_type = "absolute", unit = "m³/s"
  ) |>
    dplyr::group_by(.data$variable, .data$period)
  ano <- cd_anomaly(x, cd_baseline(x, 2000:2004))
  trn <- cd_trend(dplyr::group_by(ano, .data$variable), trend_start = 2000)
  smry <- cd_summary(dplyr::group_by(trn, .data$variable))
  expect_equal(nrow(smry), 2)
  expect_equal(smry$Unit, c("m³/s", "m³/s"))
  cmp <- cd_compare(x, window_a = 2005:2009, window_b = 2000:2004, test = NULL)
  expect_equal(cmp$difference, c(5, -5))
})

# Raw-value trends (#97) ---------------------------------------------------

raw_series <- function(v, ...) {
  tibble::tibble(variable = v, period = "annual", year = 2000:2009,
                 value = seq(100, 190, by = 10), ...)
}

test_that("cd_summary gives a raw-value trend no anomaly unit (#97)", {
  skip_if_not_installed("Kendall")
  skip_if_not_installed("zyp")
  smry <- function(x) cd_summary(cd_trend(x, trend_start = 2000))
  # prcp's registry unit is "%", the unit of its anomaly, not of mm
  expect_true(is.na(smry(raw_series("prcp"))$Unit))
  expect_true(is.na(smry(raw_series("soil_moisture"))$Unit))
  expect_equal(smry(raw_series("tmean"))$Unit, "°C")
  expect_equal(
    smry(raw_series("q_mean", anomaly_type = "absolute", unit = "m3/s"))$Unit,
    "m3/s"
  )
  expect_equal(
    smry(raw_series("prcp", anomaly_type = "absolute", unit = "mm"))$Unit,
    "mm"
  )
})

test_that("cd_summary's Unit matches cd_plot_timeseries()'s label (#97)", {
  skip_if_not_installed("Kendall")
  skip_if_not_installed("zyp")
  skip_if_not_installed("ggplot2")
  plot_unit <- function(x) {
    y <- cd_plot_timeseries(x)$labels$y
    if (grepl("\\)$", y)) sub("^.* \\((.*)\\)$", "\\1", y) else NA_character_
  }
  cases <- list(
    raw_series("prcp"),
    raw_series("tmean"),
    raw_series("snow_cover"),
    raw_series("swe"),
    raw_series("q_mean", unit = "%", long_name = "Mean discharge"),
    raw_series("q_mean", anomaly_type = "absolute", unit = "m3/s"),
    raw_series("q_mean", anomaly_type = "pct_normal", unit = "%"),
    raw_series("prcp", anomaly_type = "absolute", unit = "mm"),
    raw_series("prcp", anomaly_type = "absolute")
  )
  for (x in cases) {
    # an unregistered series with no anomaly_type has no anomaly to take
    typed <- "anomaly_type" %in% names(x) || x$variable[1] %in% cd_variables()$variable
    for (on in if (typed) c("value", "anomaly") else "value") {
      if (on == "anomaly") x <- cd_anomaly(x, cd_baseline(x, 2000:2004))
      label <- paste(c(on, unlist(x[1, intersect(c("variable", "anomaly_type", "unit"), names(x))])),
                     collapse = " ")
      expect_identical(
        cd_summary(cd_trend(x, trend_start = 2000))$Unit, plot_unit(x),
        info = label
      )
    }
  }
})

test_that("cd_summary resolves raw and anomaly trends row by row (#97)", {
  skip_if_not_installed("Kendall")
  skip_if_not_installed("zyp")
  x <- raw_series("prcp")
  ano <- cd_anomaly(x, cd_baseline(x, 2000:2004))
  trn <- dplyr::bind_rows(cd_trend(x, 2000), cd_trend(ano, 2000))
  expect_equal(cd_summary(trn)$Unit, c(NA, "%"))
})

test_that("cd_summary reads a trend without trend_on as an anomaly trend (#97)", {
  # the shape of trends saved before #97, e.g. inst/vignette-data/*.rds
  trend <- tibble::tibble(
    variable = "prcp", period = "annual", trend_start = 1951,
    slope = 0.05, intercept = -100, mk_pvalue = 0.4, n_years = 75
  )
  expect_equal(cd_summary(trend)$Unit, "%")
})

# Stations sharing a long_name (#98) ----------------------------------------

station_trend <- function(...) {
  tibble::tibble(
    variable = c("q_site1", "q_site2", "q_site1"), period = c("annual", "annual", "spawn"),
    trend_start = 2000, slope = c(0.1, -0.2, 0.3), intercept = 0, mk_pvalue = 0.05,
    n_years = 20, ...
  )
}

test_that("cd_summary tells apart stations that share a long_name (#98)", {
  smry <- cd_summary(station_trend(long_name = "Mean discharge", unit = "m3/s"))
  expect_equal(
    smry$Parameter,
    c("Mean discharge (q_site1)", "Mean discharge (q_site2)", "Mean discharge (q_site1)")
  )
})

test_that("cd_summary labels shared long_names as cd_plot_comparison() does (#98)", {
  skip_if_not_installed("ggplot2")
  cmp <- tibble::tibble(
    variable = c("q_site1", "q_site2"), period = "annual",
    mean_a = 1:2, mean_b = 2:3, difference = -1, method = "mean_diff",
    long_name = "Mean discharge"
  )
  p <- suppressWarnings(cd_plot_comparison(cmp))
  smry <- cd_summary(station_trend(long_name = "Mean discharge")[1:2, ])
  expect_setequal(smry$Parameter, unique(p$data$param))
})

test_that("cd_summary adds no suffix to registered variables (#98)", {
  # registry long_names are unique, so no ERA5 row is ever suffixed
  expect_equal(anyDuplicated(cd_variables()$long_name), 0)
  vars <- cd_variables()$variable
  trend <- tibble::tibble(
    variable = rep(vars, 2), period = rep(c("annual", "winter"), each = length(vars)),
    trend_start = 1951, slope = 0.1, intercept = 0, mk_pvalue = 0.1, n_years = 70
  )
  expect_false(any(grepl("\\(", cd_summary(trend)$Parameter)))
})
