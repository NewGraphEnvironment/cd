# Review p2 round 2 — #93 Phase 2 (cd_compare long_name pass-through, cd_plot_comparison facets)

Reviewed the staged diff in a copy (`scratchpad/p2r2`), repo files untouched. Relevant test files
(compare, plot_comparison, trend, summary, plot_timeseries) all pass with `NOT_CRAN=true`.

## Mechanism

**Label *resolution* is single-sourced; label *identity* is not.** Every consumer gets the
label from `meta_resolve()` (carried `long_name` -> `cd_variables()` by variable), so the
resolved string cannot diverge between functions. What diverges is what each function
assumes the string *is*:

- `cd_plot_comparison()` uses the label as the **facet key** (`facet_wrap(~ param)`), so it
  must be unique per variable. It makes it unique in one pass: detect duplicates among
  `(variable, param)` pairs, then append `" (variable)"`. Uniqueness is checked *before* the
  rewrite and never after.
- `cd_summary()`, `cd_plot_timeseries()`, `cd_trend()`, `cd_compare()` treat the label as
  **display text only**, never deduplicated. `cd_summary()` also drops `variable`, so its
  `Parameter` column is the only identifier a reader has.
- The terminal fallbacks are two lists that do not agree: `cd_summary()` /
  `cd_plot_comparison()` fall back to the variable name; `cd_plot_timeseries()` falls back to
  the value column name (`"anomaly"`/`"value"`), pre-existing.

Where it reaches:

| function | label source | unique per variable? | fallback |
|---|---|---|---|
| meta_resolve | carried -> registry | n/a | NA |
| cd_trend / cd_compare | meta_resolve, written to `long_name` only if column present | no (per variable/period via meta_check) | NA |
| cd_summary | meta_resolve | **no**, and no `variable` column | variable |
| cd_plot_timeseries | meta_resolve | single series | `val_col` |
| cd_plot_comparison | meta_resolve + append | yes, but only one pass | variable |

## Findings

- **[fragile]** R/cd_plot_comparison.R:37-39 — the disambiguation is not closed under its own
  output: an appended label can equal another variable's real label, and the two facets merge
  again. Measured: `variable = c("a","b","c")`, `long_name = c("Q","Q","Q (a)")` puts `a` and
  `c` both in facet `"Q (a)"`, silently plotting two series in one panel. Contrived input, so
  low priority, but it is the same failure the fix exists to prevent. The mechanism is
  "uniqueness checked before the rewrite, not after". Keying the facet on `variable` and
  using the label only through a `labeller` would close the class; re-checking uniqueness
  after appending closes it too.

- **[fragile]** tests/testthat/test-cd_plot_comparison.R:23-58 — no fixture can tell the
  intended dedupe (per *variable*) apart from a plain per-*row* one. Mutation:
  `shared <- x$param %in% x$param[duplicated(x$param)]` (duplicates over rows) leaves all 24
  compare + plot_comparison tests green. That mutant appends `" (tmean)"` to every facet of
  any variable compared over more than one period, which is the default workflow
  (`cd_compare()` over several seasons). The only multi-period fixture (line 47) is one where
  the variable is shared anyway, so both implementations give the same answer. This is
  "A fixture that cannot reach the failure mode": the axis the code depends on, one
  variable in several periods with a unique label, is never exercised. One registered
  variable in two periods with `expect_identical(unique(p$data$param), "Mean temperature")`
  pins it.

- **[fragile]** R/cd_summary.R:42 — outside this diff but the same mechanism: the
  "one long_name, many stations" case the plot now handles produces indistinguishable rows in
  `cd_summary()` (two `Parameter = "Mean discharge"`, `Period = "Annual"` rows with different
  slopes, no `variable` column). Measured with `q_site1`/`q_site2`. The comparison plot now
  says `"Mean discharge (q_site1)"` for a series the table calls `"Mean discharge"`, and the
  table cannot say which row is which. It predates the branch (cd_summary has never carried
  `variable`). Worth an issue if not already covered by cd#97, not a blocker here.

- **[info, pre-existing, out of scope]** R/cd_plot_timeseries.R:67 — fallback is `val_col`,
  not the variable name, so an unregistered, unlabelled series reads "anomaly" on the y-axis
  while `cd_summary()`/`cd_plot_comparison()` call it by name. Same shape as before the
  branch (`HEAD~1` fell back to `val_col` too). Listed because it is the third disagreeing
  fallback. Reviewed and committed in the previous commit.

## Vacuity check on the new tests

- `test-cd_compare.R` long_name tests: not vacuous. Mutations: dropping `meta_check` fails
  "errors on two long_names"; dropping the resolve step fails "fills an NA long_name" and
  "partly NA ... matches the registry"; always emitting `long_name` fails "adds no long_name
  column" (plus 3 older tests via `expect_named`). A missing column makes `cmp$long_name`
  NULL, which `expect_identical(NULL, "...")` rejects.
- `test-cd_plot_comparison.R`: the named-vector lookups (`param["q_mean"]`) return NA for an
  absent name, and `expect_identical(NA, "...")` fails, so they are not vacuous. The
  `expect_setequal` calls compare against non-empty `p$data$param` (never `character(0)`).
  The gap is the missing fixture above, not a vacuous assertion.
- `expect_error(..., "long_name")` matches only the interpolated column name, but no other
  error path in `cd_compare()` mentions it, and the mutation shows it fires. Acceptable.

No bugs in `cd_compare()`: the `distinct()` join is one row per variable/period because
`meta_check()` runs on the resolved column first; `series_check()` ungroups first; zero-row
input returns early from `meta_check()`.

Checklist: read the Mechanisms section and the R rules on testthat, named lookups and vacuity
(the file is 510 KB; the index-only rules outside those areas were not read line by line).
