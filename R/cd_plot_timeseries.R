#' Plot climate anomaly time series
#'
#' Creates a bar chart of anomalies over time with optional Theil-Sen
#' trend lines. Positive and negative anomalies are colored differently.
#'
#' The y-axis label is `long_name` and `unit` from `x` where present and
#' not `NA`, otherwise from [cd_variables()] — resolved by the same rules
#' as [cd_summary()] (see the input contract in [cd_anomaly()]) — else the
#' plotted column's name. `unit` is the
#' anomaly's unit, so on raw `value` input it is shown only where the
#' anomaly type is `absolute` or `pct_point_diff`, whose anomaly unit is
#' the unit of the values.
#'
#' @param x A tibble from [cd_anomaly()] with columns `variable`,
#'   `period`, `year`, `anomaly`, optionally `anomaly_type`, `unit` and
#'   `long_name`. Also works with [cd_extract()] output (uses `value`
#'   column). One row per year in the plotted series.
#' @param variable Character. Which variable to plot. Default uses
#'   the first variable in `x`.
#' @param period Character. Which period to plot. Default `"annual"`.
#' @param trend Optional tibble from [cd_trend()] to overlay trend lines.
#'   Only rows whose `trend_on` names the plotted column (`anomaly` or
#'   `value`) are drawn, so a table holding trends on both scales draws
#'   only the one that fits the bars, and warns when none does. Rows with
#'   no `trend_on`, or `NA`, are drawn whatever the plotted column (unlike
#'   [cd_summary()], which reads them as anomaly trends). The earliest
#'   `trend_start` is drawn dashed, later ones solid.
#' @param title Optional plot title.
#' @param colors Named character vector of length 2 for positive/negative
#'   bar colors. Default `c(pos = "#d73027", neg = "#4575b4")`.
#'
#' @return A [ggplot2::ggplot] object.
#'
#' @examples
#' \dontrun{
#' catalog <- cd_catalog()
#' aoi <- sf::st_read("my_aoi.gpkg")
#' ts <- cd_extract(catalog, aoi, variables = "tmean", periods = "annual")
#' bl <- cd_baseline(ts, baseline_years = 1951:1980)
#' ano <- cd_anomaly(ts, bl)
#' trn <- cd_trend(ano, trend_start = c(1951, 1981))
#' cd_plot_timeseries(ano, trend = trn)
#' }
#'
#' @export
cd_plot_timeseries <- function(x,
                               variable = NULL,
                               period = "annual",
                               trend = NULL,
                               title = NULL,
                               colors = c(pos = "#d73027", neg = "#4575b4")) {
  rlang::check_installed("ggplot2",
    reason = "to create time series plots"
  )

  # Determine value column and filter
  val_col <- if ("anomaly" %in% names(x)) "anomaly" else "value"
  if (is.null(variable)) variable <- x$variable[1]

  dat <- x[which(x$variable == variable & x$period == period), ]
  if (nrow(dat) == 0) {
    rlang::abort(paste0("No data for variable='", variable, "', period='", period, "'"))
  }
  dat <- series_check(dat)

  dat$fill <- ifelse(dat[[val_col]] >= 0, "pos", "neg")

  # Labels: carried columns first, then cd_variables(), as in cd_summary()
  meta <- meta_resolve(dat, raw = val_col == "value")
  cols_meta <- intersect(c("anomaly_type", "unit", "long_name"), names(dat))
  for (col in cols_meta) dat[[col]] <- meta[[col]]
  meta_check(dat, cols_meta)
  y_label <- dplyr::coalesce(meta$long_name[1], val_col)
  if (!is.na(meta$unit[1])) y_label <- paste0(y_label, " (", meta$unit[1], ")")

  p <- ggplot2::ggplot(dat, ggplot2::aes(x = .data$year, y = .data[[val_col]], fill = .data$fill)) +
    ggplot2::geom_col(width = 0.8, show.legend = FALSE) +
    ggplot2::scale_fill_manual(values = colors) +
    ggplot2::labs(
      x = NULL, y = y_label,
      title = title
    ) +
    ggplot2::theme_minimal(base_size = 12)

  # Overlay trend lines
  if (!is.null(trend)) {
    trn_dat <- trend[which(trend$variable == variable & trend$period == period), ]
    # Only trends on the plotted scale; a table without trend_on (hand-built, or
    # from before #97) is drawn on either (#103)
    on_scale <- col_or_na(trn_dat, "trend_on") %in% c(NA, val_col)
    if (nrow(trn_dat) > 0 && !any(on_scale)) {
      rlang::warn(paste0(
        "No trend for variable='", variable, "', period='", period,
        "' is on the plotted scale (trend_on = '", val_col, "'); none drawn."
      ))
    }
    trn_dat <- trn_dat[on_scale, ]
    # Earliest start first, so it takes the dashed line
    if (nrow(trn_dat) > 1) trn_dat <- trn_dat[order(trn_dat$trend_start), ]
    for (i in seq_len(nrow(trn_dat))) {
      slope <- trn_dat$slope[i]
      intercept <- trn_dat$intercept[i]
      start_yr <- trn_dat$trend_start[i]
      end_yr <- max(dat$year)

      line_dat <- data.frame(
        year = c(start_yr, end_yr),
        y = c(intercept + slope * start_yr, intercept + slope * end_yr)
      )

      lty <- if (i == 1) "dashed" else "solid"
      p <- p + ggplot2::geom_line(
        data = line_dat,
        ggplot2::aes(x = .data$year, y = .data$y),
        inherit.aes = FALSE,
        linewidth = 0.8,
        linetype = lty
      )
    }
  }

  p
}
