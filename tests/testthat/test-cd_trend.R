test_that("cd_trend returns expected structure", {
  ts <- tibble::tibble(
    variable = rep("tmean", 10),
    period = rep("annual", 10),
    year = 1951:1960,
    value = seq(0, 9)
  )
  trn <- cd_trend(ts, trend_start = 1951)

  expect_s3_class(trn, "tbl_df")
  expect_named(trn, c("variable", "period", "trend_start", "slope", "intercept", "mk_pvalue", "n_years"))
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
