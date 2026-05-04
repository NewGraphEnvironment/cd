#' Compute climate anomalies
#'
#' Calculates departure from a baseline for each year. Uses
#' [cd_variables()] to determine the anomaly type: absolute deviation
#' for temperature, VPD, RH, and the annual snow scalars; percent of
#' normal for precipitation, soil moisture, and the monthly snow vars
#' (`swe`, `snowfall`, `snowmelt`); percentage-point difference for
#' variables that are already fractions/percentages (`snow_cover`,
#' `snowfall_fraction`).
#'
#' @param x A tibble from [cd_extract()] with columns `variable`,
#'   `period`, `year`, `value`.
#' @param baseline A tibble from [cd_baseline()] with columns
#'   `variable`, `period`, `baseline_mean`.
#' @param cap_pct Numeric. Cap for percent-of-normal anomalies.
#'   Values beyond +/- `cap_pct` are clamped. Default `200`. Only
#'   applies to `pct_normal` variables; `absolute` and
#'   `pct_point_diff` anomalies are not capped.
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
#'
#' # Compute anomalies relative to early-period baseline
#' # Absolute deviation for temperature; percent of normal for precipitation
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
        .data$anomaly_type %in% c("absolute", "pct_point_diff") ~
          .data$value - .data$baseline_mean,
        .data$anomaly_type == "pct_normal" ~
          pmin(pmax((.data$value / .data$baseline_mean) * 100 - 100, -cap_pct), cap_pct)
      )
    ) |>
    dplyr::select("variable", "period", "year", "anomaly", "anomaly_type", "unit")
}
