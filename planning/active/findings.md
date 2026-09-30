# Findings — cd_plot_timeseries(trend =): overlay draws raw-value trend lines on an anomaly plot (#103)

## Issue context

**If we do it:** `cd_plot_timeseries(ano, trend = trn)` draws only the trend lines that belong on the plotted scale. **If we never do:** a trend table that holds both raw-value and anomaly trends of a series draws the raw line (in mm, say) over an anomaly plot, with no warning.

## Problem

The `trend =` overlay in `cd_plot_timeseries()` filters by `variable` and `period` only, and reads `slope`, `intercept` and `trend_start` (`R/cd_plot_timeseries.R:80-101`). The plan review for #97 measured that `cd_plot_timeseries(ano, trend = dplyr::bind_rows(cd_trend(x), cd_trend(ano)))` draws the raw line (slope 10, intercept -19900) on the anomaly plot, and assigns line styles by row order.

This was already possible before #97, but nothing on the trend said which scale it was on. #97 adds `trend_on` (`"value"` / `"anomaly"`) to every `cd_trend()` result, so the overlay can now tell.

## Proposed Solution

- In the overlay, keep only rows where `trend_on` matches the plotted column, or where `trend_on` is absent or `NA` (older tables): `col_or_na(trend, "trend_on") %in% c(NA, val_col)`.
- Test: a mixed raw and anomaly trend table draws only the anomaly line on an anomaly plot.

Depends on #97.

## Errors Encountered

| Error | Resolution |
|-------|------------|
