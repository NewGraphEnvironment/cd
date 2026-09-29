# Review round 3 — #97 (the plan-review fixes, and the cross-reference sweep)

## Clean

No issues found in the diff.

## The four fixes

Probed in a temp copy (`scratchpad/r3.*/cd`), repo untouched.

- `R/cd_compare.R:78` comment ("the unit of `difference` depends on `method`") — true:
  `mean_diff` is in value units, `pct_change` in percent. `cd_compare()` still carries
  `long_name` only.
- `R/cd_plot_timeseries.R:6-12` ("resolved by the same rules as [cd_summary()]") — true on
  both inputs now: the plot calls `meta_resolve(dat, raw = val_col == "value")`, and
  `cd_summary()` calls `meta_resolve(trend, raw = trend_on == "value")` on columns that
  `cd_trend()` already resolved the same way. The one case where they differ is a raw-value
  trend table with no `trend_on`, which is the accepted back-compat default.
- New test "cd_trend errors when a raw series carries two units": it fires. Putting back the
  pre-#97 carry (raw input carries only `long_name`) turns it red (test-cd_trend.R:147),
  along with the four raw-carry assertions at :101-112.
- New test "cd_summary reads a trend without trend_on as an anomaly trend": it fires.
  Reading a missing `trend_on` as `"value"` turns it red (test-cd_summary.R:215). The #92
  tests at :60 and :82 also go red, so those older tests already pinned this rule for a
  carried unit. The new test adds the registry-fallback path (registered prcp → `"%"`).
- Suite in the temp copy: `[ FAIL 0 | PASS 348 ]`. The one warning comes from the unchanged
  `test-cd_plot_comparison.R:10`. `devtools::document()` regenerates `man/` byte-identical
  to what is staged.

## Mechanism behind the two stale-doc findings

Prose in one function restated the behaviour of **another** function, and the restatement
carried a qualifier that described that other function's current behaviour:
"as in cd_trend()" plus "only long_name passes through" in cd_compare, and
"for anomalies, resolved by the same rules as cd_summary()" in cd_plot_timeseries. When
#97 changed `cd_trend()` and `cd_summary()`, the prose describing them in *their own* files
was updated. The copies in files the change had no reason to open were not. It is the
"one fact derived twice" shape applied to documentation. A cross-reference that only
points ("see [cd_anomaly()]") cannot go stale this way. One that restates and qualifies
("same rules as X, for anomalies") can, and nothing checks it.

## Every restatement of cd_trend() / cd_summary() / meta_resolve() metadata handling

Found with grep over R/, man/, vignettes/, README*, NEWS.md, CLAUDE.md. man/ mirrors the
roxygen line for line and was regenerated identical, so only the R/ source is listed.

| place | claim | still true? |
|---|---|---|
| R/cd_trend.R:11-18 (`@return`) | `trend_on`; `anomaly_type`/`unit`/`long_name` passed through; on raw values `unit` kept only for absolute/pct_point_diff; cd_summary reads them | yes. An unregistered raw series with no `anomaly_type` also loses its unit (NA type is outside the kept set), which "kept only for absolute and pct_point_diff" covers |
| R/cd_trend.R:48-49 (comment) | on raw values the anomaly unit describes the slope only for absolute/pct_point_diff; trend_on tells cd_summary | yes |
| R/cd_summary.R:7-12 | labels/units from carried columns "carried by cd_trend()", else registry "by the same rules as cd_anomaly()" | yes for anomaly trends. For raw trends the next sentence (:12-16) states the exception in the same paragraph |
| R/cd_summary.R:12-16 | on `trend_on == "value"` Unit only for absolute/pct_point_diff; agrees with cd_plot_timeseries | yes, and pinned by the parity test. "a slope in mm" names prcp as the example, not a general claim |
| R/cd_anomaly.R:27-28 | optional columns resolved row by row, fall back to cd_variables() | yes |
| R/cd_anomaly.R:35-39 (`unit` item) | used by cd_summary and cd_plot_timeseries; on raw values both show it only for absolute/pct_point_diff | yes. It does not mention that cd_trend now also carries `unit`, but it makes no claim that it doesn't |
| R/cd_anomaly.R:40-42 (`long_name` item) | carried through to cd_trend and cd_compare; used by summary/plots | yes |
| R/cd_anomaly.R:45-48 | one anomaly_type/unit/long_name per series; overriding type gets no registry unit | yes. meta_check now also applies to raw input in cd_trend, which is the intended error |
| R/cd_anomaly.R:161-169 (`meta_resolve` doc) | raw=TRUE keeps unit only for absolute/pct_point_diff; `raw` recycled row by row | yes (`rep_len`) |
| R/cd_compare.R:43-47 (`@return`) | `long_name` "resolved as in cd_trend()" | yes. long_name resolution did not change |
| R/cd_compare.R:78 (comment) | fixed this round | yes |
| R/cd_plot_timeseries.R:6-12 | fixed this round | yes |
| R/cd_plot_timeseries.R:62 (comment) | carried columns first, then cd_variables(), "as in cd_summary()" | yes |
| R/cd_plot_comparison.R:34 (comment) | long_name, then registry, then name | yes, unaffected |
| CLAUDE.md:34 | contract in ?cd_anomaly; rules in series_check/meta_resolve/meta_check | yes |
| README.md:35-38 | cd_trend on anomalies → cd_summary | yes, anomaly path unchanged |
| vignettes/*.Rmd | every cd_trend call is on `ano` (anomalies); no prose about units on raw trends | yes. The `prcp mm/yr` label is filed as #102 |
| NEWS.md | no unreleased section. 0.5.0 says cd_trend carries `anomaly_type`/`unit` "only when trending anomalies" and 0.5.1 says cd_compare has "no unit: it works on raw values". Both are released history, and #97 supersedes the first | history, not stale. The release entry for #97 should say it supersedes the 0.5.0 sentence: cd_trend gains `trend_on`, raw input now carries `anomaly_type`/`unit`, and cd_summary's Unit for a raw pct_normal trend goes from `%` to NA (G1 in review-plan.md) |

Planning notes: nothing in planning/active/*.md contradicts the code. findings.md:21 and
task_plan.md:15 describe the state before #97 ("cd_trend() drops the columns") as the
problem statement, which is correct in that role.
