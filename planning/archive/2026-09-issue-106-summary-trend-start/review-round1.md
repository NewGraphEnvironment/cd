# Code review — round 1 (#106, staged diff)

## Clean
No issues found.

Checked (probes read-only, against the source tree via `devtools::load_all()`):

- `NOT_CRAN=true` `test_file("tests/testthat/test-cd_summary.R")`: all pass, no skips (Kendall/zyp installed), so the new `skip_if_not_installed` blocks do run.
- New `@examples` line `cd_summary(cd_trend(ts, trend_start = c(1951, 1956)))` runs on the bundled example data (years 1951-1960) and returns 2 rows with `Start` = 1951/1956, Years 10/5.
- Detection (`col_or_na()` -> character) and display (`trend$trend_start`, raw) read the same column; they can only disagree for numeric starts that differ below 15 significant digits, which is not a realistic input. Column absent -> all-NA -> length 1 -> no `Start`, and `trend$trend_start` is never evaluated, so no `$` partial-match exposure. 0-row input -> `unique(character(0))` has length 0 -> no column, no `add_column` recycling error.
- Row alignment: `out` comes from `mutate()`/`select()` on the ungrouped `trend`, so row order matches `trend$trend_start`. Grouped input is ungrouped on line 68 before either is read.
- `.after` handles the with/without `Trend on` cases; `Region` is appended afterwards, so the order `Parameter, Period, Trend on, Start, ..., Region` holds (and is tested).
- Tests would go red with the block removed (`expect_named` including `Start`), so they pin the change.
- Downstream consumers: the two vignettes pass `cd_summary()` output straight to `knitr::kable()` without positional column names or `col.names`, so the extra column cannot misalign anything; no other R function consumes `cd_summary()` output.
