#' Format trend results as a reporting table
#'
#' Joins trend statistics with variable metadata and computes Total
#' Change (slope x years). Returns a tibble ready for
#' [DT::datatable()] or [gt::gt()].
#'
#' Labels and units come from `long_name` and `unit` columns on `trend`
#' where present and not `NA` (carried by [cd_trend()] from the input
#' contract in [cd_anomaly()]), otherwise from [cd_variables()] — by
#' the same rules as [cd_anomaly()], so a registered variable trended
#' under a different `anomaly_type` gets no registry unit. A variable
#' found in neither is labelled by its name, with no unit. On a trend of
#' raw values (`trend_on == "value"`) `Unit` is shown only for `absolute`
#' and `pct_point_diff` series — the anomaly unit of a `pct_normal`
#' series is `"%"`, which does not describe a slope in mm — so it agrees
#' with the axis label of [cd_plot_timeseries()] on the same series.
#'
#' Rows are kept distinguishable. A `long_name` shared by several variables
#' (one label on many stations) gets the variable name appended, as in
#' [cd_plot_comparison()]: `"Mean discharge (q_site1)"`. A table holding both
#' raw-value and anomaly trends, such as
#' `dplyr::bind_rows(cd_trend(x), cd_trend(ano))`, gains a `Trend on` column
#' (`"Value"` or `"Anomaly"`; a missing or `NA` `trend_on` reads as
#' `"Anomaly"`). A table on one scale has no such column. Likewise a table
#' holding several trend windows, such as
#' `cd_trend(x, trend_start = c(1951, 1981))`, gains a `Start` column: the
#' start year asked of [cd_trend()], not the first year with data. It is
#' added when the table as a whole holds more than one `trend_start` (an `NA`
#' counts as one), so binding a 1991 trend of one station to a 2000 trend of
#' another adds it too; a table with one window, or no `trend_start` column,
#' has none. All three are decided within one call, so summaries
#' bound together (one per region, each with its `region_name`) can differ in
#' suffixes, and a `Trend on` or `Start` column present in only some of them
#' is `NA` for the rest.
#'
#' @param trend A tibble from [cd_trend()].
#' @param region_name Optional character label for the AOI. If provided,
#'   adds a `Region` column.
#'
#' @return A tibble with columns `Parameter`, `Period`, `Slope`, `Years`,
#'   `Total Change`, `Unit`, `p-value`, and optionally `Region`. When `trend`
#'   mixes raw-value and anomaly trends, a `Trend on` column follows `Period`.
#'   When it holds more than one `trend_start`, a `Start` column follows
#'   `Period` (or `Trend on`).
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
#' trn <- cd_trend(ts, trend_start = 1951)
#'
#' # Reporting table with Total Change = slope * years
#' cd_summary(trn)
#'
#' # Add region label for multi-AOI reports
#' cd_summary(trn, region_name = "Example AOI")
#'
#' # Two trend windows: a Start column says which row is which
#' cd_summary(cd_trend(ts, trend_start = c(1951, 1956)))
#'
#' @export
cd_summary <- function(trend, region_name = NULL) {
  trend <- dplyr::ungroup(trend)
  meta <- meta_resolve(trend, raw = col_or_na(trend, "trend_on") %in% "value")
  labels_param <- label_disambiguate(
    trend$variable,
    dplyr::coalesce(meta$long_name, as.character(trend$variable))
  )
  labels_unit <- meta$unit

  out <- trend |>
    dplyr::mutate(
      Parameter = .env$labels_param,
      Period = stringr::str_to_title(.data$period),
      Slope = round(.data$slope, 3),
      Years = .data$n_years,
      `Total Change` = round(.data$slope * .data$n_years, 1),
      Unit = .env$labels_unit,
      `p-value` = .data$mk_pvalue
    ) |>
    dplyr::select("Parameter", "Period", "Slope", "Years", "Total Change", "Unit", "p-value")

  # A table mixing raw-value and anomaly trends of one series would otherwise
  # give rows that differ by Unit at most. Same rule as Unit: only "value" is
  # a raw-value trend; anything else, NA included, reads as anomaly.
  on_value <- col_or_na(trend, "trend_on") %in% "value"
  if (length(unique(on_value)) > 1) {
    out <- tibble::add_column(
      out, `Trend on` = dplyr::if_else(on_value, "Value", "Anomaly"), .after = "Period"
    )
  }

  # Trends over several windows (cd_trend(x, trend_start = c(1951, 1981)))
  # otherwise differ only by Years. An NA start counts as a window of its own.
  if (length(unique(col_or_na(trend, "trend_start"))) > 1) {
    out <- tibble::add_column(
      out, Start = trend$trend_start,
      .after = if ("Trend on" %in% names(out)) "Trend on" else "Period"
    )
  }

  if (!is.null(region_name)) {
    out$Region <- region_name
  }

  out
}
