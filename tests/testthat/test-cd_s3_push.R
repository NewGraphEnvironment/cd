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

test_that("cd_s3_push passes --size-only only when asked", {
  dir <- withr::local_tempdir()
  cmds <- character()
  testthat::local_mocked_bindings(
    system = function(command, ...) {
      cmds <<- c(cmds, command)
      0L
    },
    .package = "base"
  )
  suppressMessages(cd_s3_push(dir, dry_run = TRUE))
  suppressMessages(cd_s3_push(dir, dry_run = TRUE, size_only = FALSE))
  expect_match(cmds[1], "--size-only", fixed = TRUE)
  # A checksum-carrying publish must upload a rebuilt file of unchanged size.
  expect_false(grepl("--size-only", cmds[2], fixed = TRUE))
  expect_match(cmds[2], "--dryrun", fixed = TRUE)
})
