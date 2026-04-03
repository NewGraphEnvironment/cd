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
