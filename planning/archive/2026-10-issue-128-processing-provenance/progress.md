# Progress — Move run provenance to the STAC processing extension (#128)

## Session 2026-10-11

- Plan-mode exploration — phases approved by user ("go all phases")
- Created branch `128-move-run-provenance-to-the-stac-process` off main
- Scaffolded PWF baseline from issue #128 with approved phases
- Next: start Phase 1
- Phase 1: `stac_provenance()` + `cd_stac_item()` write processing:* and the run link; extension declared only with a processing field. Restore-the-bug: reformatting the datetime and declaring the extension on an untagged item each turned a test red (lines 118, 139)
- Phase 2: `manifest_entries()` via `cd:::stac_provenance()`; `entry_sha()` feeds `daily_publish()` and `manifest_problems()`, which now refuses entries without processing:software's cd. test_lib.R 103/103; removing the refusal fails the new check (102/103)
- Plan review returned (`review-plan.md`): 1 blocker (repair hint), gaps folded into Phase 3 — see the disposition table
- Phase 3: `scripts/catalog_publish.R`; `daily_publish(sync = FALSE)`; datetime guard (test_lib 104/104, guard proven by restore-the-bug)
- Dry runs 2026-10-11 16:09 UTC: catalog 59 items 1950-2025, ETags match, 59/59 checksums unchanged; manifest-only 228/228 live byte for byte. `compare_128.py`: 0 problems; planted errors (old key left, bad processing key, reformatted datetime) all caught
- The first catalog dry run's aws sync took ~12 min for 300 MB (slow transfer, not a hang; two partial temp files were seen mid-download)
- Phase 4: CLAUDE.md updated; devtools::test() FAIL 0 | PASS 566 (6 warnings, pre-existing); 41 package lints, none new (`n_bands` unused predates #128)
- /code-check branch: round 1 (2 fragile, fixed 26f9d0a), round 2 Clean, round 3 (2 fragile; the repair hint finding is inside the B1 revert). Round 3 fixes: shared `has_processing_provenance()`, `catalog_vocab_problems()` in all four catalog-check callers (STEP 1 live, STEP 5, stage 3, catalog_publish.R), hint loads the checkout, `s3_put_if(on_conflict =)`. test_lib 107/107; forcing the predicate TRUE turns the vocabulary checks red
- Loop ended by enumeration: 6 publish entry points x 6 guards (checkout SHA, built-doc vocabulary, live-doc vocabulary, checksums, conditional upload, read-back). Every cell guarded except the pipelines' unconditional catalog `aws s3 cp`, which predates #128 and is covered by the workflow's concurrency group (out of scope)

## Session 2026-10-11 (after the merge)

- PR #131 merged as `d2fb0a0`; released v0.6.4 (`62cd4d0`)
- Phase 5 from a clean main at `62cd4d0`: both dry runs green (manifest-only 228/228 live byte for byte; catalog 59 items, ETags match, 59/59 checksums unchanged), then `daily_publish.R --manifest-only` at 16:58:08 UTC and `catalog_publish.R` at 16:58:34 UTC, both conditional uploads read back
- `compare_128.py` on `data/backfill/pre_128/*` vs the live documents: 0 problems over 59 items and 228 entries; all 287 published `.tif` objects kept their 2026-10-10 LastModified
- PR #129 (#126) merged as v0.6.5; its test suite, run on a trial merge of main and the PR just before merging, ran the live canary against the republished catalog, FAIL 0, no skips
