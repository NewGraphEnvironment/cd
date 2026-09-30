# Code-check review — round 3 (#101)

Reviewer: subagent, 2026-09-30. Probes ran in a scratch copy (`/private/tmp/claude-501/r3/cd`, working tree, plus HEAD's `R/cd_trend.R` sourced as `old`); the repo was not edited apart from this file.

## Clean

No issues found.

## Mechanism

The three earlier findings share one cause: the zero-row template in `R/cd_trend.R:94-104` **restates** each column's type, while the per-row `tibble()` in the `lapply()` (lines 77-87) builds the same columns from its own sources. Nothing ties the two together; they are correct only while two independent lists happen to agree. `bind_rows()` then resolves any disagreement silently through vctrs' common type (factor + character -> character, integer + double -> double), so a mismatch shows up as a changed type on the *full* path, not as an error.

Round 1's fixes removed the restatement for the three key columns (variable, period, trend_start now come from the same `combos` columns / `trend_start` vector the rows use). What still restates is the five computed columns and the metadata columns, so those are the ones enumerated below against what the row construction actually produces.

## Enumeration: every template column vs the row's type

Inputs probed (each on the full path, on the empty path by moving `trend_start` past the data, and against HEAD): character / factor / integer keys; double, integer, character and named `trend_start`; `value` vs `anomaly`; integer vs double values (including an odd-length integer series, where `median()` of integers would stay integer, and a constant integer anomaly); double `year`; an NA in the values; carried `anomaly_type`/`unit`/`long_name` as factor and as logical NA; a raw `prcp` series whose unit is dropped by `meta_resolve(raw = TRUE)`; a mixed table where one combo passes and one is too short; `bind_rows()` of an empty value-trend with a full anomaly-trend.

| column | template source | row source | row type over the input space | verdict |
|---|---|---|---|---|
| `variable` | `combos$variable[0]` | `combos$variable[i]` | same vector: chr / fct (levels kept) / int | agree by construction |
| `period` | `combos$period[0]` | `combos$period[i]` | same vector: chr / fct / int | agree by construction |
| `trend_start` | `trend_start[0]`, or `numeric()` if NULL | `combos$trend_start[i]` (`expand.grid` keeps class and names) | dbl / int / chr / named dbl; NULL gives no rows | agree (names survive on both, as on HEAD) |
| `slope` | `numeric()` | `round(unname(sen$coefficients[2]), 4)` | always double: zyp computes it by division, so integer `y`/`yr` cannot make it integer | agree |
| `intercept` | `numeric()` | `round(unname(sen$coefficients[1]), 4)` | always double: `median(y - slope * yr)` with a double slope | agree |
| `mk_pvalue` | `numeric()` | `round(mk$sl[1], 4)` | double. `mk$sl` carries a `Csingle` attribute; `[1]` drops it, so no attribute reaches the column | agree |
| `n_years` | `integer()` | `nrow(dat)` | integer | agree |
| `trend_on` | `character()` | `val_col` | character | agree |
| `anomaly_type` | `character()` | `as.character(dat[[col]][1])`, after `meta_resolve()` (which reads via `col_or_na()`, already `as.character`) | character for factor, logical-NA and character input | agree |
| `unit` | `character()` | same | character, NA_character_ when dropped for raw `pct_normal` | agree |
| `long_name` | `character()` | same | character | agree |

Column set and order: template and rows both add the metadata columns by looping over the same `cols_meta`, after the same eight, so names and order agree too.

Against HEAD, on every input above, each column of the new result is `identical()` to the old one except `slope` and `intercept`, which differ only by the dropped `"yr"` names (accepted). On every input the empty result's column classes equal the full result's.

## Consumers

- `cd_summary()` on an empty factor-keyed trend: typed 0 x 7, no warning. Two windows with one empty: one row, no spurious `Start` column. Empty value-trend bound with a full anomaly-trend: one row.
- `cd_plot_timeseries()` with an empty factor-keyed trend: returns a ggplot, no warning.
- `NOT_CRAN=true` single-file runs of `test-cd_trend.R`, `test-cd_summary.R`, `test-cd_plot_timeseries.R`: no failures.

## Not findings

- `trend_start = NA` (logical) or a factor `trend_start`: the template and rows agree (same source); the year comparison is meaningless, which predates this change.
