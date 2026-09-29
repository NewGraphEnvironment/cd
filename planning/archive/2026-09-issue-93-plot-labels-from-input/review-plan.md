# Plan review (#93) — Plan agent, 2026-09-28

Written by the parent session from the agent's reply (Plan agents have no Write tool).

1. Gap (high): distinct variables sharing a long_name merge into one facet in cd_plot_comparison() (probed: 2 variables -> 1 facet). Issue's own multi-station use case hits it.
2. Assumption: cd_variables() says vpd unit "Pa"; data is hPa (cd_derive.R:93, backfill_edh_all.py:26, vignettes label hPa/dec, values 1.5-4.2).
3. Scope: raw-input rule inline in cd_plot_timeseries is a per-function copy; cd_summary(cd_trend(raw)) still prints registry anomaly unit (% for prcp). Roxygen "same rules as cd_summary()" untrue on raw input.
4. Assumption: raw input with unresolved anomaly_type shows a carried unit (anomaly unit over raw values). Pick one rule, test both directions.
5. Gap (low): NA variable/period rows -> x[lgl, ] yields all-NA rows -> misleading duplicate error from series_check. Use which().
6. Behaviour changes for existing callers belong in PR body/NEWS: dup years error, conflicting metadata errors, raw pct_normal loses "(%)", cd_compare gains a column. Vignettes/downstream reports probed safe.
7. cd_compare long_name column: no downstream breakage (select-by-name everywhere; appended after p_value).
8. meta_resolve on factor/grouped/zero-row inputs behaves; cd_plot_comparison(cmp[0,]) and labels["a"] rownames warning pre-date branch.
9. Acceptance: add integration test plot label == cd_summary Parameter (Unit); render both vignettes, not just Peace.
10. Ordering: fine.
11. Missing tests: shared long_name; raw unit cases (unresolved type w/ unit, pct_point_diff, absolute); dup in other variable no error; NA variable rows; cd_compare test="t" column order; partial-NA long_name equal to registry; compare->plot end to end; consistency test; factor input.
