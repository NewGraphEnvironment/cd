# Findings — cd_summary(): raw-value trends get the registry's anomaly unit (#97)

## Issue context

**If we do it:** `cd_summary()` on a trend of raw values prints a unit that describes those values. **If we never do:** `cd_summary(cd_trend(ts))` on `cd_extract()` output labels a precipitation slope in mm as "%" — and, since #93, the plot beside it reads "Precipitation" with no unit, so plot and table disagree.

## Problem

`cd_trend()` on raw `value` input passes only `long_name` (the carried `unit` is the anomaly's, which does not describe a slope of raw values — `R/cd_trend.R`). But `cd_summary()` then fills `Unit` from `cd_variables()` via `meta_resolve()`, which is the **anomaly** unit: `%` for every `pct_normal` variable (prcp, soil_moisture, swe, snowfall, snowmelt), over slopes in mm or m³/m³.

#93 settled the rule for `cd_plot_timeseries()`: on raw input a unit is shown only where the resolved `anomaly_type` is `absolute` or `pct_point_diff` (the only types whose anomaly unit is the value unit), implemented once as `meta_resolve(x, raw = TRUE)`. `cd_summary()` cannot apply it today because nothing on `cd_trend()` output says whether the trend was on raw values or anomalies.

It fails in both directions. Measured in #93's review, plot label vs `cd_summary(cd_trend(x))$Unit` on raw values:

| series | plot (#93) | `cd_summary()` Unit |
|---|---|---|
| prcp, soil_moisture, swe, snowfall, snowmelt | no unit | `%` — wrong for a raw slope |
| unregistered, `absolute`, carried `m3/s` | `(m3/s)` | `NA` — correct unit lost, because `cd_trend()` drops the column |
| prcp carried as `absolute` with `mm` | `(mm)` | `%` |

The mechanism: three places decide whether the anomaly unit describes raw values — `cd_trend()` (drops the columns), `cd_summary()` (a missing column means "use the registry"), and the plot (`meta_resolve(raw = TRUE)`).

## Proposed Solution

- Simplest: `cd_trend()` on raw input carries `unit` resolved with `meta_resolve(x, raw = TRUE)` (and `anomaly_type`) instead of dropping them, so `cd_summary()` has nothing to re-resolve from the registry. Alternative:

  have `cd_trend()` record which it ran on (a column, or an attribute), and have `cd_summary()` call `meta_resolve(trend, raw = <that>)`.
- Test: `cd_summary(cd_trend(raw prcp))$Unit` is `NA`, and matches `cd_plot_timeseries()`'s label on the same series.

Found by the plan review for #93.

## The issue's "simplest" option is insufficient on its own (2026-09-29)

`meta_resolve()` does `unit = coalesce(carried unit, registry unit)`. For raw prcp,
`meta_resolve(x, raw = TRUE)` gives unit `NA`; carried onto the trend, `cd_summary()`'s
`meta_resolve(trend)` coalesces that `NA` back to the registry's `%`. So a marker of
what the trend ran on is required (`trend_on`), plus carrying the columns so a carried
`m3/s` / `mm` on an `absolute` series survives.

Every existing trend in the vignettes and `inst/vignette-data/*.rds` runs on anomalies,
so reading a missing `trend_on` as anomaly keeps them unchanged — no regeneration.

## Mutation check (2026-09-29)

Each half of the fix restored in a scratch copy, `devtools::test(filter = "cd_trend|cd_summary")`:

| mutant | result |
|---|---|
| `cd_summary()` ignores `trend_on` (`meta_resolve(trend)`) | FAIL 5 |
| `cd_trend()` drops carried `anomaly_type`/`unit` on raw input | FAIL 8 |
| `meta_resolve()` uses `raw[1]` only (not row by row) | FAIL 1 (the `bind_rows` test) |

Full suite: `[ FAIL 0 | WARN 6 | PASS 346 ]`; the 6 warnings are in
`test-cd_plot_comparison.R` and are present on main.

## Errors Encountered

| Error | Resolution |
|-------|------------|
| `diff -q` printed git-diff usage | `diff` is shadowed by a git wrapper in this shell; use `cmp -s` |
