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

- [ ] `git mv scripts/rag_build_snow_methodology.R scripts/rag_snow_methodology_build.R`
- [ ] `git mv scripts/rag_query_snow_methodology.R scripts/rag_snow_methodology_query.R`
- [ ] `git mv scripts/rag_build_departure_framing.R scripts/rag_departure_framing_build.R`
- [ ] Update internal docstring usage examples in each renamed script
- [ ] Update CLAUDE.md script references
- [ ] Update archived references (`planning/archive/2026-05-issue-53-snow-lit-review/`)
- [ ] Atomic commit: "Rename rag scripts to noun_verb convention"

## Phase 1 — Targeted literature search

- [ ] Web search candidate papers for DOI + access status; refine
      candidate list from ~13 starters down to ~10 confirmed
- [ ] Identify paywalled vs OA; ResearchGate fallback flagged for
      user manual download
- [ ] Cross-check existing 19 items in the `climate` Zotero collection
      to avoid duplicate adds; capture existing item keys for reuse
- [ ] Document final candidate list with citation key + DOI + access
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

- [ ] For each non-already-present paper, fetch CrossRef metadata,
      POST to Web API with `"collections": ["8MH9LCC9"]`. Tags:
      `temperature-departure-methodology`, `cd-issue-58`
- [ ] Auto-attach OA PDFs via 4-step S3 upload (see /zotero-api)
- [ ] Flag paywalled papers for user manual ResearchGate download
      (provide RG search links + parent itemKey for drag-drop)
- [ ] Verify all PDFs land in `~/Zotero/storage/{attachKey}/` after
      Zotero sync; capture per-paper `citationKey + parent itemKey +
      attachment key` in `findings.md`
- [ ] Mirror PDFs into `data/rag/temp_methodology_pdfs/` for ragnar
      ingestion (sidesteps Zotero "download files at sync"
      dependency, mirrors snow recipe)

## Phase 3 — Build ragnar DuckDB store

- [ ] Clone `scripts/rag_snow_methodology_build.R` (post-Phase-0
      rename) → `scripts/rag_temp_methodology_build.R`. Adapt header
      docstring + `pdf_specs` map
- [ ] Run `Rscript scripts/rag_temp_methodology_build.R` — target
      ~800-1200 chunks across ~10 sources via Ollama
      `nomic-embed-text`
- [ ] Verify chunk count + source count via DBI queries

## Phase 4 — Mine the store for methodology quotes

- [ ] Write `scripts/rag_temp_methodology_query.R` mirroring the
      snow query script. Query topics:
      - Trend test methodology (MK, Theil-Sen) — cross-references
        with snow rag for Yue & Wang
      - DTR / day-night asymmetry methodology + interpretation
      - Tmax vs tmin asymmetry — when does it appear, when doesn't
      - Climate→stream-temp bridge — air-temp departure to fish
        thermal stress
      - Elevation-dependent warming (mountain vs valley)
      - ERA5-Land 2m temperature validation / bias structure
      - BC / PNW-specific warming patterns
      - Salmonid thermal envelopes + critical thresholds
- [ ] Save raw retrieval to `planning/active/temp_methodology_quotes.md`
- [ ] Synthesize per-topic into `findings.md`

## Phase 5 — Synthesis + citation map

- [ ] In `findings.md`: methodology-quotes-by-topic section
- [ ] Deviations section — places where cd's temperature analysis
      differs from / extends the literature consensus (e.g., UTC-day
      tmax/tmin vs local-time per #37; Theil-Sen slope rather than
      OLS; cumulative-impact framing rather than per-decade rate)
- [ ] **"Cite this for that"** table — N-row map from vignette
      claim type to citation key(s). Ready for downstream consumer
      branch to copy `[@key]` markers verbatim
- [ ] Document existing items in `climate` collection that became
      candidates after closer review

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
