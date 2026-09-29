# Findings — cd_anomaly() and cd_summary(): accept series outside cd_variables() (#92)

## Issue context

**If we do it:** cd's baseline, anomaly, trend and window-comparison functions work on any annual series in cd's long format, streamflow or stream temperature produced by another package included. Departure is then computed one way everywhere. **If we never do:** a package that wants departure for its own series either gets `NA` from `cd_anomaly()` or writes a second copy of the statistics.

## Problem

`cd_baseline()`, `cd_trend()` and `cd_compare()` already accept any tibble with `variable`, `period`, `year`, `value`. `cd_anomaly()` does not: it looks the anomaly type up in `cd_variables()`, and a variable that is not there returns `NA` without an error.

```r
x <- data.frame(variable = "q_mean", period = "spawn", year = 2000:2001, value = 1:2)
cd_anomaly(x, cd_baseline(x, 2000:2001))
#>   variable period year anomaly anomaly_type unit
#> 1   q_mean  spawn 2000      NA         <NA> <NA>
#> 2   q_mean  spawn 2001      NA         <NA> <NA>
```

`cd_summary()` uses the same lookup for labels and units.

## Proposed Solution

- `cd_anomaly()`: when the input carries `anomaly_type` (and optionally `unit`) columns, use them; otherwise fall back to `cd_variables()`. Raise an error naming any variable whose type cannot be resolved, instead of returning `NA`.
- `cd_summary()`: the same fallback for `long_name` and `unit`.
- Tests on a series that is not in `cd_variables()`, and a documented input contract (`variable`, `period`, `year`, `value`, optional `anomaly_type`/`unit`) so other packages can target it.
- `period` is free text in the consumer functions; confirm nothing downstream assumes `cd_periods()` values.

Scope stays with the statistics. Building per-year values from a daily series over date windows belongs to whichever package produces the series.

## Consumer

wet#25 (flow in date windows at hydrometric stations) produces per-year window values in cd's long format and relies on this issue for `cd_anomaly()`.

## Exploration (2026-09-28)

- `cd_variables()$unit` is the anomaly's unit, not the value's (`prcp` = "%"); the vignette recipe runs `cd_trend()` on `cd_anomaly()` output, so `cd_summary()` reports anomaly units.
- `cd_trend()` rebuilds its output from scratch — no input column survives, so `cd_summary()` can't see input metadata without a pass-through.
- Snapshot of the example-catalog recipe before any change: `cd_summary()` -> Mean temperature / Annual / 0.128 / 10 / 1.3 / °C / 0.592 (example catalog holds only `tmean` annual).

## Errors Encountered

| Error | Resolution |
|-------|------------|
