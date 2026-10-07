# Progress — STEP 5 can publish a catalog listing only the variables that run rewrote (#89)

## Session 2026-10-07

- Plan-mode exploration — phases approved by user (strict abort chosen over merge-into-live)
- Created branch `89-step-5-can-publish-a-catalog-listing-onl` off main
- Scaffolded PWF baseline from issue #89 with approved phases
- Next: start Phase 1
- Plan review (Plan agent) returned 1 blocker + 4 gaps; dispositions in `review-plan.md`. Biggest: `--size-only` would skip the rebuilt `catalog.json` (G1)
- Phase 1: `cog_expected()`, `publish_problems()`, `catalog_problems()`, `catalog_item_years()` in `scripts/_lib.R`; 53/53 offline checks; mutation table in findings.md
- Code-check round 1: a COG recorded as written but absent on disk passed the guard. Fixed (`absent` branch)
- Phase 2: update pipeline wired: STEP 1 live keys + years check, guard before STEP 5, built-catalog readback, catalog written outside `cog_dir` and uploaded with `aws s3 cp` after the sync, live readback
- Phase 3: stage 3 uses the same helpers; stricter (stale `.tif` refused)
- Code-check round 2 clean; round 3 found the stale-catalog-after-failed-upload hole inside the G1 fix, so STEP 1 now checks years too. Loop ended by enumeration (findings.md)
- Filed #119 (partial-sync repair, plan review A3)
- Dry run exit 0; 54/54 offline checks; 491 package tests pass
