# Plan review — #98 (Plan agent, 2026-09-30)

Verdict: sound, no blockers. Findings and disposition:

| # | Category | Finding | Disposition |
|---|----------|---------|-------------|
| 1 | Gap | Repeat loop bounded by n variables can end with labels still shared when variable names contain parentheses (`"a) (b"` + `"b"`) — silently | Fixed: post-loop check aborts; `max_passes` arg lets a test reach it |
| 2 | Gap | Plot collision facets change from `Q (a),Q (b),Q (a)` to `Q (a) (a),Q (b),Q (a) (c)`; test only counted facets | Fixed: test asserts labels; goes in NEWS |
| 3 | Gap | `Trend on` should use `%in% "value"` like `Unit`, not coalesce + title-case | Fixed |
| 4 | Gap | One variable, different long_names by period — untested | Test added |
| 5 | Gap | NA `variable` not refused by `series_check()`; shared label gets `" (NA)"` | Accepted: honest output; noted here |
| 6 | Gap | Suffixes/columns decided per call; separately summarised tables bound together differ | Documented in `cd_summary()` details |
| 7 | — | Grouped input fine | No change |
| 8 | Note | Several `trend_start` values → rows differ only by `Years` | Filed as follow-up issue |
| — | Acceptance | Combined stations × scales × region test | Added |
