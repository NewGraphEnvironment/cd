# Task: cd_anomaly() and cd_summary(): accept series outside cd_variables() instead of returning NA (#92)

`cd_baseline()`, `cd_trend()` and `cd_compare()` already accept any tibble with `variable`, `period`, `year`, `value`. `cd_anomaly()` does not: it looks the anomaly type up in `cd_variables()`, and a variable that is not there returns `NA` without an error.

```r
x <- data.frame(variable = "q_mean", period = "spawn", year = 2000:2001, value = 1:2)
cd_anomaly(x, cd_baseline(x, 2000:2001))
#>   variable period year anomaly anomaly_type unit
#> 1   q_mean  spawn 2000      NA         <NA> <NA>
#> 2   q_mean  spawn 2001      NA         <NA> <NA>
```

`cd_summary()` uses the same lookup for labels and units.

Decisions taken at the plan gate:
- Input `unit` = the **anomaly's** unit, passed through verbatim (same meaning as `cd_variables()$unit`).
- `cd_trend()` passes metadata columns through, so the chain needs no caller-side join.

Findings shaping it:
- `cd_baseline()`, `cd_compare()` are already registry-free; `cd_trend()` drops all non-stat columns.
- `period` free-text audit: only `cd_extract()` validates against `cd_periods()`; `cd_plot_timeseries(period = "annual")` is a default (clear abort on miss); `cd_summary`/`cd_plot_comparison` just `str_to_title()`. Nothing downstream assumes `cd_periods()` values.
- `cd_plot_timeseries()` / `cd_plot_comparison()` already fall back to the column name / variable name — no NA, out of scope.
- `rlang::abort()` is the package's error idiom.

## Phase 1: Tests first (fail on main)
- [x] `test-cd_anomaly.R`: `q_mean`/`spawn` series with `anomaly_type = "pct_normal"`, `unit = "%"` computes anomalies and passes unit through
- [x] `test-cd_anomaly.R`: unregistered variable with no `anomaly_type` errors, message names the variable (the #92 repro)
- [x] `test-cd_anomaly.R`: invalid `anomaly_type` value errors naming it; per-row NA in the column falls back to `cd_variables()`; input column overrides registry for a registered variable
- [x] `test-cd_anomaly.R`: `long_name` passes through when present; output shape unchanged when absent (existing expect_named stays)
- [x] `test-cd_trend.R`: `anomaly_type`/`unit`/`long_name` carried through when present; shape unchanged on plain `value` input
- [x] `test-cd_summary.R`: trend with `long_name`/`unit` columns uses them; unregistered variable with none → `Parameter` = variable name, `Unit` = NA (label is cosmetic — no error); registered variables unchanged
- [x] End-to-end test: non-ERA5 series with `period = "spawn"` through `cd_baseline → cd_anomaly → cd_trend → cd_summary` (and `cd_compare`)

## Phase 2: cd_anomaly()
- [x] Resolve per row: `dplyr::coalesce(input anomaly_type, registry lookup)`; same for `unit`
- [x] Abort listing variables with unresolved type; abort on types outside `absolute`/`pct_normal`/`pct_point_diff`
- [x] Carry `long_name` through when present in `x`
- [x] Roxygen: "Input contract" section (`variable`, `period`, `year`, `value` required; optional `anomaly_type`, `unit` = anomaly unit, `long_name`); runnable example on a non-ERA5 series

## Phase 3: cd_trend() and cd_summary()
- [x] `cd_trend()`: carry `anomaly_type`, `unit`, `long_name` (first value per variable/period) when present
- [x] `cd_summary()`: coalesce trend columns with `cd_variables()`; `Parameter` falls back to `variable`
- [x] Roxygen: `@param`/`@return` updated, `@seealso` to the cd_anomaly contract
- [x] `devtools::document()`, `lintr::lint_package()`, `pkgdown::check_pkgdown()`

## Added during code-check (rounds 1–3)
- [x] Registry unit used only when the resolved type is the registry's type (R1, then R2 in cd_summary)
- [x] Shared `meta_resolve()` / `meta_check()` so every caller applies the same rules (R2 mechanism)
- [x] `series_check()`: ungroup + one row per variable/period/year in cd_baseline, cd_anomaly, cd_compare, cd_trend (R1 grouped input; R3 found the plain ungroup pooled stacked stations silently)
- [x] cd_trend resolves before checking (R3)

## Phase 4: Verify, release notes, PR
- [x] Full `devtools::test()`; mutation check — revert the abort to NA and confirm the Phase 1 error test goes red
- [x] Vignette recipe (`cd_anomaly → cd_trend → cd_summary`) output unchanged for ERA5 variables (compare `cd_summary()` on example catalog before/after)
- [ ] `/code-check` per commit; atomic commits `Fixes #92` on the last
- [ ] `/planning-archive`, `/gh-pr-push` (SRED: `Relates to NewGraphEnvironment/sred-2025-2026#23`); version bump/NEWS left to `/gh-pr-merge` (minor: NA → error is a behaviour change)

## Validation
- [ ] Tests pass
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion

