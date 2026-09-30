# Review round 1 — #103 cd_plot_timeseries trend_on filter

## Clean

No issues found.

Verified (in a scratch copy, repo untouched):
- `cd_trend()` and `cd_plot_timeseries()` pick `val_col` by the same rule (`"anomaly"` if present, else `"value"`), so `trend_on %in% c(NA, val_col)` matches the plotted column exactly.
- `col_or_na()` uses `names(x)` + `[[` (exact match), so no `$` partial-matching risk; factor `trend_on` is coerced by `as.character()`.
- New tests with the fix: all pass (31 expectations in the file).
- Against unfixed HEAD code: 6 failures across 4 of the 5 new tests (anomaly plot, value plot, bind_rows of real cd_trend(), NA-variable). The no/NA `trend_on` test passes on both, as a backward-compat test should.
- Mutations: `%in% val_col` (drops NA compat) -> 2 failures; hard-coded `c(NA, "anomaly")` -> 1 failure (value-plot test); `trend$trend_on` in place of `col_or_na()` -> 1 failure (absent-column case). Every clause of the filter is pinned.

Non-blocking note (record accuracy only): `progress.md` says "5 failures against unfixed code"; measured against HEAD it is 6 failing expectations (the 5 is the drop-only-the-trend_on-clause mutation, which keeps `which()`). Worth correcting if the progress log is the evidence record.
