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
    variable = rep("prcp", 10),
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

# long_name pass-through (#93) ---------------------------------------------

q_ts <- function(...) {
  tibble::tibble(
    variable = "q_mean", period = "spawn", year = 2001:2010,
    value = c(10, 12, 9, 11, 10, 6, 7, 5, 8, 6), ...
  )
}

test_that("cd_compare passes a carried long_name through, last", {
  cmp <- cd_compare(q_ts(long_name = "Mean discharge"),
                    window_a = 2006:2010, window_b = 2001:2005, test = NULL)
  expect_named(cmp, c("variable", "period", "mean_a", "mean_b", "difference", "method", "long_name"))
  expect_identical(cmp$long_name, "Mean discharge")
})

test_that("cd_compare adds no long_name column when the input carries none", {
  cmp <- cd_compare(q_ts(), window_a = 2006:2010, window_b = 2001:2005, test = NULL)
  expect_false("long_name" %in% names(cmp))
})

test_that("cd_compare fills an NA long_name from cd_variables()", {
  ts <- q_ts(long_name = NA_character_)
  ts$variable <- "tmean"
  cmp <- cd_compare(ts, window_a = 2006:2010, window_b = 2001:2005, test = NULL)
  expect_identical(cmp$long_name, "Mean temperature")
})

test_that("cd_compare errors on two long_names within a series", {
  ts <- q_ts(long_name = rep(c("Mean discharge", "Discharge"), each = 5))
  expect_error(
    cd_compare(ts, window_a = 2006:2010, window_b = 2001:2005, test = NULL),
    "long_name"
  )
})

test_that("cd_compare keeps one long_name per series across several variables", {
  ts <- rbind(q_ts(long_name = "Mean discharge"),
              transform(q_ts(long_name = "Peak discharge"), variable = "q_max"))
  cmp <- cd_compare(ts, window_a = 2006:2010, window_b = 2001:2005, test = NULL)
  expect_equal(nrow(cmp), 2)
  expect_identical(cmp$long_name[cmp$variable == "q_max"], "Peak discharge")
  expect_identical(cmp$long_name[cmp$variable == "q_mean"], "Mean discharge")
})

test_that("cd_compare appends long_name after p_value", {
  expect_warning(
    cmp <- cd_compare(q_ts(long_name = "Mean discharge"),
                      window_a = 2006:2010, window_b = 2001:2005),
    "p_value set to NA"
  )
  expect_identical(utils::tail(names(cmp), 2), c("p_value", "long_name"))
})

test_that("cd_compare accepts a partly NA long_name that matches the registry", {
  ts <- q_ts(long_name = rep(c("Mean temperature", NA), each = 5))
  ts$variable <- "tmean"
  cmp <- cd_compare(ts, window_a = 2006:2010, window_b = 2001:2005, test = NULL)
  expect_identical(cmp$long_name, "Mean temperature")
})

# ---------------------------------------------------------------------------
# pct_change only where the values have a real zero (#138)
# ---------------------------------------------------------------------------

# tibble() evaluates in order, so the argument cannot be called `variable`
pct_series <- function(vars, ...) {
  tibble::tibble(
    variable = rep(vars, each = 10),
    period = "annual",
    year = rep(1951:1960, length(vars)),
    value = rep(c(rep(-0.5, 5), rep(1.5, 5)), length(vars)),
    ...
  )
}

test_that("cd_compare gives no percent for temperature, with a warning (#138)", {
  ts <- pct_series("tmean")
  expect_warning(
    cmp <- cd_compare(ts, window_a = 1956:1960, window_b = 1951:1955,
                      method = "pct_change", test = NULL),
    "tmean/annual"
  )
  expect_true(is.na(cmp$difference))
  expect_equal(cmp$mean_a, 1.5)
  expect_equal(cmp$mean_b, -0.5)
  expect_equal(cmp$method, "pct_change")
})

test_that("cd_compare blocks every variable without a real zero (#138)", {
  blocked <- c("tmean", "tmax", "tmin", "rh", "snow_cover", "snowfall_fraction",
               "snowmelt_doy_50")
  ts <- pct_series(blocked)
  w <- testthat::capture_warnings(
    cmp <- cd_compare(ts, window_a = 1956:1960, window_b = 1951:1955,
                      method = "pct_change", test = NULL)
  )
  expect_length(w, 1)
  expect_true(all(is.na(cmp$difference)))
  for (v in blocked) expect_match(w, paste0(v, "/annual"), fixed = TRUE)
})

test_that("cd_compare keeps the percent for the rest of a mixed table (#138)", {
  ts <- pct_series(c("tmean", "prcp", "vpd", "swe_max"))
  ts$value[ts$variable != "tmean"] <- rep(c(rep(100, 5), rep(150, 5)), 3)
  w <- testthat::capture_warnings(
    cmp <- cd_compare(ts, window_a = 1956:1960, window_b = 1951:1955,
                      method = "pct_change", test = NULL)
  )
  expect_length(w, 1)
  expect_match(w, "tmean/annual", fixed = TRUE)
  expect_false(grepl("prcp|vpd|swe_max", w))
  expect_equal(nrow(cmp), 4)
  expect_true(is.na(cmp$difference[cmp$variable == "tmean"]))
  expect_equal(cmp$difference[cmp$variable != "tmean"], rep(50, 3))
})

