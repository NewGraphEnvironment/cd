# Task: Snowpack-departure methodology lit review (#53)

## Problem

Phase 5 of #48 will make defensible-sounding claims about snow ("freshet
N days earlier", "peak SWE down M%", "rain-snow transition moving
upslope"). For our reporting context (fish passage, aquatic restoration
appendices), these need to land on cited peer-reviewed methodology, not
back-of-envelope. This issue produces the citations and methodology
quotes; #48 Phase 5 consumes them.

User-confirmed decoupling:
- **#53 produces** `findings.md` with exact-page quotes for each of #48's
  four metric choices, citation keys ready to consume.
- **#48 Phase 5 consumes** `[@key]` citations into the vignette interp
  paragraph, sourced from this issue's `findings.md`.

Mirrors the existing `scripts/rag_build_departure_framing.R` pattern.

## Phase 1 — Targeted literature search

- [x] WebSearched DOI / publisher landing for each candidate; all 11
      papers confirmed with DOIs.
- [x] Paywalled papers identified: `pederson_etal2011` (Science),
      `yue_wang2002` (AGU). USGS / ResearchGate fallback paths
      flagged in findings.md.
- [x] Found **`kouki_etal2023`** for ERA5-Land snow validation
      (Cryosphere, OA, CC-BY 4.0).
- [x] Found **`yue_wang2002`** for MK + autocorrelation. Critical
      finding: prewhitening fails when a trend exists — informs
      whether cd should add autocorrelation correction (likely #43
      follow-up).
- [x] Found **`kang_etal2016`** — Fraser River Basin freshet-timing
      paper, directly maps to our fish-passage reporting context.
      Was not in original candidate list; added.
- [x] Captured 11 papers in `findings.md` with DOI + access status +
      coverage matrix mapping each #48 metric to its primary paper.

Starting candidate list:

| Citation key | Why |
|---|---|
| `mote_etal2005` Mote, Hamlet, Clark, Lettenmaier 2005 (BAMS) | Foundational PNW snowpack-decline methodology |
| `stewart_etal2005` Stewart, Cayan, Dettinger 2005 (J Climate) | Defines DOY-50 / centroid timing |
| `pederson_etal2011` Pederson et al. 2011 (Science) | Long-record context |
| `mote_etal2018` Mote et al. 2018 (npj Clim Atmos Sci) | Updated PNW summary |
| `knowles_etal2006` Knowles, Dettinger, Cayan 2006 (J Climate) | Snowfall fraction methodology |
| `najafi_etal2017` Najafi et al. (UNBC) | BC-specific Peace-relevant |
| `curry_etal2014` Curry et al. 2014 | BC mountain snowpack + climate change |
| `cayan_etal2001` Cayan et al. 2001 (BAMS) | Spring onset metric origins |
| `yue_wang2002` Yue & Wang 2002 (WRR) | Autocorrelation correction for MK |
| `munoz_sabater_etal2021` Muñoz-Sabater et al. 2021 (ESSD) | ERA5-Land dataset (already in Zotero, attachKey SUS5A57A) |

## Phase 2 — Add papers to Zotero (`hydrology` collection per user direction)

- [x] Verified none of the 10 candidates already in Zotero
      (10 parallel `zotero_search_items` calls all returned no matches;
      11th paper `munoz_sabater_etal2021` already known to exist with
      attachKey `SUS5A57A`).
- [x] Used existing top-level `NewGraphEnvironment/hydrology`
      collection (key `X29BX4U8`) per user direction; did not create
      a new `snowpack-departure-methodology` collection. (Initial
      adds mistakenly went to the deep-nested
      `blackwater/aquatic/hydrology` `JI7EBZNF` — PATCH'd all 10
      items to `X29BX4U8` after user feedback.)
- [x] Added 10 new entries via Web API POST with
      `"collections": ["X29BX4U8"]`. CrossRef-driven metadata for all 10.
      Tags: `snowpack-departure-methodology`, `cd-issue-53`.
- [x] Auto-attached 6 PDFs via 4-step S3 upload:
      `mote_etal2005`, `knowles_etal2006`, `mote_etal2018`,
      `cayan_etal2001`, `kang_etal2016`, `kouki_etal2023`.
