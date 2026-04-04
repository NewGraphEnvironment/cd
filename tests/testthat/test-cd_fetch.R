test_that("cd_fetch determines correct CDS variables for tmean", {
  vars <- cd_variables()
  expect_equal(vars$era5_name[vars$variable == "tmean"], "2m_temperature")
})

test_that("cd_fetch determines pct_normal variables", {
  vars <- cd_variables()
  pct <- vars$variable[vars$anomaly_type == "pct_normal"]
  expect_equal(sort(pct), c("prcp", "soil_moisture"))
})

test_that("cd_fetch is a function", {
  expect_true(is.function(cd_fetch))
})

test_that("cd_fetch validates source parameter", {
  tmp <- tempdir()
  expect_error(
    cd_fetch(years = 2024, output_dir = tmp, source = "invalid")
  )
})
