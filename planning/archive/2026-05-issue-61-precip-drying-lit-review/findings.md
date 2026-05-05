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

| File label (local) | Parent itemKey | Attach itemKey | n creators | PDF outcome | BBT citation key |
|---|---|---|---|---|---|
| `williams_etal2020` | `5K2AAPFK` | `SBSHUENU` | 9 | uploaded | `williams_etal2020Largecontribution` |
| `ficklin_novick2017` | `TJI32FNS` | `XT4HG85Q` | 2 | uploaded | `ficklin_novick2017Historicprojected` |
| `grossiord_etal2020` | `28NGCT9C` | `SGEP5ZVA` | 8 | exists | `grossiord_etal2020Plantresponses` |
| `trenberth_etal2014` | `PFDER8KC` | `Z8PQRGCS` | 7 | exists | `trenberth_etal2013Globalwarming` |
| `min_etal2011` | `WEQJ4FB3` | `X9QN8MPI` | 4 | exists | `min_etal2011Humancontribution` |
| `mekis_vincent2011` | `8UDFXV4M` | `89KJ9JEE` | 2 | exists | `mekis_vincent2011OverviewSecond` |
| `marvel_etal2019` | `784SPD6T` | `9XCZKTWD` | 6 | uploaded | `marvel_etal2019Twentiethcenturyhydroclimate` |

3 fresh PDF uploads (Williams, Ficklin, Marvel), 4 md5-deduped via
Zotero S3.

**Date wrinkle on Trenberth:** BBT generated `trenberth_etal2013...`
because CrossRef returns `issued = 2013-12-17` (online publication
date) for DOI `10.1038/nclimate2067`, while the print issue is
2014-01 (and the conventional citation is "Trenberth et al. 2014").
Leaving as-is per the auto-derived convention — the paper is still
uniquely identified by DOI; year discrepancy is cosmetic and shows
up only in the citation key string.

**Auto-restart pattern verified.** Used the macOS auto-restart
recipe added to soul#43:
```bash
osascript -e 'tell application "Zotero" to quit'
sleep 3
open -a Zotero
sleep 30   # startup + sync + BBT key gen
```
All 7 keys generated cleanly on first restart. ~30 s wait was
sufficient for 7 items.

## Methodology quotes by topic (Phase 4 + 5)

Raw retrieval results in
`planning/active/precip_drying_methodology_quotes.md` (626 lines, 24
queries × top-5 chunks). 526 chunks across 7 sources in the rag
store. Synthesis below picks the strongest hits per topic.

Top-5 hit count per paper across all queries:
- `grossiord_etal2020` — 33 (long review of VPD effects)
- `marvel_etal2019` — 23
- `ficklin_novick2017` — 23
- `trenberth_etal2014` — 21
- `williams_etal2020` — 16
- `mekis_vincent2011` — 16
- `min_etal2011` — 6

### Precipitation trend methodology (Canadian / homogenized)

- `mekis_vincent2011`: "Daily rainfall and snowfall amounts have
  been adjusted for 464 stations for known measurement issues such
  as wind undercatch, evaporation and wetting losses for each type
  of rain-gauge, snow water equivalent from ruler measurements,
  trace observations and accumulated amounts from several days...
  This second generation dataset represents an improvement over
  the first generation precipitation dataset and was specifically
  designed for climate trend analysis across Canada." → Methodology
  reference for "BC precipitation has changed by N%" claims when
  station-data anchoring is needed.
- (existing) `vincent_etal2018ChangesCanadas`: precipitation indices
  for the BC sub-region (1948–2012) with Sen + Kendall's τ. → Direct
  BC numbers + methodology.

### Anthropogenic precip-extremes attribution

- `min_etal2011`: "human-induced increases in greenhouse gases have
  contributed to the observed intensification of heavy precipitation
  events found over approximately two-thirds of data-covered parts
  of Northern Hemisphere land areas... changes in extreme
  precipitation projected by models may be underestimated because
  models seem to underestimate the observed increase in heavy
  precipitation with warming." → Foundational citation for "heavy
  precipitation events are increasing" prose.

### VPD continental-scale drying

- `ficklin_novick2017`: "spring, summer, and fall seasons exhibited
  the largest areal extent of significant increases in VPD, which
  was largely concentrated in the western and southern portions of
  the U.S. Significant increases in VPD have been caused by air
  temperature increases and relative humidity changes, especially
  during the summer season in the southern portion of the U.S., over
  the historical time period." → Direct citation for the "atmosphere
  is drying" claim. **Critical for the v0.1.1 vignette finding** that
  soils dry from both ↓P and ↑ET.
- (existing) `vincent_etal2018ChangesCanadas`: similar VPD-relevant
  Canadian findings (very warm temperatures + RH changes).

### VPD ecosystem responses

- `grossiord_etal2020`: "Plant responses to rising vapor pressure
  deficit" — comprehensive review of stomatal closure, productivity
  decline, mortality risk under rising VPD. → Use sparingly: only if
  the vignette interp wants to mention "rising VPD reduces water
  available to vegetation" beyond the soil-moisture story.

### NA megadrought attribution

- `williams_etal2020`: "the 2000-2018 southwestern North American
  drought was the second driest 19-year period since 800 CE...
  Anthropogenic trends in temperature, relative humidity, and
  precipitation estimated from 31 climate models account for 47%
  (model interquartiles of 35 to 103%) of the drought severity."
  → Authoritative citation for "anthropogenic warming is driving
  drying", though the SWNA region is south of cd's BC AOIs. Useful
  as the "biggest signal in NA drying" reference.

