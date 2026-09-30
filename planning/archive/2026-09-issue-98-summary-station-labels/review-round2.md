# Code-check review, round 2 (#98)

Reviewer: subagent, 2026-09-30. Diff: `review.diff` (planning/ excluded), HEAD bb6718d.
All probes were run in a copy of the repo under the session scratchpad. The repo itself was not modified.

## Clean

No issues found.

## What was checked

- **Test run (copy, `NOT_CRAN=true`).** Results per file:
  - test-cd_anomaly: 62 pass
  - test-cd_summary: 73 pass
  - test-cd_plot_comparison: 13 pass
  - test-cd_trend: 28 pass
  - test-cd_plot_timeseries: 39 pass

  All five had 0 fail, 0 error and 0 skip.
- **The new `max_passes` default expression.**
  - The default is evaluated lazily, at `seq_len(max_passes)`. That happens after `variable <- as.character(variable)` and before `label` changes, so it counts the original pairs.
  - A factor `variable` is read by name, and a test covers it.
  - Zero-length input gives a 0-row frame, so `max_passes` is 0, the loop is skipped and `character(0)` is returned. A test covers it.
  - An NA `variable` or NA label goes through `unique()`/`duplicated()` without error and gives `"Q (NA)"` / `"NA (a)"`. This is accepted by convention.
  - Neither caller can pass a factor `label`: `coalesce()` over `col_or_na()` (character) and `as.character(variable)` always yields character.
- **Is the bound sufficient for ordinary names?**
  - Fuzz: 30,000 random sets over 3 plain variable names, 2 to 12 rows each, with labels drawn from 121 chained suffixes (`Q`, `Q (a)`, `Q (a) (b)`, ...).
  - The most passes any set needed was 3. The largest value of (passes needed − distinct pairs) was −1, and 0 sets exceeded the bound.
  - A hand-built 7-pair chain needed 6 passes.
  - A second fuzz of 20,000 sets over 4 plain names and over `{a, b, "a) (b", "b) (a"}` gave 0 aborts.
- **Non-convergence, not reported as a finding.** When one variable's name contains `) (` followed by another variable's name, the rule can fail to converge. Minimal set:
  - variables `"a"` and `"a) (a"`
  - `a` carries `"Q"`; `"a) (a"` carries `"Q"` in one period and `"Q (a)"` in another

  The rule then never settles at any bound: tried up to 50 passes. So `cd_summary()` and `cd_plot_comparison()` abort on it, where main plotted it. The comment's "so that is the bound" reads as a sufficiency claim, and it holds only for names without that shape. The input is deliberately built to collide, it falls under the accepted "contrived label collisions" tradeoff, and the failure is a loud abort whose remedy fits the case ("Rename the variables"). Recorded so nobody rediscovers it; no change recommended.

  Separately, `label_disambiguate_enum.R` uses `"a) (b"`, and its "0 aborts" is true for that space. It does not reach the `"a) (a"` shape.
- **cd_summary `Trend on`.**
  - The predicate `%in% "value"` is the same one `meta_resolve(raw=)` uses, so it cannot be NA and `if_else` is safe.
  - A zero-row table gives `unique(logical(0))` of length 0, so no column is added. A test covers it.
  - Plain `data.frame` input: `tibble::add_column(.after = "Period")` works and returns a data.frame.
  - Grouped input is ungrouped first.
  - A factor `variable` with a shared long_name across mixed scales gives 4 distinct rows.
  - `tibble` is in Imports.
- **Doc text.**
  - The rewritten cd_summary paragraph now says per-region summaries (each with its `region_name`) bound together can differ in suffixes and have an NA `Trend on`. That is accurate, and the round-1 advice to bind trend tables first is gone.
  - The `@return` addition matches the code.
  - The cd_plot_comparison `@param` text matches the code.
  - The CLAUDE.md claim that both consumers call the helper is true. `cd_plot_timeseries()` uses one label per plot (`meta$long_name[1]`), so it is not a missed consumer.
- **Regressions.**
  - The cd_plot_comparison facet key (variable + label) is unchanged.
  - Plain-name output is identical to the old single-pass rule wherever one pass sufficed.
  - The one intended change is a chained collision such as `"Q (a) (a)"`, which goes in NEWS.
