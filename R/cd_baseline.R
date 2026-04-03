#' Compute climatological baseline
#'
#' Computes the mean value over a reference period for each variable
#' and period combination. The result is used by [cd_anomaly()] to
#' calculate departures.
#'
#' @param x A tibble from [cd_extract()] with columns `variable`,
#'   `period`, `year`, `value`.
#' @param baseline_years Integer vector of years to average.
#'   Default `1981:2010` (WMO standard).
#'
#' @return A tibble with columns `variable`, `period`, `baseline_mean`.
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
#' # Early period baseline — pre-warming reference for departure communication
#' cd_baseline(ts, baseline_years = 1951:1955)
#'
#' # Later period baseline — shows how baseline choice affects anomaly magnitude
#' cd_baseline(ts, baseline_years = 1956:1960)
#'
#' @export
cd_baseline <- function(x, baseline_years = 1981:2010) {
  missing <- setdiff(baseline_years, x$year)

  if (length(missing) > 0) {
    warning(
      length(missing), " of ", length(baseline_years),
      " baseline years not found in data: ",
      paste(range(missing), collapse = "-"),
      call. = FALSE
    )
  }

  x |>
    dplyr::filter(.data$year %in% baseline_years) |>
    dplyr::summarise(
      baseline_mean = mean(.data$value, na.rm = TRUE),
      .by = c("variable", "period")
    )
}
