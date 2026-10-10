# Integration test against the published daily cube on S3. Skipped on CI and
# when offline: a local `devtools::test()` with a network exercises the real
# remote read paths (download through the cache, and tile reads over
# /vsicurl/) that the fixture tests cannot reach.

# Defined before the test: test_that() runs as the file is sourced.
tidyr_free_wide <- function(d) {
  stats::reshape(as.data.frame(d[c("date", "variable", "value")]),
                 idvar = "date", timevar = "variable", direction = "wide",
                 sep = "_") |>
    stats::setNames(c("date", "tmean", "tmax", "tmin"))
}

test_that("cd_extract_daily reads the published cube both ways", {
  skip_on_ci()
  skip_on_cran()
  skip_if_offline(host = "stac-era5-land.s3.us-west-2.amazonaws.com")
  skip_if_not_installed("withr")
  withr::local_options(cd.cache_revalidate = TRUE)
  withr::local_envvar(R_USER_CACHE_DIR = withr::local_tempdir())

  base <- "https://stac-era5-land.s3.us-west-2.amazonaws.com/daily"
  skip_if(is.null(cd_remote_head(paste0(base, "/tmean_daily_2003.tif"))),
          "daily cube not published")

  pts <- data.frame(id = "prince_george", lon = -122.75, lat = 53.92)
  a <- cd_extract_daily(pts, "2002-12-30", "2003-01-02", cache = FALSE)
  expect_equal(nrow(a), 3 * 4)
  expect_false(anyNA(a$value))
  # Daily max >= mean >= min, every day.
  w <- tidyr_free_wide(a)
  expect_true(all(w$tmax >= w$tmean & w$tmean >= w$tmin))

  b <- cd_extract_daily(pts, "2002-12-30", "2003-01-02", cache = TRUE)
  expect_equal(b, a)
})

test_that("the published cube reaches 60 N (#123)", {
  skip_on_ci()
  skip_on_cran()
  skip_if_offline(host = "stac-era5-land.s3.us-west-2.amazonaws.com")

  # 10DA001, Petitot River below Highway 77: 59.98856 N, in the cell centred
  # on 60.0 N that the cube lacked before #123.
  pts <- data.frame(id = "10DA001", lon = -122.9609, lat = 59.98856)
  expect_no_warning(
    d <- cd_extract_daily(pts, "2002-07-01", "2002-07-03", cache = FALSE)
  )
  expect_false(anyNA(d$value))
  expect_equal(unique(d$cell_y), 60, tolerance = 1e-6)
})

test_that("the published cube reports each file's manifest checksum (#126)", {
  skip_on_ci()
  skip_on_cran()
  skip_if_offline(host = "stac-era5-land.s3.us-west-2.amazonaws.com")
  skip_if_not_installed("withr")
  withr::local_options(cd.cache_revalidate = TRUE)

  base <- "https://stac-era5-land.s3.us-west-2.amazonaws.com/daily"
  files <- daily_manifest(base)
  skip_if(is.null(files[["tmean_daily_2003.tif"]][["processing:datetime"]]),
          "live manifest predates the processing: keys (#128)")

  pts <- data.frame(id = "prince_george", lon = -122.75, lat = 53.92)
  d <- expect_no_warning(
    cd_extract_daily(pts, "2002-12-31", "2003-01-01", cache = FALSE)
  )
  want <- vapply(paste0(d$variable, "_daily_", format(d$date, "%Y"), ".tif"),
                 function(f) files[[f]][["file:checksum"]], character(1))
  expect_equal(d$checksum, unname(want))
  expect_false(anyNA(d$cd_sha))
})
