# Task: cd_plot_timeseries() and cd_plot_comparison(): use long_name/unit carried on the input (#93)

#92 lets `cd_anomaly()` input carry `long_name` and `unit`, and `cd_trend()` / `cd_summary()` use them. `cd_plot_timeseries()` still builds its y label only from `cd_variables()` (`R/cd_plot_timeseries.R`, the `var_info` lookup), so for any variable outside the registry it falls back to the bare column name. `cd_plot_comparison()` facets by `cd_variables()$long_name` the same way, falling back to the variable name.

## Decisions taken in this plan (say so if you want the other option)

1. **`cd_plot_comparison()` gets its label from a `long_name` pass-through in `cd_compare()`**, not a new label argument. `cd_compare()` works on raw values, so it passes `long_name` only — exactly `cd_trend()`'s raw-value rule (`R/cd_trend.R:44-49`). No `unit` pass-through: the `difference` unit depends on `method` (value unit vs `%`), and the comparison plot shows no units today. Keeps the chain flowing with no extra argument for the user to fill.
2. **`cd_plot_timeseries()` on raw `value` input (cd_extract output):** `unit` in the registry and on the contract is the *anomaly's* unit, so today `cd_plot_timeseries(ts, variable = "prcp")` labels raw mm as "Precipitation (%)". Rule: on `value` input show the resolved unit only where the resolved `anomaly_type` is not `pct_normal` (for `absolute` and `pct_point_diff` the anomaly unit is the value unit). Fixes the existing mislabel; tmean raw stays "Mean temperature (°C)".
3. Add `series_check()` on the plotted slice — duplicate years currently stack into one bar silently. One line; CLAUDE.md asks every consumer to call the helpers.

## Phase 1: cd_plot_timeseries() resolves labels via meta_resolve()
- [ ] Failing tests in `tests/testthat/test-cd_plot_timeseries.R` (assert `p$labels$y`, ggplot2 4.0.3 keeps it):
  - series outside `cd_variables()` carrying `long_name`/`unit` → `"Mean discharge (%)"`
  - registered `tmean`, no carried columns → `"Mean temperature (°C)"` (regression)
  - `prcp` carried as `anomaly_type = "absolute"` with no `unit` → `"Precipitation"` (no registry unit — the rule #92's review caught)
  - carried `long_name` only, no unit → `"Mean discharge"` (no empty parens)
  - unknown variable, no metadata → `"anomaly"` (fallback to column name)
  - carried `NA` rows fall back to registry
  - two `long_name` values within the plotted series → error (`meta_check`)
  - duplicate year in the plotted series → error (`series_check`)
  - raw `value` input: `prcp` → `"Precipitation"`, `tmean` → `"Mean temperature (°C)"`
- [ ] Replace the `var_info` lookup (`R/cd_plot_timeseries.R`) with `series_check()` + `meta_resolve()` + `meta_check()` on the filtered slice; label = resolved long_name, else `val_col` as today (the issue's "else the column name") plus ` (unit)` when unit non-NA
- [ ] roxygen: document label resolution (point at `?cd_anomaly` contract), `devtools::document()`

## Phase 2: cd_compare() passes long_name; cd_plot_comparison() facets by it
- [ ] Failing tests: `cd_compare()` on input with `long_name` returns a `long_name` column; without it, no column (regression); conflicting `long_name` within a series errors; registered variable with `NA` long_name gets registry name
- [ ] `R/cd_compare.R`: mirror `cd_trend()` — resolve + `meta_check(x, "long_name")` when the column is present, join one `long_name` per variable/period onto `out` (appended last); update `@return`
- [ ] Failing tests in `test-cd_plot_comparison.R`: facet labels (`p$data$param`) use carried `long_name` for an unregistered variable; registry name for `tmean`; variable name when neither
- [ ] `R/cd_plot_comparison.R`: replace `par_labels` lookup with `dplyr::coalesce(meta_resolve(x)$long_name, variable)`; update `@param x` doc
- [ ] Update the `cd_anomaly()` Input contract `long_name` item to name `cd_compare()` and the two plots as readers; `devtools::document()`

## Phase 3: Verify + wrap
- [ ] `devtools::test()` all green; `lintr::lint_package()`; `pkgdown::check_pkgdown()`
- [ ] Render check of vignette plot chunks unaffected (registered vars → same labels) — quick `cd_plot_timeseries(ano, "prcp")` against `inst/vignette-data/peace-fwcp.rds`
- [ ] `/code-check` per commit; `/planning-archive`; `/gh-pr-push` (SRED tag in PR body)

## Validation

- [ ] Tests pass
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
