test_that("cd_variables returns expected structure", {
  vars <- cd_variables()
  expect_s3_class(vars, "tbl_df")
  expect_equal(nrow(vars), 15)
  expect_named(vars, c("variable", "long_name", "unit", "anomaly_type", "era5_name"))
})

test_that("cd_variables contains all expected variables", {
  vars <- cd_variables()
  expected <- c(
    "tmean", "tmax", "tmin", "prcp", "vpd", "rh", "soil_moisture",
    "swe", "snowfall", "snowmelt", "snow_cover",
    "swe_max", "snowfall_fraction", "snowmelt_doy_50", "snowmelt_rate_peak"
  )
  expect_equal(vars$variable, expected)
})

test_that("cd_variables anomaly types are valid", {
  vars <- cd_variables()
  expect_true(all(vars$anomaly_type %in%
                    c("absolute", "pct_normal", "pct_point_diff")))
  expect_equal(sum(vars$anomaly_type == "pct_normal"), 5)
  expect_equal(sum(vars$anomaly_type == "pct_point_diff"), 2)
})

test_that("cd_variables pct_normal variables are correct", {
  vars <- cd_variables()
  pct_vars <- vars$variable[vars$anomaly_type == "pct_normal"]
  expect_equal(
    sort(pct_vars),
    c("prcp", "snowfall", "snowmelt", "soil_moisture", "swe")
  )
})

test_that("cd_variables pct_point_diff variables are correct", {
  vars <- cd_variables()
  pp_vars <- vars$variable[vars$anomaly_type == "pct_point_diff"]
  expect_equal(sort(pp_vars), c("snow_cover", "snowfall_fraction"))
})
