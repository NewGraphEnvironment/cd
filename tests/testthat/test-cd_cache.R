test_that("cd_cache_path returns a writable directory", {
  tmp <- tempfile("cd_test_cache")
  path <- cd_cache_path(cache_dir = tmp)
  expect_true(dir.exists(path))
  expect_equal(path, tmp)
  unlink(tmp, recursive = TRUE)
})

test_that("cd_cache_path uses default when NULL", {
  path <- cd_cache_path()
  expect_true(dir.exists(path))
  expect_match(path, "cd")
})

test_that("cd_cache_clear removes files", {
  tmp <- tempfile("cd_test_cache")
  dir.create(tmp, recursive = TRUE)
  writeLines("test", file.path(tmp, "test.txt"))
  expect_equal(length(list.files(tmp)), 1)

  n <- cd_cache_clear(cache_dir = tmp)
  expect_equal(n, 1L)
  expect_false(dir.exists(tmp))
})

test_that("cd_cache_clear returns 0 for empty cache", {
  tmp <- tempfile("cd_test_cache_empty")
  n <- cd_cache_clear(cache_dir = tmp)
  expect_equal(n, 0L)
})

test_that("cd_cache_info returns expected structure", {
  tmp <- tempfile("cd_test_cache")
  dir.create(tmp, recursive = TRUE)
  writeLines(paste(rep("x", 1000), collapse = ""), file.path(tmp, "test.txt"))

  info <- cd_cache_info(cache_dir = tmp)
  expect_type(info, "list")
  expect_named(info, c("path", "n_files", "size_mb"))
  expect_equal(info$n_files, 1)
  expect_true(file.size(file.path(tmp, "test.txt")) > 0)

  unlink(tmp, recursive = TRUE)
})
