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
