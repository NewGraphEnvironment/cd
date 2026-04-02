test_that("cd_catalog parses example catalog", {
  cat_path <- system.file("extdata", "example_catalog.json", package = "cd")
  catalog <- cd_catalog(catalog = cat_path)

  expect_s3_class(catalog, "tbl_df")
  expect_named(catalog, c("variable", "period", "href"))
  expect_equal(nrow(catalog), 1)
  expect_equal(catalog$variable, "tmean")
  expect_equal(catalog$period, "annual")
})

test_that("cd_catalog resolves relative hrefs", {
  cat_path <- system.file("extdata", "example_catalog.json", package = "cd")
  catalog <- cd_catalog(catalog = cat_path)

  expect_true(file.exists(catalog$href))
})

test_that("cd_catalog returns empty tibble for empty catalog", {
  tmp <- tempfile(fileext = ".json")
  jsonlite::write_json(
    list(type = "Catalog", id = "empty", stac_version = "1.0.0", items = list()),
    tmp, auto_unbox = TRUE
  )
  catalog <- cd_catalog(catalog = tmp)

  expect_s3_class(catalog, "tbl_df")
  expect_equal(nrow(catalog), 0)
  unlink(tmp)
})

test_that("cd_catalog preserves absolute hrefs", {
  tmp <- tempfile(fileext = ".json")
  jsonlite::write_json(list(
    type = "Catalog", id = "test", stac_version = "1.0.0",
    items = list(list(
      type = "Feature", id = "test-item",
      properties = list(`cd:variable` = "prcp", `cd:period` = "summer"),
      assets = list(data = list(href = "https://example.com/prcp_summer.tif"))
    ))
  ), tmp, auto_unbox = TRUE)
  catalog <- cd_catalog(catalog = tmp)

  expect_equal(catalog$href, "https://example.com/prcp_summer.tif")
  unlink(tmp)
})

test_that("cd_catalog_default returns a URL", {
  url <- cd_catalog_default()
  expect_type(url, "character")
  expect_match(url, "^https://")
})

test_that("cd_catalog_default respects option override", {
  withr::with_options(list(cd.catalog_url = "https://custom.example.com/cat.json"), {
    expect_equal(cd_catalog_default(), "https://custom.example.com/cat.json")
  })
})
