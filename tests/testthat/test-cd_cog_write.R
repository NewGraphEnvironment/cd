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

test_that("cd_cog_write writes tags into the file", {
  r <- terra::rast(nrows = 5, ncols = 5, vals = 1:25)
  tmp <- tempfile(fileext = ".tif")
  cd_cog_write(r, tmp, overwrite = TRUE,
               tags = c(CD_VERSION = "9.9.9", CD_RUN_ID = "42"))
  m <- terra::metags(terra::rast(tmp))
  expect_equal(m$value[m$name == "CD_VERSION"], "9.9.9")
  expect_equal(m$value[m$name == "CD_RUN_ID"], "42")
  # In the TIFF itself, not a sidecar that the S3 push excludes.
  expect_false(file.exists(paste0(tmp, ".aux.json")))
  expect_false(file.exists(paste0(tmp, ".aux.xml")))
  unlink(tmp)
})

test_that("cd_cog_write drops provenance the input carries", {
  # A raster read back from a published COG carries that run's CD_* tags;
  # STEP 4 appends to exactly such a raster.
  r <- terra::rast(nrows = 5, ncols = 5, vals = 1:25)
  terra::metags(r) <- c(CD_RUN_TIME = "old", CD_SHA = "old", units = "degC")
  tmp <- tempfile(fileext = ".tif")
  cd_cog_write(r, tmp, overwrite = TRUE, tags = c(CD_RUN_TIME = "new"))
  m <- terra::metags(terra::rast(tmp))
  expect_equal(m$value[m$name == "CD_RUN_TIME"], "new")
  expect_false("CD_SHA" %in% m$name)
  expect_equal(m$value[m$name == "units"], "degC")
  # The caller's raster is untouched.
  expect_equal(terra::metags(r)$value[terra::metags(r)$name == "CD_RUN_TIME"], "old")

  # Without tags too: stale provenance never rides along.
  cd_cog_write(r, tmp, overwrite = TRUE)
  m <- terra::metags(terra::rast(tmp))
  expect_false(any(startsWith(m$name, "CD_")))
  unlink(tmp)
})

test_that("cd_cog_write rejects malformed tags", {
  r <- terra::rast(nrows = 5, ncols = 5, vals = 1:25)
  tmp <- tempfile(fileext = ".tif")
  expect_error(cd_cog_write(r, tmp, tags = c(`cd:sha` = "x")), "may not contain ':'")
  expect_error(cd_cog_write(r, tmp, tags = "x"), "named character")
  expect_error(cd_cog_write(r, tmp, tags = c(CD_SHA = NA_character_)), "named character")
  expect_false(file.exists(tmp))
})

test_that("cd_cog_write is byte-deterministic for the same input and tags", {
  # A checksum is only informative if an unchanged input reproduces it
  # (NewGraphEnvironment/sred#39). The run-time tag is the only intended
  # difference between two builds.
  r <- terra::rast(nrows = 20, ncols = 30, nlyrs = 3,
                   vals = seq_len(20 * 30 * 3) / 7)
  names(r) <- c("2001", "2002", "2003")
  tags <- c(CD_VERSION = "1.0.0", CD_SHA = "abc", CD_RUN_TIME = "2026-01-01T00:00:00Z",
            CD_RUN_ID = "1")
  a <- tempfile(fileext = ".tif")
  b <- tempfile(fileext = ".tif")
  cd_cog_write(r, a, overwrite = TRUE, tags = tags)
  Sys.sleep(1.1)
  cd_cog_write(r, b, overwrite = TRUE, tags = tags)
  expect_identical(readBin(a, "raw", file.size(a)), readBin(b, "raw", file.size(b)))

  # And the tags are part of the bytes: changing one changes the file.
  cd_cog_write(r, b, overwrite = TRUE,
               tags = replace(tags, "CD_RUN_TIME", "2026-01-01T00:00:01Z"))
  expect_false(identical(readBin(a, "raw", file.size(a)), readBin(b, "raw", file.size(b))))
  unlink(c(a, b))
})
