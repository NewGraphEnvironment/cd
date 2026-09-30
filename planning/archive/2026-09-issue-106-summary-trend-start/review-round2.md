# Code review — round 2 (#106, staged diff)

## Clean
No issues found.

Checked (probes read-only, against the source tree via `devtools::load_all()` and a `cp -r` copy for `document()`):

- **Chunk labels.** `grep -o '^```{r …' | sort | uniq -d` over both vignettes is empty. The edits added no chunk; `trend-table` is unique in each file.
- **No leakage.** `trn_tbl` appears only inside its own `trend-table` chunk in each vignette, and `trn` is not reassigned. Later consumers of `trn` (`plot-prcp`'s `trend = trn`, `compare-table`'s `trn$trend_start == 1951` filter, `rollup`'s `get_75()`) all subset by value, not position, and still see the unchanged `trn`.
- **Reorder against the shipped data.** Both `inst/vignette-data/*.rds` `trn` hold 118 rows (59 variable/period keys × {1951, 1981}), ungrouped, with no `trend_on` column (pre-0.5.2 save, so all rows read as anomaly and there is no `Trend on`). After the reorder: `rle(paste(variable, period))` gives 59 runs, all of length 2. `cd_summary(trn_tbl)` has columns `Parameter, Period, Start, Slope, …`, `Start` is identical to `trn_tbl$trend_start`, and it has exactly the same rows as `cd_summary(trn)`. The reorder only moves rows. The sort key (match codes plus a numeric start) is unique per row, so the order is deterministic and does not depend on `LC_COLLATE`.
- **Visible recipe versus table.** The shown `cd::cd_summary(trn)` gives the same rows and columns as the table. Only the row order differs (a live `cd_trend()` uses `expand.grid` order). This was a deliberate choice for the hidden chunk and does not break anything.
- **`man/` in sync.** `devtools::document()` in a copy produced no further changes, so `man/cd_summary.Rd` matches the roxygen.
- **Roxygen claims, each probed on the bundled example data:**
  - "The start year asked of `cd_trend()`, not the first year with data" holds. `cd_trend()` writes the requested `ts` into `trend_start`, and `cd_trend(ts_tmean, 1940)` records Start 1940 over data that begins in 1951.
  - "Decided over the whole table" holds. Detection is `length(unique(col_or_na(trend, "trend_start"))) > 1` on the ungrouped table.
  - "An NA counts as one" holds. `unique()` keeps NA as a value.
  - "No `trend_start` column → none" holds. `col_or_na` returns all-NA, which has length ≤ 1.
  - "A column present in only some bound summaries is NA for the rest" holds. `bind_rows(cd_summary(a, "R1"), cd_summary(bind_rows(a, b), "R2"))` gives `Start` NA for R1.
  - `@return` placement ("follows Period (or Trend on)") matches `.after`.
- **CLAUDE.md sentence** is true of the code. `Trend on` is added only when `on_value` takes more than one value, and `Start` only when `trend_start` does. A single-window, single-scale table keeps the 7-column shape (pinned by the existing `cols_summary` tests).
- **R change, fresh read.** `trend$trend_start` is reached only when the column exists (exact `%in% names` check first), so partial matching on a plain data.frame is not a risk. Rows of `out` line up with `trend`, because `mutate`/`select` on the ungrouped table do not reorder them.

Non-blocking observation, not a defect: the prose "The trend table shows two rows per variable" (peace-fwcp.Rmd:202, kootenay-lake.Rmd:210) means per variable *and period*. It predates this diff, and the new adjacent pairs plus the `Start` column make it read more accurately than before.
