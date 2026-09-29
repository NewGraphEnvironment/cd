## Outcome

`cd_summary()` labelled a trend of raw values with the registry's **anomaly** unit, so a raw
precipitation slope in mm read `%` and a carried `m3/s` on an unregistered `absolute` series
was dropped. `cd_trend()` now writes `trend_on` (`"value"` / `"anomaly"`) on every row and, on
raw input, carries `anomaly_type`/`unit`/`long_name` with the unit resolved by
`meta_resolve(raw = TRUE)`; `cd_summary()` resolves row by row with `raw = trend_on == "value"`,
and `meta_resolve()` now accepts a vector `raw`. The issue's "simplest" option (carry a masked
unit alone) turned out not to work: `meta_resolve()` reads a carried `NA` as "fall back to the
registry", so without a marker the `%` comes straight back. A table without `trend_on` —
including the committed `inst/vignette-data/*.rds`, all anomaly trends — is read as anomaly,
so nothing needed regenerating.

## Measurement

- Plan review checked 126 combinations (4 variables × 6 `anomaly_type` states × 3 `unit` states
  × raw/anomaly) of `cd_summary()$Unit` against the `cd_plot_timeseries()` label: 0
  disagreements on fresh `cd_trend()` output. Round 2 added ~20 adversarial inputs (factors,
  partly-NA columns, grouped, subset `cd_anomaly()` output): 0 disagreements.
- Mutation check, each half of the fix restored in a scratch copy: `cd_summary()` ignoring
  `trend_on` → FAIL 5; `cd_trend()` dropping the raw carry → FAIL 8 (9 after the abort test);
  `meta_resolve()` using `raw[1]` → FAIL 1; a missing `trend_on` read as `"value"` → FAIL 3.
- Full suite `[ FAIL 0 | WARN 6 | PASS 348 ]` (the 6 warnings are pre-existing in
  `test-cd_plot_comparison.R`). `devtools::check()`: 0 errors; the warning and notes are
  pre-existing (#100 for `.Rbuildignore`).

Follow-ups filed from the reviews: #101 (0x0 `cd_trend()` result breaks `cd_summary()`),
#102 (vignettes label a pct_normal prcp slope `mm/yr`), #103 (`cd_plot_timeseries(trend =)`
ignores `trend_on`); the mixed raw/anomaly row case was added to #98.

Closed by: commit a0bee81 / PR (to follow)
