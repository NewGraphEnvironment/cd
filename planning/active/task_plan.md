# Task: cd_summary(): trends from several trend_start values differ only by Years (#106)

`cd_trend()` accepts several `trend_start` values (`R/cd_trend.R`), and `cd_summary()` drops `trend_start`. The rows keep `Years` (`n_years`), which varies with the start, but nothing names the window. Same family as #98: #98 kept stations apart (` (variable)` suffix) and raw vs anomaly trends apart (a conditional `Trend on` column).

## Decisions (approved at plan gate)
- **Column name `Start`, holding the start year** (e.g. `1951`). Not `Window "1951–2025"`: the end year isn't in the trend table, and `trend_start + n_years - 1` is wrong when the series has gaps.
- **Position:** identifier columns first — `Parameter, Period, [Trend on], [Start], Slope, Years, …`.
- **Detection:** `col_or_na(trend, "trend_start")` (`R/cd_anomaly.R:136`), counted over the whole table like `Trend on`. Missing column → no `Start`, no error (hand-built tables). `NA` beside a real start counts as distinct and shows `NA`. Values copied from `trend$trend_start` unchanged (keeps numeric type; `col_or_na` returns character).
- Summaries bound together (one per region) can differ in having `Start`, as #98 already documents for `Trend on`.

## Phase 1: Failing tests (`tests/testthat/test-cd_summary.R`)
- [x] Two starts (`cd_trend(raw_series("tmean"), c(2000, 2004))`) → `Start` after `Period`, values match `trend_start`, `Parameter/Period/Start` unique
- [x] One start → no `Start` column (existing shape tests still pass; add explicit case)
- [x] No `trend_start` column at all, and a 0-row table → no `Start`, no error
- [x] `NA` start beside a real one → `Start` present, `NA` shown
- [x] Mixed scales × two starts × region → order `Parameter, Period, Trend on, Start, …, Region`; rows unique on all four identifiers

## Phase 2: Implement
- [x] `cd_summary()`: add the `Start` block after the `Trend on` block, `.after` = `Trend on` if present else `Period`
- [x] Roxygen: extend the "Rows are kept distinguishable" paragraph and `@return`; add an example `cd_summary(cd_trend(ts, trend_start = c(1951, 1956)))` (example data spans 1951–1960)
- [x] `devtools::document()`

## Phase 3: Docs + vignettes
- [x] `CLAUDE.md` "A trend table can mix scales" paragraph: one sentence that `cd_summary()` also names the window (`Start`) when starts differ
- [x] Render the `trend-table` chunk of both vignettes from their committed `.rds` and confirm `Start` appears and rows are unique (no data regen needed — `trn` already carries `trend_start`)
- [x] Hidden `trend-table` chunk orders rows by variable, period, start so each 1951/1981 pair is adjacent (plan review: grid order put 59 rows between them)

## Phase 4: Verify
- [ ] `devtools::test()` all green; `lintr::lint_package()` clean; `pkgdown::check_pkgdown()`
- [ ] `/code-check` on each commit (with Plan-agent review of the task_plan run concurrently after baseline)

NEWS/version bump left to `/gh-pr-merge`, as for #98.

## Validation
- [ ] Tests pass
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
