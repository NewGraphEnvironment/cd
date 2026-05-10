#' Compare arbitrary time windows
#'
#' Computes the mean value for two user-defined time windows, the
#' difference between them, and (by default) a p-value testing
#' whether the two windows differ.
#'
#' Defaults compare a recent decade (`2015:2025`) to the WMO-style
#' standard normal reference period (`1951:1980`) — the framing
#' used in the package vignettes. This is a *cumulative-impact*
#' comparison ("how much warmer is the recent decade than the
#' pre-warming reference?") rather than a rate-of-change
#' comparison; for the latter use [cd_trend()].
#'
#' The window-vs-window p-value (`test = "t"` Welch t-test or
#' `test = "wilcox"` Mann-Whitney U) tests whether the means of
#' the two windows differ — a different question than
#' [cd_trend()]'s Mann-Kendall test, which checks for a monotonic
#' trend across the full series. Two windows can differ
#' significantly without a monotonic trend (step changes, U-shapes)
#' and a non-significant trend doesn't always mean the windows are
#' indistinguishable. The test treats annual values as independent;
#' for series with strong autocorrelation the t-test p is mildly
#' anti-conservative — the Wilcoxon alternative is more robust to
#' non-Gaussian tails / outliers but shares the independence
#' assumption.
#'
#' @param x A tibble from [cd_extract()] with columns `variable`,
#'   `period`, `year`, `value`.
#' @param window_a Integer vector of years for the recent / impact
#'   window. Default `2015:2025`.
#' @param window_b Integer vector of years for the reference
#'   window. Default `1951:1980` (WMO-style standard normal).
#' @param method Character. Comparison method: `"mean_diff"` for
#'   `mean_a - mean_b`, or `"pct_change"` for percentage change
#'   relative to window_b.
#' @param test Character or NULL. Window-vs-window significance
#'   test: `"t"` for Welch's two-sample t-test (default) or
#'   `"wilcox"` for Mann-Whitney U. Set to `NULL` to skip — output
#'   then drops the `p_value` column. Rows where either window has
#'   fewer than 8 non-NA values get `p_value = NA` and a single
#'   batched warning.
#'
#' @return A tibble with columns `variable`, `period`, `mean_a`,
#'   `mean_b`, `difference`, `method`, and (when `test` is
#'   non-NULL) `p_value`.
#'
#' @examples
#' catalog <- cd_catalog(
#'   system.file("extdata", "example_catalog.json", package = "cd")
#' )
#' aoi <- sf::st_read(
#'   system.file("extdata", "example_aoi.gpkg", package = "cd"),
#'   quiet = TRUE
#' )
#' ts <- cd_extract(catalog, aoi)
#'
#' # The toy example catalog only spans 1951:1960, so the windows
#' # below override the defaults (2015:2025 vs 1951:1980) — those
#' # are the right choice on the live STAC catalog. test = NULL
#' # because the toy windows have < 8 years.
#' cd_compare(ts, window_a = 1956:1960, window_b = 1951:1955, test = NULL)
#'
#' # Same comparison as percentage change
#' cd_compare(ts, window_a = 1956:1960, window_b = 1951:1955,
#'            method = "pct_change", test = NULL)
#'
#' @export
cd_compare <- function(x,
                       window_a = 2015:2025,
                       window_b = 1951:1980,
                       method = "mean_diff",
                       test = "t") {
  method <- match.arg(method, c("mean_diff", "pct_change"))
  if (!is.null(test)) test <- match.arg(test, c("t", "wilcox"))

  mean_a <- x |>
    dplyr::filter(.data$year %in% window_a) |>
    dplyr::summarise(mean_a = mean(.data$value, na.rm = TRUE), .by = c("variable", "period"))

  mean_b <- x |>
    dplyr::filter(.data$year %in% window_b) |>
    dplyr::summarise(mean_b = mean(.data$value, na.rm = TRUE), .by = c("variable", "period"))

  n_a <- length(unique(x$year[x$year %in% window_a]))
  n_b <- length(unique(x$year[x$year %in% window_b]))
  if (n_a < 2) warning("window_a has fewer than 2 years of data", call. = FALSE)
  if (n_b < 2) warning("window_b has fewer than 2 years of data", call. = FALSE)

  out <- dplyr::left_join(mean_a, mean_b, by = c("variable", "period"))

  out$difference <- switch(method,
    mean_diff = out$mean_a - out$mean_b,
    pct_change = (out$mean_a - out$mean_b) / abs(out$mean_b) * 100
  )
  out$method <- method

  if (!is.null(test)) {
    p <- vapply(seq_len(nrow(out)), function(i) {
      v <- out$variable[i]
      p_ <- out$period[i]
      a <- x$value[x$variable == v & x$period == p_ & x$year %in% window_a]
      b <- x$value[x$variable == v & x$period == p_ & x$year %in% window_b]
      a <- a[!is.na(a)]
      b <- b[!is.na(b)]
      if (length(a) < 8 || length(b) < 8) return(NA_real_)
      pv <- tryCatch(
        switch(test,
          t      = stats::t.test(a, b, var.equal = FALSE)$p.value,
          wilcox = stats::wilcox.test(a, b, exact = FALSE)$p.value
        ),
        error = function(e) NA_real_
      )
      round(pv, 4)
    }, numeric(1))

    if (any(is.na(p))) {
      bad <- which(is.na(p))
      warning(sprintf(
        "p_value set to NA for %d row(s) with < 8 years in either window: %s",
        length(bad),
        paste(sprintf("%s/%s", out$variable[bad], out$period[bad]), collapse = ", ")
      ), call. = FALSE)
    }
    out$p_value <- p
  }

  out
}
