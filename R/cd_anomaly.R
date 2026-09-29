#' Compute climate anomalies
#'
#' Calculates departure from a baseline for each year. The anomaly type
#' decides the arithmetic: absolute deviation for temperature, VPD, RH,
#' and the annual snow scalars; percent of normal for precipitation, soil
#' moisture, and the monthly snow vars (`swe`, `snowfall`, `snowmelt`);
#' percentage-point difference for variables that are already
#' fractions/percentages (`snow_cover`, `snowfall_fraction`).
#'
#' @section Input contract:
#' `cd_anomaly()` works on any annual series in cd's long format, not
#' only the ERA5-Land variables in [cd_variables()] — streamflow or stream
#' temperature produced by another package included. Required columns:
#'
#' \describe{
#'   \item{`variable`}{Series name.}
#'   \item{`period`}{Free text: a season, a month, or any window the
#'     producer defines (e.g. `"spawn"`). Nothing requires [cd_periods()]
#'     values.}
#'   \item{`year`}{Integer year.}
#'   \item{`value`}{Numeric, one row per variable, period and year —
#'     duplicates (two stations stacked under one `variable`) are an error
#'     in [cd_baseline()], [cd_anomaly()], [cd_compare()] and [cd_trend()],
#'     not pooled.}
#' }
#'
#' Optional columns, resolved row by row; where absent or `NA` they fall
#' back to [cd_variables()]:
#'
#' \describe{
#'   \item{`anomaly_type`}{One of `"absolute"`, `"pct_normal"`,
#'     `"pct_point_diff"`. Required for any variable not in
#'     [cd_variables()]; a variable whose type cannot be resolved is an
#'     error, never a silent `NA`.}
#'   \item{`unit`}{Unit of the **anomaly**, passed through as given — the
#'     same meaning as `cd_variables()$unit`, so `"%"` for a
#'     `pct_normal` series whatever the unit of `value`.}
#'   \item{`long_name`}{Label, carried through to [cd_trend()] and used
#'     by [cd_summary()].}
#' }
#'
#' Each variable and period must resolve to a single `anomaly_type`,
#' `unit` and `long_name`, so for a variable outside [cd_variables()]
#' carry each on every row or on none. A registered variable that carries
#' an `anomaly_type` different from the registry's gets no registry unit. A `pct_normal` series whose baseline mean is `0` (a dry-window
#' minimum flow, say) has no percent of normal: its anomalies come back
#' `NaN` or clamped at `cap_pct`, so use `absolute` for such series.
#'
#' @param x A tibble from [cd_extract()] with columns `variable`,
#'   `period`, `year`, `value`.
#' @param baseline A tibble from [cd_baseline()] with columns
#'   `variable`, `period`, `baseline_mean`.
#' @param cap_pct Numeric. Cap for percent-of-normal anomalies.
#'   Values beyond +/- `cap_pct` are clamped. Default `200`. Only
#'   applies to `pct_normal` variables; `absolute` and
#'   `pct_point_diff` anomalies are not capped.
#'
#' @return A tibble with columns `variable`, `period`, `year`,
#'   `anomaly`, `anomaly_type`, `unit`, and `long_name` when `x` carries
#'   one.
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
#' # Compute anomalies relative to early-period baseline
#' # Absolute deviation for temperature; percent of normal for precipitation
#' bl <- cd_baseline(ts, baseline_years = 1951:1955)
#' cd_anomaly(ts, bl)
#'
#' # Any series in the same long format, e.g. mean discharge over a
#' # spawning window, carrying its own anomaly type and unit
#' q <- data.frame(
#'   variable = "q_mean", period = "spawn", year = 2001:2006,
#'   value = c(12, 9, 14, 7, 6, 8),
#'   anomaly_type = "pct_normal", unit = "%", long_name = "Mean discharge"
#' )
#' cd_anomaly(q, cd_baseline(q, baseline_years = 2001:2003))
#'
#' @export
cd_anomaly <- function(x, baseline, cap_pct = 200) {
  types <- c("absolute", "pct_normal", "pct_point_diff")
  x <- series_check(x)
  meta <- meta_resolve(x)
  x$anomaly_type <- meta$anomaly_type
  x$unit <- meta$unit
  if ("long_name" %in% names(x)) x$long_name <- meta$long_name

  unresolved <- unique(as.character(x$variable[is.na(x$anomaly_type)]))
  if (length(unresolved) > 0) {
    rlang::abort(paste0(
      "Cannot resolve `anomaly_type` for variable(s) not in cd_variables(): ",
      paste(unresolved, collapse = ", "),
      ". Add an `anomaly_type` column (one of ", paste(types, collapse = ", "), ")."
    ))
  }
  invalid <- setdiff(x$anomaly_type, types)
  if (length(invalid) > 0) {
    rlang::abort(paste0(
      "Unsupported `anomaly_type`: ", paste(invalid, collapse = ", "),
      ". Use one of ", paste(types, collapse = ", "), "."
    ))
  }
  meta_check(x)

  cols_out <- c("variable", "period", "year", "anomaly", "anomaly_type", "unit")
  if ("long_name" %in% names(x)) cols_out <- c(cols_out, "long_name")

  x |>
    dplyr::left_join(
      baseline[c("variable", "period", "baseline_mean")],
      by = c("variable", "period")
    ) |>
    dplyr::mutate(
      anomaly = dplyr::case_when(
        .data$anomaly_type %in% c("absolute", "pct_point_diff") ~
          .data$value - .data$baseline_mean,
        .data$anomaly_type == "pct_normal" ~
          pmin(pmax((.data$value / .data$baseline_mean) * 100 - 100, -cap_pct), cap_pct)
      )
    ) |>
    dplyr::select(dplyr::all_of(cols_out))
}

