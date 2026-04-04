test_that("cd_cog_write creates a valid file", {
  r <- terra::rast(nrows = 10, ncols = 10, vals = rnorm(100))
  tmp <- tempfile(fileext = ".tif")
  result <- cd_cog_write(r, tmp, overwrite = TRUE)

  expect_true(file.exists(tmp))
  expect_equal(result, tmp)

  # Read back and verify
  r2 <- terra::rast(tmp)
  expect_equal(terra::nrow(r2), 10)
  expect_equal(terra::ncol(r2), 10)
  unlink(tmp)
})

test_that("cd_cog_write respects overwrite flag", {
  r <- terra::rast(nrows = 5, ncols = 5, vals = 1:25)
  tmp <- tempfile(fileext = ".tif")
  cd_cog_write(r, tmp, overwrite = TRUE)

  expect_error(cd_cog_write(r, tmp, overwrite = FALSE))
  unlink(tmp)
})

test_that("cd_cog_write returns path invisibly", {
  r <- terra::rast(nrows = 5, ncols = 5, vals = 1:25)
  tmp <- tempfile(fileext = ".tif")
  result <- cd_cog_write(r, tmp, overwrite = TRUE)

  expect_equal(result, tmp)
  unlink(tmp)
})
