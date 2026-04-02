#' Compute climate anomalies
#'
#' Calculates departure from a baseline for each year. Uses
#' [cd_variables()] to determine the anomaly type: absolute deviation
#' for temperature, VPD, and RH; percent of normal for precipitation
#' and soil moisture.
#'
#' @param x A tibble from [cd_extract()] with columns `variable`,
#'   `period`, `year`, `value`.
#' @param baseline A tibble from [cd_baseline()] with columns
#'   `variable`, `period`, `baseline_mean`.
#' @param cap_pct Numeric. Cap for percent-of-normal anomalies.
#'   Values beyond +/- `cap_pct` are clamped. Default `200`.
#'
#' @return A tibble with columns `variable`, `period`, `year`,
#'   `anomaly`, `anomaly_type`, `unit`.
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
#' bl <- cd_baseline(ts, baseline_years = 1951:1955)
#' cd_anomaly(ts, bl)
#'
#' @export
cd_anomaly <- function(x, baseline, cap_pct = 200) {
  vars <- cd_variables()
  lookup <- stats::setNames(vars$anomaly_type, vars$variable)
  units <- stats::setNames(vars$unit, vars$variable)

  joined <- dplyr::left_join(x, baseline, by = c("variable", "period"))

  joined |>
    dplyr::mutate(
      anomaly_type = lookup[.data$variable],
      unit = units[.data$variable],
      anomaly = dplyr::case_when(
        .data$anomaly_type == "absolute" ~
          .data$value - .data$baseline_mean,
        .data$anomaly_type == "pct_normal" ~
          pmin(pmax((.data$value / .data$baseline_mean) * 100 - 100, -cap_pct), cap_pct)
      )
    ) |>
    dplyr::select("variable", "period", "year", "anomaly", "anomaly_type", "unit")
}
