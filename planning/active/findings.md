# Findings — Snowpack-departure methodology lit review (#53)

## Issue context (verbatim from #53)

Phase 5 of #48 will make defensible-sounding claims like "freshet has
shifted N days earlier," "peak SWE has declined M%," and "the rain-snow
transition is moving upslope." For our reporting context (fish passage,
aquatic restoration appendices), these claims need to land on cited
peer-reviewed methodology, not back-of-envelope. Without that,
downstream report reviewers can fairly push back on choice of metric,
baseline window, trend test, and bias-correction (or lack thereof).

The four metrics shipping in #48 are themselves methodology choices:
**7-day rolling sum** for freshet flashiness; **DOY-50** for melt
timing; **annual peak SWE** for snowpack magnitude; **annual snowfall
fraction** for precipitation phase. Each has a literature behind it —
this issue produces a `findings.md` of exact-page quotes that justify
each metric choice, indexed by citation key, ready for #48 Phase 5 to
consume.

## State found during plan-mode exploration

### Existing rag-build pattern

`scripts/rag_build_departure_framing.R` is the template to mirror:
- Hardcoded `citationKey -> attachKey` map
- Reads PDFs from `~/Zotero/storage/{attachKey}/`
- Writes DuckDB to `data/rag/{name}.duckdb` (gitignored — `data/rag/`
  already in `.gitignore`)
- Uses `ragnar` package with `embed_ollama(model = "nomic-embed-text")`
- Verifies via `n_chunks` and `n_origins` queries

### Existing Zotero entries we can reuse

From `scripts/rag_build_departure_framing.R` (lines 31–38):
- `munoz_sabater2021` — attachKey `SUS5A57A` (ERA5-Land dataset paper)
  → directly relevant, drop straight into the snow rag-build map.
- `mora_etal2013` — attachKey `36G25ZK9` (climate departure timing)
  → general framing, less central to snow but worth including.
- `hersbach_etal2020` — attachKey `IE8SUWCS` (ERA5 global reanalysis)
  → context for ERA5-Land's parent dataset.

### Vignette citation infrastructure status

`vignettes/peace-fwcp.Rmd` currently has **zero citations**. No `bibliography:`
YAML field, no `[@cite]` markers, no `references.bib`. Phase 5 of #48 will
wire this up for the first time. This issue's deliverable is the
`findings.md` with citation keys ready — the YAML wiring lands in #48.

## Architecture decisions taken (user-confirmed)

1. **Decoupled boundary.** This issue produces methodology notes and a
   ragnar store. Vignette citation insertion happens on the `48-snow-vars`
   branch in Phase 5. Avoids merge conflicts.
2. **Branch is parallel to `48-snow-vars`.** Off main, separate PRs.
3. **Vignette edits forbidden on this branch** to keep the boundary clean.
4. **Mirror existing rag-build script structure** verbatim, just with a
   different citation-key map and output path.

## Search log (Phase 1)

Phase 1 ran web searches against publisher landings and DOI lookups
on the candidate list. All 11 papers below have confirmed DOIs and
identified PDF access. Citation keys follow the BBT
`firstauthor_etal{year}` convention used in `rag_build_departure_framing.R`.

### Final candidate list (11 papers)

