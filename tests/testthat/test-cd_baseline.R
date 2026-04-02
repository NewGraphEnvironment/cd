test_that("cd_baseline computes mean of baseline years", {
  ts <- tibble::tibble(
    variable = rep("tmean", 10),
    period = rep("annual", 10),
    year = 1951:1960,
    value = c(-3, -2, -1, 0, 1, 2, 3, 4, 5, 6)
  )
  bl <- cd_baseline(ts, baseline_years = 1951:1955)

  expect_s3_class(bl, "tbl_df")
  expect_named(bl, c("variable", "period", "baseline_mean"))
  expect_equal(nrow(bl), 1)
  expect_equal(bl$baseline_mean, mean(-3:1))
})

test_that("cd_baseline handles multiple variable-period combos", {
  ts <- tibble::tibble(
    variable = rep(c("tmean", "prcp"), each = 5),
    period = rep("annual", 10),
    year = rep(1951:1955, 2),
    value = c(1:5, 10:14)
  )
  bl <- cd_baseline(ts, baseline_years = 1951:1955)

  expect_equal(nrow(bl), 2)
  expect_equal(bl$baseline_mean[bl$variable == "tmean"], 3)
  expect_equal(bl$baseline_mean[bl$variable == "prcp"], 12)
})

test_that("cd_baseline warns on missing years", {
  ts <- tibble::tibble(
    variable = rep("tmean", 5),
    period = rep("annual", 5),
    year = 1951:1955,
    value = 1:5
  )
  expect_warning(
    cd_baseline(ts, baseline_years = 1951:1960),
    "5 of 10 baseline years not found"
  )
})

test_that("cd_baseline uses only specified years", {
  ts <- tibble::tibble(
    variable = rep("tmean", 10),
    period = rep("annual", 10),
    year = 1951:1960,
    value = c(rep(0, 5), rep(10, 5))
  )
  bl <- cd_baseline(ts, baseline_years = 1956:1960)

  expect_equal(bl$baseline_mean, 10)
})
