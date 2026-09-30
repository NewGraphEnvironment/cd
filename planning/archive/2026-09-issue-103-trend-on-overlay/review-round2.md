# Review round 2 — #103 warning + trend_start ordering

## Findings
- **[fragile]** R/cd_plot_timeseries.R:90 — the `nrow(trn_dat) > 0` half of the warning guard is not pinned by any test. Mutation in a scratch copy (`if (!any(on_scale))`) leaves `test-cd_plot_timeseries.R` at `[ FAIL 0 | PASS 37 ]`. Without it, `any(logical(0))` is FALSE, so every plot whose trend table has no rows for the plotted variable/period (e.g. an annual-only trend table passed to a seasonal plot, or a 0-row trend) would emit a spurious "No trend ... is on the plotted scale" warning. The code is correct today; the guard can be removed without anything going red. One `expect_no_warning()` with a trend for another period, or `trn_mixed[0, ]`, pins it.
- **[fragile, low]** R/cd_plot_timeseries.R:98 — a trend table with no `trend_start` column now errors with the uninformative `argument 1 is not a vector` from `order(NULL)`, and does so even when zero rows match variable/period (a tibble also warns "Unknown or uninitialised column"). At HEAD such a table drew a one-point line (nothing) silently. Not a `cd_trend()` shape, and the roxygen invites hand-built tables only in the `trend_on` sense, so this is a message-quality regression rather than lost data.

## Verified clean (probes on the working tree, repo untouched; mutations in a scratch copy)
- 0-row trend: no warning, no lines. Data.frame, grouped tibble, single-row data.frame: filter + order behave (a logical/`order()` row index on a data.frame never drops to a vector because it keeps all columns).
- Factor `trend_on`: `col_or_na()` coerces via `as.character()`; only the matching level is drawn.
- Wrong-scale-only (tibble and data.frame): warns with the documented message, draws nothing.
- NA `trend_start`: `order()` puts NA last, so the earliest real start takes the dashed line (NA row draws nothing, as at HEAD).
- Duplicate `trend_start`: `order()` is stable; first-in-input keeps dashed, rest solid.
- NA `trend_on` + a `value` row on an anomaly plot: only the NA row drawn, no warning (some row is on scale) — matches roxygen.
- `cd_summary()` reads absent/NA `trend_on` as anomaly (`%in% "value"`), so the roxygen contrast is accurate.
- Removing the ordering or the warning each turns a test red (per progress.md; the dashing test's `x[1] == 1951` and `expect_warning(..., "plotted scale")` are the pins, confirmed by reading).
- Character `trend_start` errors in `slope * start_yr` — pre-existing at HEAD, not introduced here.

## Triage (parent session)

Both findings are inside the round-1-era fixes (warning, ordering) — fixed:
- nrow guard untested → `expect_no_warning()` for an other-period trend and a 0-row trend; mutation dropping the guard → FAIL 2
- `order(NULL)` error when no row matches → ordering only when `nrow(trn_dat) > 1`

## Enumeration (terminates the loop)

Mechanism: new overlay statements assume a shape of `trn_dat` (rows present, columns present).
17 input shapes run through HEAD's and the branch's `cd_plot_timeseries()` (`scratchpad/enum.R`):
full, zero_row, other_period, other_scale, no/NA/factor trend_on, no variable/period/trend_start,
no trend_start + other period, one row no trend_start, NA variable, NA trend_start, data.frame, grouped, reversed.
Differences from HEAD: other_scale 2 wrong-scale lines → 0 + warning (the fix); NA variable / NA trend_start /
reversed now dash the earliest real start; no variable/period error → silent 0 lines (accepted round 1);
>=2 rows with no trend_start column: two meaningless lines → error (not a cd_trend() shape; loud beats wrong).
Nothing else changed.
