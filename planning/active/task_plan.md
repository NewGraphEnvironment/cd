# Task: Lit-review temperature-departure methodology + interpretation backing (#58)

## Problem

Vignette interpretation paragraphs in `vignettes/peace-fwcp.Rmd` and
`vignettes/kootenay-lake.Rmd` make defensible-sounding claims about
temperature departure — "warming has accelerated/slowed", "summer
daytime maximum is the salmonid thermal envelope", "day-night
asymmetry shows up here unlike X" — but currently land on **zero**
peer-reviewed citations for those claims. For FWCP fish-passage
reporting context, these need the same cited backing #53/#54/v0.1.7
gave the Snowpack section.

## Scope

First of three sequential climate-departure lit reviews covering the
non-snow vignette sections (the 3-split: temperature, precipitation +
drying, interpretation framing). Mirrors the #53 / #54 / v0.1.7
pattern verbatim:

- Targeted lit search → candidate list of ~10 papers
- Add to `NewGraphEnvironment/climate` Zotero collection (key
  `8MH9LCC9`), PDFs first per `/lit-search` policy
- Build `data/rag/temp_methodology.duckdb` ragnar store
- Mine for methodology quotes; write `findings.md` with "cite this
  for that" map
- Vignette `[@key]` insertion happens on a downstream branch, not here

A 4th issue (#59, BEC zone shifts) is filed as a tracker; sequenced
after the 3-split.

## Phase 0 — Naming-convention rename (prep)

Mechanical `git mv` to switch existing rag scripts to `noun_verb`
order so the directory reads cleanly. One atomic commit, easy review.

- [x] `git mv scripts/rag_build_snow_methodology.R scripts/rag_snow_methodology_build.R`
- [x] `git mv scripts/rag_query_snow_methodology.R scripts/rag_snow_methodology_query.R`
- [x] `git mv scripts/rag_build_departure_framing.R scripts/rag_departure_framing_build.R`
- [x] Update internal docstring usage examples in each renamed script
- [x] Update CLAUDE.md script references
- [x] Update archived references (`planning/archive/2026-05-issue-53-snow-lit-review/README.md`
      — left task_plan/findings/progress as-is since they're historical records)
- [x] Atomic commit: "Rename rag scripts to noun_verb convention"

## Phase 1 — Targeted literature search

- [x] Web search candidate papers for DOI + access status; refined
      candidate list to **10 confirmed new papers**
- [x] Identified paywalled vs OA: 4 OA-fetchable (Karl 93, Wang 12
      ClimateWNA, Vincent 18, Richter & Kolmes 05 via NOAA), 6 require
      user RG download (Easterling 97, Vose 05, Pepin 15, Rangwala 12,
      Mantua 10, Eaton & Scheller 96)
- [x] Cross-checked existing 19 items in the `climate` Zotero
      collection: 7 reuse-relevant for #58 (`mora_etal2013`, ERA5/
      ERA5-Land, NorWeST, Dierauer 20 BC ecoregions, Warkentin 22,
      Moore 22), 2 cross-rag references from snow rag (`najafi_etal2017`,
      `yue_wang2002`); rest screened out as Issue 2/3 fits or peripheral
- [x] Documented final candidate list with citation key + DOI + access
      status + topical coverage matrix in `findings.md`

Starting candidate list (will refine):

| Citation key | Topic / Why |
|---|---|
| `karl_etal1993` | Foundational DTR paper (BAMS) — day-night asymmetry origin |
| `easterling_etal1997` | Tmax vs tmin trends globally (Science) — direct follow-up to Karl 93 |
| `vose_etal2005` | DTR over land 1950-2004 update (GRL) |
| `vincent_etal2018` (or current) | Canadian temperature trends — BC context |
| `wang_etal2014` ClimateNA | BC-specific historical temp downscaling |
| `mantua_etal2010` | PNW climate impacts on salmon (Climatic Change) |
| `eaton_scheller1996` | Salmonid stream-temp thermal limits (L&O) — classic |
| `isaak_etal2017` | NorWeST stream-temp model — *already in collection* |
| `pepin_etal2015` | Elevation-dependent warming (Nature Climate Change) |
| `rangwala_miller2012` | Mountain climate change review (Climatic Change) |
| `mauger_etal2015` | PNW Climate Impacts Assessment |
| `mora_etal2013` | Climate-departure framing — *already in collection* |
| `najafi_etal2017` | BC attribution — *already in snow rag* |

## Phase 2 — Add to NewGraphEnvironment/climate Zotero collection

- [x] For each of 10 candidates: CrossRef metadata fetch → POST to
      Web API with `"collections": ["8MH9LCC9"]`, tags
      `temperature-departure-methodology` + `cd-issue-58`
- [x] PDF acquisition: 1 fetched via curl (Wang 12 from UAlberta),
      9 user-provided via ResearchGate; 2 OCR'd (Karl 93, Richter &
      Kolmes 05)
- [x] Auto-attach all 10 PDFs via 4-step S3 upload (3 fresh uploads,
      7 deduped via md5)
- [x] PATCH all 10 items to clear `Citation Key: ...` override from
      `extra` field — BBT auto-derives keys per NGE convention; soul#43
      filed to update `/lit-search` + `/zotero-api` skills
- [x] Captured per-paper `parent itemKey + attachment key` in
      `findings.md`
