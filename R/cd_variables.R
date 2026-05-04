#' Climate variable metadata
#'
#' Returns a tibble of metadata for the climate variables supported by the
#' cd package. Used internally for unit labels, anomaly type routing, and
#' ERA5-Land API variable names. Covers the seven core climate variables
#' plus eight snow-related variables (four monthly natives, four annual
#' derived) added in v0.2.0.
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{variable}{Short name used throughout the package.}
#'     \item{long_name}{Human-readable label for plots and tables.}
#'     \item{unit}{Measurement unit (degree C, percent, Pa, mm, day, mm/wk).}
#'     \item{anomaly_type}{"absolute" for direct departures (value - baseline,
#'       reported in the variable's native unit), "pct_normal" for
#'       percent-of-normal anomalies (100 * value / baseline - 100, capped),
#'       "pct_point_diff" for departures in percentage points (used for
#'       variables that are already fractions/percentages, e.g. snow cover,
#'       snowfall fraction, where pct-of-normal is meaningless and the
#'       natural delta is value - baseline interpreted as percentage points).}
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
    variable = c(
      "tmean", "tmax", "tmin", "prcp", "vpd", "rh", "soil_moisture",
      "swe", "snowfall", "snowmelt", "snow_cover",
      "swe_max", "snowfall_fraction", "snowmelt_doy_50", "snowmelt_rate_peak"
    ),
    long_name = c(
      "Mean temperature", "Maximum temperature", "Minimum temperature",
      "Precipitation", "Vapour pressure deficit", "Relative humidity",
      "Soil moisture",
      "Snow water equivalent", "Snowfall", "Snowmelt", "Snow cover",
      "Annual peak snow water equivalent", "Snowfall fraction",
      "Day of 50% melt", "Peak weekly melt rate"
    ),
    unit = c(
      "\u00b0C", "\u00b0C", "\u00b0C", "%", "Pa", "%", "%",
      "%", "%", "%", "%",
      "mm", "%", "day", "mm/wk"
    ),
    anomaly_type = c(
      "absolute", "absolute", "absolute",
      "pct_normal",
      "absolute", "absolute",
      "pct_normal",
      "pct_normal", "pct_normal", "pct_normal", "pct_point_diff",
      "absolute", "pct_point_diff", "absolute", "absolute"
    ),
    era5_name = c(
      "2m_temperature", NA_character_, NA_character_,
      "total_precipitation",
      NA_character_, NA_character_,
      NA_character_,
      NA_character_, NA_character_, NA_character_, NA_character_,
      NA_character_, NA_character_, NA_character_, NA_character_
    )
  )
}
