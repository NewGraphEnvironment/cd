#' Climate variable metadata
#'
#' Returns a tibble of metadata for the climate variables supported by the
#' cd package. Used internally for unit labels, anomaly type routing, which
#' variables can take a percent change, and ERA5-Land API variable names. Covers the seven core climate variables
#' plus eight snow-related variables (four monthly natives, four annual
#' derived) added in v0.2.0.
#'
#' `tmax` and `tmin` are monthly means of the daily maximum and minimum of
#' hourly 2 m temperature, over **local days** at a fixed UTC-8 (Pacific
#' Standard Time, no daylight saving; an hour off in the Mountain Standard
#' Time corner of eastern BC), the same days as [cd_extract_daily()].
#' Before cd#37 the published layers used UTC days, which run from one
#' afternoon peak to the next and read tmax about 0.5-0.8 degrees C high.
#' `tmean`, `vpd`, `rh` and `soil_moisture` average hourly values over UTC
#' months.
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{variable}{Short name used throughout the package.}
#'     \item{long_name}{Human-readable label for plots and tables.}
#'     \item{unit}{Unit of the anomaly (degree C, percent, hPa, day,
#'       mm/wk): percent for every `pct_normal` and `pct_point_diff`
#'       variable, whatever the unit of its values.}
#'     \item{anomaly_type}{"absolute" for direct departures (value - baseline,
#'       reported in the variable's native unit), "pct_normal" for
#'       percent-of-normal anomalies (100 * value / baseline - 100, capped),
#'       "pct_point_diff" for departures in percentage points (used for
#'       variables that are already fractions/percentages, e.g. snow cover,
#'       snowfall fraction, where pct-of-normal is meaningless and the
#'       natural delta is value - baseline interpreted as percentage points).}
#'     \item{pct_change}{`TRUE` where a percent change between two windows
#'       means something, because the values have a real zero. `FALSE` for
#'       temperatures in degree C and the day of 50% melt, whose zero is
#'       arbitrary (a base mean near 0 degree C makes the percent unbounded
#'       and its sign arbitrary), and for variables whose values are already in percent (`rh`,
#'       `snow_cover`, `snowfall_fraction`). Read
#'       by [cd_compare()]. Independent of `anomaly_type`: `vpd` and
#'       `snowmelt_rate_peak` are `absolute` and still take a percent.}
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
      "\u00b0C", "\u00b0C", "\u00b0C", "%", "hPa", "%", "%",
      "%", "%", "%", "%",
      "%", "%", "day", "mm/wk"
    ),
    anomaly_type = c(
      "absolute", "absolute", "absolute",
      "pct_normal",
      "absolute", "absolute",
      "pct_normal",
      "pct_normal", "pct_normal", "pct_normal", "pct_point_diff",
      "pct_normal", "pct_point_diff", "absolute", "absolute"
    ),
    pct_change = c(
      FALSE, FALSE, FALSE,
      TRUE,
      TRUE, FALSE,
      TRUE,
      TRUE, TRUE, TRUE, FALSE,
      TRUE, FALSE, FALSE, TRUE
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
