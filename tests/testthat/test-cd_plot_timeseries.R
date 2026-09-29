test_that("cd_plot_timeseries returns a ggplot", {
  dat <- tibble::tibble(
    variable = rep("tmean", 10),
    period = rep("annual", 10),
    year = 1951:1960,
    anomaly = c(-2, -1, 0.5, 1, -0.5, 2, 1.5, -1, 0, 3)
  )
  p <- cd_plot_timeseries(dat)
  expect_s3_class(p, "ggplot")
})

test_that("cd_plot_timeseries works with trend overlay", {
  dat <- tibble::tibble(
    variable = rep("tmean", 10),
    period = rep("annual", 10),
    year = 1951:1960,
    anomaly = seq(-2, 3, length.out = 10)
  )
  trn <- tibble::tibble(
    variable = "tmean", period = "annual",
    trend_start = 1951, slope = 0.5, intercept = -990,
    mk_pvalue = 0.01, n_years = 10
  )
  p <- cd_plot_timeseries(dat, trend = trn)
  expect_s3_class(p, "ggplot")
})

test_that("cd_plot_timeseries works with value column", {
  dat <- tibble::tibble(
    variable = rep("tmean", 5),
    period = rep("annual", 5),
    year = 1951:1955,
    value = c(10, 11, 12, 13, 14)
  )
  p <- cd_plot_timeseries(dat)
  expect_s3_class(p, "ggplot")
})

test_that("cd_plot_timeseries errors on missing data", {
  dat <- tibble::tibble(
    variable = "tmean", period = "annual",
    year = 1951, anomaly = 1
  )
  expect_error(cd_plot_timeseries(dat, variable = "prcp"))
})

# Labels (#93) -------------------------------------------------------------

ano_dat <- function(variable = "q_mean", ...) {
  tibble::tibble(
    variable = variable, period = "spawn", year = 2001:2006,
    anomaly = c(-10, 5, 20, -30, 15, 0), ...
  )
}

test_that("cd_plot_timeseries labels a series outside cd_variables() by its carried metadata", {
  p <- cd_plot_timeseries(
    ano_dat(anomaly_type = "pct_normal", unit = "%", long_name = "Mean discharge"),
    period = "spawn"
  )
  expect_identical(p$labels$y, "Mean discharge (%)")
})

test_that("cd_plot_timeseries keeps the registry label for a registered variable", {
  p <- cd_plot_timeseries(ano_dat("tmean"), period = "spawn")
  expect_identical(p$labels$y, "Mean temperature (°C)")
})

test_that("cd_plot_timeseries drops the registry unit under an overriding anomaly_type", {
  p <- cd_plot_timeseries(ano_dat("prcp", anomaly_type = "absolute"), period = "spawn")
  expect_identical(p$labels$y, "Precipitation")
})

test_that("cd_plot_timeseries omits the parentheses when no unit resolves", {
  p <- cd_plot_timeseries(ano_dat(long_name = "Mean discharge"), period = "spawn")
  expect_identical(p$labels$y, "Mean discharge")
})

test_that("cd_plot_timeseries names the column, with a carried unit, when no long_name resolves", {
  p <- cd_plot_timeseries(ano_dat(unit = "%"), period = "spawn")
  expect_identical(p$labels$y, "anomaly (%)")
})

test_that("cd_plot_timeseries falls back to the column name when nothing resolves", {
  p <- cd_plot_timeseries(ano_dat(), period = "spawn")
  expect_identical(p$labels$y, "anomaly")
})

test_that("cd_plot_timeseries falls back to the registry where carried metadata is NA", {
  p <- cd_plot_timeseries(
    ano_dat("tmean", unit = NA_character_, long_name = NA_character_),
    period = "spawn"
  )
  expect_identical(p$labels$y, "Mean temperature (°C)")
})

test_that("cd_plot_timeseries errors on two long_names within the plotted series", {
  dat <- ano_dat(long_name = rep(c("Mean discharge", "Discharge"), each = 3))
  expect_error(cd_plot_timeseries(dat, period = "spawn"), "long_name")
})

test_that("cd_plot_timeseries errors on duplicate years instead of stacking bars", {
  dat <- rbind(ano_dat(), ano_dat())
  expect_error(cd_plot_timeseries(dat, period = "spawn"), "More than one row")
})

test_that("cd_plot_timeseries on raw values gives no anomaly unit to a pct_normal variable", {
  val <- function(v) {
    tibble::tibble(variable = v, period = "annual", year = 1951:1955, value = 1:5)
  }
  expect_identical(cd_plot_timeseries(val("prcp"))$labels$y, "Precipitation")
  expect_identical(cd_plot_timeseries(val("tmean"))$labels$y, "Mean temperature (°C)")
})

test_that("cd_plot_timeseries on raw values shows a unit only where the anomaly unit is the value unit", {
  val <- function(v, ...) {
    tibble::tibble(variable = v, period = "annual", year = 1951:1955, value = 1:5, ...)
  }
  expect_identical(cd_plot_timeseries(val("snow_cover"))$labels$y, "Snow cover (%)")
  # no resolvable anomaly_type: a carried (anomaly) unit is not the values' unit
  expect_identical(
    cd_plot_timeseries(val("q_mean", unit = "%", long_name = "Mean discharge"))$labels$y,
    "Mean discharge"
  )
  expect_identical(
    cd_plot_timeseries(val("q_mean", anomaly_type = "absolute", unit = "m3/s",
                           long_name = "Mean discharge"))$labels$y,
    "Mean discharge (m3/s)"
  )
})

test_that("cd_plot_timeseries ignores rows with NA variable or period", {
  dat <- tibble::tibble(
    variable = "tmean", period = c(NA, NA, "annual", "annual", "annual"),
    year = c(2001, 2002, 2001, 2002, 2003), anomaly = c(9, 9, 1, -1, 2)
  )
  p <- cd_plot_timeseries(dat)
  expect_identical(p$labels$y, "Mean temperature (°C)")
  expect_equal(nrow(p$data), 3)
})

test_that("cd_plot_timeseries checks duplicates only in the plotted series", {
  dat <- rbind(ano_dat("tmean"), ano_dat("q_mean"), ano_dat("q_mean"))
  expect_s3_class(cd_plot_timeseries(dat, variable = "tmean", period = "spawn"), "ggplot")
})

test_that("cd_plot_timeseries labels match cd_summary() for a series from another package", {
  q <- tibble::tibble(
    variable = "q_mean", period = "spawn", year = 2001:2010,
    value = c(12, 9, 14, 7, 6, 8, 10, 11, 5, 9),
    anomaly_type = "pct_normal", unit = "%", long_name = "Mean discharge"
  )
  ano <- cd_anomaly(q, cd_baseline(q, baseline_years = 2001:2005))
  smry <- cd_summary(cd_trend(ano, trend_start = 2001))
  p <- cd_plot_timeseries(ano, period = "spawn")
  expect_identical(p$labels$y, paste0(smry$Parameter, " (", smry$Unit, ")"))
})