- [x] PDFs mirrored into `data/rag/temp_methodology_pdfs/` for
      ragnar ingestion (gitignored)
- [x] **Captured all 10 BBT-auto citation keys** after Zotero restart
      + BBT plugin update from 8.0.25 to 9.x (Z8/9 line); Pepin 2015
      required a creators-PATCH to seed the working-group authors
      since CrossRef returned only the corporate name. Final keys
      mapped in findings.md Phase 2 table

## Phase 3 — Build ragnar DuckDB store

- [x] Cloned `scripts/rag_snow_methodology_build.R` →
      `scripts/rag_temp_methodology_build.R`. Adapted header
      docstring + 10-paper `pdf_specs` map
- [x] Ran `Rscript scripts/rag_temp_methodology_build.R` — built
      `data/rag/temp_methodology.duckdb` with **677 chunks across
      10 sources** via Ollama `nomic-embed-text` (~28 s)
- [x] Verified retrieval: query for "diurnal temperature range
      minimum maximum asymmetry" returns sensible top-3 chunks
      (Karl 93 abstract + DTR variable construction, Rangwala &
      Miller 12 alpine trends, Vincent 18 nighttime asymmetry)

## Phase 4 — Mine the store for methodology quotes

- [x] Wrote `scripts/rag_temp_methodology_query.R` mirroring the
      snow query script. 8 topics × 3 queries × top-5 chunks =
      120 candidate chunks total
- [x] Topics covered: DTR asymmetry, Tmax/Tmin globe, Canadian/BC
      trends, BC downscaling, EDW, climate-stream-temp bridge,
      salmonid thermal envelope, trend methodology
- [x] Raw retrieval saved to `planning/active/temp_methodology_quotes.md`
      (637 lines)
- [x] Synthesized per-topic into `findings.md` (Phase 5)

## Phase 5 — Synthesis + citation map

- [x] In `findings.md`: methodology-quotes-by-topic section covering
      all 8 topics with selected quotes per paper
- [x] Cross-cutting methodology section: baseline window (same as
      snow), trend test (Vincent 18's AC-iterative vs cd's raw MK,
      Yue & Wang 02 supports our approach), ERA5-Land 2m T validation
      (gap noted, alternatives proposed)
- [x] Deviations section — 4 documented deviations: UTC-day tmax/tmin
      (#37), raw MK vs Vincent 18's AC-iterative, no direct ERA5-Land
      2m T validation paper, regional DTR-asymmetry magnitude may
      not match global ratio
- [x] **"Cite this for that"** map — 18-row claim → citation
      lookup, framed as a menu not an order. Downstream branch picks
      sparingly per the plain-language philosophy (memory:
      `feedback_vignette_citations_sparse.md`)
- [x] Documented existing items in `climate` collection (7 reuse-
      relevant) + 2 cross-rag references from snow rag
- [x] Philosophy preface added to findings.md: this is a library
      not a prescription; downstream cites authorities sparingly
      for findings visible in AOI graphs/tables

## Phase 6 — PR + release

- [ ] `/code-check` clean before each commit
- [ ] Atomic commits — Phase 0 rename, Phase 1 search log, Phase 2
      Zotero adds summary, Phase 3 build script, Phases 4–5
      findings.md
- [ ] PR with `Fixes #58`. SRED tag (`Relates to NewGraphEnvironment/sred-2025-2026#23`)
      in PR body, **not** issue
- [ ] After merge: `/planning-archive` → archived findings.md becomes
      long-lived methodology reference. Bump v0.2.1 → v0.2.2

## Validation

- [ ] `data/rag/temp_methodology.duckdb` exists; `ragnar_retrieve()`
      returns sensible chunks for each topic query
- [ ] 8–12 papers in `climate` Zotero collection with PDFs attached,
      all tagged `temperature-departure-methodology` + `cd-issue-58`
- [ ] `findings.md` has methodology quotes attributed by citation key
      for each of the 8 query topics
- [ ] PWF checkboxes match landed work
- [ ] `devtools::test()` clean (script-only changes shouldn't break
      package tests, but verify)
- [ ] Atomic-commits audit: `git log --oneline -- planning/ scripts/rag_*.R`
      tells the full story

## Out of scope

- **Snowpack methodology** — covered by #53/#54
- **Precipitation + drying** — Issue 2 of the 3-split (forthcoming)
- **Interpretation framing** — Issue 3 of the 3-split (forthcoming)
- **BEC zone shifts** — #59 tracker (post-3-split)
- **Vignette `[@key]` insertion** — downstream consumer branch, not
  this one
- **Original methodology research** — refining `cd_trend()` / new
  metric proposals
- **Updating `vignettes/references.bib`** — also downstream consumer

## Notes for execution

- Branch: `58-temperature-lit-review`
- Vignette edits forbidden on this branch
- Zotero state lives outside the repo. Citation keys hardcoded in the
  R script's map → reproducible
- Ollama prerequisite: `ollama serve` + `ollama pull nomic-embed-text`
- Existing 19 climate-collection items to screen first — likely
  reusable: `mora_etal2013`, `hersbach_etal2020`,
  `munoz_sabater_etal2021`, `isaak_etal2017`, `dierauer_etal2020`,
  `warkentin_etal2022`, `islam_etal2019`, IPCC AR6 (WGI, SYR)
