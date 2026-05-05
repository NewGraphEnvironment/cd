# Findings — Lit-review precipitation + drying methodology + interpretation backing (#61)

## Issue context (verbatim from #61)

Vignette interpretation paragraphs in `peace-fwcp.Rmd` and
`kootenay-lake.Rmd` make defensible-sounding claims about
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
Mirrors the #58 / #54 / v0.1.7 pattern verbatim.

## Topics to cover

1. Precipitation trend methodology — long-record analyses,
   homogenization, treatment of trace events
2. Heavy / extreme precipitation — intensity-frequency-duration,
   anthropogenic attribution
3. Orographic / mountain precipitation — rain-shadow gradients
   (Selkirk-Purcell type contrasts in Kootenay AOI)
4. Vapor pressure deficit (VPD) + relative humidity — atmospheric
   evaporative demand driver
5. Soil moisture as integrative drought signal — supply-demand
   balance, temperature acceleration of drying
6. ERA5-Land precip / soil-moisture validation
7. Drought-fish linkage — summer-flow / soil-moisture deficit →
   thermal habitat
8. Trend-test methodology cross-check (already covered for trend
   tests in snow + temp rags; cross-rag query suffices)

## State found during plan-mode exploration

### Existing rag-build pattern (mirror this verbatim)

`scripts/rag_temp_methodology_build.R` (the post-#58 canonical) is
the template. Reads PDFs from `data/rag/<topic>_pdfs/` (Web-API-
downloaded local cache). Writes DuckDB to `data/rag/<topic>.duckdb`
(gitignored). Uses `ragnar` with `embed_ollama(model =
"nomic-embed-text")`.

### Existing items in `climate` collection (re-use, do not re-add)

19 items already there — relevant precip/drying-side starters:

| BBT key | Year | Why relevant |
|---|---|---|
| `vincent_etal2018ChangesCanadas` | 2018 | Canada precip trends in same paper as temp |
| `islam_etal2019Quantifyingprojected` | 2019 | Fraser flow regime change |
| `dierauer_etal2020Climatechange` | 2020 | BC ecoregion drought |
| `warkentin_etal2022Lowsummer` | 2022 | BC summer flow + chinook |
| `munoz-sabater_etal2021ERA5Landstateoftheart` | 2021 | ERA5-Land soil-moisture validation |
| `mora_etal2013projectedtiming` | 2013 | Climate-departure framing (cross-cutting) |
| `hersbach_etal2020ERA5global` | 2020 | ERA5 dataset paper |
| `moore_schindler2022Gettingahead` | 2022 | Adaptation framing |

### Cross-rag references (already in other rag stores; query them
without re-adding)

- `data/rag/snow_methodology.duckdb`:
  - `knowles_etal2006SnowfallVersus` — rain-vs-snow phase shift,
    feeds the soil-moisture + precip-fraction story
  - `yue_wang2002Applicabilityprewhitening` — MK + autocorrelation
    methodology (covers all variables, not just snow)
- `data/rag/temp_methodology.duckdb`:
  - `vincent_etal2018ChangesCanadas` — Canadian temp + precip
    trends, Sen+MK methodology
  - All 9 other temp-rag papers if needed for cross-cutting
    methodology questions

## Architecture decisions (carrying forward from #58)

1. **Decoupled boundary.** This issue produces ragnar store +
   findings.md. Vignette `[@key]` insertion happens on a
   downstream branch.
2. **Branch parallel to nothing** — Issue 3 (interpretation framing)
   is sequential, not parallel.
3. **Vignette edits forbidden on this branch** to keep boundary clean.
4. **Mirror existing rag-build script structure** verbatim — hardcoded
   map, local PDF cache, Ollama embeddings, `noun_verb` naming.
