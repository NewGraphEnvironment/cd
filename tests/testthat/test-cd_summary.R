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
