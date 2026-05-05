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

## Methodology quotes by topic (Phase 4 + 5)

Raw retrieval results in `planning/active/temp_methodology_quotes.md`
(637 lines, 24 queries × top-5 chunks). Synthesis below picks the
strongest hits per topic and groups them by the literature angle they
support. Citation labels match the rag-script `pdf_specs` map; the
actual BBT-auto-derived Zotero keys (which is what lands in vignette
`[@key]` markers downstream) get captured in the Zotero-adds table
above once Zotero is restarted.

### DTR / day-night asymmetry (foundational + BC context)

**Methodological precedent.** Karl et al. (1993) is the foundational
DTR-asymmetry paper; Easterling et al. (1997) and Vose et al. (2005)
extend the analysis through 2004 with broader land coverage. Vincent
et al. (2018) confirms the asymmetry holds in Canada specifically.

- `karl_etal1993` (abstract): "the rise of the minimum temperature
  has occurred at a rate three times that of the maximum temperature
  during the period 1951–90 (0.84°C versus 0.28°C). The decrease of
  the diurnal temperature range is approximately equal to the
  increase of mean temperature. The asymmetry is detectable in all
  seasons and in most of the regions studied." → Canonical
  3:1 min:max ratio quote for cd vignette interpretation.
- `vose_etal2005`: "From 1950–2004, the maximum temperature trend is
  0.141°C dec−1, the minimum temperature trend is 0.204°C dec−1, and
  the DTR trend is −0.066°C dec−1." 71% of global land area covered.
  → Updated trend numbers, methodology continuity from Karl 1993.
- `vincent_etal2018`: "nighttime very warm and very cold temperatures
  have warmed more than daytime very warm and very cold temperatures,
  both in the cold and warm seasons. This result is consistent with
  greater warming observed at nighttime than during daytime." Canada,
  1948–2016. → Confirms the asymmetry in our regional context (BC is
  a Vincent 18 sub-region).
- `karl_etal1993` (mechanism): cloud cover increases partially
  explain DTR decrease; sulfate aerosol forcing is "primarily Northern
  Hemisphere... too uncertain to estimate" relative role; soil
  moisture, snow cover, RH all modulate DTR. → Mechanism caveats
  for "why DTR is shrinking" claim.
- `pepin_etal2015`: "snow–albedo mechanism has a stronger influence
  on maximum than minimum temperatures because of the increase in
  absorbed solar radiation"; soil-moisture modulates whether warmth
  goes to Tmax (sensible-heat partitioning) or Tmin (latent-heat
  feedback). → Adds mountain-region nuance to the simple DTR story.
- `rangwala_miller2012` (Table 2): a comprehensive driver-by-driver
  table summarizing how each climate driver (snow, clouds, humidity,
  aerosols) shifts Tmax vs Tmin. → Useful reference for vignette
  interp paragraph that notes "our AOI does/doesn't show the
  textbook DTR asymmetry."

### Tmax / Tmin trends — global benchmark

- `vose_etal2005`: "minimum temperature increased more rapidly than
  maximum temperature (0.204 vs 0.141°C dec−1) from 1950–2004,
  resulting in a significant DTR decrease (−0.066°C dec−1)." Trends
  larger in NH (greater warming in boreal winter and spring); little
  Southern Hemisphere seasonality. → Reference rates against which
  cd's BC AOI rates can be compared.
- `karl_etal1993` (Table 1): per-country tables of MAX, MIN, DTR
  trends 1951-1990 for Canada (0.9 / 1.5 / 0.6 °C/100yr annual) and
  USA (-0.6 / 1.0 / -1.5). → Direct Canada-1990 baseline numbers.

### Canadian / BC temperature trends — direct regional anchor

`vincent_etal2018` is the closest paper in our corpus to cd's BC AOIs
— it's an ECCC homogenized-data study with explicit BC sub-regional
results.

- `vincent_etal2018`: "Canada is becoming warmer. The annual mean
  temperature averaged over land has increased by 1.7°C from 1948
  to 2012 (Vincent et al., 2015)... summer 95th percentile of tmax
  has increased by 0.9°C for the 1948–2016 period, whereas the
  summer 95th percentile of tmin has increased by 1.3°C." → Direct
  Canadian context for "BC is warming" framing in the vignette
  interpretation.
- `vincent_etal2018` (Table 3): provides BC-specific regional trends
  for ~21 indices (summer days, hot days, hot nights, summer 95th
  perc. tmax/tmin, frost days, growing season, growing degree-days).
  → If the vignette wants to compare cd's AOI numbers against a
  province-wide Vincent 18 benchmark, Table 3 has the values.
