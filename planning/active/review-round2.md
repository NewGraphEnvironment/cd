# Review round 2 — cd#92 (fixes from round 1)

Probed in a temp copy (`pkgload::load_all()`); probe script at
`$SCRATCHPAD/probe.R`. The four affected test files pass as staged.

## Findings

- **[bug]** R/cd_summary.R:39-43 — Round-1 fix 1 reproduced one axis over. `cd_anomaly()`
  now correctly leaves `unit` NA for prcp carried as `"absolute"`, `cd_trend()` carries that
  NA `unit` (and `anomaly_type = "absolute"`), and `cd_summary()` then does
  `coalesce(col_or_na(trend, "unit"), vars$unit[idx])` — refilling the registry's `"%"`.
  Measured: prcp/absolute series -> `cd_anomaly()$unit` NA -> `cd_trend()$unit` NA ->
  `cd_summary()$Unit` `"%"` for a slope in mm/yr. The registry-unit fallback in
  `cd_summary()` needs the same guard as `cd_anomaly()` (use `vars$unit[idx]` only when the
  trend's `anomaly_type`, if carried, equals `vars$anomaly_type[idx]`). The round-1 test
  stops at `cd_anomaly()`, so it cannot see this.

- **[bug]** R/cd_summary.R:47,52 — Regression on grouped input, the same class as round-1
  fix 2. `labels_param`/`labels_unit` are full-length vectors injected with `.env$` into
  `mutate()`; on a grouped `trend` mutate evaluates per group and aborts
  ("`Parameter` must be size 1, not 2"). The pre-diff code
  (`unname(par_labels[.data$variable])`) worked on the same grouped input (measured: old
  code returns the table, new code errors). Needs `dplyr::ungroup(trend)` at the top, as
  cd_anomaly/cd_baseline got.

- **[fragile]** R/cd_compare.R:76-82 — Fix 2 landed in two of three `summarise(.by=)`
  callers. `cd_compare()` on grouped input still aborts
  ("Can't supply `.by` when `.data` is a grouped data frame"), and it is part of the
  documented chain the new consumer runs (the #92 end-to-end test calls
  `cd_compare(x, ...)` on the same `x`). Pre-existing, not in the diff, but a grouped
  `x` now passes `cd_baseline()`/`cd_anomaly()` and dies one call later.

- **[fragile]** R/cd_trend.R:44-45,77 — Fix 3's one-value-per-series check lives only in
  `cd_anomaly()`. `cd_trend()` on raw values (`value` column — the documented
  `cd_trend(ts)` path, never passing through `cd_anomaly()`) still carries `long_name` and
  takes `dat$long_name[1]` silently: measured, a series with `long_name` alternating
  `"A"`/`"B"` returns `"A"` with no error. Same for anomaly input built outside
  `cd_anomaly()`. The check needs to run in `cd_trend()` too (or in a shared helper).

- **[fragile]** R/cd_anomaly.R:113-124 — `n_distinct()` counts `NA` as a value, and
  `long_name` is not coalesced before the check, so a series whose `long_name` is set on
  some rows and `NA` on others aborts — contradicting the documented contract ("where
  absent or `NA` they fall back to cd_variables()"). Measured: tmean with
  `long_name = c("Mean temperature", NA, NA, NA)` aborts "More than one `anomaly_type`,
  `unit`, `long_name` value within a series: tmean/annual" (the message names all three
  columns, not the one that differs). Same for an unregistered variable whose `unit` is
  partially NA. Fails loud rather than silent, so low severity, but it rejects input the
  docs say is valid.
