test_that("cd_crop returns cropped SpatRaster from sf AOI", {
  href <- system.file("extdata", "example_climate.tif", package = "cd")
  aoi <- sf::st_read(
    system.file("extdata", "example_aoi.gpkg", package = "cd"),
    quiet = TRUE
  )
  r <- cd_crop(href, aoi)

  expect_s4_class(r, "SpatRaster")
  expect_equal(terra::nlyr(r), 10)
  expect_true(all(!is.na(terra::values(r)[1, ])))
})

test_that("cd_crop accepts SpatVector AOI", {
  href <- system.file("extdata", "example_climate.tif", package = "cd")
  aoi <- terra::vect(
    system.file("extdata", "example_aoi.gpkg", package = "cd")
  )
  r <- cd_crop(href, aoi)

  expect_s4_class(r, "SpatRaster")
  expect_equal(terra::nlyr(r), 10)
})

test_that("cd_crop preserves band names", {
  href <- system.file("extdata", "example_climate.tif", package = "cd")
  aoi <- sf::st_read(
    system.file("extdata", "example_aoi.gpkg", package = "cd"),
    quiet = TRUE
  )
  r <- cd_crop(href, aoi)

  expect_equal(names(r), as.character(1951:1960))
})
