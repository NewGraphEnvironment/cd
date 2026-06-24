fixture <- function() {
  system.file("extdata", "example_climate.tif", package = "cd")
}

test_that("local paths pass through untouched", {
  f <- fixture()
  expect_identical(cd_cache_fetch(f), f)
})

test_that("non-http and degenerate inputs pass through", {
  expect_identical(cd_cache_fetch("s3://bucket/key.tif"), "s3://bucket/key.tif")
  expect_identical(cd_cache_fetch("/local/abs/path.tif"), "/local/abs/path.tif")
  expect_identical(cd_cache_fetch(NA_character_), NA_character_)
})

test_that("remote fetch downloads, validates size, and writes meta", {
  tmp <- tempfile("cd_cache")
  fx <- fixture()
  sz <- file.size(fx)

  local_mocked_bindings(
    cd_remote_head = function(href) list(etag = "v1", size = sz),
    cd_remote_download = function(href, destfile) file.copy(fx, destfile)
  )

  url <- "https://example.com/data/tmean-annual.tif"
  out <- cd_cache_fetch(url, cache_dir = tmp)

  expect_true(file.exists(out))
  expect_equal(file.size(out), sz)
  meta <- jsonlite::read_json(paste0(out, ".meta"))
  expect_equal(meta$etag, "v1")
  expect_equal(meta$url, url)

  unlink(tmp, recursive = TRUE)
})

test_that("matching ETag serves the cached copy without re-downloading", {
  tmp <- tempfile("cd_cache")
  fx <- fixture()
  sz <- file.size(fx)

  local_mocked_bindings(
    cd_remote_head = function(href) list(etag = "v1", size = sz),
    cd_remote_download = function(href, destfile) file.copy(fx, destfile)
  )
  url <- "https://example.com/data/x.tif"
  first <- cd_cache_fetch(url, cache_dir = tmp)

  # Second call: download must NOT be invoked.
  local_mocked_bindings(
    cd_remote_head = function(href) list(etag = "v1", size = sz),
    cd_remote_download = function(href, destfile) stop("should not download")
  )
  second <- cd_cache_fetch(url, cache_dir = tmp)
  expect_identical(first, second)

  unlink(tmp, recursive = TRUE)
})

test_that("changed ETag triggers a re-download", {
  tmp <- tempfile("cd_cache")
  fx <- fixture()
  sz <- file.size(fx)
  url <- "https://example.com/data/x.tif"

  local_mocked_bindings(
    cd_remote_head = function(href) list(etag = "v1", size = sz),
    cd_remote_download = function(href, destfile) file.copy(fx, destfile)
  )
  cd_cache_fetch(url, cache_dir = tmp)

  downloaded <- 0L
  local_mocked_bindings(
    cd_remote_head = function(href) list(etag = "v2", size = sz),
    cd_remote_download = function(href, destfile) {
      downloaded <<- downloaded + 1L
      file.copy(fx, destfile)
    }
  )
  cd_cache_fetch(url, cache_dir = tmp)
  expect_equal(downloaded, 1L)
  meta <- jsonlite::read_json(
    paste0(cd_cache_fetch(url, cache_dir = tmp), ".meta")
  )
  expect_equal(meta$etag, "v2")

  unlink(tmp, recursive = TRUE)
})

test_that("refresh = TRUE forces a re-download even on ETag match", {
  tmp <- tempfile("cd_cache")
  fx <- fixture()
  sz <- file.size(fx)
  url <- "https://example.com/data/x.tif"

  local_mocked_bindings(
    cd_remote_head = function(href) list(etag = "v1", size = sz),
    cd_remote_download = function(href, destfile) file.copy(fx, destfile)
  )
  cd_cache_fetch(url, cache_dir = tmp)

  downloaded <- 0L
  local_mocked_bindings(
    cd_remote_head = function(href) list(etag = "v1", size = sz),
    cd_remote_download = function(href, destfile) {
      downloaded <<- downloaded + 1L
      file.copy(fx, destfile)
    }
  )
  cd_cache_fetch(url, cache_dir = tmp, refresh = TRUE)
  expect_equal(downloaded, 1L)

  unlink(tmp, recursive = TRUE)
})

