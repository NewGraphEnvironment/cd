#' Plot climate anomaly time series
#'
#' Creates a bar chart of anomalies over time with optional Theil-Sen
#' trend lines. Positive and negative anomalies are colored differently.
#'
#' @param x A tibble from [cd_anomaly()] with columns `variable`,
#'   `period`, `year`, `anomaly`. Also works with [cd_extract()] output
#'   (uses `value` column).
#' @param variable Character. Which variable to plot. Default uses
#'   the first variable in `x`.
#' @param period Character. Which period to plot. Default `"annual"`.
#' @param trend Optional tibble from [cd_trend()] to overlay trend lines.
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

  dat <- x[x$variable == variable & x$period == period, ]
  if (nrow(dat) == 0) {
    rlang::abort(paste0("No data for variable='", variable, "', period='", period, "'"))
  }

  dat$fill <- ifelse(dat[[val_col]] >= 0, "pos", "neg")

  # Variable metadata for labels
  vars <- cd_variables()
  var_info <- vars[vars$variable == variable, ]
  y_label <- if (nrow(var_info) > 0) paste0(var_info$long_name, " (", var_info$unit, ")") else val_col

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
    trn_dat <- trend[trend$variable == variable & trend$period == period, ]
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
