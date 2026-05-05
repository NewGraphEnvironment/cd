# Findings — Lit-review interpretation framing methodology + reporting backing (#63)

## Issue context (verbatim from #63)

Vignette interpretation paragraphs in `peace-fwcp.Rmd` and
`kootenay-lake.Rmd` make framing choices about how to report
climate departure to FWCP fish-passage planners — choice of
**baseline window** (cd uses 1951–1980 vs the WMO 1961–1990
canon), **framing axis** (cumulative-impact vs per-decade rate),
**reference variability** ("departure from recent variability" per
Mora 2013), and **reporting unit** (BC ecoregions vs ecoprovinces
vs watershed groups). Each is a defensible choice but currently
lands on **zero** peer-reviewed citations.

## Scope

Third (and final) of the three sequential climate-departure lit
reviews. Mirrors #58/#61 pattern verbatim.

## Topics to cover

1. Baseline window methodology — WMO 1961–1990 canon vs cd's
   1951–1980 vs alternatives; tradeoffs of 30-year periods
2. Cumulative-impact vs per-decade-rate framing
3. Departure from recent variability — Mora 2013 anchor;
   time-of-emergence / signal-to-noise
4. Shifting baseline syndrome — Pauly 1995 + descendants
5. Ecoregion as reporting unit — Wiken 1986 CCEA, BC ecoregion
   mapping (Demarchi 2011)
6. Ties to #20 + #43 — sensible `cd_compare()` defaults + window-
   vs-window p-value follow naturally from this lit review

## State found during plan-mode exploration

### Existing rag-build pattern (mirror this verbatim)

`scripts/rag_precip_drying_methodology_build.R` (the post-#61
canonical) is the template. Reads PDFs from
`data/rag/<topic>_pdfs/`. Writes DuckDB to
`data/rag/<topic>.duckdb` (gitignored). Uses `ragnar` with
`embed_ollama(model = "nomic-embed-text")`.

### Existing items in `climate` collection (re-use, do not re-add)

6 directly relevant existing items:

| BBT key | Year | Why relevant |
|---|---|---|
| `mora_etal2013projectedtiming` | 2013 | Climate-departure framing (anchor) |
| `pauly1995Anecdotesshifting` | 1995 | Shifting baselines foundational |
| `rodrigues_etal2019Unshiftingbaseline` | 2019 | Documenting historical baselines |
| `alleway_etal2023shiftingbaseline` | 2023 | SBS as connective concept |
| `intergovernmentalpanelonclimatechangeipcc2023ClimateChange` | 2023 | IPCC AR6 WGI |
| `calvin_etal2023IPCCSummary` | 2023 | IPCC AR6 SYR |

### Cross-rag references (already in other rag stores)

- `data/rag/snow_methodology.duckdb`:
  `yue_wang2002Applicabilityprewhitening` — trend-test methodology
- `data/rag/temp_methodology.duckdb`:
  `vincent_etal2018ChangesCanadas` — Canadian climate-normal practice;
  Mora 2013 cross-cutting
- `data/rag/precip_drying_methodology.duckdb`:
  `trenberth_etal2014Globalwarming`, `marvel_etal2019Twentiethcenturyhydroclimate`,
  `williams_etal2020Largecontribution` — all touch climate-departure
  framing on the drying side

## Architecture decisions (carrying forward from #58/#61)

1. **Decoupled boundary.** This issue produces ragnar store +
   findings.md. Vignette `[@key]` insertion happens on a
   downstream branch.
2. **Vignette edits forbidden on this branch.**
3. **Mirror existing rag-build script structure** verbatim —
   hardcoded map, local PDF cache, Ollama embeddings, `noun_verb`
   naming.
