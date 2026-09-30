# Code-check review — round 1 (#101)

Reviewer: subagent, 2026-09-30. Probes run in scratch copies (`cdold` = HEAD `R/cd_trend.R`, `cdcopy` = working tree); the repo was not edited apart from this file.

## Verdict

No blocking bugs. Two low-severity observations below; neither breaks any in-repo consumer.

## What was verified

- **Restore-the-bug:** ran the three touched test files with `NOT_CRAN=true` against the pre-fix `cd_trend()`:
  test-cd_trend.R FAIL 8 (the three #101 tests), test-cd_summary.R ERROR 1 (the #101 test), test-cd_plot_timeseries.R FAIL 1 (the #101 test).
  Against the fix: all three files FAIL 0 (39 / 92 / 41 pass). The author's claim holds.
- **Type agreement template vs non-empty rows** (old vs new output compared on the same inputs):
  - `trend_start = 1951` (double), `1951L` (integer), `"1951"` (character), integer start on a double `year`: `trend_start[0]` matches `combos$trend_start` in every case, so the column type is identical to the pre-fix output.
  - `slope` / `intercept`: the named numeric from `zyp` (`names = "yr"`) survives the bind exactly as before; `vctrs` does not error or strip on binding unnamed `numeric()` with a named double.
  - `n_years` integer, `trend_on` character, metadata columns character: consistent.
  - Grouped input, multi-window input, `bind_rows(cd_trend(x), cd_trend(ano))` mixing an empty and a non-empty table: unchanged / fine.
- **Consumers:** `cd_summary()` on zero-row trends (plain, carried metadata, `region_name`, two windows) returns typed 0-row tables with no warning; the mixed-scale bind still summarises. `cd_plot_timeseries()` no longer hits the `Unknown or uninitialised column` warning that `trend$variable` raised on the old 0x0 tibble. The `nrow(trn_dat) > 0` guard prevents a spurious "not on the plotted scale" warning.
- Vignettes and `data-raw/` call `cd_trend()` on character `variable` input and convert to factor **after** the call, so no caller relied on the old shape; no caller tests `ncol()` / `length()` of a trend table.

## Findings

- **[severity: fragile]** R/cd_trend.R:93-94 — a **factor** `variable` / `period` input now comes back as **character** on the non-empty path too, not only when empty. `expand.grid(stringsAsFactors = FALSE)` leaves a factor as a factor, so pre-fix `cd_trend()` returned `<fct>` columns; binding under the `character()` template coerces them (`vctrs` factor + character -> character, silently). Measured: old `variable <fct>`, new `variable <chr>` for the same input. Nothing in R/, vignettes/, data-raw/ or scripts/ passes factor series or depends on factor levels of a trend table (the vignettes re-factor after the call), so no in-repo breakage — but it is an unannounced change on the path the fix was meant to leave alone. Character is arguably the better contract; if kept, it is worth a NEWS line, or else build the template's `variable`/`period` from `x$variable[0]` / `x$period[0]`.
- **[severity: fragile]** R/cd_trend.R:96 — `trend_start = NULL` gives `trend_start[0]` = `NULL`, which `tibble()` drops, so the result is a 0 x 7 tibble **without** `trend_start`, contradicting the new `@return` sentence ("a zero-row tibble with the same columns"). Pre-fix it was 0 x 0. Degenerate input nobody passes; harmless in practice (`cd_summary()` on it is untested), noted only because the doc now makes a claim this input violates.