5. **No `Citation Key:` overrides** in `extra` — BBT auto-derives
   per NGE convention (soul#43). For corporate-author papers (cf
   Pepin 2015 in #58), PATCH individual authors after Web API POST
   so BBT doesn't fall back to title-key.
6. **BBT version compat** — Zotero 8/9 needs BBT 9.x. If a BBT
   compat issue surfaces during Phase 2 key capture, fix per the
   #58 archive notes.

## Search log (Phase 1)

Phase 1 ran web searches against publisher landings + DOI lookups
on the candidate list. 7 confirmed new papers (slimmer than #58's
10-paper list since the precip+drying story relies more on existing
collection items + cross-rag than #58 did).

### Final candidate list — 7 new papers to add

| # | Citation key (proposed) | Title (truncated) | Journal / Year | DOI | OA route |
|---|---|---|---|---|---|
| 1 | `williams_etal2020` | Large contribution from anthropogenic warming to an emerging North American megadrought | Science 368 / 2020 | `10.1126/science.aaz9600` | Paywalled, escholarship.org + emnrd.nm.gov host PDFs |
| 2 | `ficklin_novick2017` | Historic and projected changes in vapor pressure deficit suggest a continental-scale drying of the United States atmosphere | J Geophys Res Atmos 122 / 2017 | `10.1002/2016JD025855` | AGU paywalled, RG |
| 3 | `grossiord_etal2020` | Plant responses to rising vapor pressure deficit | New Phytologist 226 / 2020 | `10.1111/nph.16485` | Wiley paywalled, sperry.biology.utah.edu hosts PDF |
| 4 | `trenberth_etal2014` | Global warming and changes in drought | Nat Clim Chg 4 / 2014 | `10.1038/nclimate2067` | Paywalled, OpenSky UCAR free |
| 5 | `min_etal2011` | Human contribution to more-intense precipitation extremes | Nature 470 / 2011 | `10.1038/nature09763` | Paywalled, Edinburgh + RG host PDFs |
| 6 | `mekis_vincent2011` | An Overview of the Second Generation Adjusted Daily Precipitation Dataset for Trend Analysis in Canada | Atmos-Ocean 49 / 2011 | `10.1080/07055900.2011.583910` | T&F (likely open via Canada.gov hosted PDF) |
| 7 | `marvel_etal2019` | Twentieth-century hydroclimate changes consistent with human influence | Nature 569 / 2019 | `10.1038/s41586-019-1149-8` | Paywalled, NASA-GISS hosts free PDF |

### Skipped from initial candidate list

- **`donat_etal2013`** (HadEX2 dataset) — `min_etal2011` + `vincent_etal2018ChangesCanadas` cover the precip-extremes story sufficiently; HadEX2 would be supplementary data-paper grounding, not load-bearing for vignette claims.
- **`mass_etal2002`** (PNW NWP QPF) — actual paper is more about NWP resolution than orographic processes per se. Generic "mountains create rain-shadows" claim in the Kootenay vignette doesn't need a load-bearing physics-of-orography paper; descriptive prose + the BC-specific Vincent 2018 / Mekis & Vincent 2011 trends suffice.
- **`daly_etal2008`** (PRISM) — methodology paper for an alternative precip product; cd uses ERA5-Land directly, so PRISM is methodology-aside.
- **`sheffield_wood2008`** (drought trends, J Climate) — superseded by `trenberth_etal2014` for the framework; would be supplementary.

### Existing items in `climate` collection — reuse, do not re-add

5 directly relevant existing items:

| itemKey | BBT key | Year | Why relevant |
|---|---|---|---|
| `D9H2UQBZ` | `vincent_etal2018ChangesCanadas` | 2018 | Canada precip trends in same paper as temp |
| `U2XJ5ENM` | `islam_etal2019Quantifyingprojected` | 2019 | Fraser flow regime change |
| `G2H2KWQK` | `dierauer_etal2020Climatechange` | 2020 | BC ecoregion drought |
| `T4V2VX25` | `warkentin_etal2022Lowsummer` | 2022 | BC summer flow + chinook |
| `AIR5D4QW` | `munoz-sabater_etal2021ERA5Landstateoftheart` | 2021 | ERA5-Land soil-moisture validation |

Plus general framing items (use sparingly per philosophy):
`mora_etal2013projectedtiming`, `hersbach_etal2020ERA5global`,
`moore_schindler2022Gettingahead`.

### Cross-rag references — already in other rag stores

- **`data/rag/snow_methodology.duckdb`:**
  - `knowles_etal2006SnowfallVersus` — rain-vs-snow phase shift (precip phase change)
  - `yue_wang2002Applicabilityprewhitening` — MK + autocorrelation (covers all variables)
- **`data/rag/temp_methodology.duckdb`:**
  - `vincent_etal2018ChangesCanadas` — Canadian temp + precip trends, Sen+MK methodology
  - All 9 other temp-rag papers if needed for cross-cutting questions

### Topics-vs-papers coverage matrix

| Topic | Primary | Supporting |
|---|---|---|
| Precip trend methodology (Canadian / homogenized) | `mekis_vincent2011` | (existing) `vincent_etal2018ChangesCanadas` |
| Anthropogenic precip-extremes attribution | `min_etal2011` | — |
| Orographic / rain-shadow gradients | (descriptive prose; no load-bearing cite) | (existing) `dierauer_etal2020Climatechange` for BC ecoregion contrasts |
| VPD trends + continental drying | `ficklin_novick2017` | (existing) `vincent_etal2018ChangesCanadas` |
| VPD ecosystem/plant responses | `grossiord_etal2020` | — |
| Drought attribution (NA megadrought) | `williams_etal2020` | `trenberth_etal2014` |
| Drought framework / definition | `trenberth_etal2014` | — |
| 20th-century hydroclimate "drying" pattern | `marvel_etal2019` | `williams_etal2020` |
| BC / PNW summer-flow + thermal habitat | (existing) `warkentin_etal2022Lowsummer` | (existing) `islam_etal2019Quantifyingprojected` |
| ERA5-Land soil-moisture validation | (existing) `munoz-sabater_etal2021ERA5Landstateoftheart` | — |
| Trend test methodology | (cross-rag) `vincent_etal2018ChangesCanadas`, `yue_wang2002Applicabilityprewhitening` | — |

### PDF acquisition outcome (Phase 2)

4 of 7 fetched via curl: Williams 2020 (emnrd.nm.gov state-hosted),
Grossiord 2020 (sperry.biology.utah.edu), Mekis & Vincent 2011
(ec.gc.ca CDAS), Min 2011 (Edinburgh ghegerl PDF). 3 user-provided
via ResearchGate: Ficklin & Novick 2017, Trenberth 2014, Marvel
2019. Marvel needed OCR (LLNL preprint version, image-only scan;
working title differs from published Nature title but same DOI).
All 7 PDFs in `data/rag/precip_drying_methodology_pdfs/`,
text-layered, gitignored.

### Zotero adds (Phase 2 — completed)

7 papers POSTed to `NewGraphEnvironment/climate` (key `8MH9LCC9`)
via Web API with PDFs attached. CrossRef-driven metadata; tags
`precip-drying-departure-methodology` + `cd-issue-61`. No `Citation
Key:` overrides in `extra` (per soul#43 + #58 lesson). All 7 papers
have at least 2 individual creators per CrossRef; no corporate-only
authorship to PATCH around (cf Pepin 2015 in #58).

| File label (local) | Parent itemKey | Attach itemKey | n creators | PDF outcome | BBT citation key (post-restart) |
|---|---|---|---|---|---|
| `williams_etal2020` | `5K2AAPFK` | `SBSHUENU` | 9 | uploaded | (pending) |
| `ficklin_novick2017` | `TJI32FNS` | `XT4HG85Q` | 2 | uploaded | (pending) |
| `grossiord_etal2020` | `28NGCT9C` | `SGEP5ZVA` | 8 | exists | (pending) |
| `trenberth_etal2014` | `PFDER8KC` | `Z8PQRGCS` | 7 | exists | (pending) |
| `min_etal2011` | `WEQJ4FB3` | `X9QN8MPI` | 4 | exists | (pending) |
| `mekis_vincent2011` | `8UDFXV4M` | `89KJ9JEE` | 2 | exists | (pending) |
| `marvel_etal2019` | `784SPD6T` | `9XCZKTWD` | 6 | uploaded | (pending) |

3 fresh PDF uploads (Williams, Ficklin, Marvel), 4 md5-deduped via
Zotero S3. **User action pending: restart Zotero** so BBT generates
citation keys for the 7 Web-API-created items.

## Methodology quotes by topic (Phase 4 + 5)

(Will populate during Phase 4 + 5 execution.)

## Cross-cutting methodology

(Will populate during Phase 5 execution — likely shorter than #58
since trend-test methodology + baseline window are already settled.)

## Deviations

(Will populate during Phase 5 execution.)

## "Cite this for that" map

(Will populate during Phase 5 execution.)
