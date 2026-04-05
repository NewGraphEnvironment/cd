test_that("cd_seasons returns standard meteorological seasons", {
  s <- cd_seasons()
  expect_type(s, "list")
  expect_named(s, c("winter", "spring", "summer", "fall"))
  expect_equal(s$winter, c(12L, 1L, 2L))
  expect_equal(s$summer, 6L:8L)
})

test_that("cd_aggregate returns all periods", {
  r <- terra::rast(nrows = 5, ncols = 5, nlyrs = 12)
  terra::values(r) <- matrix(1:300, 25, 12)

  periods <- cd_aggregate(r)
  expect_type(periods, "list")
  expect_true("annual" %in% names(periods))
  expect_true("summer" %in% names(periods))
  expect_equal(length(periods), 5)
})

test_that("cd_aggregate mean is correct", {
  r <- terra::rast(nrows = 2, ncols = 2, nlyrs = 12)
  # All cells = 1 for all months
  terra::values(r) <- matrix(1, 4, 12)

  periods <- cd_aggregate(r, method = "mean")
  expect_equal(unname(terra::values(periods$annual)[1, 1]), 1)
})

test_that("cd_aggregate sum works for precip", {
  r <- terra::rast(nrows = 2, ncols = 2, nlyrs = 12)
  terra::values(r) <- matrix(10, 4, 12)

  periods <- cd_aggregate(r, method = "sum")
  # Annual sum of 12 months x 10 = 120
  expect_equal(unname(terra::values(periods$annual)[1, 1]), 120)
  # Summer sum of 3 months x 10 = 30
  expect_equal(unname(terra::values(periods$summer)[1, 1]), 30)
})

test_that("cd_aggregate accepts custom seasons", {
  r <- terra::rast(nrows = 2, ncols = 2, nlyrs = 12)
  terra::values(r) <- matrix(rep(1:12, each = 4), 4, 12)

  custom <- list(wet = c(10L, 11L, 12L, 1L, 2L, 3L), dry = 4L:9L)
  periods <- cd_aggregate(r, seasons = custom)

  expect_named(periods, c("annual", "wet", "dry"))
})
