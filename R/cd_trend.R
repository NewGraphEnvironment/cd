#' Compute trend statistics
#'
#' Runs Mann-Kendall significance test and Theil-Sen slope estimator
#' on time series data for each variable, period, and trend start year.
#'
#' @param x A tibble from [cd_extract()] or [cd_anomaly()] with columns
#'   `variable`, `period`, `year`, and either `value` or `anomaly`.
#' @param trend_start Integer vector of start years for trend windows.
#'   Default `c(1950, 1980)`.
#'
#' @return A tibble with columns `variable`, `period`, `trend_start`,
#'   `slope`, `intercept`, `mk_pvalue`, `n_years`.
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
#' # Trend on raw values
#' cd_trend(ts, trend_start = 1951)
#'
#' # Also works on anomalies — uses 'anomaly' column automatically
#' bl <- cd_baseline(ts, baseline_years = 1951:1955)
#' ano <- cd_anomaly(ts, bl)
#' cd_trend(ano, trend_start = 1951)
#'
#' @export
cd_trend <- function(x, trend_start = c(1950, 1980)) {
  rlang::check_installed(c("Kendall", "zyp"),
    reason = "to compute Mann-Kendall and Theil-Sen trend statistics"
  )

  # Use anomaly column if present, otherwise value
  val_col <- if ("anomaly" %in% names(x)) "anomaly" else "value"

  combos <- expand.grid(
    variable = unique(x$variable),
    period = unique(x$period),
    trend_start = trend_start,
    stringsAsFactors = FALSE
  )

  results <- lapply(seq_len(nrow(combos)), function(i) {
    v <- combos$variable[i]
    p <- combos$period[i]
    ts <- combos$trend_start[i]

    dat <- x[x$variable == v & x$period == p & x$year >= ts, ]
    if (nrow(dat) < 3) return(NULL)

    y <- dat[[val_col]]
    yr <- dat$year

    mk <- Kendall::MannKendall(y)
    sen <- zyp::zyp.sen(y ~ yr, data.frame(y = y, yr = yr))

    tibble::tibble(
      variable = v,
      period = p,
      trend_start = ts,
      slope = round(sen$coefficients[2], 4),
      intercept = round(sen$coefficients[1], 4),
      mk_pvalue = round(mk$sl[1], 4),
      n_years = nrow(dat)
    )
  })

  dplyr::bind_rows(results)
}
