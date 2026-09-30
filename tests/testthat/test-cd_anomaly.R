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

# Series outside cd_variables() (#92) -------------------------------------

test_that("cd_anomaly uses anomaly_type and unit carried on the input", {
  ts <- tibble::tibble(
    variable = "q_mean", period = "spawn", year = 2000:2002,
    value = c(10, 15, 5), anomaly_type = "pct_normal", unit = "%"
  )
  bl <- cd_baseline(ts, baseline_years = 2000:2002)
  ano <- cd_anomaly(ts, bl)

  expect_named(ano, c("variable", "period", "year", "anomaly", "anomaly_type", "unit"))
  expect_equal(ano$anomaly, c(0, 50, -50))
  expect_equal(unique(ano$anomaly_type), "pct_normal")
  expect_equal(unique(ano$unit), "%")
})

test_that("cd_anomaly errors naming a variable whose type cannot be resolved", {
  x <- data.frame(variable = "q_mean", period = "spawn", year = 2000:2001, value = 1:2)
  expect_error(
    cd_anomaly(x, cd_baseline(x, 2000:2001)),
    "anomaly_type.*q_mean"
  )
})

test_that("cd_anomaly errors on an anomaly_type outside the supported set", {
  ts <- tibble::tibble(
    variable = "q_mean", period = "spawn", year = 2000:2001,
    value = 1:2, anomaly_type = "ratio"
  )
  expect_error(cd_anomaly(ts, cd_baseline(ts, 2000:2001)), "ratio")
})

test_that("cd_anomaly falls back to cd_variables() row by row", {
  # NA in the carried column resolves from the registry; a registered
  # variable's carried type overrides the registry.
  ts <- tibble::tibble(
    variable = c("tmean", "tmean", "prcp", "prcp", "q_mean", "q_mean"),
    period = "annual",
    year = rep(2000:2001, 3),
    value = c(10, 12, 100, 150, 4, 6),
    anomaly_type = c(NA, NA, "absolute", "absolute", "absolute", "absolute"),
    unit = c(NA, NA, "mm", "mm", NA, NA)
  )
  ano <- cd_anomaly(ts, cd_baseline(ts, 2000:2001))

  expect_equal(ano$anomaly_type[ano$variable == "tmean"], c("absolute", "absolute"))
  expect_equal(ano$unit[ano$variable == "tmean"], c("°C", "°C"))
  expect_equal(ano$anomaly[ano$variable == "prcp"], c(-25, 25))
  expect_equal(unique(ano$unit[ano$variable == "prcp"]), "mm")
  expect_equal(ano$anomaly[ano$variable == "q_mean"], c(-1, 1))
  expect_true(all(is.na(ano$unit[ano$variable == "q_mean"])))
})

test_that("cd_anomaly carries long_name through when present", {
  ts <- tibble::tibble(
    variable = "q_mean", period = "spawn", year = 2000:2001, value = c(1, 3),
    anomaly_type = "absolute", unit = "m³/s", long_name = "Mean discharge"
  )
  ano <- cd_anomaly(ts, cd_baseline(ts, 2000:2001))
  expect_named(
    ano,
    c("variable", "period", "year", "anomaly", "anomaly_type", "unit", "long_name")
  )
  expect_equal(unique(ano$long_name), "Mean discharge")
})

test_that("cd_anomaly accepts factor metadata columns", {
  ts <- data.frame(
    variable = factor("q_mean"), period = factor("spawn"), year = 2000:2001,
    value = c(1, 3), anomaly_type = factor("absolute")
  )
  ano <- cd_anomaly(ts, cd_baseline(ts, 2000:2001))
  expect_equal(ano$anomaly, c(-1, 1))
  expect_equal(unique(ano$anomaly_type), "absolute")
})

test_that("cd_anomaly on zero rows returns zero rows", {
  ts <- tibble::tibble(
    variable = character(), period = character(), year = integer(),
    value = numeric()
  )
  bl <- tibble::tibble(variable = character(), period = character(), baseline_mean = numeric())
  ano <- cd_anomaly(ts, bl)
  expect_equal(nrow(ano), 0)
  expect_named(ano, c("variable", "period", "year", "anomaly", "anomaly_type", "unit"))
})

test_that("cd_anomaly errors when one series resolves to two anomaly types", {
  ts <- tibble::tibble(
    variable = "q_mean", period = "spawn", year = 2000:2001, value = 1:2,
    anomaly_type = c("absolute", "pct_normal")
  )
  expect_error(cd_anomaly(ts, cd_baseline(ts, 2000:2001)), "q_mean/spawn")
})

test_that("cd_anomaly resolves a factor variable by name, not by level code", {
  # factor("q_mean") has code 1; indexing a named lookup by it returned
  # tmean's "absolute" instead of failing to resolve.
  ts <- data.frame(
    variable = factor("q_mean"), period = "spawn", year = 2000:2001, value = 1:2
  )
  expect_error(cd_anomaly(ts, cd_baseline(ts, 2000:2001)), "anomaly_type.*q_mean")

  ts_prcp <- data.frame(
    variable = factor("prcp"), period = "annual", year = 2000:2001, value = c(100, 150)
  )
  ano <- cd_anomaly(ts_prcp, cd_baseline(ts_prcp, 2000:2001))
  expect_equal(unique(ano$anomaly_type), "pct_normal")
})

test_that("cd_anomaly ignores metadata columns carried on the baseline", {
  ts <- tibble::tibble(
    variable = "q_mean", period = "spawn", year = 2000:2001, value = c(1, 3),
    anomaly_type = "absolute", unit = "m³/s"
  )
  bl <- tibble::tibble(
    variable = "q_mean", period = "spawn", baseline_mean = 2,
    anomaly_type = "absolute", unit = "m³/s"
  )
  ano <- cd_anomaly(ts, bl)
  expect_named(ano, c("variable", "period", "year", "anomaly", "anomaly_type", "unit"))
  expect_equal(ano$anomaly, c(-1, 1))
})

