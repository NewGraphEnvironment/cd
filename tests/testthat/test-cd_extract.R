test_that("cd_extract returns expected structure", {
  skip_if_not_installed("sf")
  catalog <- cd_catalog(
    system.file("extdata", "example_catalog.json", package = "cd")
  )
  aoi <- sf::st_read(
    system.file("extdata", "example_aoi.gpkg", package = "cd"),
    quiet = TRUE
  )
  ts <- cd_extract(catalog, aoi)

  expect_s3_class(ts, "tbl_df")
  expect_named(ts, c("variable", "period", "year", "value", "checksum", "cd_sha"))
  expect_equal(nrow(ts), 10)
  expect_equal(ts$variable, rep("tmean", 10))
  expect_equal(ts$period, rep("annual", 10))
  expect_equal(ts$year, 1951L:1960L)
})

test_that("cd_extract values are numeric and non-NA", {
  skip_if_not_installed("sf")
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
  skip_if_not_installed("sf")
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

test_that("cd_extract cache = TRUE matches cache = FALSE for local COGs", {
  skip_if_not_installed("sf")
  catalog <- cd_catalog(
    system.file("extdata", "example_catalog.json", package = "cd")
  )
  aoi <- sf::st_read(
    system.file("extdata", "example_aoi.gpkg", package = "cd"),
    quiet = TRUE
  )
  ts_cache <- cd_extract(catalog, aoi, cache = TRUE)
  ts_nocache <- cd_extract(catalog, aoi, cache = FALSE)

  expect_equal(ts_cache, ts_nocache)
})

test_that("cd_extract filters by variables", {
  skip_if_not_installed("sf")
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

# The example COG rewritten with build tags, plus a one-row catalog for it.
tagged_catalog <- function(sha, file_run_time, catalog_run_time = file_run_time,
                           checksum = "1220aa") {
  src <- system.file("extdata", "example_climate.tif", package = "cd")
  f <- tempfile(fileext = ".tif")
  tags <- c(CD_SHA = sha, CD_RUN_TIME = file_run_time)
  tags <- tags[!is.na(tags)]
  cd_cog_write(terra::rast(src), f, tags = if (length(tags)) tags else NULL)
  tibble::tibble(variable = "tmean", period = "annual", href = f,
                 checksum = checksum, cd_sha = "from_catalog",
                 run_time = catalog_run_time)
}

extract_aoi <- function() {
  sf::st_read(system.file("extdata", "example_aoi.gpkg", package = "cd"),
              quiet = TRUE)
}

test_that("cd_extract reports the checksum and the file's own cd_sha", {
  skip_if_not_installed("sf")
  catalog <- tagged_catalog("sha_a", "2026-10-10T22:36:36Z")
  ts <- expect_no_warning(cd_extract(catalog, extract_aoi()))

  expect_equal(nrow(ts), 10)
  expect_equal(ts$checksum, rep("1220aa", 10))
  # From the file read, not the catalog's column.
  expect_equal(ts$cd_sha, rep("sha_a", 10))
})

test_that("cd_extract gives NA checksum for a file that is another build", {
  skip_if_not_installed("sf")
  # A stale cached copy: built earlier than the catalog says.
  catalog <- tagged_catalog("sha_old", "2026-01-01T00:00:00Z",
                            catalog_run_time = "2026-10-10T22:36:36Z")
  expect_warning(ts <- cd_extract(catalog, extract_aoi()), "stale cached copy")
  expect_identical(ts$checksum, rep(NA_character_, 10))
  expect_equal(ts$cd_sha, rep("sha_old", 10))
})

test_that("cd_extract gives NA checksum when the build cannot be shown", {
  skip_if_not_installed("sf")
  # Untagged file under a catalog that claims a checksum.
  catalog <- tagged_catalog(NA, NA, catalog_run_time = "2026-10-10T22:36:36Z")
  expect_warning(ts <- cd_extract(catalog, extract_aoi()), "not shown to be")
  expect_identical(ts$checksum, rep(NA_character_, 10))
  expect_identical(ts$cd_sha, rep(NA_character_, 10))

  # A catalog with a checksum but no run time cannot vouch for it either.
  catalog <- tagged_catalog("sha_a", "2026-10-10T22:36:36Z",
                            catalog_run_time = NA)
  expect_warning(ts <- cd_extract(catalog, extract_aoi()), "not shown to be")
  expect_identical(ts$checksum, rep(NA_character_, 10))
})

test_that("cd_extract gives NA provenance for a catalog without those columns", {
  skip_if_not_installed("sf")
  catalog <- cd_catalog(
    system.file("extdata", "example_catalog.json", package = "cd")
  )[c("variable", "period", "href")]
  ts <- expect_no_warning(cd_extract(catalog, extract_aoi()))

  expect_identical(ts$checksum, rep(NA_character_, 10))
  expect_identical(ts$cd_sha, rep(NA_character_, 10))
})

test_that("cd_extract with nothing to extract keeps its columns", {
  skip_if_not_installed("sf")
  catalog <- cd_catalog(
    system.file("extdata", "example_catalog.json", package = "cd")
  )
  ts <- cd_extract(catalog, extract_aoi(), variables = "prcp")
  expect_named(ts, c("variable", "period", "year", "value", "checksum", "cd_sha"))
  expect_type(ts$year, "integer")
  expect_type(ts$checksum, "character")
})
