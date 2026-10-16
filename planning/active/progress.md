# Progress — swe_max anomaly type: registry says absolute, CLAUDE.md says pct_normal (#139)

## Session 2026-10-15

- Plan-mode exploration — phases approved by user (swe_max → pct_normal; window wording only)
- Created branch `139-swe-max-anomaly-type-registry-says-absol` off main
- Scaffolded PWF baseline from issue #139 with approved phases
- Next: start Phase 1
- Phases 1+2 (one commit so no commit is red): registry swe_max → pct_normal/%, tests (incl. test-cd_fetch, test-cd_compare), bundled-data test now also checks type; rds patched by `data-raw/vignette_data_swe_max_type_patch.R`. Suite: FAIL 0, PASS 768
- Plan review landed (`review-plan.md`); B1, G1, G2, G5 folded in here; G3, G4, A1 go to Phase 3
- Phase 3: swe_max figure labels/captions to percent in both regional vignettes (incl. kootenay wsg facet); peace :912 "peak" sentence relabelled as annual SWE (its numbers are `swe`); data-raw comments; cd_compare "recent 11 years"; CLAUDE.md #138 paragraph
- Rendered both articles with the branch installed to a temp library (a plain `build_article()` read the installed cd's old rds and drew mm values under % labels); facets now ±54 % kootenay, ±38 % peace
