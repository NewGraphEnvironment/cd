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

test_that("cd_stac_catalog carries file:checksum, file:size and provenance", {
  dir <- tempfile("cd_cogs_")
  dir.create(dir)
  r <- terra::rast(nrows = 4, ncols = 5, nlyrs = 2, vals = 1:40)
  names(r) <- c("2001", "2002")
  tagged <- file.path(dir, "tmean_annual.tif")
  plain <- file.path(dir, "prcp_annual.tif")
  prov <- c(CD_VERSION = "9.9.9", CD_SHA = "abc123", CD_RUN_TIME = "2026-01-01T00:00:00Z",
            CD_RUN_ID = "42")
  cd_cog_write(r, tagged, tags = prov)
  cd_cog_write(r, plain)
  output <- tempfile(fileext = ".json")
  cd_stac_catalog(dir, output_path = output, base_url = "https://example.com")
  cat_json <- jsonlite::read_json(output)
  items <- stats::setNames(cat_json$items,
                           vapply(cat_json$items, function(i) i$id, character(1)))

  for (id in c("tmean-annual", "prcp-annual")) {
    item <- items[[id]]
    f <- file.path(dir, basename(item$assets$data$href))
    # An independent hash of the file, not file_multihash() checked against itself.
    expect_equal(item$assets$data$`file:checksum`,
                 paste0("1220", strsplit(system2("shasum", c("-a", "256", shQuote(f)),
                                                 stdout = TRUE), " ")[[1]][1]))
    expect_match(item$assets$data$`file:checksum`, "^1220[0-9a-f]{64}$")
    expect_equal(item$assets$data$`file:size`, file.size(f))
    expect_true("https://stac-extensions.github.io/file/v2.1.0/schema.json" %in%
                  unlist(item$stac_extensions))
  }
  processing <- "https://stac-extensions.github.io/processing/v1.2.0/schema.json"
  tagged_item <- items[["tmean-annual"]]
  p <- tagged_item$properties
  expect_identical(p$`processing:version`, "9.9.9")
  expect_identical(p$`processing:software`, list(cd = "abc123"))
  expect_identical(p$`processing:datetime`, "2026-01-01T00:00:00Z")
  expect_true(processing %in% unlist(tagged_item$stac_extensions))
  expect_length(tagged_item$links, 1)
  expect_identical(tagged_item$links[[1]]$rel, "processing-execution")
  expect_identical(tagged_item$links[[1]]$href,
                   "https://github.com/NewGraphEnvironment/cd/actions/runs/42")
  # The only cd: keys left are the two no extension covers.
  for (item in items) {
    expect_setequal(grep("^cd:", names(item$properties), value = TRUE),
                    c("cd:variable", "cd:period"))
  }
  # An untagged COG has no provenance, not empty objects, and does not declare
  # an extension whose schema would then require a processing: field.
  untagged <- items[["prcp-annual"]]
  expect_false(any(startsWith(names(untagged$properties), "processing:")))
  expect_length(untagged$links, 0)
  expect_false(processing %in% unlist(untagged$stac_extensions))

  # cd_catalog() reads it as before.
  catalog <- cd_catalog(output)
  expect_setequal(paste(catalog$variable, catalog$period), c("tmean annual", "prcp annual"))
  unlink(c(dir, output), recursive = TRUE)
})

test_that("the run time is copied as the exact string and only a CI run id links", {
  dir <- tempfile("cd_cogs_")
  dir.create(dir)
  r <- terra::rast(nrows = 4, ncols = 5, nlyrs = 1, vals = 1:20)
  names(r) <- "2001"
  # A valid RFC 3339 form other than the writer's own: any reformat to "Z"
  # would break the exact-string match readers make against the file's tag.
  cd_cog_write(r, file.path(dir, "tmean_annual.tif"),
               tags = c(CD_VERSION = "1.0.0", CD_SHA = "def456",
                        CD_RUN_TIME = "2026-02-03T04:05:06+00:00", CD_RUN_ID = "local"))
  output <- tempfile(fileext = ".json")
  cd_stac_catalog(dir, output_path = output, base_url = "https://example.com")
  item <- jsonlite::read_json(output)$items[[1]]
  expect_identical(item$properties$`processing:datetime`, "2026-02-03T04:05:06+00:00")
  expect_length(item$links, 0)
  unlink(c(dir, output), recursive = TRUE)
})

test_that("stac_provenance keeps absent tags out and links only digit run ids", {
  none <- stac_provenance()
  expect_length(none$properties, 0)
  expect_length(none$links, 0)
  only_sha <- stac_provenance(sha = "abc")
  expect_identical(only_sha$properties, list(`processing:software` = list(cd = "abc")))
  expect_length(stac_provenance(run_id = "12a")$links, 0)
  expect_length(stac_provenance(run_id = "")$links, 0)
  expect_identical(stac_provenance(run_id = "987")$links[[1]]$href,
                   "https://github.com/NewGraphEnvironment/cd/actions/runs/987")
})

test_that("file_multihash is the sha256 multihash of the bytes", {
  f <- tempfile()
  writeBin(charToRaw("abc"), f)
  # sha256("abc"), FIPS 180-2 test vector.
  abc <- "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  expect_equal(file_multihash(f), paste0("1220", abc))
  unlink(f)
})
