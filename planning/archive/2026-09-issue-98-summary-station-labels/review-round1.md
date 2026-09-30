# Code-check review, round 1 (#98)

Reviewer: subagent, 2026-09-30. Diff: `review.diff` (planning/ excluded). Tests for
test-cd_summary.R, test-cd_anomaly.R and test-cd_plot_comparison.R pass in a copy of the repo
(0 failed, 0 error, 0 skipped).

## Findings

- **[severity: fragile]** R/cd_anomaly.R:191-197 — the pass bound `max_passes = length(unique(variable))` is not an upper bound on the passes the rule needs, and the roxygen claim "Ordinary names settle within one pass per variable; names built to collide (parentheses in `variable`) might not" is false. The number of passes depends on how long the chain of colliding labels is, and one variable can carry a different `long_name` in each period (meta_check allows that), so the chain can be longer than the number of variables even when no variable name has a parenthesis. Minimal repro, reproduced in a copy:

  ```r
  label_disambiguate(c("a", "e", "e", "e"), c("Q", "Q", "Q (a)", "Q (a) (a)"))
  #> Error: Could not give each variable its own label; still shared: Q (a) (a). ...
  ```

  With 2 variables the loop stops after 2 passes, but a third pass would settle it: `"Q (a) (a) (a)"` / `"Q (a) (a) (e)"`. A fuzz over 5 plain variable names and 10 labels drawn from `Q`, `Q (a)`, `Q (a) (a)`, … aborted in 11 of 40,000 draws at the current bound. With `max_passes` set to the number of distinct (variable, label) pairs it aborted in 0. The effect is that `cd_summary()`, and `cd_plot_comparison()`, which plotted such input before this branch because its facets are keyed on variable, now error on valid input. The input is contrived, so the practical risk is low. The error is loud, not silent. However, the comment's guarantee is wrong, and so is the `cd_plot_comparison` roxygen "until each variable's label is its own" (R/cd_plot_comparison.R:11-12, man/cd_plot_comparison.Rd). A bound of `nrow(unique(data.frame(variable, label)))` fixes it. So does the count of distinct labels plus one. Either way, the comment should stop saying that only parenthesised variable names can fail.

- **[severity: fragile]** R/cd_summary.R:24-27 (and man/cd_summary.Rd) — the new advice "tables summarised separately and then bound together (one per region, say) can differ in suffixes and columns; bind the trend tables first and summarise once" leads to the defect this issue fixes when it is applied to the example it names. Per-region trend tables from `cd_extract()` on different AOIs carry the same variable names (`tmean` in each). `bind_rows(trend_A, trend_B) |> cd_summary()` therefore gives pairs of rows with the same Parameter/Period and nothing to tell them apart. `label_disambiguate()` sees one variable and adds no suffix. `region_name` is a single scalar, so it cannot label both regions. The reader loses the region identity that summarising per region with `region_name` and then binding keeps. The only cost of that per-region approach is a `Trend on` column that is `NA` for regions on one scale, plus possibly different suffixes. The advice holds only when variable names are already distinct across the tables being bound, for example wet's per-station names. It should say that, or recommend summarising per region with `region_name` and binding the summaries.

No other issues found. Checked:
- The `Trend on` logic: NA/missing/other values read as Anomaly, and this matches `meta_resolve(raw=)`.
- Zero-row input and factor `variable`.
- `tibble` is in Imports.
- `label_disambiguate` gives the post-condition of distinct labels per variable whenever it returns (fuzz: 0 violations).
- The `cd_plot_comparison` facet key is unchanged.
- The CLAUDE.md claim that both consumers call the helper is true. `cd_plot_timeseries()` draws one label per plot, so it is not a sibling that was missed.
