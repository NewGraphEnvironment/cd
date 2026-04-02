#' Climate variable metadata
#'
#' Returns a tibble of metadata for the seven climate variables supported
#' by the cd package. Used internally for unit labels, anomaly type routing,
#' and ERA5-Land API variable names.
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{variable}{Short name used throughout the package.}
#'     \item{long_name}{Human-readable label for plots and tables.}
#'     \item{unit}{Measurement unit (degree C, percent, Pa).}
#'     \item{anomaly_type}{"absolute" for direct departures, "pct_normal"
#'       for percent-of-normal anomalies.}
#'     \item{era5_name}{ERA5-Land variable name for CDS API requests,
#'       or NA for derived variables.}
#'   }
#'
#' @examples
#' cd_variables()
#' cd_variables()$variable
#'
#' @export
cd_variables <- function() {
  tibble::tibble(
    variable = c("tmean", "tmax", "tmin", "prcp", "vpd", "rh", "soil_moisture"),
    long_name = c(
      "Mean temperature", "Maximum temperature", "Minimum temperature",
      "Precipitation", "Vapour pressure deficit", "Relative humidity",
      "Soil moisture"
    ),
    unit = c("\u00b0C", "\u00b0C", "\u00b0C", "%", "Pa", "%", "%"),
    anomaly_type = c(
      "absolute", "absolute", "absolute",
      "pct_normal",
      "absolute", "absolute",
      "pct_normal"
    ),
    era5_name = c(
      "2m_temperature", NA_character_, NA_character_,
      "total_precipitation",
      NA_character_, NA_character_,
      NA_character_
    )
  )
}
