# Review round 2 — #97 (`trend_on`, raw-value units in `cd_summary()`)

## Clean

No bugs, security issues or data-loss risks found in the diff.

## What was tried (all in a scratch copy, repo untouched)

Scoped suite (`cd_trend|cd_summary|cd_plot_timeseries`): `[ FAIL 0 | PASS 103 ]`.

### (a) Adversarial table-vs-plot parity: `cd_summary(cd_trend(x))$Unit` vs the unit parsed from `cd_plot_timeseries(x)$labels$y`

Every case agreed or both errored with the same `meta_check()` message:

| input | summary | plot |
|---|---|---|
| prcp, `anomaly_type`/`unit` as factors (absolute, mm) | mm | mm |
| factor `variable` (prcp / tmean) | NA / °C | NA / °C |
| tmean, carried `unit = "K"`, no type | K | K |
| prcp, carried `unit = "mm"`, no type (registry pct_normal) | NA | NA |
| prcp, `anomaly_type` NA on one row only | error (meta_check) | same error |
| q, absolute, `unit` NA on one row only | error (meta_check) | same error |
| tmean, `unit` NA on one row only | °C | °C |
| snow_cover raw; snow_cover ppd with `unit = "pp"` | % ; pp | % ; pp |
| prcp typed pct_point_diff, no unit | NA | NA |
| grouped tmean | °C | °C |
| unregistered, invalid type "relative" | NA | NA |
| `unit = ""` | "" | "" |
| anomaly prcp (absolute, mm); same without `unit` col; without `anomaly_type` col | mm; NA; mm | mm; NA; mm |
| anomaly prcp default; without `unit` col; rows subset | %; %; % | %; %; % |
| input with both `anomaly` and `value` columns | °C | °C |

Also: `trend_on` stored as a factor still resolves (`col_or_na` coerces); a `bind_rows()`
of a new raw trend with an anomaly trend lacking `trend_on` gives `c(NA, "%")` as intended.

### (b) Do the tests discriminate?

- Parity test label parsing: `$labels$y` is populated on ggplot2 4.0.3 (probe returns the
  label); a `NULL` label would make `if (grepl(...))` error, not pass. No registry
  `long_name` ends in `)`, so an NA unit cannot be mis-parsed from a long_name. With
  `cd_summary()`'s `raw =` reverted, raw prcp gives "%" vs plot NA (red); with the
  `cd_trend()` carry reverted, q_mean absolute m3/s gives NA vs "m3/s" (red).
- `bind_rows` test catches both "always raw" and "raw[1] only" mutants.
- Extra mutant not in findings.md: mask only `anomaly_type %in% "pct_normal"` in
  `meta_resolve()` (so an untyped raw unit leaks) — `devtools::test()` goes `FAIL 1`, so
  the shared rule is pinned by an existing test even though the parity test (which
  exercises both sides through the same helper) cannot see it by construction.

### (c) Roxygen in the diff

`cd_trend()` `@return`, `cd_summary()` description and the `?cd_anomaly` `unit` item all
match the code as probed.

## Note (not a bug, outside the diff)

- `R/cd_compare.R:78` comment reads "Raw values, so only long_name passes through, as in
  cd_trend()" — no longer true of `cd_trend()`, which now carries `anomaly_type`/`unit` on
  raw input. `cd_compare()`'s behaviour is unaffected; only the "as in cd_trend()" clause is
  stale. The `@return` there ("`long_name` ... resolved as in [cd_trend()]") is still accurate.