4. **No `Citation Key:` overrides** in `extra` — BBT auto-derives
   per NGE convention (soul#43).
5. **Auto-restart Zotero** for BBT key generation per soul#43
   pattern; no need to prompt user.
6. **BBT 9.x** already active for Z8/9 from #58 compat fix.

## Search log (Phase 1)

Phase 1 confirmed 4 new candidate papers via web search. Wiken 1986
(Canadian terrestrial ecozones) + Demarchi 2011 (BC ecoregions)
dropped from formal scope — the BC-ecoregion-as-reporting-unit
grounding is established convention in BC fisheries / ecology and
can be described in vignette prose without a heavy `[@key]` cite.
The 4 selected papers cover the load-bearing framing topics:
baseline window, time-of-emergence, alternative normals, public
perception of cumulative change.

### Final candidate list — 4 new papers to add

| # | Citation key (proposed) | Title (truncated) | Journal / Year | DOI | OA route |
|---|---|---|---|---|---|
| 1 | `arguez_vose2011` | The Definition of the Standard WMO Climate Normal: The Key to Deriving Alternative Climate Normals | BAMS 92 / 2011 | `10.1175/2010BAMS2955.1` | AMS Cloudflare-blocked, RG |
| 2 | `livezey_etal2007` | Estimation and Extrapolation of Climate Normals and Climatic Trends | JAMC 46 / 2007 | `10.1175/2007JAMC1666.1` | meto.umd.edu hosts free PDF |
| 3 | `hawkins_sutton2012` | Time of emergence of climate signals | GRL 39 / 2012 | `10.1029/2011GL050087` | AGU paywalled, RG |
| 4 | `hansen_etal2012` | Perception of climate change | PNAS 109 / 2012 | `10.1073/pnas.1205276109` | harvard.edu hosts free PDF |

### Existing items in `climate` collection — reuse, do not re-add

6 directly relevant existing items (BBT keys captured during #58/#61):

| BBT key | Year | Why relevant |
|---|---|---|
| `mora_etal2013projectedtiming` | 2013 | Climate-departure framing anchor (Nature) |
| `pauly1995Anecdotesshifting` | 1995 | Shifting baselines foundational |
| `rodrigues_etal2019Unshiftingbaseline` | 2019 | Documenting historical baselines |
| `alleway_etal2023shiftingbaseline` | 2023 | SBS as connective concept |
| `intergovernmentalpanelonclimatechangeipcc2023ClimateChange` | 2023 | IPCC AR6 WGI |
| `calvin_etal2023IPCCSummary` | 2023 | IPCC AR6 SYR |

### Cross-rag references (already in other rag stores; query without re-adding)

- `data/rag/snow_methodology.duckdb`:
  - `yue_wang2002Applicabilityprewhitening` — trend-test methodology
- `data/rag/temp_methodology.duckdb`:
  - `vincent_etal2018ChangesCanadas` — Canadian climate-normal practice
- `data/rag/precip_drying_methodology.duckdb`:
  - `trenberth_etal2014Globalwarming`, `marvel_etal2019Twentiethcenturyhydroclimate`,
    `williams_etal2020Largecontribution` — drying-side framing references

### Topics-vs-papers coverage matrix

| Topic | Primary | Supporting |
|---|---|---|
| WMO climate normal definition + alternatives | `arguez_vose2011` | `livezey_etal2007` |
| Computing climate normals when trends exist (cd's situation) | `livezey_etal2007` | (cross-rag) `vincent_etal2018ChangesCanadas` |
| Time of emergence / signal-to-noise framing | `hawkins_sutton2012` | (existing) `mora_etal2013projectedtiming` |
| Climate-departure framing (recent variability) | (existing) `mora_etal2013projectedtiming` | `hawkins_sutton2012` |
| Cumulative-impact / "loaded dice" framing | `hansen_etal2012` | — |
| Shifting baseline syndrome | (existing) `pauly1995Anecdotesshifting` | (existing) `rodrigues_etal2019Unshiftingbaseline`, `alleway_etal2023shiftingbaseline` |
| IPCC framing for FWCP context | (existing) `calvin_etal2023IPCCSummary` | (existing) `intergovernmentalpanelonclimatechangeipcc2023ClimateChange` |

### PDF acquisition strategy

- **OA / publicly hosted (auto-fetchable via curl):** Hansen 2012
  (harvard.edu seas), Livezey 2007 (meto.umd.edu kostya).
- **Paywalled — flag for user RG download:** Arguez & Vose 2011
  (AMS Cloudflare blocks curl), Hawkins & Sutton 2012 (AGU paywalled).

## Methodology quotes by topic (Phase 4 + 5)

(Will populate during Phase 4 + 5 execution.)

## Cross-cutting methodology

(Will populate during Phase 5 execution — likely the shortest of
the three since trend-test + baseline-window are already settled
in #58/#61; this issue just adds citation backing for the framing
choices.)

## Deviations

(Will populate during Phase 5 execution.)

## "Cite this for that" map

(Will populate during Phase 5 execution.)

## 3-split scoreboard (downstream consumer pointer)

After this issue lands, the climate-departure 3-split is complete:

- **Snowpack** (#53 → v0.1.7) — `planning/archive/2026-05-issue-53-snow-lit-review/findings.md`
- **Temperature** (#58 → v0.2.2) — `planning/archive/2026-05-issue-58-temperature-lit-review/findings.md`
- **Precipitation + drying** (#61 → v0.2.3) — `planning/archive/2026-05-issue-61-precip-drying-lit-review/findings.md`
- **Interpretation framing** (this issue → v0.2.4) — `planning/archive/2026-05-issue-63-interpretation-framing-lit-review/findings.md`

The downstream vignette wire-up branch pulls from all four files
selectively per the plain-language vignette philosophy
(`feedback_vignette_citations_sparse.md`).
