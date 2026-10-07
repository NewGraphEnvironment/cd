# Plan review — #37 (Plan agent, 2026-10-06)

Read-only reviewer; findings returned as reply text and written here by the parent.
Disposition column added by the parent after probing each claim.

| ID | Class | Finding | Disposition |
|---|---|---|---|
| A1 | Assumption | Bias direction in the issue and plan is wrong: correction moves tmax DOWN 0.5-0.9 degC and tmin DOWN 0.2-0.3 degC. UTC day = 16:00-16:00 PST, so a hot afternoon counts twice (tmax high); a local midnight day holds two partial nights (tmin low). | **Confirmed** independently (republish dry-run + EDH probe). Plan, findings, NEWS, issue body corrected. |
| A2 | Assumption | Bias drifts over time (0.49 degC 1960 -> 0.61 degC 2020 at -125,52), so trends move, not just levels; vignette captions (peace-fwcp.Rmd:775, :858-860; kootenay-lake.Rmd:871, :965-967) carry claims. | Accepted; Phase 4 scope. |
| A3 | Assumption | Prove live COGs are the EDH UTC-day product by recomputing one pixel. | **Done**: Prince George 2002 annual tmax 9.181844 live vs 9.182 recomputed; Kamloops 11.845894 vs 11.846. |
| B1 | Blocker | Re-running republish could back up corrected COGs over the UTC backup. | Already guarded in the script as written (S3 backup never overwritten; local backup seeded from the S3 backup when present; backup only uploaded when its MD5 equals the live ETag). Local backup dir `data/backfill/republish_37/` is outside any synced dir. |
| G1 | Gap | Equivalence check collides with regen and fetches other vars. | Handled before the review landed: stub files for the 5 other vars, comparison to a renamed cube copy, all cleaned up. Tolerance stated: 1.3e-5 degC. |
| G2 | Gap | Stale UTC mentions: R/cd_extract_daily.R:16-20 (+ man), backfill_edh_daily.py:76, _lib.py:3-5, qa_monthly.R:125. | Accepted; Phase 4. |
| G3 | Gap | Test read_cog_days: float32, NaN survival, leap year, single band. | Accepted (float32, NaN, leap); single band not a cube shape, skipped. |
| G4 | Gap | Grid assertion needs tolerance. | `compareGeom()` already tolerant; band names asserted identical. No change. |
| G5 | Gap | Probe failure (latest_local NA) leaves STEP 3 uncapped -> wasted fetch of 5 vars + snow. | Accepted: NA now skips STEP 3 (run already red via daily_failed). |
| G6 | Gap | Move cap into a tested R helper. | Declined: after G5 the cap is a single subset expression; noted. |
| G7 | Gap | pipeline_stage3_edh.R would publish a 10-item catalog from a tmax/tmin-only monthly dir. | Accepted: guard added before catalog + push. |
| G8 | Gap | ETag==MD5 holds only under the multipart threshold. | Accepted: size assert before upload. |
| O1 | Ordering | Don't make the irreversible publish what unblocks the PR; refresh vignettes from local COGs, publish at merge. | Accepted: Decision 3 changed. |
| O2 | Ordering | main's CI would append UTC 2026 onto local history if the PR outlives ~Feb 2027. | Moot once publish moves to merge. |
| O3 | Ordering | Equivalence needs a cube-derived file. | Handled (see G1). |
| O4 | Ordering | Vignette data regen re-extracts all 15 vars; assert non-tmax/tmin rows unchanged. | Accepted; Phase 4. |
| S1 | Scope | Derive CI tmax/tmin from the just-built cube to save a fetch. | Declined: couples the two producers; one extra t2m-year fetch a year is cheap. |
| S2 | Scope | Document tmean/vpd/rh on UTC months; run qa_monthly.R. | Accepted (doc); qa_monthly.R checked in Phase 4. |
| Acc | Acceptance | Concrete point values: tmax_annual 2002 at (-123, 54) ~8.29 (was 9.02); tmin ~-0.54 (was -0.23); tmax_summer ~20.83. | Adopted as post-publish checks. |