- `vincent_etal2018` (Methods): "The trend calculation followed the
  methodology presented in Zhang, Vincent, Hogg, and Niitsoo (2000).
  The estimated magnitude of the trend is based on the slope
  estimator of Sen (1968), and the statistical significance of the
  trend is based on the nonparametric Kendall's τ-test (Kendall,
  1955). Because serial correlation is occasionally present in the
  climatological time series, the method also uses an iterative
  procedure to account for the lag-1 autocorrelation of the time
  series (Wang & Swail, 2001)." → **`cd_trend()` uses identical
  Sen+MK slope+significance**; only difference is cd's raw form
  doesn't apply iterative AC handling. See Deviations.

### BC-specific climate downscaling — context

- `wang_etal2012` ClimateWNA: "20 000 surfaces of monthly, seasonal,
  and annual climate variables from 1901 to 2009; several climate
  normal periods; and multimodel climate projections for the 2020s,
  2050s, and 2080s." UBC Forest Conservation Genetics, U Alberta,
  PCIC. → Contextualizes cd's ERA5-Land approach against the
  ClimateWNA downscaled-station alternative used by ecosystem
  classification work in BC. Useful to note the difference: cd
  reads native-grid ERA5-Land (~9 km, internally consistent across
  variables) versus ClimateWNA's PRISM-anchored interpolated station
  product (~800 m, denser station network in populated valleys).

### Elevation-dependent warming (EDW) — mountain context

`pepin_etal2015` and `rangwala_miller2012` both review EDW evidence
across mountain regions. cd's BC AOIs span 800–3500 m elevation.

- `pepin_etal2015` (abstract): "growing evidence that the rate of
  warming is amplified with elevation, such that high-mountain
  environments experience more rapid changes in temperature than
  environments at lower elevations. Elevation-dependent warming
  (EDW) can accelerate the rate of change in mountain ecosystems,
  cryospheric systems, hydrological regimes and biodiversity."
  → Justifies why cd's per-ecoregion view (which spans elevation
  bands within an AOI) matters.
- `pepin_etal2015` (mechanisms): "snow albedo and surface-based
  feedbacks; water vapour changes and latent heat release; surface
  water vapour and radiative flux changes; surface heat loss and
  temperature change; and aerosols. All lead to enhanced warming
  with elevation (or at a critical elevation)." → Lists the
  mechanisms that we don't quantify directly but should mention
  briefly in interp.
- `rangwala_miller2012` Swiss Alps (Ceppi et al. 2010): "high
  warming rates during summer (0.46°C/decade) and winter (0.40°C/
  decade)." Colorado Rockies: "0.5–1°C/decade during the last three
  decades, but particularly since the mid-1990s." → Reference
  magnitudes for "BC mountain AOI warmed by X" comparisons.
- `rangwala_miller2012` (caveat): "it is still uncertain whether
  mountainous regions generally are warming at a different rate
  than the rest of the global land surface, or whether
  elevation-based sensitivities in warming rates are prevalent
  within mountains." → **Strong caveat** for any "mountains warm
  faster" claim in the vignette — it's a per-region pattern, not
  a global rule.

### Climate → stream-temperature → fish thermal stress bridge

This is the citation backbone for the v0.1.1 vignette claim that
"summer daytime maximum is the temperature envelope for salmonid
thermal stress in tributaries." Three papers anchor it.

- `eaton_scheller1996` (foundational): "The effects of climate
  warming on the thermal habitat of 57 species of fish of the U.S.
  were estimated using results for a doubling of atmospheric carbon
  dioxide that were predicted by the Canadian Climate Center general
  circulation model... cold-water and cool-water species are
  predicted to lose substantially more thermal habitat than
  warm-water species." → Establishes air-T → stream-T → fish-thermal
  -habitat chain at continental scale.
- `mantua_etal2010`: "Simulations predict rising water temperatures
  will thermally stress salmon throughout Washington's watersheds,
  becoming increasingly severe later in the twenty-first century...
  basins strongly influenced by transient runoff (a mix of direct
  runoff from cool-season rainfall and springtime snowmelt) are most
  sensitive to climate change... combined effects of warming
  summertime stream temperatures and altered streamflows will likely
  reduce the reproductive success for many Washington salmon
  populations." → PNW-specific bridge, exactly the salmonid
  thermal-stress framing for FWCP fish-passage reporting.
- (existing) `isaak_etal2017` (NorWeST): regional stream-temperature
  model for the western US, predicts broad climate-warming-driven
  stream-temperature increases. Already in the climate collection;
  doesn't need adding.
- (existing) `warkentin_etal2022`: BC-specific chinook-and-summer-
  flow study — empirical evidence that low summer flows (which
  warm faster) reduce salmon productivity. Already in collection.

### Salmonid thermal envelope — direct PNW thresholds

