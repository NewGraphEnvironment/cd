# Progress — Move run provenance to the STAC processing extension (#128)

## Session 2026-10-11

- Plan-mode exploration — phases approved by user ("go all phases")
- Created branch `128-move-run-provenance-to-the-stac-process` off main
- Scaffolded PWF baseline from issue #128 with approved phases
- Next: start Phase 1
- Phase 1: `stac_provenance()` + `cd_stac_item()` write processing:* and the run link; extension declared only with a processing field. Restore-the-bug: reformatting the datetime and declaring the extension on an untagged item each turned a test red (lines 118, 139)