#' A column of `x` as character, or all-`NA` when `x` has no such column
#' @noRd
col_or_na <- function(x, col) {
  if (col %in% names(x)) as.character(x[[col]]) else rep(NA_character_, nrow(x))
}

#' Ungroup `x` and abort on more than one row per variable, period and year.
#' Grouping is dropped because every caller keys by variable and period
#' itself; a grouping by anything else (a station, a polygon) would
#' otherwise pool series silently, which the duplicate check refuses.
#' @noRd
series_check <- function(x) {
  x <- dplyr::ungroup(x)
  keys <- x[c("variable", "period", "year")]
  dup <- duplicated(keys)
  if (any(dup)) {
    shown <- utils::head(unique(paste(keys$variable[dup], keys$period[dup], keys$year[dup], sep = "/")), 5)
    rlang::abort(paste0(
      "More than one row per variable, period and year (",
      sum(dup), " duplicate(s), e.g. ", paste(shown, collapse = ", "),
      "). Series from several sites or AOIs need distinct `variable` names, ",
      "or one call per site."
    ))
  }
  x
}

#' Resolve series metadata row by row: carried column first, then
#' cd_variables(). The registry's unit belongs to the registry's type, so a
#' carried type that overrides it (prcp as "absolute") gets no registry unit.
#' `unit` is the anomaly's unit; `raw = TRUE` keeps it only where that is also
#' the unit of the values (`absolute`, `pct_point_diff`), for callers labelling
#' raw values. The one place these rules live; every consumer calls it.
#' @noRd
meta_resolve <- function(x, raw = FALSE) {
  vars <- cd_variables()
  idx <- match(as.character(x$variable), vars$variable)
  anomaly_type <- dplyr::coalesce(col_or_na(x, "anomaly_type"), vars$anomaly_type[idx])
  unit_registry <- dplyr::if_else(
    anomaly_type == vars$anomaly_type[idx], vars$unit[idx], NA_character_,
    missing = NA_character_
  )
  unit <- dplyr::coalesce(col_or_na(x, "unit"), unit_registry)
  if (raw) {
    unit[!anomaly_type %in% c("absolute", "pct_point_diff")] <- NA_character_
  }
  list(
    anomaly_type = anomaly_type,
    unit = unit,
    long_name = dplyr::coalesce(col_or_na(x, "long_name"), vars$long_name[idx])
  )
}

#' Abort unless each variable/period carries one value of each metadata
#' column present in `x` (NA counts as a value). `x` must be ungrouped.
#' @noRd
meta_check <- function(x, cols = c("anomaly_type", "unit", "long_name")) {
  cols <- intersect(cols, names(x))
  if (length(cols) == 0 || nrow(x) == 0) return(invisible(x))
  n <- dplyr::summarise(
    x,
    dplyr::across(dplyr::all_of(cols), dplyr::n_distinct),
    .by = c("variable", "period")
  )
  msgs <- character(0)
  for (col in cols) {
    bad <- n[[col]] > 1
    if (any(bad)) {
      msgs <- c(msgs, paste0(
        "`", col, "` in ", paste(n$variable[bad], n$period[bad], sep = "/", collapse = ", ")
      ))
    }
  }
  if (length(msgs) > 0) {
    rlang::abort(paste0(
      "More than one value within a series (carry it on every row or none): ",
      paste(msgs, collapse = "; "), "."
    ))
  }
  invisible(x)
}
