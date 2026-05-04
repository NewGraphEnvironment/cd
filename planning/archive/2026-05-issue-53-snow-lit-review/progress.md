# Progress — Snowpack-departure methodology lit review (#53)

## Session 2026-05-04

- Plan-mode exploration:
  - Read `scripts/rag_build_departure_framing.R` end-to-end —
    template to mirror, simple hardcoded map + ragnar build.
  - Confirmed `vignettes/peace-fwcp.Rmd` has zero existing citations
    (no `bibliography:` YAML field, no `[@cite]` markers). Phase 5 of
    #48 will wire bib infrastructure for the first time, sourced from
    this issue's `findings.md`.
  - Identified ~10 candidate papers (Mote 2005/2018, Stewart 2005,
    Knowles 2006, Najafi, Curry 2014, Cayan 2001, Yue-Wang 2002,
    Pederson 2011, plus existing `munoz_sabater2021` already in
    Zotero).
- Phases approved by user.
- Created branch `53-snow-lit-review` off main.
- Scaffolded PWF baseline.
- Phase 1 complete: 11 candidate papers identified with DOIs and
  OA status confirmed. New additions to original candidate list:
  - `kouki_etal2023` — ERA5-Land snow validation in The Cryosphere
    (TC), CC-BY 4.0. Replaces "find an ERA5-Land snow validation
    paper" placeholder.
  - `kang_etal2016` — Fraser River Basin freshet-timing paper,
    Scientific Reports, OA. Directly maps to fish-passage reporting
    context (10-day advance, declining summer flows during salmon
    migration). Wasn't on the original list — surfaced during the
    BC-specific search.
  - Dropped `curry_etal2014` from original list — `najafi_etal2017`
    is the better BC-attribution paper.
- 8 of 11 papers are OA (npj, Sci Rep, Cryosphere, ESSD, plus AMS
  6-month embargo for the older AMS papers). 2 require manual
  download from ResearchGate (`pederson_etal2011`, `yue_wang2002`).
- Phase 2 complete: 10 new entries added to existing
  `blackwater/aquatic/hydrology` Zotero collection (key `JI7EBZNF`)
  per user direction (skipped creating a new
  `snowpack-departure-methodology` sub-collection). Single-batch
  POST via Web API with CrossRef-driven metadata; all 10 succeeded.
- 6 of 10 PDFs auto-attached via 4-step S3 upload (Mote 2005, Mote
  2018, Knowles 2006, Cayan 2001, Kang 2016, Kouki 2023). 4 need
  manual download (Stewart 2005, Najafi 2017, Yue & Wang 2002,
  Pederson 2011). RG search links provided for user.
- Phases 3–5 implemented:
  - Phase 3: `scripts/rag_build_snow_methodology.R` clones the
    departure-framing pattern but reads PDFs from a local cache
    (`data/rag/snow_methodology_pdfs/`) rather than
    `~/Zotero/storage/{attachKey}/` — cache is populated via Web
    API loop, doesn't depend on user's Zotero desktop sync setting.
    Built duckdb store: 11 sources, 1006 chunks.
  - Phase 4: `scripts/rag_query_snow_methodology.R` runs 23
    queries across 8 topics, raw retrieval to
    `planning/active/snow_methodology_quotes.md` (727 lines).
    Synthesis into findings.md by #48 metric.
  - Phase 5: deviations section + 15-row "cite this for that"
    citation map in findings.md, ready for #48 Phase 5 to
    consume. Notable findings:
    - `cd_trend()`'s raw MK + Theil-Sen (no prewhitening) is
      **methodologically correct** per Yue & Wang 2002.
    - ERA5-Land overestimates SWE in mountains (Kouki 2023:
      150–200% NH-wide, larger in mountains). Trends still valid
      because bias is stable over time. ASWS QA in #48 Phase 3
      will document our specific BC bias.
    - `snowmelt_rate_peak` is our invention — no close precedent.
      Document as "diagnostic of upstream snowmelt intensity"
      rather than implying methodological pedigree.
- Next: Phase 6 PR. Branch state: 6 commits since baseline.
