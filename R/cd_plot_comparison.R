#' Plot time window comparison
#'
#' Creates a dot plot or bar chart showing the mean value for two
#' time windows and their difference. Useful for communicating
#' cumulative change (e.g., "recent decade vs pre-warming").
#'
#' @param x A tibble from [cd_compare()] with columns `variable`,
#'   `period`, `mean_a`, `mean_b`, `difference`.
#' @param title Optional plot title.
#' @param labels Named character vector of length 2 for window labels.
#'   Default `c(a = "Recent", b = "Historical")`.
#'
#' @return A [ggplot2::ggplot] object.
#'
#' @examples
#' \dontrun{
#' ts <- cd_extract(catalog, aoi)
#' cmp <- cd_compare(ts, window_a = 2015:2025, window_b = 1951:1980)
#' cd_plot_comparison(cmp, labels = c(a = "2015-2025", b = "1951-1980"))
#' }
#'
#' @export
cd_plot_comparison <- function(x,
                               title = NULL,
                               labels = c(a = "Recent", b = "Historical")) {
  rlang::check_installed("ggplot2",
    reason = "to create comparison plots"
  )

  vars <- cd_variables()
  par_labels <- stats::setNames(vars$long_name, vars$variable)

  # Reshape for plotting
  plot_dat <- rbind(
    data.frame(
      variable = x$variable,
      period = x$period,
      window = labels["a"],
      value = x$mean_a,
      stringsAsFactors = FALSE
    ),
    data.frame(
      variable = x$variable,
      period = x$period,
      window = labels["b"],
      value = x$mean_b,
      stringsAsFactors = FALSE
    )
  )

  plot_dat$param <- ifelse(
    plot_dat$variable %in% names(par_labels),
    unname(par_labels[plot_dat$variable]),
    plot_dat$variable
  )
  plot_dat$label <- stringr::str_to_title(plot_dat$period)
  plot_dat$window <- factor(plot_dat$window, levels = labels)

  color_vals <- stats::setNames(c("#d73027", "#4575b4"), labels)

  p <- ggplot2::ggplot(plot_dat,
    ggplot2::aes(x = .data$value, y = .data$label,
                 color = .data$window, shape = .data$window)) +
    ggplot2::geom_point(size = 3) +
    ggplot2::scale_color_manual(values = color_vals) +
    ggplot2::facet_wrap(~ .data$param, scales = "free_x") +
    ggplot2::labs(
      x = NULL, y = NULL, color = "Window", shape = "Window",
      title = title
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(legend.position = "bottom")

  p
}
