# Task: cd_plot_timeseries(trend =): overlay draws raw-value trend lines on an anomaly plot (#103)


The `trend =` overlay in `cd_plot_timeseries()` filters by `variable` and `period` only, and reads `slope`, `intercept` and `trend_start` (`R/cd_plot_timeseries.R:80-101`). The plan review for #97 measured that `cd_plot_timeseries(ano, trend = dplyr::bind_rows(cd_trend(x), cd_trend(ano)))` draws the raw line (slope 10, intercept -19900) on the anomaly plot, and assigns line styles by row order.

This was already possible before #97, but nothing on the trend said which scale it was on. #97 adds `trend_on` (`"value"` / `"anomaly"`) to every `cd_trend()` result, so the overlay can now tell.

## Phase 1: Test first
- [ ] `tests/testthat/test-cd_plot_timeseries.R`: a mixed table (one `trend_on = "value"` row, one
      `trend_on = "anomaly"` row) on an anomaly plot draws exactly one line layer, and its y values are
      the anomaly trend's (checked via `ggplot2::layer_data()`), not the raw one's
- [ ] Same table on a raw `value` plot draws only the `"value"` line (the filter is symmetric)
- [ ] A table without `trend_on`, and one with `trend_on = NA`, still draws its line (backward compat)
- [ ] Confirm the new tests fail against current code

## Phase 2: Filter the overlay on `trend_on`
- [ ] Replace the row filter with
      `trend[which(trend$variable == variable & trend$period == period & col_or_na(trend, "trend_on") %in% c(NA, val_col)), ]`
      — `which()` also stops an `NA` variable/period trend row becoming an all-NA line, matching how `dat` is filtered a few lines above
- [ ] `@param trend` roxygen: rows whose `trend_on` is not the plotted column are skipped; absent/`NA` `trend_on` is drawn; `devtools::document()`
- [ ] Mutation check: drop the `trend_on` clause in a scratch copy → new tests go red
- [ ] `devtools::test()` full suite, `lintr::lint_package()`, `/code-check`, commit `Fixes #103`

## Out of scope (noted, not changed)
- Line style by row order (first row dashed, rest solid) — the issue mentions it, but once the filter
  removes the other scale's rows it no longer mixes scales; changing it is a separate design choice.
- `cd_summary()` dropping `trend_on` — tracked in #98.

## Validation
- [ ] Tests pass
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion, then `/gh-pr-push`

