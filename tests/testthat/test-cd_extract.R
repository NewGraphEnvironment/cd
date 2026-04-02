test_that("cd_extract returns expected structure", {
  catalog <- cd_catalog(
    system.file("extdata", "example_catalog.json", package = "cd")
  )
  aoi <- sf::st_read(
    system.file("extdata", "example_aoi.gpkg", package = "cd"),
    quiet = TRUE
  )
  ts <- cd_extract(catalog, aoi)

  expect_s3_class(ts, "tbl_df")
  expect_named(ts, c("variable", "period", "year", "value"))
  expect_equal(nrow(ts), 10)
  expect_equal(ts$variable, rep("tmean", 10))
  expect_equal(ts$period, rep("annual", 10))
  expect_equal(ts$year, 1951L:1960L)
})

test_that("cd_extract values are numeric and non-NA", {
  catalog <- cd_catalog(
    system.file("extdata", "example_catalog.json", package = "cd")
  )
  aoi <- sf::st_read(
    system.file("extdata", "example_aoi.gpkg", package = "cd"),
    quiet = TRUE
  )
  ts <- cd_extract(catalog, aoi)

  expect_type(ts$value, "double")
  expect_true(all(!is.na(ts$value)))
})

test_that("cd_extract filters by years", {
  catalog <- cd_catalog(
    system.file("extdata", "example_catalog.json", package = "cd")
  )
  aoi <- sf::st_read(
    system.file("extdata", "example_aoi.gpkg", package = "cd"),
    quiet = TRUE
  )
  ts <- cd_extract(catalog, aoi, years = 1951:1953)

  expect_equal(nrow(ts), 3)
  expect_equal(ts$year, 1951L:1953L)
})

test_that("cd_extract filters by variables", {
  catalog <- cd_catalog(
    system.file("extdata", "example_catalog.json", package = "cd")
  )
  aoi <- sf::st_read(
    system.file("extdata", "example_aoi.gpkg", package = "cd"),
    quiet = TRUE
  )
  # Filter to a variable not in catalog — should return empty

ts <- cd_extract(catalog, aoi, variables = "prcp")
  expect_equal(nrow(ts), 0)
})
