test_that("cd_trend returns expected structure", {
  ts <- tibble::tibble(
    variable = rep("tmean", 10),
    period = rep("annual", 10),
    year = 1951:1960,
    value = seq(0, 9)
  )
  trn <- cd_trend(ts, trend_start = 1951)

  expect_s3_class(trn, "tbl_df")
  expect_named(trn, c(
    "variable", "period", "trend_start", "slope", "intercept", "mk_pvalue",
    "n_years", "trend_on"
  ))
  expect_equal(trn$trend_on, "value")
  expect_equal(nrow(trn), 1)
  expect_equal(trn$n_years, 10)
  expect_equal(trn$trend_start, 1951)
})

test_that("cd_trend slope is positive for increasing series", {
  ts <- tibble::tibble(
    variable = rep("tmean", 20),
    period = rep("annual", 20),
    year = 1951:1970,
    value = seq(0, 19)
  )
  trn <- cd_trend(ts, trend_start = 1951)

  expect_true(trn$slope > 0)
  expect_true(trn$mk_pvalue < 0.05)
})

test_that("cd_trend handles multiple trend_start values", {
  ts <- tibble::tibble(
    variable = rep("tmean", 20),
    period = rep("annual", 20),
    year = 1951:1970,
    value = seq(0, 19)
  )
  trn <- cd_trend(ts, trend_start = c(1951, 1960))

  expect_equal(nrow(trn), 2)
  expect_equal(trn$trend_start, c(1951, 1960))
  expect_true(trn$n_years[1] > trn$n_years[2])
})

test_that("cd_trend works with anomaly column", {
  ts <- tibble::tibble(
    variable = rep("tmean", 10),
    period = rep("annual", 10),
    year = 1951:1960,
    anomaly = seq(-5, 4)
  )
  trn <- cd_trend(ts, trend_start = 1951)

  expect_equal(nrow(trn), 1)
  expect_true(trn$slope > 0)
})

test_that("cd_trend skips combos with < 3 years", {
  ts <- tibble::tibble(
    variable = rep("tmean", 2),
    period = rep("annual", 2),
    year = 1959:1960,
    value = 1:2
  )
  trn <- cd_trend(ts, trend_start = 1959)

  expect_equal(nrow(trn), 0)
})

test_that("cd_trend carries anomaly_type, unit and long_name through (#92)", {
  skip_if_not_installed("Kendall")
  skip_if_not_installed("zyp")
  x <- tibble::tibble(
    variable = "q_mean", period = "spawn", year = 2000:2009,
    anomaly = seq(-5, 13, by = 2), anomaly_type = "pct_normal", unit = "%",
    long_name = "Mean discharge"
  )
  trn <- cd_trend(x, trend_start = 2000)
  expect_named(trn, c(
    "variable", "period", "trend_start", "slope", "intercept", "mk_pvalue",
    "n_years", "trend_on", "anomaly_type", "unit", "long_name"
  ))
  expect_equal(trn$trend_on, "anomaly")
  expect_equal(trn$unit, "%")
  expect_equal(trn$long_name, "Mean discharge")
  expect_equal(trn$anomaly_type, "pct_normal")
})

test_that("cd_trend on raw values carries a unit only where it describes the values (#97)", {
  skip_if_not_installed("Kendall")
  skip_if_not_installed("zyp")
  x <- tibble::tibble(
    variable = "q_mean", period = "spawn", year = 2000:2009,
    value = 1:10, anomaly_type = "pct_normal", unit = "%",
    long_name = "Mean discharge"
  )
  trn <- cd_trend(x, trend_start = 2000)
  expect_named(trn, c(
    "variable", "period", "trend_start", "slope", "intercept", "mk_pvalue",
    "n_years", "trend_on", "anomaly_type", "unit", "long_name"
  ))
  expect_equal(trn$trend_on, "value")
  expect_equal(trn$anomaly_type, "pct_normal")
  # "%" is the anomaly's unit, not the unit of a slope of raw values
  expect_true(is.na(trn$unit))

  x$anomaly_type <- "absolute"
  x$unit <- "m3/s"
  expect_equal(cd_trend(x, trend_start = 2000)$unit, "m3/s")
})

test_that("cd_trend errors when one series carries two long_names (#92)", {
  skip_if_not_installed("Kendall")
  skip_if_not_installed("zyp")
  x <- tibble::tibble(
    variable = "q_mean", period = "spawn", year = 2000:2009, value = 1:10,
    long_name = rep(c("A", "B"), 5)
  )
  expect_error(cd_trend(x, trend_start = 2000), "long_name.*q_mean/spawn")
})

test_that("cd_trend resolves partly-NA metadata before checking it (#92)", {
  skip_if_not_installed("Kendall")
  skip_if_not_installed("zyp")
  x <- tibble::tibble(
    variable = "tmean", period = "annual", year = 2000:2009, value = 1:10,
    long_name = c("Mean temperature", rep(NA, 9))
  )
  expect_equal(cd_trend(x, trend_start = 2000)$long_name, "Mean temperature")
  ano <- tibble::tibble(
    variable = "tmean", period = "annual", year = 2000:2009, anomaly = 1:10,
    unit = c("°C", rep(NA, 9))
  )
  expect_equal(cd_trend(ano, trend_start = 2000)$unit, "°C")
})

test_that("cd_trend errors when a raw series carries two units (#97)", {
  skip_if_not_installed("Kendall")
  skip_if_not_installed("zyp")
  x <- tibble::tibble(
    variable = "q_mean", period = "annual", year = 2000:2009, value = 1:10,
    anomaly_type = "absolute", unit = rep(c("m3/s", "L/s"), 5)
  )
  expect_error(cd_trend(x, trend_start = 2000), "unit.*q_mean/annual")
})
