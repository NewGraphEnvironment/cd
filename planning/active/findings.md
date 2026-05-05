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

`scripts/rag_snow_methodology_build.R` (renamed in this branch's
Phase 0 from `rag_build_snow_methodology.R`) is the template to mirror:
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

Phase 1 ran web searches against publisher landings + DOI lookups
on the candidate list, plus a deep screen of the 19 existing items
in the `NewGraphEnvironment/climate` collection (key `8MH9LCC9`).
All 10 new papers below have confirmed DOIs and identified PDF
access. Citation keys follow the BBT `firstauthor_etal{year}`
convention used in the snow lit review (#54).

### Final candidate list — 10 new papers to add

| # | Citation key | Title (truncated) | Journal / Year | DOI | OA route |
|---|---|---|---|---|---|
| 1 | `karl_etal1993` | A New Perspective on Recent Global Warming: Asymmetric Trends of Daily Maximum and Minimum Temperature | BAMS 74 / 1993 | `10.1175/1520-0477(1993)074<1007:ANPORG>2.0.CO;2` | UNL DigitalCommons OA |
| 2 | `easterling_etal1997` | Maximum and Minimum Temperature Trends for the Globe | Science 277 / 1997 | `10.1126/science.277.5324.364` | Paywalled, RG |
| 3 | `vose_etal2005` | Maximum and minimum temperature trends for the globe: An update through 2004 | GRL 32 / 2005 | `10.1029/2005GL024379` | AGU paywalled, RG |
| 4 | `vincent_etal2018` | Changes in Canada's Climate: Trends in Indices Based on Daily Temperature and Precipitation Data | Atmos-Ocean 56 / 2018 | `10.1080/07055900.2018.1514579` | T&F open + Canada.gov hosted |
| 5 | `pepin_etal2015` | Elevation-dependent warming in mountain regions of the world | Nat Clim Chg 5 / 2015 | `10.1038/nclimate2563` | Paywalled, RG |
| 6 | `rangwala_miller2012` | Climate change in mountains: a review of elevation-dependent warming and its possible causes | Clim Change 114 / 2012 | `10.1007/s10584-012-0419-3` | Springer paywalled, RG |
| 7 | `wang_etal2012` | ClimateWNA — High-Resolution Spatial Climate Data for Western North America | JAMC 51 / 2012 | `10.1175/JAMC-D-11-043.1` | AMS OA after embargo |
| 8 | `mantua_etal2010` | Climate change impacts on streamflow extremes and summertime stream temperature… freshwater salmon habitat in Washington State | Clim Change 102 / 2010 | `10.1007/s10584-010-9845-2` | Springer paywalled, RG + UW CIG host |
| 9 | `eaton_scheller1996` | Effects of climate warming on fish thermal habitat in streams of the United States | L&O 41 / 1996 | `10.4319/lo.1996.41.5.1109` | Wiley paywalled, RG |
| 10 | `richter_kolmes2005` | Maximum Temperature Limits for Chinook, Coho, and Chum Salmon, and Steelhead Trout in the Pacific Northwest | Rev Fish Sci 13 / 2005 | `10.1080/10641260590885861` | T&F paywalled, **NOAA hosts free PDF** |

### Existing items in `climate` collection — reuse, do not re-add

7 directly relevant existing items (BBT-generated long citation keys
shown; we may PATCH cleaner overrides via Zotero `extra` field as a
follow-up cleanup):

| itemKey | BBT key | Year | Why relevant |
|---|---|---|---|
| `CPJDEZE6` | `mora_etal2013projectedtiming` | 2013 | Climate-departure framing (Nature) |
| `NXHY5NRA` | `hersbach_etal2020ERA5global` | 2020 | ERA5 dataset paper |
| `AIR5D4QW` | `munoz-sabater_etal2021ERA5Landstateoftheart` | 2021 | ERA5-Land dataset paper |
| `LQUDWBT7` | `isaak_etal2017NorWeSTSummer` | 2017 | NorWeST stream-temp model |
| `G2H2KWQK` | `dierauer_etal2020Climatechange` | 2020 | BC ecoregion drought |
| `T4V2VX25` | `warkentin_etal2022Lowsummer` | 2022 | BC summer flow + chinook |
| `KNFBUI5T` | `moore_schindler2022Gettingahead` | 2022 | Climate adaptation salmon |

Other items in collection screened and judged out-of-scope for #58
(better fits for Issue 2 precip+drying or Issue 3 framing): IPCC AR6
WGI/SYR (general framing), Pauly/Rodrigues/Alleway shifting-baselines
(Issue 3 framing), Yokohata 2019 climate-risk viz (peripheral), HYDAT
(data source not lit), ECCC 2016 climate scenarios report (technical),
Carbon Credits 2023 (irrelevant), Islam 2019 Fraser flow regimes
(Issue 2).

### Cross-rag references — already in `data/rag/snow_methodology.duckdb`

These don't need re-adding; the temperature rag's query script can
optionally cross-query the snow rag for these:

| Citation key | Why relevant for #58 |
|---|---|
| `najafi_etal2017` | BC attribution methodology — covers temperature as well as snow |
| `yue_wang2002` | MK + autocorrelation methodology — applies to all variables, not just snow |

### Topics-vs-papers coverage matrix

| Topic | Primary | Supporting |
|---|---|---|
| DTR / day-night asymmetry methodology | `karl_etal1993` | `easterling_etal1997`, `vose_etal2005` |
| Tmax vs tmin trends globally | `easterling_etal1997` | `vose_etal2005`, `karl_etal1993` |
| Canadian / BC temperature trends | `vincent_etal2018` | (cross-rag) `najafi_etal2017` |
| BC-specific climate downscaling | `wang_etal2012` (ClimateWNA) | `vincent_etal2018` |
| Elevation-dependent warming | `pepin_etal2015` | `rangwala_miller2012` |
| Climate-departure framing | (existing) `mora_etal2013` | (Issue 3 will deepen) |
| ERA5 / ERA5-Land grounding | (existing) `munoz-sabater_etal2021` | (existing) `hersbach_etal2020` |
| Climate→stream-temp bridge | `mantua_etal2010` | (existing) `isaak_etal2017`, (existing) `warkentin_etal2022` |
| Salmonid thermal envelope | `richter_kolmes2005` | `eaton_scheller1996`, `mantua_etal2010` |
| BC ecoregion warming patterns | (existing) `dierauer_etal2020` | (Issue 2 will deepen) |
| Adaptation framing | (existing) `moore_schindler2022` | (Issue 3 will deepen) |
| Trend test methodology | (cross-rag) `yue_wang2002` | (cross-rag) `najafi_etal2017` |

### PDF acquisition outcome (Phase 2)

Final PDF acquisition was almost entirely user-driven RG downloads —
NOAA / UNL DigitalCommons / T&F all blocked curl with 403 / Cloudflare
challenges. Only 1 of the 4 expected OA papers fetched cleanly via
curl (Wang 2012 ClimateWNA from author's UAlberta page). User
provided the other 9 via ResearchGate; 2 needed OCR (Karl 1993 image
scan from 2000-era Acrobat 3.0 import; Richter & Kolmes 2005 27-page
ProQuest scan). All 10 PDFs are text-layered, in
`data/rag/temp_methodology_pdfs/`.

### Zotero adds (Phase 2 — completed)

10 papers POSTed to `NewGraphEnvironment/climate` (key `8MH9LCC9`)
via Web API with PDFs attached. CrossRef-driven metadata; tags
`temperature-departure-methodology` + `cd-issue-58`. Initial run
mistakenly stuffed `Citation Key: <clean_key>` into the `extra`
field; per NGE convention BBT keys are auto-derived not manually
overridden, so all 10 items were PATCHed to clear the `extra` field
override. **BBT will generate the actual citation keys after Zotero
desktop restart** (sync alone doesn't trigger key generation for
Web-API-created items per CLAUDE.md). soul#43 filed to update
`/lit-search` + `/zotero-api` skills so future runs avoid the
override pattern.

| File label (local) | Parent itemKey | Attach itemKey | BBT citation key (post-restart) |
|---|---|---|---|
| `karl_etal1993` | `2FJQRX6N` | `X2UMWNUB` | (pending) |
| `easterling_etal1997` | `E27RPMRD` | `MI3CH39H` | (pending) |
| `vose_etal2005` | `94VFUHHZ` | `SIAFNGKV` | (pending) |
| `vincent_etal2018` | `D9H2UQBZ` | `P7QHP3BJ` | (pending) |
| `pepin_etal2015` | `GDFQS8ZB` | `UJVF9IFP` | (pending) |
| `rangwala_miller2012` | `376MUXNQ` | `GR9S4I3F` | (pending) |
| `wang_etal2012` | `NDTB37G6` | `5V7E4CWX` | (pending) |
| `mantua_etal2010` | `T5Q9MD9E` | `E5DWJAGA` | (pending) |
| `eaton_scheller1996` | `6VBSPJQN` | `72R34DQB` | (pending) |
| `richter_kolmes2005` | `4ICU2XDB` | `RTU4TMRG` | (pending) |

The "File label (local)" column doubles as the filename in
`data/rag/temp_methodology_pdfs/<label>.pdf` and the script
`pdf_specs` map's `label`. The actual BBT keys (which is what lands
in the vignette's `[@key]` markers downstream) get captured into the
table above once Zotero is restarted.

### PDF dedup observation

8 of 10 PDFs returned `{"exists": 1}` from Zotero's S3 — meaning
Zotero already had identical bytes (md5 match) somewhere in the
shared S3. Only `karl_etal1993`, `vose_etal2005`, and
`richter_kolmes2005` were fresh uploads. This is global Zotero S3
deduplication; each library still has its own attachment record
pointing at the deduped file. No action required.

### Notes on access

- **AMS journals** (`karl_etal1993`, `wang_etal2012`): 6-month embargo
  then OA. Both are >>6 months old → freely available via journal
  landing or DigitalCommons mirrors.
- **`richter_kolmes2005`:** NOAA hosts a free PDF at
  `https://www.noaa.gov/sites/default/files/legacy/document/2020/Oct/07354626288.pdf` —
  prefer this over the T&F paywalled landing.
- **`mantua_etal2010`:** UW Climate Impacts Group hosts a copy
  alongside the Springer landing.
- **`vincent_etal2018`:** ECCC / Canada.gov links directly to the T&F
  full article — likely free access, will verify in Phase 2.

## Methodology quotes by topic (Phase 4)

(Will populate during Phase 4 execution.)

## Cross-cutting methodology

(Will populate during Phase 5 execution.)

## Deviations

(Will populate during Phase 5 execution.)

## "Cite this for that" map

(Will populate during Phase 5 execution.)
