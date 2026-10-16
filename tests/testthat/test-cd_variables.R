test_that("cd_variables returns expected structure", {
  vars <- cd_variables()
  expect_s3_class(vars, "tbl_df")
  expect_equal(nrow(vars), 15)
  expect_named(vars, c("variable", "long_name", "unit", "anomaly_type", "pct_change", "era5_name"))
})

test_that("cd_variables contains all expected variables", {
  vars <- cd_variables()
  expected <- c(
    "tmean", "tmax", "tmin", "prcp", "vpd", "rh", "soil_moisture",
    "swe", "snowfall", "snowmelt", "snow_cover",
    "swe_max", "snowfall_fraction", "snowmelt_doy_50", "snowmelt_rate_peak"
  )
  expect_equal(vars$variable, expected)
})

test_that("cd_variables anomaly types are valid", {
  vars <- cd_variables()
  expect_true(all(vars$anomaly_type %in%
                    c("absolute", "pct_normal", "pct_point_diff")))
  expect_equal(sum(vars$anomaly_type == "pct_normal"), 5)
  expect_equal(sum(vars$anomaly_type == "pct_point_diff"), 2)
})

test_that("cd_variables pct_normal variables are correct", {
  vars <- cd_variables()
  pct_vars <- vars$variable[vars$anomaly_type == "pct_normal"]
  expect_equal(
    sort(pct_vars),
    c("prcp", "snowfall", "snowmelt", "soil_moisture", "swe")
  )
})

test_that("cd_variables pct_point_diff variables are correct", {
  vars <- cd_variables()
  pp_vars <- vars$variable[vars$anomaly_type == "pct_point_diff"]
  expect_equal(sort(pp_vars), c("snow_cover", "snowfall_fraction"))
})

test_that("cd_variables allows a percent change only where values have a real zero (#138)", {
  vars <- cd_variables()
  expect_type(vars$pct_change, "logical")
  expect_false(anyNA(vars$pct_change))
  expect_equal(
    sort(vars$variable[!vars$pct_change]),
    sort(c("tmean", "tmax", "tmin", "rh", "snow_cover", "snowfall_fraction", "snowmelt_doy_50"))
  )
})

test_that("cd_variables gives vpd the unit its data is in (hPa)", {
  # Tetens in cd_derive_vpd() and the EDH backfiller both produce hPa (#96)
  vars <- cd_variables()
  expect_equal(vars$unit[vars$variable == "vpd"], "hPa")
})

test_that("bundled vignette data carries the registry's units (#96)", {
  # A carried `unit` wins over cd_variables() in meta_resolve(), so a unit
  # baked into the vignettes' precomputed tables outlives a registry fix.
  files <- list.files(
    system.file("vignette-data", package = "cd"),
    pattern = "\\.rds$", full.names = TRUE
  )
  expect_gt(length(files), 0)
  vars <- cd_variables()
  tables <- 0L
  check <- function(x, path) {
    if (is.data.frame(x)) {
      if (all(c("variable", "unit", "anomaly_type") %in% names(x))) {
        tables <<- tables + 1L
        idx <- match(as.character(x$variable), vars$variable)
        same_type <- !is.na(idx) & x$anomaly_type == vars$anomaly_type[idx]
        bad <- same_type & x$unit != vars$unit[idx]
        expect_false(
          any(bad, na.rm = TRUE),
          info = paste(path, paste(unique(x$variable[which(bad)]), collapse = ", "))
        )
      }
    } else if (is.list(x)) {
      for (i in seq_along(x)) check(x[[i]], paste0(path, "[[", i, "]]"))
    }
  }
  for (f in files) check(readRDS(f), basename(f))
  expect_gt(tables, 0)
})
