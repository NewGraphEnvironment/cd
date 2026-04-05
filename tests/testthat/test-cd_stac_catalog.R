test_that("cd_stac_catalog generates valid catalog from COGs", {
  # Use shipped example data
  cog_dir <- system.file("extdata", package = "cd")
  output <- tempfile(fileext = ".json")

  cd_stac_catalog(
    cog_dir, output_path = output,
    base_url = "https://example.com"
  )

  expect_true(file.exists(output))

  # Read back with cd_catalog
  catalog <- cd_catalog(output)
  expect_s3_class(catalog, "tbl_df")
  expect_true(nrow(catalog) >= 1)
  expect_true(nrow(catalog) > 0)

  unlink(output)
})

test_that("cd_stac_catalog roundtrips with cd_catalog", {
  cog_dir <- system.file("extdata", package = "cd")
  output <- tempfile(fileext = ".json")

  cd_stac_catalog(cog_dir, output_path = output, base_url = "https://example.com")
  catalog <- cd_catalog(output)

  # hrefs should use the base_url
  expect_true(all(grepl("^https://example.com/", catalog$href)))

  unlink(output)
})

test_that("cd_stac_catalog errors on empty directory", {
  empty_dir <- tempfile("cd_empty_")
  dir.create(empty_dir)

  expect_error(
    cd_stac_catalog(empty_dir),
    "No .tif files"
  )

  unlink(empty_dir, recursive = TRUE)
})

test_that("cd_stac_catalog writes valid JSON", {
  cog_dir <- system.file("extdata", package = "cd")
  output <- tempfile(fileext = ".json")

  cd_stac_catalog(cog_dir, output_path = output, base_url = "https://example.com")

  # Parse JSON directly
  cat_json <- jsonlite::read_json(output)
  expect_equal(cat_json$type, "Catalog")
  expect_equal(cat_json$stac_version, "1.0.0")
  expect_true(length(cat_json$items) >= 1)

  # Check item structure
  item <- cat_json$items[[1]]
  expect_equal(item$type, "Feature")
  expect_true(!is.null(item$properties$`cd:variable`))
  expect_true(!is.null(item$assets$data$href))

  unlink(output)
})
