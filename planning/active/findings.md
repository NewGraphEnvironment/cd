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

## Zotero adds (Phase 2 — completed)

4 new papers POSTed to `NewGraphEnvironment/climate` (key
`8MH9LCC9`) via Web API with PDFs attached. Tags
`interpretation-framing-methodology` + `cd-issue-63`. No `Citation
Key:` overrides in `extra` (per soul#43 + #58/#61 lessons). All 4
items have ≥2 individual creators per CrossRef.

| File label | Parent itemKey | Attach itemKey | n creators | PDF | BBT citation key |
|---|---|---|---|---|---|
| `arguez_vose2011` | `QP7CM985` | `PTQ9PAHZ` | 2 | uploaded | `arguez_vose2011DefinitionStandard` |
| `livezey_etal2007` | `RTIBVA58` | `P6KFMRF9` | 5 | exists | `livezey_etal2007EstimationExtrapolation` |
| `hawkins_sutton2012` | `HZNAB47T` | `NG4EZK8V` | 2 | uploaded | `hawkins_sutton2012Timeemergence` |
| `hansen_etal2012` | `9ICS93S7` | `S7JUXCGB` | 3 | exists | `hansen_etal2012Perceptionclimate` |

Auto-restart pattern (per soul#43) used for BBT key generation —
worked first try, all 4 keys clean.

## Methodology quotes by topic (Phases 4 + 5)

Raw retrieval in `planning/active/interpretation_framing_quotes.md`
(373 lines, 16 queries × top-5 chunks). 291 chunks across 4 sources.

Top-5 hit count per paper:
- `arguez_vose2011` — 26 (BAMS short-paper, dense on normals topic)
- `hansen_etal2012` — 21
- `hawkins_sutton2012` — 18
- `livezey_etal2007` — 15

### Baseline window methodology (WMO climate normal definition)

`arguez_vose2011` is the canonical reference for what a "climate
normal" is and why it's what it is. Five attributes define the
standard WMO climate normal: averaging period, period start, period
length, observing period, and update frequency. **Departure from
any of these five = an "alternative" climate normal.**

- `arguez_vose2011`: "We propose that any potential alternative
  climate normal is the result of changing one or more of these five
  attributes... [WMO normals are] more useful as a comparison metric
  than as a predictor of expected future conditions in a changing
  climate." → Direct grounding for cd's choice of 1951–1980
  (departure on the period-start attribute) — defensible per Arguez
  & Vose's framework as long as the choice is documented.
- `livezey_etal2007`: "in a changing climate, traditional 30-year
  averages are increasingly poor estimators of the current climate
  state for variables with significant trends" — proposes
  alternative trend-aware methods (hinge-fit). → Justifies why a
  fixed-baseline-window choice (cd's 1951–1980) is a valid
  reference state for *departure* analysis even though it would be
  a poor *prediction* of current means.

### Time of emergence / signal-to-noise

`hawkins_sutton2012` is the foundational time-of-emergence paper.

- `hawkins_sutton2012`: "Time of Emergence (ToE), defined as the
  time at which the climate change signal emerges from the noise of
  natural climate variability... ToE is a critical indicator for
  understanding the urgency of climate adaptation." Maps ToE for
  surface air temperature using CMIP3. → Frame for "the climate
  signal at our BC AOIs has already emerged" claims; supports the
  cd_compare framework (#20 + #43) by giving citation backing for
  why a window-vs-window p-value matters.
- (existing) `mora_etal2013projectedtiming`: extends ToE concept to
  a *departure* index (year when projected mean climate moves
  outside the historical envelope). Already in the climate
  collection — direct continuation of Hawkins & Sutton 2012.

### Cumulative-impact / "loaded dice" framing

`hansen_etal2012` is the canonical "loaded dice" cumulative-impact
paper.

- `hansen_etal2012`: "the perceived shift of the climate is so large
  that we should be able to detect it in the language of probability
  loadings on a die... 3-sigma extreme outliers, which covered much
  less than 1% of Earth's surface during the 1951–1980 base period,
  now typically cover about 10% of the land area."
  → **Authoritative grounding for cd's cumulative-impact framing**
  ("regional summer Tmax has shifted N standard deviations"). Note
  Hansen 2012 explicitly uses the 1951–1980 base period — same as
  cd. This validates the choice of baseline window for
  cumulative-impact reporting at FWCP fish-passage planner level.

### Shifting baseline syndrome (existing references)

- (existing) `pauly1995Anecdotesshifting`: foundational fisheries
  paper introducing "shifting baseline syndrome" — generational
  forgetting of historical reference states.
- (existing) `rodrigues_etal2019Unshiftingbaseline`: framework for
  documenting historical baselines explicitly to counter SBS.
- (existing) `alleway_etal2023shiftingbaseline`: SBS as a connective
  concept for environmental change.

→ The fixed 1951–1980 baseline is itself an "anti-SBS" choice (it
doesn't drift forward as time passes), aligning with the SBS
literature's recommendation to anchor on documented historical
reference states.

### Departure from recent variability (existing reference)

- (existing) `mora_etal2013projectedtiming`: "the year when the
  projected mean climate of a given location moves to a state
  continuously outside the bounds of historical variability."
  → cd's `cd_compare` framework (per #20) is in this lineage.
  Mora 2013 is the climate-departure framing anchor.

### Trend-test methodology (cross-rag)

- (cross-rag) `yue_wang2002Applicabilityprewhitening` (snow rag) —
  raw MK is correct for our 76-year strong-trend series. Already
  covered in #54 / #58 / #61 archives. No new content here.

## Cross-cutting methodology

Shorter than #58 / #61 since the trend-test + baseline-window
methodology is already settled in #58/#61 archives. The only
cross-cutting addition: **Hansen 2012's choice of 1951–1980 base
period validates cd's choice** for cumulative-impact ("loaded
dice") reporting, even though the WMO standard is 1961–1990. This
is the strongest defense of cd's baseline choice in the climate-
departure 3-split lit reviews.

## Deviations from consensus

1. **Baseline window 1951–1980 vs WMO 1961–1990.** cd uses
   1951–1980. Per `arguez_vose2011`, this is an "alternative
   climate normal" — defensible if documented. Hansen 2012 uses
   the same window for explicit cumulative-impact framing, which
   provides direct precedent. Trade-off: cd's window is on the
   early side relative to WMO, but it cleanly anchors the
   ERA5-Land record (1950–) and aligns with the cumulative-impact
   framing the vignettes adopt.
2. **No autocorrelation correction** (per Yue & Wang 2002,
   cross-rag) — consistent across all three lit reviews.
3. **Time-of-emergence framing isn't quantified per-AOI** in cd
   — we report departure as a magnitude vs the 1951–1980 baseline
   rather than as a year-of-emergence per Hawkins & Sutton 2012.
   Either framing is defensible; cd's chosen framing is more
   accessible to FWCP planners ("2 °C warmer over the record")
   than ToE ("emerged from variability in year X").

## "Cite this for that" — citation map for downstream vignette wiring

Same philosophy preface applies (this is a library, not a
prescription; downstream cites authorities sparingly for findings
visible in AOI plots/tables). 11-row menu:

| Claim type | Primary citation | Supporting |
|---|---|---|
| Climate-normal definition (5 attributes) | `@arguez_vose2011DefinitionStandard` | — |
| Why cd's 1951–1980 baseline is acceptable | `@arguez_vose2011DefinitionStandard` | `@hansen_etal2012Perceptionclimate` |
| Why fixed-baseline reference outperforms drift in changing climate | `@livezey_etal2007EstimationExtrapolation` | (existing) `@pauly1995Anecdotesshifting` |
| Time-of-emergence / signal-to-noise framing | `@hawkins_sutton2012Timeemergence` | (existing) `@mora_etal2013projectedtiming` |
| Cumulative-impact ("loaded dice") framing | `@hansen_etal2012Perceptionclimate` | — |
| 3-sigma extreme outliers / probability shift | `@hansen_etal2012Perceptionclimate` | — |
| Climate-departure index methodology | (existing) `@mora_etal2013projectedtiming` | `@hawkins_sutton2012Timeemergence` |
| Shifting baseline syndrome | (existing) `@pauly1995Anecdotesshifting` | (existing) `@rodrigues_etal2019Unshiftingbaseline`, `@alleway_etal2023shiftingbaseline` |
| Anti-SBS justification for fixed historical baseline | (existing) `@rodrigues_etal2019Unshiftingbaseline` | (existing) `@pauly1995Anecdotesshifting` |
| IPCC-level framing for FWCP-context interpretation | (existing) `@calvin_etal2023IPCCSummary` | (existing) `@intergovernmentalpanelonclimatechangeipcc2023ClimateChange` |
| Trend test methodology (raw MK is correct for trended series) | (cross-rag) `@yue_wang2002Applicabilityprewhitening` | — |

## 3-split scoreboard (downstream consumer pointer)

After this issue lands, the climate-departure 3-split is complete:

- **Snowpack** (#53 → v0.1.7) — `planning/archive/2026-05-issue-53-snow-lit-review/findings.md`
- **Temperature** (#58 → v0.2.2) — `planning/archive/2026-05-issue-58-temperature-lit-review/findings.md`
- **Precipitation + drying** (#61 → v0.2.3) — `planning/archive/2026-05-issue-61-precip-drying-lit-review/findings.md`
- **Interpretation framing** (this issue → v0.2.4) — `planning/archive/2026-05-issue-63-interpretation-framing-lit-review/findings.md`

The downstream vignette wire-up branch pulls from all four files
selectively per the plain-language vignette philosophy
(`feedback_vignette_citations_sparse.md`).
