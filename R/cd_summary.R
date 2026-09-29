#' Format trend results as a reporting table
#'
#' Joins trend statistics with variable metadata and computes Total
#' Change (slope x years). Returns a tibble ready for
#' [DT::datatable()] or [gt::gt()].
#'
#' Labels and units come from `long_name` and `unit` columns on `trend`
#' where present and not `NA` (carried by [cd_trend()] from the input
#' contract in [cd_anomaly()]), otherwise from [cd_variables()] — by
#' the same rules as [cd_anomaly()], so a registered variable trended
#' under a different `anomaly_type` gets no registry unit. A variable
#' found in neither is labelled by its name, with no unit.
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
#'
#' # Reporting table with Total Change = slope * years
#' cd_summary(trn)
#'
#' # Add region label for multi-AOI reports
#' cd_summary(trn, region_name = "Example AOI")
#'
#' @export
cd_summary <- function(trend, region_name = NULL) {
  trend <- dplyr::ungroup(trend)
  meta <- meta_resolve(trend)
  labels_param <- dplyr::coalesce(meta$long_name, as.character(trend$variable))
  labels_unit <- meta$unit

  out <- trend |>
    dplyr::mutate(
      Parameter = .env$labels_param,
      Period = stringr::str_to_title(.data$period),
      Slope = round(.data$slope, 3),
      Years = .data$n_years,
      `Total Change` = round(.data$slope * .data$n_years, 1),
      Unit = .env$labels_unit,
      `p-value` = .data$mk_pvalue
    ) |>
    dplyr::select("Parameter", "Period", "Slope", "Years", "Total Change", "Unit", "p-value")

  if (!is.null(region_name)) {
    out$Region <- region_name
  }

  out
}
