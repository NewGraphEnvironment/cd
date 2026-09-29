# Code review — round 4 (#93, Phase 1 fixes: meta_resolve(raw =), which() subset)

Scope: staged diff `diff-p1b.patch` (R/cd_anomaly.R, R/cd_plot_timeseries.R, its test, Rd).
The unstaged Phase 2 edits (cd_compare / cd_plot_comparison) were not reviewed, but their
`meta_resolve()` calls were checked for a behaviour change. Probes and mutations ran in a
scratchpad copy, never in the repo.

## Clean

No issues found in the fixes.

## Checked, no finding

- **`raw` default reaches every caller unchanged.** `grep -rn meta_resolve R/` gives six
  callers: cd_anomaly.R:90, cd_trend.R:47, cd_summary.R:41, cd_compare.R:80 (unstaged),
  cd_plot_comparison.R:36 (unstaged, `$long_name` only), and cd_plot_timeseries.R:63. Only the
  plot passes `raw`. With `raw = FALSE`, the refactor (`unit` computed into a local, then
  returned) is value-identical to the old inline `coalesce()`. Probed: `meta_resolve(x)` on
  prcp/absolute, tmean/NA and q/pct_normal returned the same units as before (`NA`, `°C`, `%`).
  The cd_trend -> cd_summary raw-unit divergence is deferred to cd#97, as accepted.
- **`NA` anomaly_type in `%in%`.** `NA %in% c(...)` is `FALSE`, so an unresolved type drops
  the unit. The test at "q_mean, unit = '%', no anomaly_type -> 'Mean discharge'" asserts
  exactly that. A factor `anomaly_type` or `unit` column goes through `col_or_na()`
  (`as.character`) and resolves correctly (probe: `value (m3/s)`).
- **`which()` subset.**
  - Factor `variable`/`period` columns: labels right.
  - Zero matches (factor or character): the `nrow == 0` abort still fires with its own
    message.
  - `variable = NA`, `variable = character(0)`, or `NA` in `x$variable[1]` under the
    default: all give the "No data" abort. Before, the first case gave an all-`NA` plot.
  - Plain `data.frame` and grouped tibble: OK.
- **meta_check after the carve-out.**
  - On raw input, conflicting carried `unit` values within a pct_normal series (prcp: mm /
    cm) are NA'd before the check, so they pass. The unit is never displayed, and
    `cd_trend()` on raw input does not check `unit` either, so nothing is mislabelled.
  - On anomaly input the same conflict still aborts.
  - A partially carried `anomaly_type` on raw input (`c(NA, "absolute", NA, NA)` on prcp)
    now aborts, where `cd_trend()`'s raw path accepts it. That input violates the
    `?cd_anomaly` "every row or none" contract, and the plot's raw path needs a uniform type
    to choose the unit, so it is not a finding.
- **Label uniformity (`[1]`).** The carved unit depends only on `anomaly_type`, and
  `anomaly_type` is checked or registry-keyed on one variable, so row 1 is representative.
- **Guards proven.**
  - Restoring `x[lgl, ]` turns the NA-rows test red (FAIL 1).
  - Removing the raw carve-out turns two tests red (FAIL 2).
  - Rd regenerated in the copy is byte-identical to the repo's `man/`.
  - Test runs: plot suite `NOT_CRAN=true` `[ FAIL 0 | PASS 22 ]`. The trend, summary,
    anomaly, compare and plot_comparison suites also reported no failures.
- **Pre-existing, outside the diff:**
  - The trend overlay still subsets with `trend[lgl, ]` (cd_plot_timeseries.R, trend
    block), so `NA` rows in `trend` become `NA` lines.
  - `series_check()` counts two `NA` years as "1 duplicate(s)".
  - Neither was introduced here.
