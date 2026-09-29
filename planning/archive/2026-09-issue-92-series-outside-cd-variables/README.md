## Outcome

`cd_anomaly()` returned a silent `NA` for any variable outside `cd_variables()`, which blocked wet#25 from using cd's statistics on streamflow. The consumer chain now takes any series in cd's long format: optional `anomaly_type`, `unit` (the anomaly's unit, same meaning as `cd_variables()$unit`) and `long_name` columns are resolved row by row with a registry fallback, an unresolvable type is an error, `cd_trend()` carries the metadata through, and `cd_summary()` uses it. The input contract is documented in `?cd_anomaly`. The lesson came from review: each entry point had re-derived its own input assumptions (ungrouped, keyed by variable/period, one row per year, metadata resolved before checked), so three rounds each found a fix applied to one copy and missed in the next — the last one a plain `ungroup()` that turned station-grouped input from an error into silent pooling. The fix was structural: `series_check()`, `meta_resolve()` and `meta_check()` shared by every caller, and the loop ended by enumerating all exports against them rather than by a clean round. Plot labels for carried metadata were split out to #93.

## Measurement

- Tests 256 → 278 pass; 21 mutations (every new guard, each chain caller's check) all turn a test red; unmutated, none.
- ERA5 path unchanged: regional Peace and Kootenay `cd_trend(ano)` reproduce the committed `trn` exactly and `cd_summary()` is identical; example-catalog recipe identical before/after. Only visible change on that path: `cd_trend(ano)` gains `anomaly_type`/`unit` columns, and `cd_anomaly()` drops a stray `names` attribute.
- All committed vignette series have 0 duplicate (variable, period, year) keys, so the new duplicate guard cannot break a render.
- Code-check: 3 rounds, 10 findings, 10 fixed, 2 inside earlier fixes; plan review found 2 blockers (factor-code registry lookup; baseline join suffixes) before implementation.

## Evidence

`planning/archive/2026-09-issue-92-series-outside-cd-variables/review-*.md`

Closed by: commit e3d9cae / PR #94
