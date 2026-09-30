# Code review — round 3 (#106, adversarial: row identity)

## Clean
No issues found.

Row identifiers of a `cd_trend()` row: `variable`, `period`, `trend_start`,
`trend_on` (plus baseline and AOI, which are not stored and excluded by the
brief). In `cd_summary()` these map to `Parameter` (via `label_disambiguate()`),
`Period`, `Start`, `Trend on`, `Region`. Constructions run against the source
tree (`devtools::load_all()`, scripts in the session scratchpad `probe3*.R`):

- Shared `long_name` on two stations × two windows: 4 rows, `Q (q_a)` / `Q (q_b)` ×
  2000/2004, `anyDuplicated(Parameter, Period, Start) == 0`.
- Mixed scales with *disjoint* windows (`bind_rows(cd_trend(x, 2000), cd_trend(ano, 2004))`):
  both `Trend on` and `Start` added, values aligned.
- Mixed scales × two windows on a plain `data.frame` (not tibble) with `region_name`:
  column order `Parameter, Period, Trend on, Start, …, Region`, 4 distinct rows;
  `add_column(.after = "Trend on")` works on a data.frame.
- Integer start bound to double start (`cd_trend(x, 2000L)` + `cd_trend(x, 2004)`): `Start` added, correct.
- Requested start before the data (`c(1990, 2000, 2008)`, 2008 window dropped for <3 years):
  the two surviving rows have identical stats and are told apart only by `Start`
  (1990 / 2000) — the documented "start year asked" behaviour.
- Input grouped by `trend_start`, and `rowwise()` input: identical to ungrouped output.
- `NA` start beside a real one; a `Date` start: shown unchanged, aligned.
- Per-region summaries bound together, one region single-window: that region's
  `Start` is `NA` — the documented behaviour, not a wrong value.
- Both vignettes' committed `trn` (`inst/vignette-data/{peace_fwcp,kootenay_lake}.rds`)
  after the hidden-chunk reorder: 118 rows each, 0 duplicates on
  `Parameter/Period/Start`, `Start` and `Years` equal `trn_tbl$trend_start` / `n_years` row for row.

No input found where the function now errors and did not before: the new block
only runs when `trend_start` is present with >1 distinct value, `out` and
`trend` share row order, and `out` never already holds a `Start` column.

Not a finding: `cd_trend(x, c(2000, 2000))` (or binding the same trend twice)
gives two summary rows identical on every column. The input rows are the same
trend twice — `cd_trend()` does not deduplicate `trend_start` — so there is
nothing for `cd_summary()` to distinguish; pre-existing and outside this change.
