# Integration test against the live S3 catalog. Skipped on CRAN and when
# offline, so CI (which has no business pulling COGs from S3) never runs
# it, but a local `devtools::test()` with a network exercises the real
# curl HEAD + ETag parsing + download path that the mocked unit tests in
# test-cd_cache_fetch.R deliberately stub out.

test_that("cd_cache_fetch round-trips a real COG from live S3", {
  skip_on_cran()
  skip_if_offline(host = "stac-era5-land.s3.us-west-2.amazonaws.com")
  skip_if_not_installed("withr")

  catalog <- tryCatch(cd_catalog(), error = function(e) NULL)
  skip_if(is.null(catalog) || nrow(catalog) == 0, "live catalog unreachable")

  url <- catalog$href[catalog$period == "annual"][1]
  skip_if(is.na(url) || !grepl("^https?://", url), "no remote annual COG in catalog")

  cache <- withr::local_tempdir()

  # Cold read: real download, real S3 ETag captured, size validated.
  p1 <- cd_cache_fetch(url, cache_dir = cache)
  expect_true(file.exists(p1))
  meta <- jsonlite::read_json(paste0(p1, ".meta"))
  expect_true(is.character(meta$etag) && nchar(meta$etag) > 0)
  # The advertised Content-Length must equal the bytes actually written.
  expect_equal(meta$size, file.size(p1))

  # Warm read: HEAD revalidation hits, same path, file is NOT rewritten.
  mtime_cold <- file.info(p1)$mtime
  p2 <- cd_cache_fetch(url, cache_dir = cache)
  expect_identical(p2, p1)
  expect_identical(file.info(p2)$mtime, mtime_cold)

  # The cached file is a valid COG with the same structure as a direct
  # remote read — i.e. caching serves the real data, not a stale/partial.
  r_cache <- terra::rast(p2)
  r_direct <- terra::rast(url)
  expect_equal(terra::nlyr(r_cache), terra::nlyr(r_direct))
  expect_equal(names(r_cache), names(r_direct))

  # Offline fast path: serve the cached copy with no network at all.
  withr::local_options(cd.cache_revalidate = FALSE)
  expect_identical(cd_cache_fetch(url, cache_dir = cache), p1)
})
