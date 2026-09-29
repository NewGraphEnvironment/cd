# Code-check round 1 — #97 (staged diff)

## Clean

No issues found.

What was checked (scratch copy, repo untouched):

- `NOT_CRAN=true devtools::test(filter = "cd_trend|cd_summary|cd_plot_timeseries|cd_compare|cd_anomaly")`:
  `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 193 ]` (ggplot2 4.0.3, dplyr 1.2.1).
- `meta_resolve()` vector `raw`: every caller passes either a scalar (`val_col == "value"`, default
  `FALSE`) or `col_or_na(...) %in% "value"`, which is always length `nrow` and never `NA`, so
  `rep_len()` never recycles a mismatched vector and the mask never sees `NA`. Zero rows gives
  `logical(0)`, fine.
- Masking is idempotent: `cd_trend()` masks on raw input, `cd_summary()` re-coalesces the registry
  unit and masks again by `trend_on`, landing on the same `NA`. Probed raw prcp carrying an all-`NA`
  `anomaly_type` column, and a `data.frame` with factor `variable` and all-`NA` `unit`: both give
  `Unit` `NA`, consistent with the plot rule.
- Back-compat: a trend without `trend_on` gives `NA %in% "value"` = `FALSE`, so it is read as
  anomaly, as intended. `bind_rows()` of old and new trends fills `NA`, so it is also read as anomaly.
- Consumers: `cd_compare()` and `cd_plot_comparison()` are unchanged (scalar default). `cd_plot_timeseries()`
  reads only `slope`/`intercept`/`trend_start` from `trend`. Vignettes and `data-raw/*_vignette_data.R`
  run `cd_trend()` only on anomalies and access trend columns by name (`trn[..., c("variable","period","mk_pvalue")]`,
  segment builders), so the new `trend_on` column and its position break nothing. The committed rds
  lacks `trend_on` and resolves as anomaly, so it is unchanged.
- Behaviour change, per contract rather than a bug: raw input carrying `anomaly_type`/`unit` that
  varies within one series now aborts in `cd_trend()` through `meta_check()`, as it already did in
  `cd_plot_timeseries()`. `cd_extract()` output carries none of these columns, so the standard chain
  is unaffected.
- Test parser `plot_unit()`: no `cd_variables()$long_name` contains a parenthesis, so the `" (unit)"`
  regex cannot misread a long name as a unit.

Outside the diff (pre-existing, not introduced here): `cd_summary()` on a zero-row `cd_trend()` result
(every series shorter than 3 years) errors with `Column 'period' not found`, because `bind_rows()` of
all-`NULL` returns a 0x0 tibble.
