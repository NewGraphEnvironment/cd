## Outcome

`cd_plot_timeseries(trend =)` kept trend rows by variable and period only, so a table holding
both `cd_trend(x)` and `cd_trend(ano)` (possible since #97, told apart by `trend_on`) drew the
raw-value line over anomaly bars. The overlay now keeps rows whose `trend_on` matches the plotted
column via `col_or_na(trend, "trend_on") %in% c(NA, val_col)`. Rows with no `trend_on`, or `NA`,
still draw on either scale, which is the backward-compatible reading. That differs on purpose from
`cd_summary()`, which reads them as anomaly trends, and the roxygen says so. The plan review added
two things the issue implied but the plan had deferred. The overlay now warns when rows match the
series but none is on the plotted scale, since the trend would otherwise vanish silently. It also
orders rows by `trend_start`, so the earliest start is dashed whatever the row order, as the
vignette captions promise. `which()` in the filter also stops an `NA` variable/period row drawing
an all-NA line and taking the dashed slot. A mixed table in which some rows lack `trend_on`
(legacy) can still mix scales; with no marker on those rows there is nothing to filter on.

## Measurement

- New tests against unfixed code: FAIL 5 before the NA-variable test was added. Against HEAD's
  `R/cd_plot_timeseries.R` with the final test file: FAIL 9.
- Mutation checks, each run in a scratch copy:
  - drop the `trend_on` clause → FAIL 5
  - drop `which()` → FAIL 1
  - drop the `trend_start` ordering → FAIL 1
  - drop the warning → FAIL 1
  - drop the warning's `nrow > 0` guard → FAIL 2
- Code-check: 2 rounds plus an enumeration.
  - Round 1: Clean.
  - Round 2: 2 findings, both inside the plan-review fixes (an untested guard, and `order(NULL)`
    erroring on a table with no `trend_start`).
  - The loop ended on an enumeration of 17 trend-table shapes run through HEAD's and the branch's
    code. Every difference was intended or accepted (`review-round2.md`).
- Full suite `[ FAIL 0 | WARN 6 | PASS 365 ]` (the 6 warnings are pre-existing in
  `test-cd_plot_comparison.R`).

Closed by: commit 0bef871
