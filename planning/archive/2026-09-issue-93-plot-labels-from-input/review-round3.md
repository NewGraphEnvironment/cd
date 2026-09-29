# Code review — round 3 (#93, Phase 1: cd_plot_timeseries labels)

Scope: staged diff `diff-p1.patch` (R/cd_plot_timeseries.R, its test, Rd, task_plan).
The unstaged Phase 2 edits (cd_compare / cd_plot_comparison) were not reviewed. Probes ran
in a scratchpad copy with the unstaged edits stashed there, never in the repo.
Staged test file: `NOT_CRAN=true` -> `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 15 ]`.

## Findings

- **[severity: fragile]** R/cd_plot_timeseries.R:6-10, 69 (this diff), with R/cd_trend.R:45 and
  R/cd_summary.R:41-43 via R/cd_anomaly.R:163-176 (the code that decides the outcome, outside
  this diff). **Mechanism: three rules, in three places, answer "does the anomaly's `unit`
  describe a raw-value series".**
  1. `cd_trend()` on `value` input says **never**. It withholds `anomaly_type` and `unit` by
     *dropping the columns* (`cols_meta <- "long_name"`).
  2. `cd_summary()` passes the trend to `meta_resolve()`, which reads an absent column as
     "fall back to the registry". So for a registered variable the drop is undone, and the
     registry's *anomaly* unit comes back beside a raw-value slope. For an unregistered one,
     a correct carried unit is lost.
  3. `cd_plot_timeseries()` (line 69) says **unless `pct_normal`**.

  Before this diff, rules 2 and 3 agreed: both printed "%" for raw prcp, and both were wrong.
  The diff fixes the plot and leaves `cd_summary()`, so a fix landed in one of two callers.
  The roxygen at lines 6-8 ("resolved by the same rules as [cd_summary()]") is therefore
  false for `value` input. The #93 goal ("plots with the same label and unit that
  cd_summary() prints") holds only on anomaly input. What the probe measured (plot y-label
  vs `cd_summary(cd_trend(x))`):

  | raw `value` input | plot | cd_summary Unit |
  |---|---|---|
  | prcp, soil_moisture, swe, snowfall, snowmelt | no unit | `%` (wrong: slope is mm/yr, etc.) |
  | q_mean, anomaly_type=absolute, unit=m3/s | `(m3/s)` | `NA` |
  | prcp, anomaly_type=absolute, unit=mm | `(mm)` | `%` |
  | q_mean, pct_normal, unit=% | no unit | `NA` (agree) |
  | tmean, vpd, swe_max, snow_cover | registry unit | registry unit (agree) |

  In each disagreement the plot is right and `cd_summary()` mislabels a report table. That
  mislabel predates this diff. Remedy: put the raw-value carve-out in one helper that both
  `cd_trend()` (which then passes the resolved, carved-out `unit` instead of dropping the
  column) and the plot call. At minimum, scope the roxygen claim to anomaly input.

  **Everywhere the mechanism reaches:**
  - **`cd_anomaly()` output** always carries resolved `anomaly_type` and `unit`, plus
    `long_name` iff it was carried. The plot and `cd_trend()` -> `cd_summary()` agree on all
    of these; four probes (unregistered pct_normal, prcp absolute, prcp, unregistered without
    `long_name`) all matched on unit.
  - **`cd_trend()` output**
    - On anomaly input, all three columns are passed resolved, and `cd_summary()`'s second
      `meta_resolve()` is idempotent on them, so the two agree.
    - On `value` input, only `long_name` is passed, which gives the divergence in the table
      above.
  - **Label fallback when no `long_name` resolves:** `cd_summary()` falls back to the
    `variable` name (`q_mean`) and the plot to the column name (`anomaly` / `value`). The two
    lists of fallbacks disagree by design; the spec asks for that, so it is not a finding.
  - **Phase 2 `cd_compare()`** mirrors `cd_trend()`'s long_name-only raw rule and draws no
    unit, so it has no unit to disagree about.

- **[severity: fragile]** R/cd_plot_timeseries.R:52 with :56 and :63-67. The row filter
  `x[x$variable == variable & x$period == period, ]` inserts an all-`NA` row for each `NA` in
  `variable` or `period`. That was harmless before (ggplot drops the row, and the label was
  keyed on the `variable` argument). The diff now feeds those rows to two new consumers:
  - **`series_check()`.** Two such rows abort with "More than one row per variable, period
    and year (... e.g. NA/NA/NA)", which names no real duplicate.
  - **`meta$...[1]`.** An `NA` row sorting first turns the label into the column name.
    Measured: `period[1] <- NA` on tmean raw gives `"value"`; before the diff it gave
    `"Mean temperature (°C)"`.

  The rest of the chain accepts the same `x`: `cd_trend()`'s `series_check()` on the full
  frame keys those rows by year. So the plot now refuses, or mislabels, input the chain
  accepts. Round 1 noted this as predating the diff, but the abort and the row-1 label
  dependence are both new. Fix: `x[which(x$variable == variable & x$period == period), ]`.

## Checked, no finding
- `meta$...[1]` uniformity. Every carried column is checked after resolution. Absent columns
  are registry-keyed on one variable, and `unit` follows the checked `anomaly_type`.
- pct_point_diff raw (snow_cover) keeps `%`. That is correct: the raw value is a percentage.
- Checklist mechanisms applied: "A fix lands in one of two callers" (finding 1),
  "Cross-function consistency for label normalization" (finding 1), "One fact derived twice"
  (the unit rule is derived twice), "Zero-length/empty/unset" (absent column vs NA column:
  meta_resolve treats them the same, which is how rule 2 undoes rule 1).
