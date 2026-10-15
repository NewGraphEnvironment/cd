# Code-check round 1: #138 (branch 138-cd-compare-method-pct-change-returns-a-p vs main)

## Findings

- **[fragile]** R/cd_compare.R:123 — the guard joins the resolved `pct_change` back onto `out` with
  `match(paste(out$variable, out$period), paste(ok$variable, ok$period))`. `paste()`'s space separator
  is ambiguous, so variable `"a b"`/period `"c"` and variable `"a"`/period `"b c"` share the key `"a b c"`,
  and both rows take the first one's flag. Reproduced in a temp copy: a series carrying
  `pct_change = TRUE` beside a colliding one carrying `FALSE` got `difference = NA` and was named in the
  warning (the reverse order would let a blocked series keep its percent). Needs a space in both an
  off-registry variable name and a custom season/period name, so unlikely, but it fails silently and
  the package already guards the same shape elsewhere (`cd_plot_comparison()` keys with `"\u001f"`).
  Fix: key with `dplyr::left_join(out, ok, by = c("variable", "period"))`, or `paste(..., sep = "\u001f")`.

## Checked, no issue

- Registry `pct_change` vector aligns with `variable` order (15 entries; FALSE set = tmean, tmax, tmin,
  rh, snow_cover, snowfall_fraction, snowmelt_doy_50).
- `meta_resolve()` never returns NA for `pct_change` (final fallback is `!anomaly_type %in% ...`), so
  `which(!ok)` cannot fail toward pass through an NA; zero-row input resolves to `logical(0)` cleanly.
- `$`/`[[` uses are guarded by `%in% names(x)` or exact `[[`, so no partial match on a data.frame.
- Other `meta_resolve()` callers (cd_trend, cd_summary, cd_plot_timeseries, cd_plot_comparison,
  cd_anomaly) read only named elements; the new list element reaches none of them, and a numeric
  carried `pct_change` is ignored there. cd_anomaly's `cols_out` drops the column.
- data-raw vignette scripts call `pct_change` only on pct_normal variables; northern_bc uses mean_diff
  for temperature/doy/fraction, so no regen changes.
- test-cd_compare.R (91), test-cd_variables.R (45), test-cd_anomaly.R (63): 0 failed, 0 error, 0 skipped
  under NOT_CRAN=true in a temp copy.