test_that("cd_anomaly does not borrow the registry unit for an overridden type", {
  # prcp is pct_normal ("%") in the registry; as "absolute" its anomaly is mm.
  ts <- tibble::tibble(
    variable = "prcp", period = "annual", year = 2000:2001, value = c(100, 150),
    anomaly_type = "absolute"
  )
  ano <- cd_anomaly(ts, cd_baseline(ts, 2000:2001))
  expect_equal(ano$anomaly, c(-25, 25))
  expect_true(all(is.na(ano$unit)))
})

test_that("cd_anomaly errors when one series carries two long_names", {
  ts <- tibble::tibble(
    variable = "q_mean", period = "spawn", year = 2000:2001, value = 1:2,
    anomaly_type = "absolute", long_name = c("A", "B")
  )
  expect_error(cd_anomaly(ts, cd_baseline(ts, 2000:2001)), "long_name.*q_mean/spawn")
})

test_that("cd_baseline and cd_anomaly accept grouped input", {
  ts <- tibble::tibble(
    variable = "q_mean", period = "spawn", year = 2000:2001, value = c(1, 3),
    anomaly_type = "absolute"
  ) |>
    dplyr::group_by(.data$variable, .data$period)
  bl <- cd_baseline(ts, 2000:2001)
  expect_equal(bl$baseline_mean, 2)
  expect_equal(cd_anomaly(ts, bl)$anomaly, c(-1, 1))
})

test_that("cd_anomaly fills a partly-NA long_name for a registered variable", {
  ts <- tibble::tibble(
    variable = "tmean", period = "annual", year = 2000:2003, value = 1:4,
    long_name = c("Mean temperature", NA, NA, NA)
  )
  ano <- cd_anomaly(ts, cd_baseline(ts, 2000:2003))
  expect_equal(unique(ano$long_name), "Mean temperature")
})

test_that("stacked sites under one variable are refused, not pooled (#92)", {
  skip_if_not_installed("Kendall")
  skip_if_not_installed("zyp")
  q <- tibble::tibble(
    station = rep(c("A", "B"), each = 10), variable = "q_mean", period = "spawn",
    year = rep(2000:2009, 2), value = c(1:10, 101:110), anomaly_type = "absolute"
  )
  for (x in list(q, dplyr::group_by(q, .data$station))) {
    expect_error(cd_baseline(x, 2000:2004), "q_mean/spawn/2000")
    expect_error(cd_anomaly(x, tibble::tibble(variable = "q_mean", period = "spawn", baseline_mean = 1)),
                 "More than one row per variable, period and year")
    expect_error(cd_compare(x, 2005:2009, 2000:2004, test = NULL), "More than one row")
    expect_error(cd_trend(x, trend_start = 2000), "More than one row")
  }
})

# label_disambiguate() (#98) ------------------------------------------------

test_that("label_disambiguate appends the variable to a label several variables share", {
  expect_identical(
    label_disambiguate(c("q_site1", "q_site2", "q_site1"), rep("Mean discharge", 3)),
    c("Mean discharge (q_site1)", "Mean discharge (q_site2)", "Mean discharge (q_site1)")
  )
})

test_that("label_disambiguate leaves unique labels and single variables alone", {
  expect_identical(
    label_disambiguate(c("tmean", "prcp"), c("Mean temperature", "Precipitation")),
    c("Mean temperature", "Precipitation")
  )
  # one variable over several periods is not a collision
  expect_identical(label_disambiguate(c("tmean", "tmean"), c("T", "T")), c("T", "T"))
  expect_identical(label_disambiguate(character(0), character(0)), character(0))
})

test_that("label_disambiguate ends with one distinct label per variable when a suffix collides", {
  out <- label_disambiguate(c("a", "b", "c", "a"), c("Q", "Q", "Q (a)", "Q"))
  expect_identical(out, c("Q (a) (a)", "Q (b)", "Q (a) (c)", "Q (a) (a)"))
  pairs <- unique(data.frame(v = c("a", "b", "c", "a"), l = out))
  expect_false(anyDuplicated(pairs$l) > 0)
})

test_that("label_disambiguate reads a factor variable by name", {
  expect_identical(
    label_disambiguate(factor(c("q2", "q1")), c("Q", "Q")),
    c("Q (q2)", "Q (q1)")
  )
})

test_that("label_disambiguate handles one variable carrying different labels by period", {
  expect_identical(
    label_disambiguate(c("a", "a", "b"), c("X", "Y", "X")),
    c("X (a)", "Y", "X (b)")
  )
})

test_that("label_disambiguate settles a collision chain longer than the variable count", {
  # two variables, three passes: a carries three labels across periods
  out <- label_disambiguate(c("a", "e", "e", "e"), c("Q", "Q", "Q (a)", "Q (a) (a)"))
  expect_identical(out, c("Q (a) (a) (a)", "Q (e)", "Q (a) (e)", "Q (a) (a) (e)"))
})

test_that("label_disambiguate aborts rather than return a label two variables share", {
  expect_error(
    label_disambiguate(c("a", "b", "c"), c("Q", "Q", "Q (a)"), max_passes = 1),
    "still shared: Q \\(a\\)"
  )
  # a variable name built to collide never settles, at any bound
  expect_error(
    label_disambiguate(c("a", "a) (a", "a) (a"), c("Q", "Q", "Q (a)")),
    "still shared"
  )
})
