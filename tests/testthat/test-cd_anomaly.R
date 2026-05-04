test_that("cd_anomaly computes absolute anomalies", {
  ts <- tibble::tibble(
    variable = rep("tmean", 5),
    period = rep("annual", 5),
    year = 1951:1955,
    value = c(10, 11, 12, 13, 14)
  )
  bl <- tibble::tibble(variable = "tmean", period = "annual", baseline_mean = 12)
  ano <- cd_anomaly(ts, bl)

  expect_s3_class(ano, "tbl_df")
  expect_named(ano, c("variable", "period", "year", "anomaly", "anomaly_type", "unit"))
  expect_equal(ano$anomaly, c(-2, -1, 0, 1, 2))
  expect_equal(unique(ano$anomaly_type), "absolute")
})

test_that("cd_anomaly computes pct_normal anomalies", {
  ts <- tibble::tibble(
    variable = rep("prcp", 3),
    period = rep("annual", 3),
    year = 1951:1953,
    value = c(100, 150, 200)
  )
  bl <- tibble::tibble(variable = "prcp", period = "annual", baseline_mean = 100)
  ano <- cd_anomaly(ts, bl)

  expect_equal(ano$anomaly, c(0, 50, 100))
  expect_equal(unique(ano$anomaly_type), "pct_normal")
})

test_that("cd_anomaly caps pct_normal at +/- cap_pct", {
  ts <- tibble::tibble(
    variable = rep("prcp", 2),
    period = rep("annual", 2),
    year = 1951:1952,
    value = c(500, -300)
  )
  bl <- tibble::tibble(variable = "prcp", period = "annual", baseline_mean = 100)
  ano <- cd_anomaly(ts, bl, cap_pct = 200)

  expect_equal(ano$anomaly[1], 200)
  expect_equal(ano$anomaly[2], -200)
})

test_that("cd_anomaly computes pct_point_diff anomalies", {
  # snowfall_fraction is already in % so the anomaly is value - baseline
  # interpreted as percentage points (not percent of normal).
  ts <- tibble::tibble(
    variable = rep("snowfall_fraction", 3),
    period = rep("annual", 3),
    year = 1951:1953,
    value = c(30, 25, 20)
  )
  bl <- tibble::tibble(
    variable = "snowfall_fraction", period = "annual", baseline_mean = 30
  )
  ano <- cd_anomaly(ts, bl)

  expect_equal(ano$anomaly, c(0, -5, -10))
  expect_equal(unique(ano$anomaly_type), "pct_point_diff")
  expect_equal(unique(ano$unit), "%")
})

test_that("cd_anomaly does not apply cap_pct to pct_point_diff", {
  # An extreme departure (e.g. snow_cover dropping from 80% to 5%) should
  # show -75 percentage points, not get clamped at -200 like pct_normal.
  ts <- tibble::tibble(
    variable = "snow_cover", period = "annual", year = 2025, value = 5
  )
  bl <- tibble::tibble(
    variable = "snow_cover", period = "annual", baseline_mean = 80
  )
  ano <- cd_anomaly(ts, bl, cap_pct = 50)
  expect_equal(ano$anomaly, -75)
})

test_that("cd_anomaly handles multiple variables", {
  ts <- tibble::tibble(
    variable = c(rep("tmean", 3), rep("prcp", 3)),
    period = rep("annual", 6),
    year = rep(1951:1953, 2),
    value = c(10, 11, 12, 100, 150, 200)
  )
  bl <- tibble::tibble(
    variable = c("tmean", "prcp"),
    period = c("annual", "annual"),
    baseline_mean = c(11, 100)
  )
  ano <- cd_anomaly(ts, bl)

  expect_equal(nrow(ano), 6)
  tmean_ano <- ano$anomaly[ano$variable == "tmean"]
  prcp_ano <- ano$anomaly[ano$variable == "prcp"]
  expect_equal(tmean_ano, c(-1, 0, 1))
  expect_equal(prcp_ano, c(0, 50, 100))
})
