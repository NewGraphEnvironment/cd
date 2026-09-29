test_that("cd_plot_comparison returns a ggplot", {
  cmp <- tibble::tibble(
    variable = c("tmean", "prcp"),
    period = c("annual", "annual"),
    mean_a = c(3.5, 850),
    mean_b = c(1.2, 820),
    difference = c(2.3, 30),
    method = c("mean_diff", "mean_diff")
  )
  p <- cd_plot_comparison(cmp)
  expect_s3_class(p, "ggplot")
})

test_that("cd_plot_comparison accepts custom labels", {
  cmp <- tibble::tibble(
    variable = "tmean", period = "annual",
    mean_a = 3.5, mean_b = 1.2, difference = 2.3, method = "mean_diff"
  )
  p <- cd_plot_comparison(cmp, labels = c(a = "2015-2025", b = "1951-1980"))
  expect_s3_class(p, "ggplot")
})

test_that("cd_plot_comparison facets by long_name carried from cd_compare() (#93)", {
  cmp <- tibble::tibble(
    variable = c("q_mean", "tmean", "q_max"), period = "annual",
    mean_a = c(6, 3.5, 20), mean_b = c(10, 1.2, 25),
    difference = c(-4, 2.3, -5), method = "mean_diff",
    long_name = c("Mean discharge", NA, NA)
  )
  p <- cd_plot_comparison(cmp)
  param <- stats::setNames(p$data$param, p$data$variable)
  expect_identical(unname(param["q_mean"]), "Mean discharge")
  expect_identical(unname(param["tmean"]), "Mean temperature")
  expect_identical(unname(param["q_max"]), "q_max")
})

test_that("cd_plot_comparison labels without a long_name column as before", {
  cmp <- tibble::tibble(
    variable = c("tmean", "q_mean"), period = "annual",
    mean_a = c(3.5, 6), mean_b = c(1.2, 10), difference = c(2.3, -4),
    method = "mean_diff"
  )
  p <- cd_plot_comparison(cmp)
  expect_setequal(p$data$param, c("Mean temperature", "q_mean"))
})

test_that("cd_plot_comparison keeps variables that share a long_name in separate facets", {
  cmp <- tibble::tibble(
    variable = c("q_site1", "q_site2", "q_site1"), period = c("annual", "annual", "spawn"),
    mean_a = 1:3, mean_b = 2:4, difference = -1, method = "mean_diff",
    long_name = "Mean discharge"
  )
  p <- suppressWarnings(cd_plot_comparison(cmp))
  expect_setequal(
    unique(p$data$param),
    c("Mean discharge (q_site1)", "Mean discharge (q_site2)")
  )
})

test_that("cd_compare() output plots with its carried long_name end to end", {
  ts <- tibble::tibble(
    variable = "q_mean", period = "spawn", year = 2001:2010,
    value = c(10, 12, 9, 11, 10, 6, 7, 5, 8, 6), long_name = "Mean discharge"
  )
  cmp <- cd_compare(ts, window_a = 2006:2010, window_b = 2001:2005, test = NULL)
  p <- suppressWarnings(cd_plot_comparison(cmp))
  expect_identical(unique(p$data$param), "Mean discharge")
})

test_that("cd_plot_comparison never puts two variables in one facet, even when labels collide", {
  cmp <- tibble::tibble(
    variable = c("a", "b", "c"), period = "annual",
    mean_a = 1:3, mean_b = 2:4, difference = -1, method = "mean_diff",
    long_name = c("Q", "Q", "Q (a)")
  )
  p <- suppressWarnings(cd_plot_comparison(cmp))
  facet_vars <- unique(p$data[c("facet", "variable")])
  expect_equal(nrow(facet_vars), 3)
  expect_false(anyDuplicated(facet_vars$facet) > 0)
  b <- suppressWarnings(ggplot2::ggplot_build(p))
  expect_equal(nrow(b$layout$layout), 3)
})

test_that("cd_plot_comparison adds no suffix to one variable compared over several periods", {
  cmp <- tibble::tibble(
    variable = "tmean", period = c("annual", "summer"),
    mean_a = c(3.5, 15), mean_b = c(1.2, 13), difference = 2, method = "mean_diff"
  )
  p <- suppressWarnings(cd_plot_comparison(cmp))
  expect_identical(unique(p$data$param), "Mean temperature")
})
