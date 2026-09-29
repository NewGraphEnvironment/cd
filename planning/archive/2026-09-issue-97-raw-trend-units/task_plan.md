# Task: cd_summary(): raw-value trends get the registry's anomaly unit (#97)

`cd_trend()` on raw `value` input passes only `long_name` (the carried `unit` is the anomaly's, which does not describe a slope of raw values — `R/cd_trend.R`). But `cd_summary()` then fills `Unit` from `cd_variables()` via `meta_resolve()`, which is the **anomaly** unit: `%` for every `pct_normal` variable (prcp, soil_moisture, swe, snowfall, snowmelt), over slopes in mm or m³/m³.

#93 settled the rule for `cd_plot_timeseries()`: on raw input a unit is shown only where the resolved `anomaly_type` is `absolute` or `pct_point_diff` (the only types whose anomaly unit is the value unit), implemented once as `meta_resolve(x, raw = TRUE)`. `cd_summary()` cannot apply it today because nothing on `cd_trend()` output says whether the trend was on raw values or anomalies.

It fails in both directions. Measured in #93's review, plot label vs `cd_summary(cd_trend(x))$Unit` on raw values:

| series | plot (#93) | `cd_summary()` Unit |
|---|---|---|
| prcp, soil_moisture, swe, snowfall, snowmelt | no unit | `%` — wrong for a raw slope |
| unregistered, `absolute`, carried `m3/s` | `(m3/s)` | `NA` — correct unit lost, because `cd_trend()` drops the column |
| prcp carried as `absolute` with `mm` | `(mm)` | `%` |

The mechanism: three places decide whether the anomaly unit describes raw values — `cd_trend()` (drops the columns), `cd_summary()` (a missing column means "use the registry"), and the plot (`meta_resolve(raw = TRUE)`).

## Finding that shapes the design

The issue's "simplest" option (carry `unit` resolved with `raw = TRUE`) **does not work
on its own**: for raw prcp that carried unit is `NA`, and `meta_resolve()` treats a
carried `NA` as "fall back to the registry" — so `cd_summary()` would still print `%`.
A marker saying what the trend ran on is required; the issue's alternative is the fix,
combined with carrying the columns.

**Design (the one schema choice — edit here if you want it different):** `cd_trend()`
adds a column `trend_on` (`"value"` / `"anomaly"`) on every output, placed after
`n_years`. A column, not an attribute, because the vignettes and data-raw scripts
`bind_rows`/subset trend tables, which drop attributes. A trend table without the
column (hand-built, or the committed `inst/vignette-data/*.rds`, all on anomalies) is
read as anomaly — today's behaviour, so no data regeneration.

## Phase 1: Tests first (red)

- [x] `test-cd_trend.R`: raw input returns `trend_on = "value"`, anomaly input `"anomaly"`; update the three `expect_named()` calls (lines 11, 78, 96)
- [x] `test-cd_trend.R`: raw input carrying `anomaly_type`/`unit` passes them through, `unit` resolved with `raw = TRUE` (the #92 test at line 88 changes from "not carried" to "carried, masked")
- [x] `test-cd_summary.R`: the issue's three rows through the chain — raw prcp → `Unit` `NA`; unregistered `absolute` + `m3/s` → `"m3/s"`; prcp carried `absolute` + `mm` → `"mm"`
- [x] `test-cd_summary.R`: parity — for each of those series, `cd_summary()$Unit` agrees with the unit in `cd_plot_timeseries()`'s y label (`p$labels$y`)
- [x] `test-cd_summary.R`: a `bind_rows()` of a raw and an anomaly trend of prcp resolves per row (`NA`, `"%"`); a trend without `trend_on` keeps today's registry behaviour (existing tests cover)

## Phase 2: Implementation

- [x] `R/cd_anomaly.R` `meta_resolve()`: accept `raw` as a vector (`rep_len(raw, nrow)`, mask `raw & !type %in% c("absolute","pct_point_diff")`); scalar callers unchanged
- [x] `R/cd_trend.R`: on raw input carry `anomaly_type`, `unit`, `long_name` (those present) with `unit` from `meta_resolve(x, raw = TRUE)`; add `trend_on`
- [x] `R/cd_summary.R`: `meta_resolve(trend, raw = col_or_na(trend, "trend_on") %in% "value")`
- [x] Restore the bug (drop the `raw =` in `cd_summary()`, and separately the carry in `cd_trend()`) and confirm the new tests go red

## Phase 3: Docs

- [x] `cd_trend()` `@return`: `trend_on`, and the raw-input carry (unit describes the values, only for `absolute`/`pct_point_diff`)
- [x] `cd_summary()` description: on raw-value trends, unit only where it describes the values — same rule as `cd_plot_timeseries()`
- [x] `?cd_anomaly` contract `unit` item: add `cd_summary()` to the "on raw values" sentence; `meta_resolve()` comment for vector `raw`
- [x] `devtools::document()`, `lintr::lint_package()`, full `devtools::test()`, `devtools::check()`

## Validation

- [x] Tests pass
- [x] `/code-check` clean on each commit
- [x] PWF checkboxes match landed work
- [x] `/planning-archive` on completion
