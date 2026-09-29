# Findings — cd_plot_timeseries() and cd_plot_comparison(): use long_name/unit carried on the input (#93)

## Issue context

**If we do it:** a series from another package (streamflow, stream temperature) plots with the same label and unit that `cd_summary()` prints. **If we never do:** the plot's y-axis reads `anomaly` while the table beside it reads "Mean discharge (%)".

## Problem

#92 lets `cd_anomaly()` input carry `long_name` and `unit`, and `cd_trend()` / `cd_summary()` use them. `cd_plot_timeseries()` still builds its y label only from `cd_variables()` (`R/cd_plot_timeseries.R`, the `var_info` lookup), so for any variable outside the registry it falls back to the bare column name. `cd_plot_comparison()` facets by `cd_variables()$long_name` the same way, falling back to the variable name.

## Proposed Solution

- `cd_plot_timeseries()`: take `long_name` / `unit` from `x` when present and not `NA`, else `cd_variables()`, else the column name — the same order `cd_summary()` uses. Call the internal `meta_resolve()` (R/cd_anomaly.R, from #92) rather than re-implementing the lookup: it also keeps a registry unit off a variable carried under a different `anomaly_type`, a rule a second copy would miss (it was missed once in #92's review).
- `cd_plot_comparison()`: the same for facet labels. `cd_compare()` output carries no metadata today, so this needs either a pass-through there or a label argument; decide in the plan.
- Tests on a series outside `cd_variables()`.



## Plan-mode exploration (2026-09-28)

- `cd_variables()$unit` is the **anomaly** unit (prcp = `%`, pct_normal), so `cd_plot_timeseries()` on raw `value` input currently labels raw prcp mm as "Precipitation (%)". Hence decision 2 in task_plan.
- `cd_compare()` output carries no metadata; `cd_trend()` passes only `long_name` on raw-value input (`R/cd_trend.R:44-49`) — the rule mirrored for `cd_compare()`.
- ggplot2 4.0.3 installed: `p$labels$y` still returns a `labs()`-set label, so tests assert on it.

## Review triage (Phase 1 code-check rounds 1-3 + plan review)

- Plan review: `review-plan.md`. Round findings: `review-round{1,2,3}.md`.
- Round 1 Clean. Rounds 2 and 3 + plan review #5: `x[lgl, ]` on NA `variable`/`period` makes all-NA rows -> wrong label (first row) or a false duplicate error. Fixed: `which()`. Mutant (revert) -> 1 test red.
- Round 3 mechanism + plan review #3/#4: three places decide whether the anomaly unit describes raw values (cd_trend drops, cd_summary re-fills from registry, plot inline rule). Rule moved into `meta_resolve(x, raw = TRUE)`: unit kept only for `absolute`/`pct_point_diff`; unresolved type drops a carried unit. Mutant -> 2 tests red. cd_trend/cd_summary alignment filed as cd#97 (out of #93's scope: changes cd_summary output for raw trends).
- Plan review #1: shared long_name merged facets in cd_plot_comparison (probed 2 vars -> 1 facet). Fixed in Phase 2 by appending ` (variable)` to shared labels.
- Plan review #2: vpd registry unit "Pa", data hPa. Filed cd#96.
- Plan review #6: behaviour changes for existing callers go in the PR body (NEWS at merge).
- Pre-existing, not touched: `labels["a"]` rownames warning in cd_plot_comparison; `cd_plot_comparison(cmp[0,])` errors.

## Errors Encountered

| Error | Resolution |
|-------|------------|
| First mutation run PASSed: `git checkout -- .` inside the scratch copy reset its tests to HEAD, and the sed pattern did not match | Copy current R/ and tests/ into the copy, no checkout; substitute with python `str.replace`; assert the fix line is gone before running |