### Drought framework

- `trenberth_etal2014`: "the formulation of the Palmer Drought
  Severity Index (PDSI) and the data sets used to determine the
  evapotranspiration component" — methodology and data choices
  matter for drought definitions. Rebuts earlier "drought is
  decreasing globally" claims by reanalyzing PDSI with proper
  Penman-Monteith ET. → Anchor citation if the vignette discusses
  "drought" as a concept (define carefully — supply minus demand).

### 20th-century hydroclimate pattern (signal emergence)

- `marvel_etal2019`: "three distinct periods are identifiable in
  climate models, observations and reconstructions during the
  twentieth century. In recent decades (1981 to present), the signal
  of greenhouse gas forcing is present but not yet detectable at
  high confidence." Uses millennium-scale tree-ring PDSI
  reconstructions. → Useful for "the human signal in hydroclimate is
  detectable in the early 20th century" framing; less central than
  Williams 2020 for cd's BC AOIs but stronger globally.

### BC / PNW summer flow + thermal habitat

- (existing) `warkentin_etal2022Lowsummer`: empirical link from low
  summer flows to chinook productivity in a BC watershed. → Direct
  BC citation for the climate→fish bridge on the precip side
  (complements the temperature-side bridge from #58).
- (existing) `islam_etal2019Quantifyingprojected`: Fraser flow
  regime change projections. → Regional context for "BC flow regimes
  are shifting".

### Trend test methodology (cross-rag)

- (cross-rag from snow rag)
  `yue_wang2002Applicabilityprewhitening` — same MK + AC story as
  #58. Raw MK is correct for cd's 76-year strong-trend series.

## Cross-cutting methodology

### Baseline window — same as snow + temperature

cd's 1951–1980 baseline is acceptable for precip + soil moisture +
VPD. None of the new papers anchor on a different normal in a way
that conflicts with our choice.

### Trend test — same as snow + temperature

Raw MK + Theil-Sen via `cd_trend()` is consistent with both the
Vincent 2018 + Mekis & Vincent 2011 methodology (Sen + Kendall's
τ + iterative AC) and Yue & Wang 2002 (raw MK is correct when
trend exists). No new methodology questions.

### ERA5-Land precipitation + soil-moisture validation — known caveat

No paper in our 7-paper corpus directly validates ERA5-Land precip
or soil moisture against in-situ observations for cd's BC AOIs.
Available alternatives:

- (existing) `munoz-sabater_etal2021ERA5Landstateoftheart`: ERA5-Land
  validation paper for soil moisture (limited to fluxnet sites
  globally).
- `mekis_vincent2011`: gives a station-based BC precipitation
  ground-truth that cd's ERA5-Land precip trends can be compared
  against qualitatively.
- `ficklin_novick2017`: uses ERA-Interim VPD, similar reanalysis
  product family. Bias structure analogous.

**Recommendation for vignette interp:** note this as a known caveat
(same as the temp-side ERA5-Land caveat in #58). Validation against
ECCC homogenized stations is a possible follow-up issue.

## Deviations

The new precip+drying analysis doesn't introduce additional
deviations beyond the temperature-side ones already documented in
the #58 archive. The cd pipeline is methodologically consistent on
the trend-test + baseline-window questions for all variables.

## "Cite this for that" — citation map for downstream vignette wiring

Same philosophy preface applies (this is a library, not a
prescription; downstream cites authorities sparingly for findings
visible in AOI plots/tables). 14-row menu:

| Claim type | Primary citation | Supporting |
|---|---|---|
| Heavy / extreme precipitation increasing under warming | `@min_etal2011Humancontribution` | — |
| Canadian / BC adjusted precipitation methodology | `@mekis_vincent2011OverviewSecond` | (existing) `@vincent_etal2018ChangesCanadas` |
| Atmospheric drying via rising VPD | `@ficklin_novick2017Historicprojected` | (existing) `@vincent_etal2018ChangesCanadas` |
| Soils drying from both ↓P and ↑ET (the v0.1.1 finding) | `@ficklin_novick2017Historicprojected` | `@williams_etal2020Largecontribution`, `@trenberth_etal2014Globalwarming` |
| Plant / ecosystem stress from rising VPD | `@grossiord_etal2020Plantresponses` | — |
| NA megadrought attributed to anthropogenic warming | `@williams_etal2020Largecontribution` | — |
| Drought framework / PDSI methodology caveats | `@trenberth_etal2014Globalwarming` | — |
| 20th-century human signal in global hydroclimate | `@marvel_etal2019Twentiethcenturyhydroclimate` | `@williams_etal2020Largecontribution` |
| BC ecoregion drought patterns | (existing) `@dierauer_etal2020Climatechange` | — |
| BC summer flow + chinook empirical link | (existing) `@warkentin_etal2022Lowsummer` | (existing) `@islam_etal2019Quantifyingprojected` |
| ERA5 / ERA5-Land dataset citations | (existing) `@munoz-sabater_etal2021ERA5Landstateoftheart` | (existing) `@hersbach_etal2020ERA5global` |
| Climate-departure framing (cumulative-impact) | (existing) `@mora_etal2013projectedtiming` | (Issue 3 framing review) |
| Adaptation framing | (existing) `@moore_schindler2022Gettingahead` | — |
| Rain-vs-snow phase shift (cross-rag) | (cross-rag) `@knowles_etal2006SnowfallVersus` | — |
| Trend test methodology (cross-rag) | (cross-rag) `@yue_wang2002Applicabilityprewhitening` | — |
