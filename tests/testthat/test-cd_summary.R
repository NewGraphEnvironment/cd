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
