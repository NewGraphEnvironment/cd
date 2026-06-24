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

test_that("cd_crop with cache = TRUE passes a local href straight through", {
  href <- system.file("extdata", "example_climate.tif", package = "cd")
  aoi <- sf::st_read(
    system.file("extdata", "example_aoi.gpkg", package = "cd"),
    quiet = TRUE
  )
  # Local path is not remote, so cd_cache_fetch returns it unchanged and
  # nothing is written to the cache. cache = TRUE must not alter results.
  r_cache <- cd_crop(href, aoi, cache = TRUE)
  r_nocache <- cd_crop(href, aoi, cache = FALSE)

  expect_s4_class(r_cache, "SpatRaster")
  expect_equal(terra::nlyr(r_cache), 10)
  expect_equal(names(r_cache), names(r_nocache))
  expect_equal(
    terra::global(r_cache, "mean", na.rm = TRUE)$mean,
    terra::global(r_nocache, "mean", na.rm = TRUE)$mean
  )
})
