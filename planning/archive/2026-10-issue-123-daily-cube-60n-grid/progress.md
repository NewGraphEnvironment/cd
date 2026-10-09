# Progress — Daily cube stops at 59.95 N, and one point outside it aborts cd_extract_daily() (#123)

## Session 2026-10-08

- Plan-mode exploration: root cause measured (EDH coordinate float drift); phases approved by user
- Created branch `123-daily-cube-stops-at-59-95-n-and-one-poin` off main
- Scaffolded PWF baseline from issue #123 with approved phases
- Next: Phase 0 (file hashing issue), then Phase 1
- Phase 0: filed #124 (content hashes + run provenance), the hashing follow-up
- Phase 1: `bc_slice()` (half-cell pad), `bc_grid_check()` (coordinates, pre-fetch), `bc_file_check()` (written header) in `_lib.py`. All three backfillers plus `backfill_edh_tmax_tmin.py` use them. test_lib 37/37. Mutation `_BC_PAD = 0` → both new cases FAIL. Live check (coordinates only): the hourly and daily EDH stores both slice to 121 × 261 with edges 60.0/48.0/220.0/246.0 (± drift)
- Plan review (Plan agent) → `review-plan.md`: no Blockers, 17 findings with dispositions. Adopted: skip-path grid checks (G3), cross-COG `grid_problems()` (G2), ordering daily → tmax_tmin → all ∥ snow, stage 3 `--dry-run` before any push, full header read-back in Phase 4, 10DA001 live test
- Code-check Phase 1: round 1 found the snowfall_fraction cross-store join (fixed: `bc_grid_check(sf_pct)`); round 2 Clean (corrected one comment: `.where(…, 0)` raises first)
- Code-check Phase 1 round 3: a guard failure in all.py / snow.py was swallowed by the per-year `except` and exited 0, which STEP 3 would read as EDH latency (green run). Fixed: both exit 1 on any failed year (probe: fail→1, ok→0). Also `bc_file_check()` turns RasterioIOError (an OSError, which `with_retry` retries) into ValueError (mutation: test FAILs). Daily set-level `grid_problems()` gate added to Phase 4
- Code-check Phase 2 rounds 1–2: Clean
- Code-check Phase 1 round 4 (enumeration of 18 guard sites → exit status → CI outcome): every diff site exits non-zero; no normal month trips one. Pre-existing gap fixed: STEP 3's any_fetch_errored was read only when no year wrote; finish() now reads it
- Phase 2: `cd_extract_daily()` gives an outside point NA rows + a warning stating `terra::ext(template)`; 3 new fixture tests (FAIL before the fix, PASS after) + 10DA001 live test; code-check rounds 1–3 Clean (round 3 enumerated every consumer)

## Session 2026-10-08/09 (rebuild + publish)

- Phase 3: daily 3 h 10 m, snow 7 h 21 m, core monthly 9 h 55 m (concurrent). Every product's old block bit-identical except band 2025 of prcp_annual / prcp_winter / snowfall_fraction (daily-store tp changed upstream since 2026-04-12; see findings)
- Phase 4: daily pushed (228), stage 3 live (59 + catalog); A1 by hand; 10DA001 live; full read-back and CI dry-run dispatched
- Phase 5: research note + CLAUDE.md gotcha
