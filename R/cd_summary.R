#' Format trend results as a reporting table
#'
#' Joins trend statistics with variable metadata from [cd_variables()]
#' and computes Total Change (slope x years). Returns a tibble ready
#' for [DT::datatable()] or [gt::gt()].
#'
#' @param trend A tibble from [cd_trend()].
#' @param region_name Optional character label for the AOI. If provided,
#'   adds a `Region` column.
#'
#' @return A tibble with columns `Parameter`, `Period`, `Slope`, `Years`,
#'   `Total Change`, `Unit`, `p-value`, and optionally `Region`.
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
#' trn <- cd_trend(ts, trend_start = 1951)
#' cd_summary(trn)
#'
#' @export
cd_summary <- function(trend, region_name = NULL) {
  vars <- cd_variables()
  par_labels <- stats::setNames(vars$long_name, vars$variable)
  unit_lookup <- stats::setNames(vars$unit, vars$variable)

  out <- trend |>
    dplyr::mutate(
      Parameter = unname(par_labels[.data$variable]),
      Period = stringr::str_to_title(.data$period),
      Slope = round(.data$slope, 3),
      Years = .data$n_years,
      `Total Change` = round(.data$slope * .data$n_years, 1),
      Unit = unname(unit_lookup[.data$variable]),
      `p-value` = .data$mk_pvalue
    ) |>
    dplyr::select("Parameter", "Period", "Slope", "Years", "Total Change", "Unit", "p-value")

  if (!is.null(region_name)) {
    out$Region <- region_name
  }

  out
}