- `richter_kolmes2005`: "Maximum Temperature Limits for Chinook,
  Coho, and Chum Salmon, and Steelhead Trout in the Pacific
  Northwest... reviews the literature for chinook, coho, chum, and
  steelhead, which are currently listed in the Columbia River Basin
  under the Endangered Species Act. Describes specific numeric
  maximum temperature criteria that can be integrated into a broader
  recovery planning process for sensitive life stages of three
  species of Pacific Northwest salmon and steelhead."
  → **Direct citation for "salmonid thermal envelope" in the cd
  vignette interp.** PNW species overlap with FWCP Peace + Kootenay
  AOIs (chinook, coho, steelhead are all present; chum is
  PNW-coastal not BC-interior).
- `eaton_scheller1996`: 57 US species, methodology for relating
  air-T to stream-thermal-habitat for cold/cool/warm-water
  classifications. → Methodological complement to Richter & Kolmes
  for cd's "thermal habitat" framing.
- `mantua_etal2010`: PNW scenarios connect projected warming to
  specific threshold crossings — basins "transitioning toward more
  rain-dominant runoff regimes" lose snow-melt thermal buffering.

### Trend methodology (cross-reference with snow rag)

- `vincent_etal2018`: explicit Sen slope + Kendall's τ + lag-1 AC
  iterative procedure (Wang & Swail 2001) — methodology reference
  for trend tests on Canadian climate time series. → cd uses raw
  MK + Theil-Sen (no AC correction); the Vincent 18 procedure adds
  iterative AC handling. See Deviations.
- (cross-rag from `data/rag/snow_methodology.duckdb`)
  `yue_wang2002`: prewhitening fails when a real trend exists
  (Monte Carlo result); raw MK is the correct call for our 76-year
  series with strong trends. → Already covered in #54 findings.md.
  Cross-rag query: "When trend exists in a time series, the effect
  of positive/negative serial correlation on the MK test is
  dependent upon sample size, magnitude of serial correlation, and
  magnitude of trend."

## Cross-cutting methodology

### Baseline window — same as snow

Same conclusion as #54 findings.md: cd's 1951–1980 baseline is
acceptable for temperature, on the early side relative to the WMO
1961–1990 normal. The Vincent 18 trend table uses 1948–2016 (no
fixed baseline, full-record trend). Karl 93 uses 1951–1990. Vose 05
uses 1950–2004. Pepin 15 / Rangwala 12 don't fix on a single
baseline. **Heterogeneous in the literature** — our choice is
defensible and aligns with the snow-side analysis in cd.

### Trend test — raw MK + Theil-Sen vs Vincent 18's AC-iterative form

