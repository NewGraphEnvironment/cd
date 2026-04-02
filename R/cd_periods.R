#' Valid temporal aggregation periods
#'
#' Returns the set of temporal periods supported by the cd package.
#' Used for input validation and iteration in extraction and analysis
#' functions.
#'
#' @param include_monthly Logical. If `TRUE`, appends the 12 calendar
#'   months (Jan, Feb, ..., Dec) to the seasonal periods. Default `FALSE`.
#'
#' @return Character vector of period names.
#'
#' @examples
#' cd_periods()
#' cd_periods(include_monthly = TRUE)
#'
#' @export
cd_periods <- function(include_monthly = FALSE) {
  periods <- c("annual", "winter", "spring", "summer", "fall")
  if (include_monthly) {
    periods <- c(periods, month.abb)
  }
  periods
}
