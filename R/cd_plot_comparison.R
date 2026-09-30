#' Plot time window comparison
#'
#' Creates a dot plot or bar chart showing the mean value for two
#' time windows and their difference. Useful for communicating
#' cumulative change (e.g., "recent decade vs pre-warming").
#'
#' @param x A tibble from [cd_compare()] with columns `variable`,
#'   `period`, `mean_a`, `mean_b`, `difference`, optionally
#'   `long_name`. Facets are labelled by `long_name` where present and
#'   not `NA`, otherwise by [cd_variables()], otherwise by `variable`;
#'   a label shared by several variables gets the variable name appended,
#'   as in [cd_summary()]. Each variable gets its own facet whatever the
#'   labels.
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

  # Facet labels: carried long_name, then cd_variables(), then the name.
  # A label shared by several variables (one long_name, many stations)
  # carries the variable name too, so their facets read differently.
  x$param <- label_disambiguate(
    x$variable,
    dplyr::coalesce(meta_resolve(x)$long_name, as.character(x$variable))
  )
  # Facet on variable and label together, never the label alone, so no
  # label, however it collides, can put two variables in one facet.
  # Levels in label order, as faceting by label gave.
  key <- paste(x$variable, x$param, sep = "\u001f")
  x$facet <- factor(key, levels = unique(key[order(x$param, as.character(x$variable))]))
  facet_labels <- stats::setNames(x$param, key)

  # Reshape for plotting
  plot_dat <- rbind(
    data.frame(
      variable = x$variable,
      param = x$param,
      facet = x$facet,
      period = x$period,
      window = labels["a"],
      value = x$mean_a,
      stringsAsFactors = FALSE
    ),
    data.frame(
      variable = x$variable,
      param = x$param,
      facet = x$facet,
      period = x$period,
      window = labels["b"],
      value = x$mean_b,
      stringsAsFactors = FALSE
    )
  )
  plot_dat$label <- stringr::str_to_title(plot_dat$period)
  plot_dat$window <- factor(plot_dat$window, levels = labels)

  color_vals <- stats::setNames(c("#d73027", "#4575b4"), labels)

  p <- ggplot2::ggplot(plot_dat,
    ggplot2::aes(x = .data$value, y = .data$label,
                 color = .data$window, shape = .data$window)) +
    ggplot2::geom_point(size = 3) +
    ggplot2::scale_color_manual(values = color_vals) +
    ggplot2::facet_wrap(~ .data$facet, scales = "free_x",
                        labeller = ggplot2::as_labeller(facet_labels)) +
    ggplot2::labs(
      x = NULL, y = NULL, color = "Window", shape = "Window",
      title = title
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(legend.position = "bottom")

  p
}
