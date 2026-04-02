#' Extract zonal mean time series for an AOI
#'
#' For each variable and period in the catalog, crops the COG to the AOI
#' and computes the spatial mean per year (band). Returns a tidy tibble
#' of raw climate values suitable for [cd_baseline()], [cd_anomaly()],
#' or [cd_trend()].
#'
#' @param catalog A tibble from [cd_catalog()] with columns
#'   `variable`, `period`, `href`.
#' @param aoi An `sf` or `SpatVector` polygon.
#' @param variables Character vector of variables to extract.
#'   Defaults to all variables in `catalog`.
#' @param periods Character vector of periods to extract.
#'   Defaults to all periods in `catalog`.
#' @param years Optional integer vector to filter specific years.
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{variable}{Climate variable short name.}
#'     \item{period}{Temporal aggregation period.}
#'     \item{year}{Year (integer).}
#'     \item{value}{Spatial mean of the climate value for this AOI.}
#'   }
#'
#' @examples
#' catalog <- cd_catalog(
#'   system.file("extdata", "example_catalog.json", package = "cd")
#' )
#' aoi <- sf::st_read(
#'   system.file("extdata", "example_aoi.gpkg", package = "cd"),
#'   quiet = TRUE
#' )
#' cd_extract(catalog, aoi)
#'
#' @export
cd_extract <- function(catalog, aoi,
                       variables = catalog$variable,
                       periods = catalog$period,
                       years = NULL) {
  rows <- catalog[catalog$variable %in% variables & catalog$period %in% periods, ]

  results <- lapply(seq_len(nrow(rows)), function(i) {
    r <- cd_crop(rows$href[i], aoi)
    means <- terra::global(r, fun = "mean", na.rm = TRUE)
    yr <- as.integer(names(r))

    tibble::tibble(
      variable = rows$variable[i],
      period = rows$period[i],
      year = yr,
      value = round(means$mean, 4)
    )
  })

  out <- dplyr::bind_rows(results)

  if (!is.null(years)) {
    out <- out[out$year %in% years, ]
  }

  out
}
