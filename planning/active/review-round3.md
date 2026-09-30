# Review round 3: #98 (label_disambiguate, cd_summary Trend on)

Reviewer: code-check round 3, 2026-09-30. Worked in a scratchpad copy of the repo. The three changed test files pass there with `NOT_CRAN=true`: anomaly 63, summary 73, plot_comparison 13, with 0 failed, 0 errors and 0 skipped.

## Mechanism

Every earlier finding rests on one assumption: that `variable` is what makes a printed thing unique. The code and its prose assumed one variable meant one series, one label and one row, and reasoned about distinctness from that. Nobody enumerated the real map from row key to printed label. The row key is `(variable, period, trend_on, trend_start, region)`, and the map from it to a label is many-to-many. Here is how each finding broke the assumption:

- **Loop ended with a label still shared.** The code assumed one suffix per variable makes that variable's label unique.
- **`n_distinct(variable)` bound.** It assumed one label per variable, but a variable can carry a different label in each period.
- **Docs advised binding per-region tables before summarising.** They assumed `variable` identifies a series across regions.
- **`"a) (a"` never settles.** It assumed `label + " (v)"` can never equal another variable's label.

Where the mechanism reaches in this diff, with a verdict for each:

1. **`label_disambiguate()` "shared" test** (R/cd_anomaly.R `shared_find`). It is keyed on distinct `(variable, label)` pairs, so one variable repeated across periods, scales or starts is correctly not a collision. **OK.**
2. **Pass bound = distinct `(variable, label)` pairs.** I ran a stress test in the copy that the enumeration did not cover:
   - 20,000 random inputs, each with 2-4 variables drawn from `a, b, c, q1, q_2, ab`.
   - One of those names equals the base label (`"a"`).
   - 2-7 rows each, with labels made of 0-4 random `(variable)` suffixes.

   Results: the bound was never exceeded, every input settled, and the worst case needed one pass fewer than the pair count. **OK** for names without parentheses. The contrived case is accepted and pinned.
3. **Abort after the loop.** It fires, and the test pins the rendered label (`"still shared: Q \\(a\\)"`), not only a field name. **OK.**
4. **`max_passes` default.** It is evaluated lazily, before `label` changes. It is 0 on empty input, which returns `character(0)`. **OK.**
5. **Factor `variable`.** It is converted with `as.character()` before any use, and a test covers it. **OK.**
6. **`cd_summary()` row identity.** Stations are told apart by the suffix and scales by `Trend on`. Rows that still match are the `trend_start` rows told apart only by `Years` (#106, out of scope) and bound summaries (documented). **OK.**
7. **`Trend on` rule.** It uses the same expression as the `Unit` rule (`col_or_na(trend, "trend_on") %in% "value"`), so there is no second derivation. It is decided for the whole table, which is a superset of the per-series need and harmless. Zero rows gives no column. **OK.**
8. **`cd_plot_comparison()`.** Facets are keyed on variable plus label, and labels go through the helper. **OK.**
9. **`cd_summary` roxygen and Rd.** They match the code, and the Rd is regenerated. **OK.**
10. **`cd_plot_comparison` roxygen and Rd.** **OK.**
11. **The helper's roxygen ("every consumer that prints labels calls it") and CLAUDE.md ("Anything that prints a label per variable passes it through `label_disambiguate()`").** **FALSE for `cd_plot_timeseries()`.** See the finding below.
12. **`cd_plot_timeseries` roxygen ("resolved by the same rules as `cd_summary()`").** It now differs from `cd_summary()` for a shared `long_name`. This is part of the same finding.
13. **Claims made in test comments.** I checked each one:
    - "two variables, three passes": traced by hand; it needs 3 passes over 4 pairs.
    - "registry long_names are unique": asserted in the test and true for all 15.
    - The crafted `"a) (a"` case aborts as the test states.

    **OK.**

## Findings

- **[severity: fragile]** CLAUDE.md (consumer-chain paragraph) and R/cd_anomaly.R (the `label_disambiguate` roxygen: "every consumer that prints labels calls it"). Both state a universal rule that `cd_plot_timeseries()` does not follow. It builds its y-axis label from `meta$long_name[1]` (R/cd_plot_timeseries.R:73) and never calls `label_disambiguate()`, although it receives the full `x` with every variable. I measured this in the copy with two stations sharing `long_name = "Mean discharge"`:
  - `cd_summary()` gives `"Mean discharge (q_site1)"` and `"Mean discharge (q_site2)"`.
  - `cd_plot_timeseries(x, "q_site1")` and `cd_plot_timeseries(x, "q_site2")` both give the y label `"Mean discharge (m3/s)"`.

  So a station's figure and its table row name it differently, and two station figures are labelled identically. The `cd_plot_timeseries` roxygen also still says its label is "resolved by the same rules as `cd_summary()`". The code is not wrong, because each plot shows one variable the caller chose. The problem is that the new shared-helper rule overclaims its reach, and a later contributor would trust it. There are two fixes:
  - Narrow both sentences, for example "anything that labels several variables side by side".
  - Or pass the timeseries label through `label_disambiguate(x$variable, …)` over the full `x` and pick the plotted variable's label.

No bugs or security issues found in the code paths changed by this diff.

/Users/airvine/Projects/repo/cd/planning/active/review-round3.md
