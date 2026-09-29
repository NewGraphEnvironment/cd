# Code-check review — round 1 (#92)

Reviewer: subagent, 2026-09-28. Diff: staged changes to R/cd_anomaly.R, R/cd_trend.R,
R/cd_summary.R and tests. All probes ran in a scratch copy of the repo; the repo is unchanged.

## Findings

- **[bug] R/cd_anomaly.R:87-88**: `anomaly_type` and `unit` fall back to the registry
  independently. Suppose a registered variable carries its own `anomaly_type` but no `unit`
  (or `unit = NA`). It then gets the registry's unit, and that unit belongs to the registry's
  type, not the carried one. Probe:
  `tibble(variable = "prcp", period = "annual", year = 2000:2002, value = c(100, 150, 50), anomaly_type = "absolute")`
  gives anomalies `0, 50, -50` (mm) labelled `unit = "%"`. `cd_trend()` carries that `"%"` and
  `cd_summary()` prints it in the `Unit` column. No error or warning, and the report shows the
  wrong unit. The `unit` fallback should apply only where the type also came from the
  registry, or where the carried type equals the registry type. Otherwise leave it `NA`
  (or abort). The existing row-by-row test avoids this case because it passes `unit = "mm"`
  alongside the override.

- **[fragile] R/cd_anomaly.R:105-109 (`dplyr::summarise(..., .by =)`)**: `cd_anomaly()` now
  errors on a grouped data frame (`Can't supply '.by' when '.data' is a grouped data frame.`).
  The old `left_join` + `mutate` + `select` path accepted grouped input (checked against HEAD
  in the scratch copy). The target consumer is a streamflow package producing per-year window
  values. That kind of producer typically writes
  `group_by(variable, period, year) |> summarise(value = ...)`, which leaves the result grouped
  by `variable, period`. It would hit this error, with a message that does not point at the
  cause. `cd_baseline()` already has the same limitation (its `summarise(.by =)` is
  pre-existing), so the full chain breaks either way. This change adds a second function that
  breaks on grouped input. A `dplyr::ungroup()` at entry (in both functions) would close it.

- **[fragile] R/cd_trend.R:77**: `long_name` is taken from the first row of each series
  (`dat[[col]][1]`), and `cd_anomaly()`'s single-value check covers only `anomaly_type` and
  `unit`, not `long_name`. A series whose rows carry different or partly-`NA` `long_name`
  (e.g. after `bind_rows()` of two producers) gets whichever value the first row has, with no
  error. If that first value is `NA`, `cd_summary()` falls back to the bare variable name even
  though a label was supplied. Probe: `long_name = c(rep("A", 5), rep("B", 5))` passes
  `cd_anomaly()` and returns trend `long_name = "A"`.

## Not a regression, noted for scope

- A series absent from `baseline` still returns `anomaly = NA` silently, even with a carried
  `anomaly_type`. The left join leaves `baseline_mean` as `NA`. This is pre-existing and a
  different path from the one #92 fixes, but it has the same "silent NA" symptom the issue
  is about.

## Checked, no issue

- `match()` with an `NA` variable: an `NA` variable is unresolved and aborts naming `NA`.
  Correct.
- Factor `variable`, `period` and `anomaly_type`: handled through `as.character` in
  `col_or_na()` and `match()`.
- Zero-row input: `col_or_na()` returns `character(0)`, `summarise(.by)` returns 0 rows, and
  the output has the expected names.
- Test regexes: `"anomaly_type.*q_mean"` would also match the mixed-series message. Removing
  the unresolved guard, though, makes the test fall through to `Unsupported 'anomaly_type': NA`,
  which does not match, so the guard is still proven. The baseline-metadata test fails without
  the `baseline[c(...)]` subset (`.x`/`.y` suffix collision), so that guard is proven too.
- The vignettes' `cd_trend()` consumers index trend columns by name and never `rbind` fresh
  trends with the bundled rds trends, so the two extra columns on anomaly-trend output break
  nothing there.
- `cd_summary()` with carried, registry and fallback labels: the lengths all equal
  `nrow(trend)`, and `.env$` injection is correct.
