# Task: cd_trend(): no series long enough gives a 0x0 tibble, and cd_summary() errors on it (#101)

`cd_trend()` returns `NULL` for every combination with fewer than 3 years, and
`dplyr::bind_rows()` of all-`NULL` is a **0 x 0** tibble — no `variable`, `period` or
`slope` columns. `cd_summary()` then fails with `Column 'period' not found in '.data'`,
which says nothing about the cause.

Plan-mode probe: a typed zero-row trend table already flows cleanly through
`cd_summary()` (with and without `region_name`, with and without meta columns) and
`cd_plot_timeseries()`. The fix is entirely `cd_trend()`'s return shape: bind results
onto a zero-row template carrying the full column set, so 0 and N surviving rows share
one code path.

## Phase 1: Tests first (fail on main)
- [x] `test-cd_trend.R`: extend `skips combos with < 3 years` — 0 rows, `expect_named()` the documented 8 columns, `trend_on` character, `n_years` integer
- [x] `test-cd_trend.R`: zero-row result keeps `anomaly_type`/`unit`/`long_name` when the input carries them
- [x] `test-cd_trend.R`: 0-row input (`x[0, ]`) returns the same typed empty shape
- [x] `test-cd_summary.R`: `cd_summary(cd_trend(<2-year series>))` has 0 rows and the documented columns (`Parameter`, `Period`, `Slope`, `Years`, `Total Change`, `Unit`, `p-value`); with `region_name`, `Region` too
- [x] `test-cd_plot_timeseries.R`: `trend = cd_trend(<too-short window>)` draws with `expect_no_warning()`
- [x] Confirm the new tests fail against unchanged `cd_trend()`

## Phase 2: Fix `cd_trend()`
- [x] Zero-row template bound under `results` in `R/cd_trend.R`
- [x] `@return`: state that a trend with no combination of >= 3 years is a zero-row tibble with the same columns
- [x] `devtools::document()`; full `devtools::test()` green; `lintr::lint_package()` clean
- [x] `/code-check`, commit with checkbox flips, `Fixes #101`

## Phase 3: Wrap up
- [x] `devtools::check()` — 0 errors; 1 warning + 8 notes all pre-existing (no VignetteBuilder, .Rbuildignore gaps #100/#107, `.data` bindings, unused `sf`)
- [ ] `/planning-archive`, `/gh-pr-push` (SRED line in PR body). Merge is a separate instruction.

## Validation

- [x] Tests pass
- [x] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
