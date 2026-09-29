# Plan review — #92 (Plan agent, 2026-09-28)

Returned as reply text (Plan agent has no Write tool); transcribed here.

- **Blocker 1 — factor `variable` picks the wrong registry row.** `lookup[.data$variable]` indexed by factor code, so `factor("q_mean")` resolved to tmean's type. Same in cd_summary. → fixed via `match(as.character())`; test + mutation M2.
- **Blocker 2 — extra baseline columns break the join** (`.x/.y` suffixes → misleading unresolved abort). → join only `variable, period, baseline_mean`; test + M4.
- **Gap 3 — types can conflict within one series** under row-wise coalesce. → abort on >1 `anomaly_type` or `unit` per variable/period; test + M3.
- **Gap 4 — take trend metadata from the in-loop subset**, not a post-hoc distinct join (would duplicate rows). → adopted.
- **Gap 5 — raw-value trend would mislabel with the anomaly unit.** → `anomaly_type`/`unit` pass through only on anomaly input; `long_name` always; test + M5.
- Gap 6 (named vectors) — implementation returns unnamed vectors. Gap 7 (NA check before invalid-type check) — ordered so.
- Gap 8 — `cd_trend()` on zero rows returns a column-less tibble, so `cd_summary()` fails. **Pre-existing; not fixed here.**
- Gap 9 — `pct_normal` with `baseline_mean == 0` → NaN/clamped. → documented in the input contract.
- Assumption 10 — vignettes load committed rds; nothing rbinds trend output. Confirmed safe.
- Acceptance 11 — before/after compare must run the new path. → the snapshot runs extract → anomaly → trend → summary.
- Acceptance 12 — cd_compare leg and plain-value trend shape pass on main; regression tests, not fail-first.
- Scope 15 — `cd_plot_timeseries()` ignores carried `long_name`/`unit`. → follow-up issue.
