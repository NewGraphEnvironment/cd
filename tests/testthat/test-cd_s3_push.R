test_that("cd_s3_push is a function", {
  expect_true(is.function(cd_s3_push))
})

test_that("cd_s3_push errors on missing directory", {
  expect_error(
    cd_s3_push("/nonexistent/path/abc123"),
    "Directory not found"
  )
})

test_that("cd_s3_push default bucket is stac-era5-land", {
  # Verify the default by inspecting the function formals
  defaults <- formals(cd_s3_push)
  expect_equal(defaults$bucket, "stac-era5-land")
})
