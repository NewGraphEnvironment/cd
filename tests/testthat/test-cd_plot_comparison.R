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