| Citation key | Title (truncated) | Journal / Year | DOI | OA? | Why |
|---|---|---|---|---|---|
| `mote_etal2005` | Declining mountain snowpack in western North America | BAMS 86 / 2005 | `10.1175/BAMS-86-1-39` | AMS — likely OA after embargo, check | Foundational PNW snowpack-decline methodology — referenced by many newer papers |
| `stewart_etal2005` | Changes toward earlier streamflow timing across western North America | J Climate 18 / 2005 | `10.1175/JCLI3321.1` | AMS — likely OA | Defines centroid timing (CT) and DOY-based streamflow metrics — direct precedent for `snowmelt_doy_50` |
| `knowles_etal2006` | Trends in snowfall versus rainfall in the western United States | J Climate 19 / 2006 | `10.1175/JCLI3850.1` | AMS / USGS preprint OA | Defines snowfall-fraction (SFE/P) methodology — direct precedent for `snowfall_fraction` |
| `mote_etal2018` | Dramatic declines in snowpack in the western US | npj Clim Atmos Sci / 2018 | `10.1038/s41612-018-0012-1` | **OA** (npj) | Updated PNW summary, methodology continuity from 2005 paper, recent framing for "Δ peak SWE" interpretations |
| `najafi_etal2017` | Attribution of the Observed Spring Snowpack Decline in British Columbia to Anthropogenic Climate Change | J Climate 30 / 2017 | `10.1175/JCLI-D-16-0189.1` | AMS — check | **BC-specific attribution paper.** Uses VIC + CMIP5 fingerprinting to attribute observed BC SWE decline to anthropogenic forcing — directly relevant to our reporting context. Lead author is at UNBC |
| `cayan_etal2001` | Changes in the Onset of Spring in the Western United States | BAMS 82 / 2001 | `10.1175/1520-0477(2001)082<0399:CITOOS>2.3.CO;2` | AMS — likely OA | Spring-onset / first-pulse methodology origins; cross-validates `snowmelt_doy_50` and the broader earlier-spring framing |
| `yue_wang2002` | Applicability of prewhitening to eliminate the influence of serial correlation on the Mann-Kendall test | Water Resour Res 38 / 2002 | `10.1029/2001WR000861` | AGU — paywalled but ResearchGate likely | Trend-test methodology. Critical finding: prewhitening **fails** when a trend exists; the trend-free pre-whitening (TFPW) procedure followed. Informs whether cd should add autocorrelation correction |
| `pederson_etal2011` | The Unusual Nature of Recent Snowpack Declines in the North American Cordillera | Science 333 / 2011 | `10.1126/science.1201570` | Paywalled (Science) — USGS / RG preprint OA | Tree-ring + instrumental long-record context. Shows late-20th-century declines are unprecedented over ~1000 years — frames the "departure-from-historical" interpretation |
| `kang_etal2016` | Impacts of a Rapidly Declining Mountain Snowpack on Streamflow Timing in Canada's Fraser River Basin | Sci Rep 6 / 2016 | `10.1038/srep19299` | **OA** (Scientific Reports) | **BC + freshet-timing + salmon-migration paper.** Documents 10-day advance of Fraser freshet 1949–2006, declining summer flows affecting up-river migrations. Maximally relevant to fish-passage reporting context |
| `kouki_etal2023` | Evaluation of snow cover properties in ERA5 and ERA5-Land with several satellite-based datasets in the Northern Hemisphere in spring 1982–2018 | The Cryosphere 17 / 2023 | `10.5194/tc-17-5007-2023` | **OA** (TC, CC-BY 4.0) | **ERA5-Land snow-validation paper.** Documents that ERA5-Land overestimates SWE in mountain regions; ERA5-Land improves on ERA5 at mid-altitude mountains. Bounds the bias for our four metrics |
| `munoz_sabater_etal2021` | ERA5-Land: a state-of-the-art global reanalysis dataset for land applications | ESSD / 2021 | (already in Zotero) | OA | ERA5-Land dataset paper — already in Zotero with attachKey `SUS5A57A` per `scripts/rag_build_departure_framing.R`. Reuse |

### Topics-vs-papers coverage matrix

