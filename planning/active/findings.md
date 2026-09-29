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

## Errors Encountered

| Error | Resolution |
|-------|------------|
