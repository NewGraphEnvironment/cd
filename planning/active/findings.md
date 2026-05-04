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

## Papers added to Zotero — top-level `NewGraphEnvironment/hydrology` collection (key `X29BX4U8`)

NOTE — there are TWO `hydrology` collections in the NGE library:
`X29BX4U8` (top-level, the right one) and `JI7EBZNF` (deep-nested
under `blackwater/aquatic/hydrology`, project-specific). Initial Phase 2
adds went to the wrong one; PATCH'd all 10 to the top-level on
2026-05-04 after user feedback. Future scripts that need the snow-
methodology corpus should use `X29BX4U8`.

10 new entries added via Web API POST with `collections=["X29BX4U8"]` (single
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

Raw retrieval results in
`planning/active/snow_methodology_quotes.md` (727 lines, 23 queries
× top-5 chunks). Synthesis below picks the strongest hits per metric
and groups them by the literature angle they support.

### `swe_max` (annual peak SWE)

**Methodological precedent:** April 1 SWE as the canonical annual
peak proxy. Pederson et al. (2011) and Mote et al. (2005, 2018)
both use 1 April SWE as the seasonal apex; our `swe_max` uses
the actual annual maximum from daily SWE rather than fixing at
April 1. The two are equivalent in most BC/PNW pixels (April 1 is
near peak in our region), and the actual-max formulation avoids
date sensitivity in years with anomalous accumulation/melt timing.

- `pederson_etal2011`: "Snowpack as measured on 1 April is a crucial
  component of regional runoff forecasting and water supply
  evaluations, and records of 1 April SWE are generally longer than
  for any other time of the year. In addition, 1 April measurements
  often approximate maximum SWE accumulation in our study
  watersheds... peak accumulation timing can vary substantially at
  individual measurement sites." → Justifies aggregating to a
  regional/watershed scale (which is what cd's mean-over-AOI does).

- `mote_etal2018`: "the decline in average April 1 snow water
  equivalent since mid-century is roughly 15–30% or 25–50 km3,
  comparable in volume to the West's largest man-made reservoir,
  Lake Mead." → Reference magnitude for "peak SWE down N%" claims.
  Over 90% of sites declining, 33% significant.

- `mote_etal2005`: "Mountain snowpack in western North America is
  a key component of the hydrologic cycle, storing water from the
  winter (when most precipitation falls) and releasing it in spring
  and early summer." → Foundational framing for why peak SWE is
  the right metric.

- `najafi_etal2017`: BC-specific SWE attribution. Four BC basins
  (Fraser, Peace, Columbia, Campbell). Peace = "drainage area of
  101 000 km2... 51% of the annual precipitation in this basin
  falls as snow." → Direct context for the FWCP Peace AOI in #48.

### `snowfall_fraction` (annual sf/tp ratio in %)

**Direct methodological precedent.** Knowles, Dettinger, Cayan
(2006) defines the SFE/P methodology. Our `snowfall_fraction` is
the same ratio at a slightly different aggregation (annual sum
daily snowfall / annual sum daily precip), with the result
expressed in % rather than as a unit fraction.

- `knowles_etal2006`: "documenting a regional trend toward smaller
  ratios of winter-total snowfall water equivalent (SFE) to
  winter-total precipitation (P) during the period 1949–2004. The
  trends toward reduced SFE are a response to warming across the
  region, with the most significant reductions occurring where
  winter wet-day minimum temperatures, averaged over the study
  period, were warmer than -5°C." → Directly justifies our metric
  AND identifies the threshold (warmer winter wet-day Tmin) where
  the signal is strongest. BC interior is colder than -5°C wet-day
  Tmin in winter on average; signal expected to be weaker in
  northern BC than coastal/southern PNW.

- `mote_etal2018`: complementary SWE-side update; corroborates
  the snowfall-vs-rain trend.

### `snowmelt_doy_50` (day of 50% cumulative melt)

**Methodological precedent:** Stewart, Cayan, Dettinger (2005)
defines streamflow center timing (CT). Our `snowmelt_doy_50` uses
the same idea applied to snowmelt flux directly rather than to
streamflow — the upstream signal that drives streamflow CT.

- `stewart_etal2005`: defines three streamflow timing measures —
  (1) monthly/seasonal fractional flows, (2) spring pulse onset,
  (3) **center timing**: `CT = Σ(ti · qi) / Σ qi` where ti is time
  in days from start of water year, qi is daily streamflow. "CT
  provides a time-integrated perspective of the timing of this
  pulse and the overall distribution of flow for each year, and
  it is less noisy than the spring pulse onset date." → Justifies
  preferring a cumulative/median measure (like our DOY-50) over a
  pulse-onset measure for trend detection.

- `stewart_etal2005`: "Widespread and regionally coherent trends
  toward earlier onsets of springtime snowmelt and streamflow have
  taken place across most of western North America... timing
  changes have resulted in increasing fractions of annual flow
  occurring earlier in the water year by 1–4 weeks."

- `cayan_etal2001`: "spring pulse" defined as day of minimum
  cumulative departure of daily flow from mean. → A different
  family of timing metric; our DOY-50 is more closely aligned with
  Stewart's CT than with Cayan's pulse.

- `kang_etal2016`: BC-specific. "The 2006 reconstructed
  hydrographs by 10 days relative to the 1949 ones confirm the
  recent 10-day advances of the onset of the spring freshets for
  the Fraser River at Hope... declines persist during the
  recession to lower flows in autumn just when the salmon are
  migrating up the Fraser River." → Reference order of magnitude
  for our claim about Peace freshet shift.

### `snowmelt_rate_peak` (annual max of 7-day rolling melt)

**No close methodological precedent in this literature.** The
established freshet-flashiness measures in Stewart 2005 and Kang
2016 are streamflow-based (CT, pulse onset, fractional flows),
not melt-flux-based. Our metric is a closer-to-source measure —
ERA5-Land's `smlt` flux directly, with a 7-day rolling window to
capture multi-day peak events while smoothing out the
hour-to-hour stochasticity. Document this as a deviation in the
"Deviations from consensus" section and note that the metric is
diagnostic of freshet intensity at the upstream (snowpack) end of
the chain, before routing through soil and channel storage.

- `stewart_etal2005`: "snowmelt-dominated gauges with more than
  30 complete years of record" — sample-size requirement for
  trend detection that we exceed comfortably with 76 years.

- `kang_etal2016`: "SWE declined by 105 mm by the time of its peak
  accumulation" — order of magnitude for snowpack changes; melt
  rate is the temporal derivative of this.

## Cross-cutting methodology

### Baseline window — our 1951–1980 vs alternatives

**Literature precedent is heterogeneous.** No single "right"
baseline window dominates the snow-departure literature:

- `knowles_etal2006`: 1949–2004 study period (treats whole record
  as the analysis window, not a baseline-vs-recent split)
- `stewart_etal2005`: 1948–2002
- `mote_etal2005`: 1916–2003 (then later updated to 1955–2016 in
  Mote 2018)
- `mote_etal2018`: 1955–2016 with no fixed baseline, just linear
  trends across the full record
- `najafi_etal2017`: 1961–2005 (45-year period, aligns with WMO
  1961–1990 normal partially)

Our 1951–1980 baseline is acceptable. On the early side relative
to the WMO 1961–1990 normal, but the FWCP Peace vignette already
uses 1951–1980 across the existing 7 vars (anchored to ERA5-Land's
start year and 30-year normal length). Consistency across vars
within the vignette outweighs cross-paper alignment.

### Mann-Kendall + autocorrelation

**Critical finding from `yue_wang2002`** — pre-whitening can
*hurt*, not help, when a real trend exists:

- "When trend exists in a time series, the effect of
  positive/negative serial correlation on the MK test is dependent
  upon sample size, magnitude of serial correlation, and magnitude
  of trend. When sample size and magnitude of trend are large
  enough, serial correlation no longer [significantly affects the
  test]."

- "When sample size and magnitude of trend are large enough... it
  is better to use the MK test on the original data rather than
  after prewhitening. Prewhitening will seriously distort the
  possibility of the test."

- "Removal of positive serial correlation by prewhitening
  dramatically reduces the slope of the trend, and removal of
  negative serial correlation by prewhitening inflates the slope
  of the trends."

→ For cd's 76-year series with strong climate trends, RAW MK +
Theil-Sen (no prewhitening) is the *correct* choice per Yue &
Wang. This is what `cd_trend()` already does. **Our methodology
is consistent with the literature consensus on the trend-test
question.**

`kang_etal2016` confirms the practice for hydrological work:
"The non-parametric MKT is commonly used for hydrological trend
analyses as it is robust to outliers and can be applied to
non-normal data... slope magnitudes are extracted from the
associated Kendall-Theil Robust Lines. Statistically significant
when p < 0.05 with a two-tailed test." Identical to `cd_trend()`.

### ERA5-Land snow biases

**Important caveat for absolute values; trends are still
defensible.** Kouki et al. (2023) is the headline:

- `kouki_etal2023`: "Both ERA5 and ERA5-Land overestimate total
  NH SWE by 150% to 200% compared to the SWE reference data.
  ERA5-Land shows larger overestimation... mostly due to very
  high SWE values over mountainous regions."

- `kouki_etal2023`: "snow depth above 1500 m is unrealistically
  large in ERA5... The snowpack is presented in IFS with a single
  layer of snow, which does not produce enough melting, and this
  results in excessively high snow depths."

- `munoz_sabater_etal2021`: "Over the US, and particularly over
  the Rockies region, ERA5-Land generally outperforms ERA5 in
  terms of lower RMSE... However... at the sites located in very
  high mountains (snb and swa, located at altitudes greater than
  3300 m) is slightly better with ERA5 than with ERA5-Land."

→ For #48: absolute SWE values from ERA5-Land are biased high in
mountain BC pixels. The ASWS QA cross-check planned for #48 Phase 3
will document the bias for our sites. **Trends in our annual
metrics remain interpretable** as long as the bias is approximately
stable over time (which the Kouki paper's time series support —
RMSE for ERA5-Land stays around 2780-3160 Gt across the study
period, no obvious trend in bias).

## Deviations from consensus

1. **`snowmelt_rate_peak` (7-day rolling sum of daily smlt) is
   our invention.** Closest precedent is streamflow-based
   freshet-flashiness work (Stewart 2005, Kang 2016) operating on
   gauged flow rather than melt flux. Our metric is more
   diagnostic at the upstream end of the chain (before soil/
   channel storage attenuation) but less directly comparable to
   the streamflow-timing literature. Document this clearly in the
   vignette interp paragraph rather than implying methodological
   precedent.

2. **Baseline window 1951–1980 is on the early side** vs the WMO
   1961–1990 normal that the IPCC and Najafi 2017 anchor on.
   Justification: ERA5-Land's record starts 1950; using 1951–1980
   keeps the baseline a clean 30-year block at the start of
   record, and it aligns with the existing 7-var vignette
   sections. Reasonable but not unique.

3. **No autocorrelation correction in `cd_trend()` is
   defensible** per `yue_wang2002` (raw MK is correct when sample
   size and trend magnitude are large, our 76-year series with
   strong trends qualify). #43 (cd_compare p-value follow-up) can
   address autocorrelation correction if it ever becomes
   motivated, but the literature does NOT recommend prewhitening
   for our use case.

4. **`swe_max` uses actual annual maximum of daily SWE** rather
   than fixing on April 1 SWE per the literature canon. Our
   approach is more direct (no date sensitivity) and equivalent
   in effect for BC pixels where peak accumulation is at or near
   April 1. Slight deviation from "April 1 SWE" canon — a brief
   methodology note in the vignette would help.

## "Cite this for that" — citation map for #48 Phase 5

Copy-paste-ready map. Each row gives a vignette claim type and
the citation key(s) that ground it. BBT will generate citation
keys on Zotero restart; the keys below match my proposed labels
and should match BBT's auto-generated keys (firstauthor + year
convention). If BBT generates different keys, the user will need
to update the vignette `[@key]` references.

| Claim type | Primary citation | Supporting |
|---|---|---|
| Peak SWE methodology (April 1 SWE / annual max) | `@pederson_etal2011`, `@mote_etal2018` | `@mote_etal2005` |
| Peak SWE has declined | `@mote_etal2018` (15–30% PNW decline) | `@najafi_etal2017` (BC), `@pederson_etal2011` (1000-yr context) |
| Snowfall fraction methodology (SFE/P) | `@knowles_etal2006` | — |
| Snowfall fraction declining where Tmin > -5°C | `@knowles_etal2006` | — |
| DOY-50 / center-timing methodology | `@stewart_etal2005` | `@cayan_etal2001` |
| Freshet shifting earlier (1–4 weeks WNA) | `@stewart_etal2005` | `@cayan_etal2001` (2 days/decade onset) |
| Freshet shifting earlier (10 days, BC Fraser) | `@kang_etal2016` | — |
| BC-specific climate-departure framing | `@najafi_etal2017`, `@kang_etal2016` | — |
| Peace basin = 51% of precip falls as snow | `@najafi_etal2017` | — |
| MK + Theil-Sen for hydrological trend tests | `@kang_etal2016` | `@yue_wang2002` |
| Why no prewhitening (raw MK is correct for our case) | `@yue_wang2002` | — |
| ERA5-Land overestimates SWE in mountains | `@kouki_etal2023` | `@munoz_sabater_etal2021` |
| ERA5-Land bias is approximately stable over time → trends valid | `@kouki_etal2023` | — |
| ERA5-Land dataset citation | `@munoz_sabater_etal2021` | — |
| Salmon-migration impact framing | `@kang_etal2016` | — |
| Snowpack decline unprecedented vs ~1000 yr context | `@pederson_etal2011` | — |