| #48 metric / topic | Primary paper | Supporting paper(s) |
|---|---|---|
| `swe_max` (annual peak SWE) | `mote_etal2018` | `mote_etal2005`, `najafi_etal2017`, `pederson_etal2011` |
| `snowfall_fraction` | `knowles_etal2006` | (none — it's the canonical methodology) |
| `snowmelt_doy_50` | `stewart_etal2005` | `cayan_etal2001`, `kang_etal2016` |
| `snowmelt_rate_peak` | (search may surface a freshet-flashiness paper during Phase 4) | `stewart_etal2005`, `kang_etal2016` |
| Baseline window choice | (general — `mote_etal2005`, `najafi_etal2017` use 1916–2003 baseline; check during Phase 4) | |
| MK + autocorrelation | `yue_wang2002` | (the TFPW follow-up Yue et al. 2002 ref to dig up if needed) |
| ERA5-Land snow biases | `kouki_etal2023` | `munoz_sabater_etal2021` |
| BC-specific context | `najafi_etal2017`, `kang_etal2016` | (Najafi attribution + Kang impacts, both Peace/Fraser-relevant) |

### Notes on access strategy

- **AMS journals (Mote 2005, Stewart 2005, Knowles 2006, Najafi 2017, Cayan 2001):** AMS has a 6-month embargo then OA. All target papers are >6 months old → should be freely available. Check publisher landing page during Phase 2 Zotero adds; fall back to USGS pubs preprints for any that are paywalled (Cayan, Stewart, Knowles all have `pubs.usgs.gov` mirrors per search results).
- **`pederson_etal2011`:** Science is paywalled. USGS pub mirror at `pubs.usgs.gov/publication/70155831` per search results — check if direct PDF download is available; otherwise flag for user manual download from ResearchGate.
- **`yue_wang2002`:** Wiley/AGU paywalled. ResearchGate has the PDF per search results — flag for user manual download.
- **`mote_etal2018`, `kang_etal2016`, `kouki_etal2023`, `munoz_sabater_etal2021`:** all OA — direct fetch via web API S3 upload.

### Out of search scope

- Did NOT search for streamflow-modelling-specific or glacier-dynamics literature (per #53 out-of-scope list).
- Did NOT search for very recent (2024–2026) papers — focus is on the established methodology canon. If something in Phase 4 mining points us at a critical recent paper, can add 1–2 more.

## Papers added to Zotero — `hydrology` collection (per user direction; key `JI7EBZNF`)

10 new entries added via Web API POST with `collections=["JI7EBZNF"]` (single
batch, all succeeded). 11th paper `munoz_sabater_etal2021` already in Zotero
from prior project (attachKey `SUS5A57A`).

### PDFs attached automatically (6/10)

| Citation key | Zotero itemKey | Attachment key | Source URL |
|---|---|---|---|
| `mote_etal2005` | `UUB24X5K` | `G9IRM42Z` | `journals.ametsoc.org/downloadpdf/journals/bams/86/1/bams-86-1-39.pdf` (Unpaywall OA) |
| `knowles_etal2006` | `TD2GMMC8` | `I8DV96F4` | `journals.ametsoc.org/downloadpdf/journals/clim/19/18/jcli3850.1.pdf` (Unpaywall OA) |
| `mote_etal2018` | `2IIWVD5J` | `DEV98ZWA` | `nature.com/articles/s41612-018-0012-1.pdf` (npj OA) |
| `cayan_etal2001` | `39JIJR3F` | `9R74HB5D` | `journals.ametsoc.org/downloadpdf/journals/bams/82/3/...` (Unpaywall OA) |
| `kang_etal2016` | `BHN3CHWI` | `I6HJU2U9` | `nature.com/articles/srep19299.pdf` (Sci Rep OA) |
| `kouki_etal2023` | `CAE7SFPP` | `XXK3PP36` | `tc.copernicus.org/articles/17/5007/2023/tc-17-5007-2023.pdf` (TC CC-BY) |

### PDFs need manual download (4/10)

Zotero entry exists in the hydrology collection; just needs the PDF
dragged into it. See companion list output below findings.md → user
drops PDFs into the existing Zotero items by the parent key.

| Citation key | Zotero itemKey | Reason |
|---|---|---|
| `stewart_etal2005` | `ZHU2DW9V` | Unpaywall: no OA. Direct AMS PDF returns HTTP 403 (paywall, despite the matching Mote 2005 paper being OA) |
| `najafi_etal2017` | `KHPBJR3H` | Unpaywall: no OA. AMS direct also 403 |
| `yue_wang2002` | `G4578ERF` | Wiley/AGU paywalled (expected) |
| `pederson_etal2011` | `WSTZDDGG` | Science paywalled (expected) |

### munoz_sabater_etal2021 (already in library)

| Citation key | Zotero attachKey | Source |
|---|---|---|
| `munoz_sabater_etal2021` | `SUS5A57A` | Already in Zotero from prior `rag_build_departure_framing.R` |

## Methodology quotes by #48 metric

_Phase 4 will populate these subsections with exact-page quotes._

### `swe_max` (annual peak SWE)

### `snowfall_fraction` (annual sf/tp ratio in %)

### `snowmelt_doy_50` (day of 50% cumulative melt)

### `snowmelt_rate_peak` (annual max of 7-day rolling melt)

## Cross-cutting methodology

### Baseline window (1951–1980 vs alternatives)

### Mann-Kendall + autocorrelation

### ERA5-Land snow biases (validation literature)

## Deviations from consensus

_Phase 5 will populate this section with where cd's choices differ
from the literature consensus and why._

## "Cite this for that" — citation map for #48 Phase 5

_Phase 5 will populate this table as copy-paste-ready input for the
vignette interp paragraph._

| Vignette claim | Citation key | Page |
|---|---|---|
