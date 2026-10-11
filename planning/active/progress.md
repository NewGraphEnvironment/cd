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
