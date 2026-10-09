# Plan review — #123 (Plan agent, 2026-10-08)

Verdict: no Blockers. Each finding with its disposition:

| id | type | finding | disposition |
|---|---|---|---|
| A1 | Acceptance | Dry-run in Oct 2026 exits at "No year complete in local time beyond 2025" (`pipeline_update_edh.R:591`), before STEP 2's tmax/tmin local-day check (`:601-624`) | Check it by hand in Phase 4: HEAD the 10 live keys and their `_backup/tmax_tmin_utc_day/` twins and compare ETags |
| A2 | Acceptance | Neither dry-run nor stage 3's read-back proves the grid changed (they compare keys and years only) | Phase 4 reads back all 59 live COG headers and all 228 daily headers, cache bypassed, and the catalog bbox via curl |
| A3 | Acceptance | Live test only covers Prince George | Add 10DA001 to `test-cd_extract_daily_live.R` |
| A4 | Acceptance | `xyFromCell(NA)` is NaN; `adjacent(NA)` gives cell 1; ext prints 17 digits | Already handled in WIP; test tightened to `expect_identical(NA_real_)` |
| G1 | Gap | snowfall_fraction inner-joins hourly / daily store arrays | Fixed (code-check round 1 found the same); plus a written-file check on every output |
| G2 | Gap | Stage 3 would publish a mixed-grid set | `grid_problems()` in `scripts/_lib.R`, called by stage 3 and STEP 5 |
| G3 | Gap | Skip paths trust stale files | Every backfiller runs `bc_file_check()` on each existing output of a year, written or skipped |
| G4 | Gap | No consumer note | PR body + NEWS line via `/gh-pr-merge`: cells renumbered, `cd_cache_clear()` if `cd.cache_revalidate = FALSE`; comment on wet#40 after publish |
| O1 | Ordering | all.py refetches tmax/tmin if tmax_tmin.py has not finished | Order: daily → tmax_tmin → all ∥ snow |
| O2 | Ordering | Live COGs are aggregates; compare after `stage3 --dry-run`; publish daily only after stage 3 is ready | Adopted |
| O3 | Ordering | Keep the old live COGs locally | Done: `data/backfill/_grid_120x260/cogs_live` (59) + `catalog_live.json` |
| S1 | Assumption | "Fails safe" covers monthly only; STEP D has no grid check on main | Corrected in findings; merge before local 2026 completes (~Feb–Mar 2027); new code's STEP D path runs `bc_file_check()` in the daily backfiller |
| S2 | Assumption | Value identity needs a stated tolerance for reductions | Report max abs diff and count per file; ulp-scale = pass, noted |
| S3 | Assumption | Inner block by index | `grid_identity.py` uses `[:, 1:, 1:]` and checks the grids explicitly |
| S4 | Assumption | Run time and quota | ~2 h daily + ~4 h all + ~3 h snow; ~60k requests (~12% of quota) |
| SC1 | Scope | All-off-grid call still downloads | Not done: an edge case, and a second code path |
| SC2 | Scope | STEP 1 could check dims on every dry-run | Follow-up, not #123 |
