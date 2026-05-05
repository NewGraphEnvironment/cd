# Task: Lit-review precipitation + drying methodology + interpretation backing (#61)

## Problem

Vignette interpretation paragraphs in `vignettes/peace-fwcp.Rmd` and
`vignettes/kootenay-lake.Rmd` make defensible-sounding claims about
precipitation departure and "drying" — falling annual precipitation,
rising VPD/evapotranspiration, declining soil moisture, "soils
drying due to both ↓P and ↑ET" (the v0.1.1 finding) — but currently
land on **zero** peer-reviewed citations. For FWCP fish-passage
reporting context, these need the same cited backing #53/#54 gave
Snowpack and #58/#60/v0.2.2 gave Temperature.

## Scope

Second of three sequential climate-departure lit reviews covering
the non-snow vignette sections (3-split: temperature [done #58],
**precip+drying [this issue]**, interpretation framing).
Mirrors the #58 / #54 / v0.1.7 pattern verbatim:

- Targeted lit search → ~10 papers
- Add to `NewGraphEnvironment/climate` Zotero collection (key
  `8MH9LCC9`), PDFs first per `/lit-search` policy
- Build `data/rag/precip_drying_methodology.duckdb` ragnar store
- Mine for methodology quotes; write `findings.md` with "cite this
  for that" map
- Vignette `[@key]` insertion happens on a downstream branch, not here

## Phase 1 — Targeted literature search

- [ ] Web search candidate papers for DOI + access status; refine
      candidate list to ~10 confirmed
- [ ] Identify paywalled vs OA; ResearchGate fallback flagged for
      user manual download
- [ ] Cross-check existing 19 items in the `climate` collection +
      the temp methodology rag's papers + the snow rag's papers to
      avoid duplicate adds; capture existing item keys for reuse
- [ ] Document final candidate list with citation key + DOI + access
      status + topical coverage matrix in `findings.md`

Starting candidate list (will refine):

| Citation key | Topic / Why |
|---|---|
| `donat_etal2013` HadEX2 | Global temp + precip extremes dataset (J Geophys Res) |
| `min_etal2011` | Anthropogenic contribution to extreme precipitation (Nature) |
| `mekis_vincent2011` | Adjusted daily Canadian precipitation dataset (Atmos-Ocean) |
| `daly_etal2008` PRISM | Physiographic mapping of climate (orographic methods) |
| `mass_etal2002` | Orographic precip processes PNW |
| `williams_etal2020` | Anthropogenic warming → North American megadrought (Science) |
| `ficklin_novick2017` | Globally rising VPD (J Climate) |
| `grossiord_etal2020` | Plant + ecosystem responses to rising VPD (New Phytol) |
| `trenberth_etal2014` | Global warming + drought changes (Nat Clim Chg) |
| `marvel_etal2019` | 20th-century hydroclimate changes (Nature) |
| `sheffield_wood2008` | Global drought trends + variability (J Climate) |

## Phase 2 — Add to NewGraphEnvironment/climate Zotero collection

- [ ] For each non-already-present paper, fetch CrossRef metadata,
      POST to Web API with `"collections": ["8MH9LCC9"]`. Tags:
      `precip-drying-departure-methodology`, `cd-issue-61`. **Do NOT
      set `Citation Key:` overrides** in `extra` — let BBT auto-derive
      per NGE convention (soul#43). Verify each item creates with at
      least one personal author so BBT doesn't fall back to title-key
      (per Pepin 2015 lesson in #58 archive)
- [ ] Auto-attach OA PDFs via 4-step S3 upload (see /zotero-api)
- [ ] Flag paywalled papers for user manual ResearchGate download
      (provide RG search links + parent itemKey for drag-drop)
- [ ] OCR any image-only scans before attaching (per Karl 1993 +
      Richter & Kolmes 2005 lesson in #58)
- [ ] After Zotero restart + BBT key generation: capture per-paper
      `BBT-citationKey + parent itemKey + attachment key` in
      `findings.md`
- [ ] Mirror PDFs into `data/rag/precip_drying_methodology_pdfs/`
      for ragnar ingestion (gitignored)

## Phase 3 — Build ragnar DuckDB store

- [ ] Clone `scripts/rag_temp_methodology_build.R` →
      `scripts/rag_precip_drying_methodology_build.R`. Adapt header
      docstring + `pdf_specs` map
- [ ] Run `Rscript scripts/rag_precip_drying_methodology_build.R` —
      target ~600-1000 chunks across ~10 sources via Ollama
      `nomic-embed-text`
- [ ] Verify chunk count + source count via DBI queries

## Phase 4 — Mine the store for methodology quotes

- [ ] Write `scripts/rag_precip_drying_methodology_query.R` mirroring
      the temp query script. Query topics:
      - Precipitation trend methodology (long-record, homogenization)
      - Heavy / extreme precipitation + anthropogenic attribution
      - Orographic / mountain precipitation + rain-shadow gradients
      - Vapor pressure deficit (VPD) trends + drivers
      - Soil moisture as integrative drought signal
      - ERA5-Land precip / soil-moisture validation / bias structure
      - Drought-fish linkage — BC summer-flow + thermal habitat
      - Trend test methodology cross-check (cross-rag with snow + temp)
- [ ] Save raw retrieval to `planning/active/precip_drying_methodology_quotes.md`
- [ ] Synthesize per-topic into `findings.md`

## Phase 5 — Synthesis + citation map

- [ ] In `findings.md`: methodology-quotes-by-topic section
- [ ] Cross-cutting methodology section: baseline window (same as
      snow + temp), trend test cross-checks, ERA5-Land precip +
      soil-moisture validation gap (if any)
- [ ] Deviations section — places where cd's precip/drying analysis
      differs from the literature consensus
- [ ] **"Cite this for that"** table — N-row map from vignette claim
      type to BBT-auto-derived citation key(s). Framed as a menu, not
      an order, per memory `feedback_vignette_citations_sparse.md`
- [ ] Document existing items in `climate` collection + cross-rag
      references from snow + temperature methodology stores

## Phase 6 — PR + release

- [ ] `/code-check` clean (lint + tests) before each commit
- [ ] Atomic commits — Phase 1 search log, Phase 2 Zotero adds
      summary, Phase 3 build script, Phases 4–5 findings.md
- [ ] PR with `Fixes #61`. SRED tag (`Relates to NewGraphEnvironment/sred-2025-2026#23`)
      in PR body, **not** issue
- [ ] After merge: `/planning-archive` → archived findings.md becomes
      long-lived methodology reference. Bump v0.2.2 → v0.2.3

## Validation

- [ ] `data/rag/precip_drying_methodology.duckdb` exists;
      `ragnar_retrieve()` returns sensible chunks for each topic
- [ ] 8–12 papers in `climate` Zotero collection with PDFs attached,
      all tagged `precip-drying-departure-methodology` + `cd-issue-61`
- [ ] BBT-auto-derived citation keys captured for all new items
- [ ] `findings.md` has methodology quotes attributed by citation key
      for each of the 8 query topics
- [ ] PWF checkboxes match landed work
- [ ] `devtools::test()` clean; `lintr::lint()` clean on new scripts
- [ ] Atomic-commits audit: `git log --oneline -- planning/ scripts/rag_*.R`
      tells the full story

## Out of scope

- **Temperature methodology** — covered by #58/#60/v0.2.2
- **Snowpack methodology** — covered by #53/#54/v0.1.7
- **Interpretation framing** — Issue 3 of the 3-split (forthcoming)
- **BEC zone shifts** — #59 tracker (post-3-split)
- **Vignette `[@key]` insertion** — downstream consumer branch
- **Original methodology research / new metric proposals**

## Notes for execution

- Branch: `61-precip-drying-lit-review`
- Vignette edits forbidden on this branch
- Ollama prerequisite: `ollama serve` + `ollama pull nomic-embed-text`
- BBT version compat: confirm BBT 9.x active for Zotero 8/9 (Z7
  needed BBT 8.x; #58 hit a compat block when BBT 8.0.25 was on
  Zotero 9 — already resolved)
- Existing `climate` collection contains items relevant on the
  precip side that #58 set aside as Issue-2 scope:
  `vincent_etal2018ChangesCanadas` (covers Canada precip too),
  `islam_etal2019Quantifyingprojected` (Fraser flow regimes),
  `dierauer_etal2020Climatechange` (BC ecoregion drought),
  `warkentin_etal2022Lowsummer` (BC summer flow + chinook),
  `munoz-sabater_etal2021ERA5Landstateoftheart` (ERA5-Land soil
  moisture validation)
- Cross-rag from snow methodology store:
  `knowles_etal2006SnowfallVersus` (rain-vs-snow phase shift —
  feeds into the soil-moisture and precip-fraction story)
