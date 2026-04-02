test_that("cd_periods returns 5 seasonal periods by default", {
  periods <- cd_periods()
  expect_length(periods, 5)
  expect_equal(periods, c("annual", "winter", "spring", "summer", "fall"))
})

test_that("cd_periods includes monthly when requested", {
  periods <- cd_periods(include_monthly = TRUE)
  expect_length(periods, 17)
  expect_true("Jan" %in% periods)
  expect_true("Dec" %in% periods)
})

test_that("cd_periods returns character vector", {
  expect_type(cd_periods(), "character")
})
