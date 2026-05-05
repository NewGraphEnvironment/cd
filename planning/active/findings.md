# Findings — Lit-review temperature-departure methodology + interpretation backing (#58)

## Issue context (verbatim from #58)

Vignette interpretation paragraphs in `peace-fwcp.Rmd` and
`kootenay-lake.Rmd` make defensible-sounding claims about temperature
departure — "warming has accelerated/slowed", "summer daytime maximum
is the salmonid thermal envelope", "day-night asymmetry shows up here
unlike X" — but currently land on **zero** peer-reviewed citations
for those claims. For FWCP fish-passage reporting context, these need
the same cited backing #53 gave the Snowpack section.

## Scope

First of three sequential climate-departure lit reviews covering the
non-snow vignette sections (the 3-split: temperature, precipitation +
drying, interpretation framing). Mirrors the #53 / #54 / v0.1.7
pattern verbatim:

- Targeted lit search → candidate list of ~10 papers
- Add to `NewGraphEnvironment/climate` Zotero collection (key
  `8MH9LCC9`), PDFs first per `/lit-search` policy
- Build `data/rag/temp_methodology.duckdb` ragnar store
- Mine for methodology quotes, write `findings.md` with "cite this
  for that" citation map
- Vignette citation insertion (the `[@key]` markers) happens on a
  downstream branch, not here

## Topics to cover

1. Temperature trend methodology — global / NH / BC-specific
2. Day-night asymmetry (DTR — diurnal temperature range)
3. Tmax vs tmin trends — the established asymmetry that our AOIs
   don't always show
4. Climate→stream-temperature bridge — link from air-temperature
   departure to salmonid thermal stress (the FWCP fish-passage
   context bridge)
5. Per-ecoregion / mountain-vs-interior warming patterns
6. ERA5-Land temperature validation — bias structure (parallel to
   snow's Kouki 2023 for SWE)

## State found during plan-mode exploration

### Existing rag-build pattern

`scripts/rag_build_snow_methodology.R` is the template to mirror
(getting renamed to `rag_snow_methodology_build.R` in Phase 0):
- Hardcoded `citationKey -> attachKey` map
- Reads PDFs from `data/rag/<topic>_pdfs/` (Web-API-downloaded local
  cache, not `~/Zotero/storage/{attachKey}/` — sidesteps the "download
  at sync time" Zotero desktop dependency)
- Writes DuckDB to `data/rag/{topic}_methodology.duckdb` (gitignored)
- Uses `ragnar` package with `embed_ollama(model = "nomic-embed-text")`
- Verifies via `n_chunks` and `n_origins` queries

### Existing Zotero entries we can reuse

19 items already in `NewGraphEnvironment/climate` (key `8MH9LCC9`).
Relevant temperature-side starters:
- `mora_etal2013` — climate-departure framing (Nature)
- `hersbach_etal2020` — ERA5 dataset paper
- `munoz_sabater_etal2021` — ERA5-Land dataset paper
- `isaak_etal2017` — NorWeST stream-temperature model
- `dierauer_etal2020` — BC ecoregion snow + streamflow drought
- `warkentin_etal2022` — BC summer flow + chinook
- `islam_etal2019` — Fraser flow regime change
- IPCC AR6 WGI + SYR — global / NH temperature foundational

Already in snow rag, **don't re-add**: `najafi_etal2017` (BC SWE +
temperature attribution), `yue_wang2002` (MK + autocorrelation).
Cross-rag queries can reach these without duplication.

### Vignette citation infrastructure status

`vignettes/peace-fwcp.Rmd` already has `bibliography: references.bib`
+ `link-citations: true` from #54. Snow-section `[@key]` markers
already wired. Temperature/precip/drying interpretation paragraphs
have **zero `[@key]` markers** — they read as confidently-stated but
unsupported claims. This issue produces the citation backbone; a
downstream branch wires the markers in.

## Architecture decisions taken (user-confirmed)

1. **3-split.** Temperature here, precip+drying next, interpretation
   framing third. BEC tracker (#59) sequenced after.
2. **Decoupled boundary.** This issue produces ragnar store +
   findings.md. Vignette `[@key]` insertion happens on a downstream
   branch.
3. **Branch parallel to nothing.** No simultaneous branches at
   present.
4. **Vignette edits forbidden on this branch** to keep boundary clean.
5. **Mirror existing rag-build script structure** verbatim — hardcoded
   map, local PDF cache, Ollama embeddings.
6. **Naming-convention prep first.** Phase 0 renames existing
   `rag_build_*.R` / `rag_query_*.R` to `rag_*_build.R` / `rag_*_query.R`
   (`noun_verb` per cd convention) before adding new files.

## Search log (Phase 1)

(Will populate during Phase 1 execution.)

## Methodology quotes by topic (Phase 4)

(Will populate during Phase 4 execution.)

## Cross-cutting methodology

(Will populate during Phase 5 execution.)

## Deviations

(Will populate during Phase 5 execution.)

## "Cite this for that" map

(Will populate during Phase 5 execution.)