Vincent 18 explicitly applies iterative lag-1 autocorrelation
handling (Wang & Swail 2001) on top of Sen slope + Kendall's τ.
`cd_trend()` does not. Yue & Wang (2002, snow rag) demonstrates
that **prewhitening hurts when a real trend exists** — for cd's
76-year series with strong climate trends, raw MK is correct.
Whether the iterative-AC procedure differs meaningfully from
prewhitening (i.e., is Vincent's procedure trend-aware?) is a
secondary methodology question, possibly motivating #43 if it
becomes important. For now, raw MK + Theil-Sen is the right call
and Vincent 18's results are still directly comparable since their
AC correction effect is small for shorter records (their statement:
"serial correlation is *occasionally* present").

### ERA5-Land 2m temperature validation

**No paper in our 10-paper corpus directly validates ERA5-Land
2m temperature against in-situ observations for cd's BC AOIs.**
This is a notable gap. Available alternatives:

- (existing) `munoz_sabater_etal2021`: ERA5-Land dataset paper
  validates ERA5-Land vs ground truth at limited "fluxnet" sites
  for various land-surface variables; 2m T is a forcing, not the
  focus.
- `karl_etal1993` + `vose_etal2005` + `vincent_etal2018` provide
  station-based trend benchmarks against which cd's ERA5-Land
  trends can be qualitatively cross-checked. We can claim
  consistency if our BC-mean trends fall within the bands
  reported by Vincent 18 for the BC sub-region.
- `kouki_etal2023` (snow rag) validates SWE; suggests bias is
  approximately stable over time. By extension (not directly
  established), cd's temperature trends are likely interpretable
  even if absolute biases exist.

**Recommendation for the vignette interp:** note this as a
known caveat. A targeted ERA5-Land 2m T validation against ECCC
homogenized stations (Vincent 18's source dataset) would
strengthen the methodology — possible follow-up issue if
reviewers push back.

## Deviations from consensus

1. **UTC-day vs local-day tmax/tmin (issue #37).** cd's tmax/tmin
   currently uses UTC-day boundaries on hourly ERA5-Land. Vincent
   18 + Karl 93 use station-day (local time). For BC longitudes
   (UTC-7 to UTC-8), the UTC-day boundary cuts mid-afternoon local
   — almost certainly biases tmax low (since the warmest local
   afternoon may be split across two UTC days). #37 tracks the fix.
   Document briefly in vignette interp; flag the magnitude as
   pending #37 quantification.

2. **Raw MK + Theil-Sen vs Vincent 18's AC-iterative procedure.**
   Yue & Wang 2002 (snow rag) supports raw MK for our case
   (76-year strong-trend series). Vincent 18's AC-iterative is more
   conservative; potentially flagged in #43 if a window-vs-window
   p-value motivates revisiting the trend test. Defensible as-is.

3. **No direct ERA5-Land 2m T validation paper for BC.** Cross-
   referenced via Vincent 18 / Karl 93 / Vose 05 trend benchmarks
   instead. Document as a known caveat in interp; possible follow-up
   issue.

4. **DTR asymmetry magnitude in cd's BC AOIs may not match the
   global 3:1 (Karl 93) or 1.45:1 (Vose 05).** Mountain regions
   (Pepin 15, Rangwala 12) show heterogeneous Tmin/Tmax response
   depending on snow-albedo / soil-moisture state. cd's per-AOI
   results may not show the textbook signal — that's interpretable
   given the AOI-specific climate state, not a methodology problem.
   This is the v0.1.1 honest framing: "the textbook day-night
   asymmetry doesn't show at Kootenay Lake — the dominant signal is
   summer daytime maximum."

## Philosophy for downstream wire-up (read this first)

This findings.md is a **library**, not a prescription. The downstream
vignette branch draws sparingly:

- Cite an authority only when the finding actually surfaces in the
  AOI's graphs/tables. Don't decorate prose with concepts that
  don't appear in the data.
- Plain language. Spell out acronyms on first use (DTR = diurnal
  temperature range; EDW = elevation-dependent warming; FWCP = Fish
  and Wildlife Compensation Program).
- The vignette interpretation educates a fish-passage planner on the
  state of science — it doesn't read like a peer-reviewed paper.
- Cross-region anomalies worth mentioning are ones a reviewer would
  push back on if they weren't acknowledged. Otherwise leave them out.
- Cross-region comparisons go in PR descriptions, not vignette prose
  — vignettes are stand-alone (per memory).

## "Cite this for that" — citation map for downstream vignette wiring

Copy-paste-ready map. Each row gives a vignette claim type and the
citation key(s) that ground it. **Citation keys here are local
labels; the actual BBT-auto-derived Zotero keys get filled in
(replacing the labels) once Zotero is restarted and the keys are
captured into the Phase 2 Zotero-adds table.** Cross-rag references
(snow rag) noted explicitly.

The downstream branch will use only a small subset of these rows —
whichever map onto findings actually visible in the AOI's
plots/tables. The map below is a menu, not an order.

| Claim type | Primary citation | Supporting |
|---|---|---|
| DTR asymmetry methodology + 3:1 min:max ratio | `@karl_etal1993` | `@vose_etal2005`, `@easterling_etal1997` |
| Updated 1950–2004 trends (0.141 / 0.204 / -0.066 °C/dec) | `@vose_etal2005` | `@karl_etal1993` |
| Canada warming 1.7°C 1948–2012 + BC sub-region indices | `@vincent_etal2018` | — |
| Sen + Kendall's τ for Canadian temp trends | `@vincent_etal2018` | (cross-rag) `@yue_wang2002` |
| Mountain elevation-dependent warming exists | `@pepin_etal2015` | `@rangwala_miller2012` |
| EDW mechanisms (snow-albedo, water vapour, etc.) | `@pepin_etal2015` | `@rangwala_miller2012` (Table 2) |
| Caveat: EDW is heterogeneous, not universal | `@rangwala_miller2012` | `@pepin_etal2015` |
| Air-T → stream-T → salmon thermal stress (continental) | `@eaton_scheller1996` | `@mantua_etal2010` |
| PNW salmon climate-stress framing | `@mantua_etal2010` | (existing) `@isaak_etal2017`, (existing) `@warkentin_etal2022` |
| Salmonid maximum-temperature criteria PNW | `@richter_kolmes2005` | `@eaton_scheller1996` |
| ClimateWNA / ClimateNA reference (BC downscaling alternative) | `@wang_etal2012` | — |
| Climate-departure framing (cumulative-impact, recent-variability) | (existing) `@mora_etal2013` | (Issue 3 framing review) |
| ERA5 / ERA5-Land dataset citations | (existing) `@munoz-sabater_etal2021` | (existing) `@hersbach_etal2020` |
| BC ecoregion / drought patterns | (existing) `@dierauer_etal2020` | — |
| BC summer flow + chinook empirical link | (existing) `@warkentin_etal2022` | — |
| Climate adaptation salmon framing | (existing) `@moore_schindler2022` | — |
| BC SWE attribution (cross-reference) | (cross-rag) `@najafi_etal2017` | — |
| Why no prewhitening (raw MK is correct) | (cross-rag) `@yue_wang2002` | — |
