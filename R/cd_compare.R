#' Compare arbitrary time windows
#'
#' Computes the mean value for two user-defined time windows and
#' the difference between them. Enables custom comparisons beyond
#' standard baseline anomalies.
#'
#' @param x A tibble from [cd_extract()] with columns `variable`,
#'   `period`, `year`, `value`.
#' @param window_a Integer vector of years for the first window.
#' @param window_b Integer vector of years for the second window.
#' @param method Character. Comparison method: `"mean_diff"` for
#'   `mean_a - mean_b`, or `"pct_change"` for percentage change
#'   relative to window_b.
#'
#' @return A tibble with columns `variable`, `period`, `mean_a`,
#'   `mean_b`, `difference`, `method`.
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
#' # How has the recent period shifted from the early period?
#' cd_compare(ts, window_a = 1956:1960, window_b = 1951:1955)
#'
#' # Same comparison as percentage change
#' cd_compare(ts, window_a = 1956:1960, window_b = 1951:1955, method = "pct_change")
#'
#' @export
cd_compare <- function(x, window_a, window_b, method = "mean_diff") {
  method <- match.arg(method, c("mean_diff", "pct_change"))

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

  out
}
