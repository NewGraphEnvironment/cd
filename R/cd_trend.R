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
#'   `slope`, `intercept`, `mk_pvalue`, `n_years`, and `trend_on`
#'   (`"value"` or `"anomaly"`, the column the trend was run on). When
#'   `x` carries them, `anomaly_type`, `unit` and `long_name` are passed
#'   through — see the input contract in [cd_anomaly()]. `unit` is the
#'   anomaly's unit, so on raw values it is kept only for `absolute` and
#'   `pct_point_diff` series, where it is also the unit of the values.
#'   [cd_summary()] reads them.
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

  x <- series_check(x)
  # Use anomaly column if present, otherwise value
  val_col <- if ("anomaly" %in% names(x)) "anomaly" else "value"
  cols_meta <- intersect(c("anomaly_type", "unit", "long_name"), names(x))
  # On raw values the anomaly's unit describes the slope only for absolute and
  # pct_point_diff series; trend_on tells cd_summary() which rule applies (#97)
  meta <- meta_resolve(x, raw = val_col == "value")
  for (col in cols_meta) x[[col]] <- meta[[col]]
  meta_check(x, cols_meta)

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

    out <- tibble::tibble(
      variable = v,
      period = p,
      trend_start = ts,
      slope = round(sen$coefficients[2], 4),
      intercept = round(sen$coefficients[1], 4),
      mk_pvalue = round(mk$sl[1], 4),
      n_years = nrow(dat),
      trend_on = val_col
    )
    for (col in cols_meta) out[[col]] <- as.character(dat[[col]][1])
    out
  })

  dplyr::bind_rows(results)
}
