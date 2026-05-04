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
- Next: pause for user review of candidate list before Phase 2
  Zotero adds (Zotero state is user-shared, modifications worth
  explicit confirmation per auto-mode guidance).
