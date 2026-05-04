# Archive: Snowpack-departure methodology lit review (#53)

## Outcome

Established the citation backbone for #48's "Snowpack" vignette
section. 11 peer-reviewed papers in
`NewGraphEnvironment/hydrology` (Zotero collection key
`X29BX4U8`), a local ragnar DuckDB store at
`data/rag/snow_methodology.duckdb` (gitignored, 1006 chunks,
11 sources), and a synthesis-plus-citation-map
`findings.md` ready for #48 Phase 5 to consume verbatim.
Released as **v0.1.7** (patch).

## Headline findings

1. **`cd_trend()`'s raw Mann-Kendall + Theil-Sen (no
   prewhitening) is methodologically correct** per Yue & Wang
   (2002, WRR). Their Monte Carlo result: prewhitening *fails*
   when a real trend exists — it underestimates slope. For our
   76-year series with strong climate trends, raw MK is the
   right call. We were lucky.
2. **`snowmelt_rate_peak` (annual max of 7-day rolling daily
   smlt) is our invention** — no close precedent in the
   literature. Document as "diagnostic of upstream snowpack-side
   freshet intensity" rather than implying methodological
   pedigree.
3. **ERA5-Land overestimates SWE in mountains by 150–200%
   NH-wide** (Kouki et al. 2023, Cryosphere). Bias is stable
   over time → trends are still valid.
4. **`swe_max` (true annual max of daily SWE) is a slight
   deviation** from the April-1-SWE canon (Pederson 2011, Mote
   2005/2018). Equivalent in effect for BC pixels; document
   briefly.
5. **Two BC-specific anchors are gold for fish-passage
   reporting:** Najafi et al. (2017) attributes BC SWE decline
   to anthropogenic forcing; Kang et al. (2016) documents the
   10-day advance of the Fraser freshet during the salmon
   migration window 1949–2006.

## Citation map (15 rows in findings.md)

The "cite this for that" table at the end of `findings.md` maps
vignette claim types to citation keys. #48 Phase 5 should be a
copy-paste exercise rather than a literature search.

## Reproducing the rag store

`data/rag/snow_methodology.duckdb` is gitignored. To rebuild:

1. Download the 11 PDFs from Zotero Web API to
   `data/rag/snow_methodology_pdfs/` (one file per citation
   key, naming `{citationKey}.pdf`). The `attachKey` for each
   paper is hardcoded in `scripts/rag_build_snow_methodology.R`.
2. `ollama serve` + `ollama pull nomic-embed-text` (one-time).
3. `Rscript scripts/rag_build_snow_methodology.R` — ~80 s,
   produces 1006 chunks across 11 sources.

To re-mine: `Rscript scripts/rag_query_snow_methodology.R` →
regenerates `snow_methodology_quotes.md` (raw retrieval, archived
here at the time of merge).

## Closing ref

- Issue: NewGraphEnvironment/cd#53
- PR: NewGraphEnvironment/cd#54 (squash 765a63c, merged 2026-05-04)
- Downstream consumer: #48 Phase 5 (vignette extension)
