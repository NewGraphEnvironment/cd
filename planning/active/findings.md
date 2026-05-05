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

(Will populate during Phase 1 execution.)

## Methodology quotes by topic (Phase 4 + 5)

(Will populate during Phase 4 + 5 execution.)

## Cross-cutting methodology

(Will populate during Phase 5 execution — likely shorter than #58
since trend-test methodology + baseline window are already settled.)

## Deviations

(Will populate during Phase 5 execution.)

## "Cite this for that" map

(Will populate during Phase 5 execution.)
