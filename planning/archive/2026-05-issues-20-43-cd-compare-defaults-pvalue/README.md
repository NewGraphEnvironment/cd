## Outcome

Two tightly coupled `cd_compare()` improvements landed together on
one branch (issue #20 explicitly says "should land together" with
#43). #20 wired the de-facto vignette framing
(`window_a = 2015:2025`, `window_b = 1951:1980` — recent decade vs
WMO-style standard normal) into the function as defaults so first-time
users get a sensible answer with `cd::cd_compare(ts)`. #43 added a
`test = "t"` argument (default) that emits a `p_value` column via
Welch's two-sample t-test on the annual values within each window;
`test = "wilcox"` switches to Mann-Whitney U; `test = NULL` skips and
drops the column. Rows where either window has < 8 non-NA years get
NA + a single batched warning naming affected variable/period rows.
Both regional vignettes now show bare `cd::cd_compare(ts)` recipes
and report both p-values side-by-side (`Δ p (windows)` from
cd_compare + `Trend p (75-yr)` from cd_trend's MK), framed in
narrative as different-question tests. Mid-PR the user flagged that
the cumulative-impact section ("Recent vs Pre-warming") was buried
~300 lines down between Snowpack and Spatial Pattern with a
methodological-sounding heading; reordered it to come directly after
Trends and renamed to "Recent Decade vs Pre-Warming Reference" so
the headline +2 °C number lands before DTR/Snow/Spatial drill-down.
Compare-table chunk recomputes `cmp` from cached `ts` to flow the
new column through without re-running the heavy precompute scripts;
`data-raw/<vignette>_vignette_data.R` updated for next refresh.
181/0 tests, lint clean, both vignettes render.

Closed by: PR #73 (squash `338c7e5`) → release commit `6bdd64b
Release v0.3.0` → tag `v0.3.0`.
