# Findings — cd_summary(): stations sharing a long_name give indistinguishable rows (#98)

## Issue context

**If we do it:** a `cd_summary()` table over several stations that share one `long_name` says which row is which station. **If we never do:** two rows read `Mean discharge / Annual` with different slopes and nothing to tell them apart — while `cd_plot_comparison()` beside the table labels the same series `Mean discharge (q_site1)`.

## Problem

`series_check()` tells callers that series from several sites need distinct `variable` names. The natural next step for streamflow is one `long_name` ("Mean discharge") on every station. `cd_summary()` (`R/cd_summary.R`) replaces `variable` with `Parameter = long_name` and drops `variable`, so those rows become indistinguishable. Measured in #93's review with `q_site1` / `q_site2`.

#93 handled the same case in `cd_plot_comparison()`: a label shared by several variables gets ` (variable)` appended, and facets key on variable + label so nothing can merge.

## Proposed Solution

- In `cd_summary()`, append ` (variable)` to a `Parameter` shared by more than one variable — the same rule as `cd_plot_comparison()`, ideally lifted into one internal helper both call.
- Test: two stations, one `long_name` → two distinct `Parameter` values; registered ERA5 variables unchanged (registry long_names are unique).

A second way to get indistinguishable rows: since #97 a trend table can hold both a raw-value and an anomaly trend of one series (`bind_rows(cd_trend(x), cd_trend(ano))`, told apart by `trend_on`). `cd_summary()` drops `trend_on`, so those rows differ only by `Unit`, and for an `absolute` variable such as tmean not even by that. Whatever disambiguates stations here should also cover `trend_on`, or `cd_summary()` should carry it.

Found by `/code-check` on #93; the `trend_on` case by the plan review for #97.

## Plan-gate decision (2026-09-29)

`trend_on` disambiguation: a conditional `Trend on` column ("Value"/"Anomaly"), added only
when the table holds both scales — the `Region` precedent. Chosen over always adding the
column (changes every existing table, both vignettes' kables) and over suffixing `Parameter`
(scale ends up in a text label rather than a filterable field).

## Exploration

- `cd_plot_comparison()` (`R/cd_plot_comparison.R:34-39`) has the #93 rule inline: a label
  shared by several variables gets ` (variable)` appended, one pass. Its residual collision
  (`long_name = c("Q", "Q", "Q (a)")`) is harmless there because facets key on
  variable + label. A table has no hidden key, so the lifted helper repeats until labels are
  distinct per variable.
- Shared helpers live in `R/cd_anomaly.R` (`col_or_na`, `series_check`, `meta_resolve`,
  `meta_check`); CLAUDE.md tells new consumers to call them.
- `cd_summary()` already reads a missing/`NA` `trend_on` as anomaly (`meta_resolve(raw = col_or_na(...) %in% "value")`).

## Errors Encountered

| Error | Resolution |
|-------|------------|

## label_disambiguate() pass bound — enumeration (2026-09-30)

Code-check round 1 showed the first bound (`n_distinct(variable)`) was reasoned, not measured:
`label_disambiguate(c("a","e","e","e"), c("Q","Q","Q (a)","Q (a) (a)"))` aborted after two
passes and settles at three, because one variable can carry a different label per period. The
bound is now the number of distinct (variable, label) pairs.

Enumeration (`label_disambiguate_enum.R`): every set of 1–4 distinct pairs over variables
`a`, `b`, `a) (b` and 12 labels built by chaining their suffixes to depth 2 — 66,711 sets.
**0 aborts, 0 labels shared by two variables.** 969 sets merge two labels of *one* variable
(`a` carrying `Q` and `Q (a)` in different periods both print `Q (a)`); those rows still differ
by `Period`, and the one-pass rule on main does the same. Accepted.
