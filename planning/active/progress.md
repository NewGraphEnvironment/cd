# Progress — Lit-review interpretation framing methodology + reporting backing (#63)

## Session 2026-05-05

- Closed #61 (precip+drying lit review): PR #62 merged, v0.2.3
  released, planning files archived to
  `planning/archive/2026-05-issue-61-precip-drying-lit-review/`
- Filed #63 (interpretation framing lit review, Issue 3 of 3-split)
- Created branch `63-interpretation-framing-lit-review` off main
- Scaffolded PWF baseline mirroring #58/#61 phase structure exactly,
  adapted for interpretation framing topics + candidate papers
- Carrying forward 5 lessons from #58 + 1 from #61:
  1. BBT 9.x for Zotero 8/9 (compat split)
  2. No `Citation Key:` overrides in `extra` (BBT auto-derives,
     soul#43)
  3. PATCH individual authors after Web API POST when CrossRef
     returns only corporate authorship (Pepin 2015 lesson)
  4. OCR image-only scans before Zotero attach (Karl 93 + Richter
     & Kolmes 05 + Marvel 19 lessons)
  5. `noun_verb` naming for new rag scripts
  6. Auto-restart Zotero via osascript+open+30s for BBT key gen,
     no manual prompt needed (#61 lesson, in soul#43)
- Phase 1 done: 4 new candidate papers confirmed (DOI + OA);
  Wiken/Demarchi BC-ecoregion gov refs dropped from formal scope
  (well-established convention, vignette can describe in prose).
  6 existing climate-collection items + cross-rag from snow + temp
  + precip+drying stores cover the framing topics
- 2 OA PDFs in cache (Hansen 2012, Livezey 2007); 2 RG-needed
  flagged for user (Arguez & Vose 2011, Hawkins & Sutton 2012)
- Phase 2 done: 4 PDFs in cache (2 curl, 2 user-RG, no OCR
  needed); 4 papers POSTed to NewGraphEnvironment/climate; auto-
  restart fired and all 4 BBT keys captured cleanly
- Phase 3 done: scripts/rag_interpretation_framing_build.R built
  data/rag/interpretation_framing.duckdb (291 chunks, 4 sources,
  ~10 s)
- Phase 4 done: scripts/rag_interpretation_framing_query.R written;
  16 queries × top-5 = 80 candidate chunks captured to
  planning/active/interpretation_framing_quotes.md (373 lines).
  All 4 papers contributing healthy share of hits
- Phase 5 done: synthesis section in findings.md covers 6 topics;
  11-row "cite this for that" map with BBT keys baked in.
  Headline finding: Hansen 2012 uses the 1951–1980 base period —
  same as cd — providing the strongest direct precedent for cd's
  baseline choice across all three lit reviews
- Next: Phase 6 — /code-check, push branch, open PR (Fixes #63,
  SRED tag in body), /planning-archive after merge, release v0.2.4
  → 3-split complete
