# Progress — Kootenay vignette: five sentences inherited from Peace contradict the Kootenay data (#146)

## Session 2026-10-16

- Plan-mode exploration — phases approved by user
- Created branch `146-kootenay-vignette-five-sentences` off main
- Scaffolded PWF baseline from issue #146 with approved phases
- Next: start Phase 1
- Phases 1–5 landed in one commit (the edits interleave in one file): filter 100 km², three-ecoregion prose, soil/warming/WSG sentences with inline numbers, "Four findings" in both articles, six new `claims` in the data script
- Offline claims harness (scratchpad): claims section of the data script evaluated against the committed rds → PASS; seven perturbations (one or more per new claim) each stop with the matching claim name; perturbing TOP (not shown) still passes
- Branch installed, Kootenay article rendered (10 s); each rewritten sentence read back from the HTML
- Phase 6 sweep: two more inherited sentences found false (seasonal snow caption carried Peace's −75 % / +37 %; the sentence above it cited "headline numbers above" the text never states). Caption computed inline; two more claims; verdict per sentence in findings.md
- Harness re-run: PASS unperturbed, all nine perturbations fire; both articles re-render with the branch installed
- Plan review landed after Phase 6; folded in (review-plan.md, dispositions in findings.md). Filed #148 (Peace "cumulative" mislabel)
- Tests: devtools::test() FAIL 0 | PASS 768
- Harness: PASS unperturbed; ten perturbations fire; filter set back to 50 fires `prose_states_filter`
