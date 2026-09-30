# Code-check review — round 2 (#101)

Reviewer: subagent, 2026-09-30. Scope: whether the round-1 fixes (template key types from `combos`, `is.null(trend_start)` fallback, `unname()` on slope/intercept) are themselves correct. All probes ran in a scratch copy of the repo; the repo was not edited apart from this file.

## Clean

No issues found.

## What was verified

Probed `cd_trend()` (working tree) on each input the brief named, reading the class of every result column:

| input | result |
|---|---|
| zero-row x, default `trend_start` | 0 x 8; variable/period `chr`, trend_start `dbl` |
| zero-row x with factor variable/period | 0 x 8; variable/period stay `fct` |
| `trend_start = NULL` | 0 x 8, `trend_start` present as `dbl` (round-1 finding 2 fixed) |
| `trend_start = "2000"` (character) | 1 row, trend_start `chr`; template and row agree |
| `trend_start = c(a = 2000)` (named) | 1 row, `dbl`; no bind error |
| `trend_start = factor(2000)` | template and row both `fct`; binds (year comparison is meaningless, which predates this change) |
| Date / POSIXct `trend_start` | empty path: `trend_start <date>`, 0 x 8. Full path errors inside `zyp.sen` (`difftime` division) before reaching the bind — the same on HEAD, so not a regression. `expand.grid()` keeps the Date class, so template and rows could not disagree even if zyp accepted it |
| integer `variable` | template and row both `int` |
| `NA` variable | `chr`, binds |
| grouped input | ungrouped by `series_check()`, unchanged |
| factor variable, character period | `fct` / `chr`, each column from its own `combos` column |
| `bind_rows(<factor empty>, <chr full>)` across two calls | vctrs coerces to `chr` silently, no error |

No input found where the template's type and the rows' type disagree: both come from the same `combos` columns (or, for `trend_start = NULL`, there are no rows at all, since `expand.grid()` with a NULL argument gives zero rows).

`unname()`: `slope` and `intercept` previously carried the name `"yr"` per element from `zyp`. Grepped R/, vignettes/, data-raw/ and scripts/ for any `names()` read on a slope or intercept: none. `mk_pvalue` has no attributes either way. So the only visible difference is that `names(trn$slope)` is now `NULL`, and no caller reads it.

Restore-the-bug, in the scratch copy:
- template keys reverted to `character()` and the NULL fallback removed: `test-cd_trend.R` FAIL 5 (the factor test and the NULL-`trend_start` test).
- `unname()` removed: `test-cd_trend.R` FAIL 1 ("empty result has the same column types as a full one").
- With the fix: test-cd_trend 48 / test-cd_summary 92 / test-cd_plot_timeseries 41 pass, 0 fail, 0 skip (`NOT_CRAN=true`).
