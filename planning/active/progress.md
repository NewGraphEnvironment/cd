# Progress: EDH migration

## Session 2026-04-12 (evening)

**Context from prior day:** Got rate-limited twice by CDS. Researched alternatives (#35), benchmarked EDH Zarr at 5× faster with no rate limits and same data. Filed #36 for migration. Pivoting now.

**Completed:**
- Branched off main: `36-edh-migration`
- Stashed and restored `scripts/test_edh_era5_land.py` on new branch
- Set up PWF files (this document, task_plan.md, findings.md)

**Next:**
- Commit planning baseline
- Write `scripts/backfill_edh.py` — the pragmatic Python backfill (Phase 2)
- Test on single year before full run

**Commits this session:** _to be appended_
