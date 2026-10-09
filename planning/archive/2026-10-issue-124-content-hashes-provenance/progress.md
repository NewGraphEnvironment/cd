# Progress — Content hashes and run provenance on every published COG (catalog items and daily cube) (#124)

## Session 2026-10-09

- Plan-mode exploration — phases approved by user ("go all phases to pr")
- Created branch `124-content-hashes-and-run-provenance-on-eve` off main (3c19b71)
- Scaffolded PWF baseline from issue #124 with approved phases
- Next: start Phase 1
- Phases 1-5 landed (9a0325a, 6bd3af6, 9719c33, 124e91f, c3920dd); plan review folded in (review-plan.md)
- Real-data dry runs: stage 3 (59 COGs, catalog checksums) and daily (228 files, bootstrap manifest); --rewrite of all 228 local files
- /code-check branch: 3 rounds + enumeration (533bbd7, 2c9a07c, 12d9370); round 3 found a defect inside round 2's fix (terra floor)
- Follow-up filed: #126 (consumer-side checksums/provenance)
- Next: PR; live republish after merge + release, from clean main