test_that("cd_compare mean_diff on temperature neither warns nor drops (#138)", {
  ts <- pct_series("tmean")
  expect_no_warning(
    cmp <- cd_compare(ts, window_a = 1956:1960, window_b = 1951:1955,
                      test = NULL)
  )
  expect_equal(cmp$difference, 2)
})

test_that("cd_compare reads a carried pct_change before the registry (#138)", {
  ts <- pct_series("q_mean", pct_change = FALSE)
  expect_warning(
    cmp <- cd_compare(ts, window_a = 1956:1960, window_b = 1951:1955,
                      method = "pct_change", test = NULL),
    "q_mean/annual"
  )
  expect_true(is.na(cmp$difference))

  ts <- pct_series("tmean", pct_change = TRUE)
  expect_no_warning(
    cmp <- cd_compare(ts, window_a = 1956:1960, window_b = 1951:1955,
                      method = "pct_change", test = NULL)
  )
  expect_equal(cmp$difference, 400)
  expect_false("pct_change" %in% names(cmp))
})

test_that("cd_compare falls back to anomaly_type off the registry (#138)", {
  ts <- pct_series("share", anomaly_type = "pct_point_diff")
  expect_warning(
    cmp <- cd_compare(ts, window_a = 1956:1960, window_b = 1951:1955,
                      method = "pct_change", test = NULL),
    "share/annual"
  )
  expect_true(is.na(cmp$difference))

  for (at in c("absolute", "pct_normal", NA)) {
    ts <- pct_series("q_mean", anomaly_type = at)
    expect_no_warning(
      cmp <- cd_compare(ts, window_a = 1956:1960, window_b = 1951:1955,
                        method = "pct_change", test = NULL)
    )
    expect_equal(cmp$difference, 400, info = at)
  }
  ts <- pct_series("q_mean")
  expect_no_warning(
    cmp <- cd_compare(ts, window_a = 1956:1960, window_b = 1951:1955,
                      method = "pct_change", test = NULL)
  )
  expect_equal(cmp$difference, 400)
})

test_that("cd_compare fills an NA carried pct_change from the registry (#138)", {
  ts <- pct_series(c("tmean", "prcp"), pct_change = NA)
  expect_warning(
    cmp <- cd_compare(ts, window_a = 1956:1960, window_b = 1951:1955,
                      method = "pct_change", test = NULL),
    "tmean/annual"
  )
  expect_true(is.na(cmp$difference[cmp$variable == "tmean"]))
  expect_equal(cmp$difference[cmp$variable == "prcp"], 400)
})

test_that("cd_compare refuses a pct_change that is not logical or not one per series (#138)", {
  ts <- pct_series("q_mean", pct_change = "no")
  expect_error(
    cd_compare(ts, window_a = 1956:1960, window_b = 1951:1955,
               method = "pct_change", test = NULL),
    "pct_change"
  )
  ts <- pct_series("q_mean", pct_change = rep(c(TRUE, FALSE), 5))
  expect_error(
    cd_compare(ts, window_a = 1956:1960, window_b = 1951:1955,
               method = "pct_change", test = NULL),
    "pct_change"
  )
})

test_that("cd_compare accepts a partly NA pct_change that matches the registry (#138)", {
  ts <- pct_series("tmean", pct_change = c(FALSE, rep(NA, 9)))
  expect_warning(
    cmp <- cd_compare(ts, window_a = 1956:1960, window_b = 1951:1955,
                      method = "pct_change", test = NULL),
    "tmean/annual"
  )
  expect_true(is.na(cmp$difference))
})

test_that("cd_compare matches the guard by name on a factor variable (#138)", {
  ts <- pct_series(c("prcp", "tmean"))
  ts$variable <- factor(ts$variable, levels = c("tmean", "prcp"))
  expect_warning(
    cmp <- cd_compare(ts, window_a = 1956:1960, window_b = 1951:1955,
                      method = "pct_change", test = NULL),
    "tmean/annual"
  )
  expect_true(is.na(cmp$difference[cmp$variable == "tmean"]))
  expect_equal(cmp$difference[cmp$variable == "prcp"], 400)
})

test_that("cd_compare keeps the p_value and percent warnings apart (#138)", {
  ts <- pct_series(c("tmean", "prcp"))
  w <- testthat::capture_warnings(
    cmp <- cd_compare(ts, window_a = 1956:1960, window_b = 1951:1955,
                      method = "pct_change")
  )
  expect_length(w, 2)
  expect_match(w[grepl("p_value", w)], "tmean/annual")
  expect_match(w[grepl("difference", w)], "tmean/annual")
  expect_false(any(grepl("prcp", w[grepl("difference", w)])))
})

test_that("a numeric pct_change column does not reach other consumers (#138)", {
  # The vignettes add a numeric percent called pct_change to compare output
  ts <- pct_series("tmean")
  cmp <- cd_compare(ts, window_a = 1956:1960, window_b = 1951:1955, test = NULL)
  cmp$pct_change <- 12.5
  expect_no_error(meta_resolve(cmp))
  expect_s3_class(cd_plot_comparison(cmp), "ggplot")
})