test_that("incomplete download (size mismatch) is rejected", {
  tmp <- tempfile("cd_cache")
  fx <- fixture()

  local_mocked_bindings(
    cd_remote_head = function(href) list(etag = "v1", size = file.size(fx) + 1),
    cd_remote_download = function(href, destfile) file.copy(fx, destfile)
  )
  expect_error(
    cd_cache_fetch("https://example.com/data/x.tif", cache_dir = tmp),
    "incomplete download"
  )
  # No partial file left behind under the cache key.
  expect_equal(length(list.files(tmp, pattern = "\\.tif$")), 0L)

  unlink(tmp, recursive = TRUE)
})

test_that("offline with a cached copy serves it; without one, errors", {
  tmp <- tempfile("cd_cache")
  fx <- fixture()
  sz <- file.size(fx)
  url <- "https://example.com/data/x.tif"

  # Populate the cache first.
  local_mocked_bindings(
    cd_remote_head = function(href) list(etag = "v1", size = sz),
    cd_remote_download = function(href, destfile) file.copy(fx, destfile)
  )
  cached <- cd_cache_fetch(url, cache_dir = tmp)

  # Now go "offline": HEAD returns NULL.
  local_mocked_bindings(
    cd_remote_head = function(href) NULL,
    cd_remote_download = function(href, destfile) stop("offline")
  )
  expect_message(
    out <- cd_cache_fetch(url, cache_dir = tmp),
    "serving cached copy"
  )
  expect_identical(out, cached)

  # A different (un-cached) URL while offline errors.
  expect_error(
    cd_cache_fetch("https://example.com/data/other.tif", cache_dir = tmp),
    "no cached copy"
  )

  unlink(tmp, recursive = TRUE)
})

test_that("ETag-less server falls back to size and still cache-hits", {
  tmp <- tempfile("cd_cache")
  fx <- fixture()
  sz <- file.size(fx)
  url <- "https://example.com/data/x.tif"

  # Server returns no ETag, only a size.
  local_mocked_bindings(
    cd_remote_head = function(href) list(etag = NULL, size = sz),
    cd_remote_download = function(href, destfile) file.copy(fx, destfile)
  )
  first <- cd_cache_fetch(url, cache_dir = tmp)

  # Second call (still no ETag): size matches -> must NOT re-download.
  local_mocked_bindings(
    cd_remote_head = function(href) list(etag = NULL, size = sz),
    cd_remote_download = function(href, destfile) stop("should not download")
  )
  expect_identical(cd_cache_fetch(url, cache_dir = tmp), first)

  # Size changes -> re-download.
  downloaded <- 0L
  local_mocked_bindings(
    cd_remote_head = function(href) list(etag = NULL, size = sz + 1),
    cd_remote_download = function(href, destfile) {
      downloaded <<- downloaded + 1L
      # produce a file of the new advertised size so validation passes
      writeBin(c(readBin(fx, "raw", sz), as.raw(0)), destfile)
    }
  )
  cd_cache_fetch(url, cache_dir = tmp)
  expect_equal(downloaded, 1L)

  unlink(tmp, recursive = TRUE)
})

test_that("cd.cache_revalidate = FALSE serves cache without a HEAD", {
  tmp <- tempfile("cd_cache")
  fx <- fixture()
  sz <- file.size(fx)
  url <- "https://example.com/data/x.tif"

  local_mocked_bindings(
    cd_remote_head = function(href) list(etag = "v1", size = sz),
    cd_remote_download = function(href, destfile) file.copy(fx, destfile)
  )
  cached <- cd_cache_fetch(url, cache_dir = tmp)

  withr::local_options(cd.cache_revalidate = FALSE)
  local_mocked_bindings(
    cd_remote_head = function(href) stop("should not HEAD"),
    cd_remote_download = function(href, destfile) stop("should not download")
  )
  expect_identical(cd_cache_fetch(url, cache_dir = tmp), cached)

  unlink(tmp, recursive = TRUE)
})
