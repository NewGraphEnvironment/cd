# Progress — Lit-review precipitation + drying methodology + interpretation backing (#61)

## Session 2026-05-05

- Closed #58 (temperature lit review): PR #60 merged, v0.2.2
  released, planning files archived to
  `planning/archive/2026-05-issue-58-temperature-lit-review/`
- Filed #61 (precip + drying lit review, Issue 2 of 3-split)
- Created branch `61-precip-drying-lit-review` off main
- Scaffolded PWF baseline mirroring #58 phase structure exactly,
  adapted for precip/drying topics + candidate papers
- Carrying forward lessons from #58:
  - BBT 9.x for Zotero 8/9 (compat split)
  - No `Citation Key:` overrides in `extra` (BBT auto-derives)
  - PATCH individual authors after Web API POST when CrossRef returns
    only corporate authorship (Pepin 2015 lesson)
  - OCR image-only scans before Zotero attach (Karl 93 + Richter
    & Kolmes 05 lesson)
  - `noun_verb` naming for new rag scripts
- Phase 1 done: 7 new candidate papers identified (DOI + OA status
  confirmed); 5 existing climate-collection items + cross-rag from
  snow + temp flagged for reuse. 11-topic coverage matrix in
  findings.md
- Phase 2 done: 7 PDFs in cache (4 curl, 3 user-RG; 1 OCR'd from
  Marvel LLNL preprint); 7 papers POSTed to NewGraphEnvironment/
  climate (parent itemKey + attach itemKey table in findings.md);
  3 fresh PDF uploads + 4 md5-dedupes. No `Citation Key:` overrides
  (soul#43 + #58 lesson applied). All 7 items have ≥2 creators
- **User action pending: restart Zotero desktop** so BBT generates
  citation keys for the 7 new items
- Next (after Zotero restart): capture BBT keys via local sqlite,
  bake into Phase 3 rag_precip_drying_methodology_build.R, run
  ragnar build