- [ ] **User manual download required** (paywalled + `najafi`,
      `stewart` returning 403 from AMS direct):
      `stewart_etal2005`, `najafi_etal2017`, `yue_wang2002`,
      `pederson_etal2011`. RG search links provided; user drags PDFs
      onto the existing Zotero entries (parent keys recorded above).
- [x] Captured per-paper `citationKey + parent itemKey + attachment
      key` in `findings.md`.

## Phase 3 — Build ragnar DuckDB store

- [x] Cloned `scripts/rag_build_departure_framing.R` structure into
      `scripts/rag_build_snow_methodology.R`.
- [x] Adapted header docstring; pivoted to read from
      `data/rag/snow_methodology_pdfs/` (Web-API-downloaded local
      cache) rather than `~/Zotero/storage/{attachKey}/` because
      the user's Zotero desktop sync setting doesn't auto-download
      attachments. The cache is reproducible from the Zotero Web
      API given the attach-key list, and is gitignored.
- [x] Hardcoded the 11-paper map.
- [x] Built `data/rag/snow_methodology.duckdb` — 11 sources, 1006
      chunks, ingested via Ollama nomic-embed-text in ~80 s.

## Phase 4 — Mine the store for methodology quotes

- [x] Wrote `scripts/rag_query_snow_methodology.R` — 23 queries
      across 8 topics, top-5 chunks each.
- [x] Raw retrieval captured at
      `planning/active/snow_methodology_quotes.md` (727 lines).
- [x] Synthesized strongest hits per metric into `findings.md`
      under the "Methodology quotes by #48 metric" and
      "Cross-cutting methodology" sections. Quotes attributed by
      citation key; page-level citations skipped (rag chunks lose
      page boundaries) but enough context to locate in source PDF
      if a vignette claim needs page-precise sourcing.

## Phase 5 — Document deviations + citation map

- [x] Deviations section in `findings.md` documents 4 places where
      cd differs from / extends the literature consensus:
      (1) `snowmelt_rate_peak` is a melt-flux metric without close
      precedent (literature precedent is streamflow-based);
      (2) baseline window 1951–1980 is on the early side vs
      WMO 1961–1990 (consistent with existing vignette sections);
      (3) no autocorrelation correction is **defensible per Yue &
      Wang 2002** — pre-whitening is wrong when trend exists;
      (4) `swe_max` uses true annual max rather than April 1 SWE.
- [x] **"Cite this for that"** table at end of `findings.md` —
      15-row map from claim type to citation key(s). Ready for
      #48 Phase 5 to copy `[@key]` markers into the vignette.

## Phase 6 — PR

- [ ] `/code-check` clean before commit.
- [ ] Atomic commits — Phase 1 search log, Phase 2 Zotero adds summary,
      Phase 3 rag-build script, Phases 4–5 findings.
- [ ] PR with `Fixes #53`. SRED ref in PR body
      (`Relates to NewGraphEnvironment/sred-2025-2026#23`) — not in
      issue body per memory.
- [ ] After merge: `/planning-archive`. Archived findings.md becomes
      the long-lived methodology reference.

## Validation

- [ ] `data/rag/snow_methodology.duckdb` exists and `ragnar_retrieve()`
      returns sensible chunks for each metric query.
- [ ] 8–12 papers in `snowpack-departure-methodology` Zotero collection
      with PDFs attached.
- [ ] `findings.md` has exact-page quotes (`@key, p. N`) for each of the
      four #48 metric choices.
- [ ] PWF checkboxes match landed work.
- [ ] `/planning-archive` on completion.

## Out of scope

- **Vignette citation insertion** — happens in #48 Phase 5, sourced from
  this issue's findings.md.
- **Setting up `bibliography:` YAML in `peace-fwcp.Rmd`** — also #48
  Phase 5.
- **Original methodology research / new metric proposals.**
- **Refactoring `cd_anomaly` / `cd_trend`** — autocorrelation correction
  goes against #43 if motivated.
- **Glacier dynamics, streamflow modelling.**

## Notes for execution

- Working in parallel with `48-snow-vars` branch. Files this branch
  touches don't overlap.
- **Vignette edits forbidden on this branch** — even small ones.
- Zotero state lives outside the repo. Branch's git diff captures only
  the build script + planning files. Citation keys are committed in the
  R script's hardcoded map, so the build is reproducible.
- Ollama prerequisite: `ollama serve` + `ollama pull nomic-embed-text`
  before invocation.
