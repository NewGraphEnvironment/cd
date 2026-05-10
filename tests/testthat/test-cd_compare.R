test_that("cd_compare computes mean_diff", {
  ts <- tibble::tibble(
    variable = rep("tmean", 10),
    period = rep("annual", 10),
    year = 1951:1960,
    value = c(rep(0, 5), rep(10, 5))
  )
  cmp <- cd_compare(ts, window_a = 1956:1960, window_b = 1951:1955, test = NULL)

  expect_s3_class(cmp, "tbl_df")
  expect_named(cmp, c("variable", "period", "mean_a", "mean_b", "difference", "method"))
  expect_equal(cmp$mean_a, 10)
  expect_equal(cmp$mean_b, 0)
  expect_equal(cmp$difference, 10)
  expect_equal(cmp$method, "mean_diff")
})

test_that("cd_compare computes pct_change", {
  ts <- tibble::tibble(
    variable = rep("tmean", 10),
    period = rep("annual", 10),
    year = 1951:1960,
    value = c(rep(100, 5), rep(150, 5))
  )
  cmp <- cd_compare(ts, window_a = 1956:1960, window_b = 1951:1955,
                    method = "pct_change", test = NULL)

  expect_equal(cmp$difference, 50)
  expect_equal(cmp$method, "pct_change")
})

test_that("cd_compare warns on small windows", {
  ts <- tibble::tibble(
    variable = rep("tmean", 3),
    period = rep("annual", 3),
    year = 1951:1953,
    value = 1:3
  )
  expect_warning(
    cd_compare(ts, window_a = 1953, window_b = 1951:1952, test = NULL),
    "window_a has fewer than 2 years"
  )
})

test_that("cd_compare uses 2015:2025 vs 1951:1980 defaults", {
  # Toy series with values that bake in the default-window framing —
  # 1951:1980 reference at value 0, 2015:2025 recent at value 2.
  ts <- tibble::tibble(
    variable = "tmean",
    period = "annual",
    year = c(1951:1980, 2015:2025),
    value = c(rep(0, 30), rep(2, 11))
  )
  cmp <- cd_compare(ts, test = NULL)

  expect_named(cmp, c("variable", "period", "mean_a", "mean_b", "difference", "method"))
  expect_equal(cmp$mean_a, 2)
  expect_equal(cmp$mean_b, 0)
  expect_equal(cmp$difference, 2)
})

test_that("cd_compare handles multiple variables", {
  ts <- tibble::tibble(
    variable = rep(c("tmean", "prcp"), each = 6),
    period = rep("annual", 12),
    year = rep(1951:1956, 2),
    value = c(0, 0, 0, 10, 10, 10, 100, 100, 100, 200, 200, 200)
  )
  cmp <- cd_compare(ts, window_a = 1954:1956, window_b = 1951:1953, test = NULL)

  expect_equal(nrow(cmp), 2)
  expect_equal(cmp$difference[cmp$variable == "tmean"], 10)
  expect_equal(cmp$difference[cmp$variable == "prcp"], 100)
})

# ---------------------------------------------------------------------------
# Window-vs-window p-value tests (#43)
# ---------------------------------------------------------------------------

test_that("cd_compare returns p_value column when test = 't' (default)", {
  set.seed(1)
  # Clean step change between two 30-year windows — Welch t should
  # return a vanishingly small p.
  ts <- tibble::tibble(
    variable = "tmean",
    period = "annual",
    year = c(1951:1980, 1991:2020),
    value = c(rnorm(30, mean = 0, sd = 1), rnorm(30, mean = 5, sd = 1))
  )
  cmp <- cd_compare(ts, window_a = 1991:2020, window_b = 1951:1980)

  expect_true("p_value" %in% names(cmp))
  expect_equal(nrow(cmp), 1)
  expect_lt(cmp$p_value, 0.001)
})

test_that("cd_compare t-test returns large p on iid noise", {
  set.seed(2)
  ts <- tibble::tibble(
    variable = "tmean",
    period = "annual",
    year = c(1951:1980, 1991:2020),
    value = rnorm(60, mean = 0, sd = 1)
  )
  cmp <- cd_compare(ts, window_a = 1991:2020, window_b = 1951:1980)

  expect_gt(cmp$p_value, 0.05)
})

test_that("cd_compare supports test = 'wilcox'", {
  set.seed(3)
  ts <- tibble::tibble(
    variable = "tmean",
    period = "annual",
    year = c(1951:1980, 1991:2020),
    value = c(rnorm(30, mean = 0), rnorm(30, mean = 5))
  )
  cmp <- cd_compare(ts, window_a = 1991:2020, window_b = 1951:1980, test = "wilcox")

  expect_true("p_value" %in% names(cmp))
  expect_lt(cmp$p_value, 0.001)
})

test_that("cd_compare with test = NULL drops p_value column", {
  ts <- tibble::tibble(
    variable = "tmean",
    period = "annual",
    year = c(1951:1980, 1991:2020),
    value = c(rep(0, 30), rep(5, 30))
  )
  cmp <- cd_compare(ts, window_a = 1991:2020, window_b = 1951:1980, test = NULL)

  expect_named(cmp, c("variable", "period", "mean_a", "mean_b", "difference", "method"))
})

test_that("cd_compare small-N guard returns NA p_value with one warning", {
  ts <- tibble::tibble(
    variable = "tmean",
    period = "annual",
    year = 1951:1960,
    value = c(rep(0, 5), rep(5, 5))
  )
  expect_warning(
    cmp <- cd_compare(ts, window_a = 1956:1960, window_b = 1951:1955),
    "p_value set to NA"
  )
  expect_true(is.na(cmp$p_value))
})

test_that("cd_compare per-row p_values on multi-variable input", {
  set.seed(4)
  # tmean: real shift (small p); prcp: no shift (large p)
  ts <- tibble::tibble(
    variable = rep(c("tmean", "prcp"), each = 60),
    period = "annual",
    year = rep(c(1951:1980, 1991:2020), 2),
    value = c(
      c(rnorm(30, mean = 0, sd = 1), rnorm(30, mean = 5, sd = 1)),
      rnorm(60, mean = 100, sd = 5)
    )
  )
  cmp <- cd_compare(ts, window_a = 1991:2020, window_b = 1951:1980)

  expect_lt(cmp$p_value[cmp$variable == "tmean"], 0.001)
  expect_gt(cmp$p_value[cmp$variable == "prcp"], 0.05)
})
