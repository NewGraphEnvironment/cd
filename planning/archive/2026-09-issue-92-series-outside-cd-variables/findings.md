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
## Plan review

See `review-plan.md`. Two blockers (factor-code lookup, baseline join suffixes) and three gaps folded into Phase 2/3.

## Verification (2026-09-28)

- Example-catalog chain (extract → baseline → anomaly → trend → summary), before vs after: `cd_summary()` identical, raw-value `cd_summary(cd_trend(ts))` identical. `cd_anomaly()` differs only in dropping a stray `names` attribute the old named-vector lookup left on `anomaly_type`/`unit`. `cd_trend(ano)` gains `anomaly_type`, `unit` columns (additive).
- Mutation table (scratch copy, filter anomaly|trend|summary): M1 unresolved abort off → 2 red; M2 name-indexed lookup → 1; M3 mixed-type abort off → 1; M4 full baseline join → 1; M5 unit passed on raw trend → 1; M6 summary ignores carried cols → 3; M7 trend drops metadata → 3. Unmutated → 0.
- Full suite: FAIL 0 | WARN 2 (pre-existing, cd_plot_comparison) | PASS 256.
- `pkgdown::check_pkgdown()` fails identically on main (DESCRIPTION URL vs github.io); no export added, unrelated.

## Errors Encountered

| Error | Resolution |
|-------|------------|
| Mutations M2–M6 all "passed" identically on first run | `git checkout -- R` in the scratch copy restored the committed (main) code, not the uncommitted implementation. Commit inside the copy first, then mutate. |

## Code-check (2026-09-28)

| Round | Findings | Fixed | Accepted | Inside previous fix? |
|-------|----------|-------|----------|----------------------|
| 1 | 3 (1 bug, 2 fragile) | 3 | 0 | — |
| 2 | 5 (2 bug, 3 fragile) | 5 | 0 | y — unit guard missing in cd_summary; grouped input still broke cd_summary |
| 3 | 2 (1 bug, 1 fragile) | 2 | 0 | y — the R2 `ungroup()` turned station-grouped input from an error into silent pooling |

Mechanism (R3): each entry point re-derived its own input assumptions — ungrouped, keyed by (variable, period), one row per year, metadata resolved before checked — so each fix landed in one copy. Response: three shared helpers in `R/cd_anomaly.R` (`series_check`, `meta_resolve`, `meta_check`).

Ended by enumeration, not a clean round: `scratchpad enum.R` walked all exports' bodies. 9 take a tibble or read the registry; `cd_aggregate`/`cd_cog_write` take rasters (n/a); all 4 series entry points call `series_check`; `cd_anomaly`, `cd_trend`, `cd_summary` call `meta_resolve`; the two `.by` callers run after `series_check`; the only remaining direct registry readers are the two plot functions → #93, whose body now says to call `meta_resolve()`.

Mutation table after R3 (M0–M21): every guard red when removed; unmutated 0 red.

Regression on real data: regional Peace and Kootenay `cd_trend(ano)` reproduce committed `trn` exactly and `cd_summary()` is identical; all committed vignette series have 0 duplicate keys.

Known, not fixed (pre-existing, separate paths): `cd_trend()` on zero rows returns a column-less tibble; a series with no baseline row gets `anomaly = NA`; `check_pkgdown()` fails on main (DESCRIPTION URL).
