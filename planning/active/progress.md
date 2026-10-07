# Progress — tmax/tmin daily aggregation uses UTC-day, not local-time day (#37)

## Session 2026-10-06

- Plan-mode exploration — phases approved by user
- Created branch `37-tmax-tmin-daily-aggregation-uses-utc-day` off main
- Scaffolded PWF baseline from issue #37 with approved phases
- Next: start Phase 1
- Phase 1: `monthly_from_daily()`, `read_cog_days()` + 7 offline cases (35/35, mutation-checked); cube grid == live COG grid
- Phase 2: `backfill_edh_all.py` tmax/tmin on local days + local-year gate; `backfill_edh_tmax_tmin.py` now cube -> monthly; STEP 2 capped at latest local year; 2002 EDH vs cube max |diff| 1.3e-5 degC
- Phase 3 (pre-publish): monthly history regenerated from cube; `tmax_tmin_republish.R` dry-run; bias measured and its sign found opposite to #37's premise; old values reproduced from EDH; plan review folded in (G3, G5, G7, G8); publish moved to merge
- Phase 4: vignette data regenerated against local COGs (other 13 vars unchanged by value; no prose edits needed); roxygen day-boundary docs; stale UTC mentions; README roadmap; CLAUDE.md; research/tmax_tmin_day_boundary.md; devtools::test 491/0
