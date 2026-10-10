cols_catalog <- c("variable", "period", "href", "checksum", "size",
                  "cd_version", "cd_sha", "run_time", "run_url")

# A catalog of hand-built items, written to a temp file.
catalog_tmp <- function(items) {
  tmp <- tempfile(fileext = ".json")
  jsonlite::write_json(
    list(type = "Catalog", id = "t", stac_version = "1.0.0", items = items),
    tmp, auto_unbox = TRUE, null = "null"
  )
  tmp
}

test_that("cd_catalog parses example catalog", {
  cat_path <- system.file("extdata", "example_catalog.json", package = "cd")
  catalog <- cd_catalog(catalog = cat_path)

  expect_s3_class(catalog, "tbl_df")
  expect_named(catalog, cols_catalog)
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
  expect_named(catalog, cols_catalog)
  expect_type(catalog$size, "double")
  expect_type(catalog$checksum, "character")
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

test_that("cd_catalog surfaces checksums and processing provenance", {
  sha <- "349f9d72e1687761ce98ebd62e6a086be30cc2a6"
  ck <- paste0("1220", strrep("ab", 32))
  tmp <- catalog_tmp(list(
    list(
      type = "Feature", id = "prcp-annual",
      properties = list(
        `cd:variable` = "prcp", `cd:period` = "annual",
        `processing:version` = "0.6.4",
        `processing:software` = list(cd = sha),
        `processing:datetime` = "2026-10-10T22:36:36Z"
      ),
      links = list(
        list(rel = "root", href = "./catalog.json"),
        list(rel = "processing-execution",
             href = "https://github.com/NewGraphEnvironment/cd/actions/runs/77")
      ),
      assets = list(data = list(
        href = "https://example.com/prcp_annual.tif",
        `file:checksum` = ck, `file:size` = 5625182
      ))
    ),
    # A local build: no run link, no software map, no file fields.
    list(
      type = "Feature", id = "tmean-annual",
      properties = list(`cd:variable` = "tmean", `cd:period` = "annual",
                        `processing:version` = "0.6.4"),
      assets = list(data = list(href = "https://example.com/tmean_annual.tif"))
    )
  ))
  catalog <- cd_catalog(tmp)

  expect_named(catalog, cols_catalog)
  expect_equal(catalog$checksum, c(ck, NA))
  expect_equal(catalog$size, c(5625182, NA))
  expect_type(catalog$size, "double")
  expect_equal(catalog$cd_version, c("0.6.4", "0.6.4"))
  expect_equal(catalog$cd_sha, c(sha, NA))
  expect_equal(catalog$run_time, c("2026-10-10T22:36:36Z", NA))
  expect_equal(catalog$run_url,
               c("https://github.com/NewGraphEnvironment/cd/actions/runs/77", NA))
  unlink(tmp)
})

test_that("cd_catalog gives NA provenance for an untagged catalog", {
  catalog <- cd_catalog(
    system.file("extdata", "example_catalog.json", package = "cd")
  )
  for (col in c("checksum", "cd_version", "cd_sha", "run_time", "run_url")) {
    expect_identical(catalog[[col]], NA_character_, info = col)
  }
  expect_identical(catalog$size, NA_real_)
})

test_that("cd_catalog reads a JSON null field as NA, not an error", {
  tmp <- catalog_tmp(list(list(
    type = "Feature", id = "x",
    properties = list(`cd:variable` = "prcp", `cd:period` = "annual",
                      `processing:datetime` = NULL,
                      # `$cd` would partial-match `cdo`; the lookup must be exact.
                      `processing:software` = list(cdo = "2.4.0")),
    assets = list(data = list(href = "https://example.com/x.tif",
                              `file:checksum` = NULL))
  )))
  catalog <- cd_catalog(tmp)
  expect_identical(catalog$run_time, NA_character_)
  expect_identical(catalog$checksum, NA_character_)
  expect_identical(catalog$cd_sha, NA_character_)
  unlink(tmp)
})
