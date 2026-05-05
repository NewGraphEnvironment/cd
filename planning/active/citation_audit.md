# Citation Audit — peace-fwcp.Rmd wire-up (#67)

Same format as #65/kootenay audit. One row per `[@key]` insertion
in `peace-fwcp.Rmd`. Per-AOI nuances vs #65 noted in each row.

---

## 1. Hansen 2012 — 1951–1980 baseline (Trends, L176)

**Vignette excerpt (current):** "Anomalies are computed against a
pre-warming reference period — 1951–1980, the three decades before
climate change accelerated. Saying a year is '+1.5 °C' means it was
1.5 °C warmer than the average year between 1951 and 1980."

**Source quote (#63 archive, `cumulative_impact_loaded_dice`):**
> "3-sigma extreme outliers, which covered much less than 1% of
> Earth's surface during the 1951–1980 base period, now typically
> cover about 10% of the land area." — Hansen et al. 2012, PNAS

**Rag store / topic:** `data/rag/interpretation_framing.duckdb` /
`cumulative_impact_loaded_dice`

**Paraphrase as written:** "1951–1980, the three decades before
climate change accelerated. This is the same base period
@hansen_etal2012Perceptionclimate use to detect the emergence of
3-sigma summertime-temperature outliers globally."

**Why warranted:** identical justification as #65 row 1. All
anomaly plots reference the 1951–1980 baseline directly.

---

## 2. Arguez & Vose 2011 — WMO climate normal (Trends, L186)

**Vignette excerpt (current):** "1981–present (45 years) — starts
at the beginning of the World Meteorological Organization's most
recent 30-year 'climate normal' (1981–2010)."

**Source quote (#63 archive, `baseline_window_methodology`):**
> "We propose that any potential alternative climate normal is the
> result of changing one or more of these five attributes...
> [WMO normals are] more useful as a comparison metric than as a
> predictor of expected future conditions in a changing climate."
> — Arguez & Vose 2011, BAMS

**Rag store / topic:** `data/rag/interpretation_framing.duckdb` /
`baseline_window_methodology`

**Paraphrase as written:** "World Meteorological Organization's most
recent 30-year 'climate normal' (1981–2010)
[@arguez_vose2011DefinitionStandard]."

**Why warranted:** identical to #65 row 2.

---

## 3. Karl 1993 — DTR asymmetry (Daytime/Overnight, L238)

**Vignette excerpt (current):** "Overnight minimums warming faster
than daytime maximums — the 'day-night asymmetry' — is one of the
textbook fingerprints of greenhouse warming (Karl et al. 1993)."

**Source quote (#58 archive, `dtr_asymmetry`):**
> "the rise of the minimum temperature has occurred at a rate three
> times that of the maximum temperature during the period 1951-90
> (0.84°C versus 0.28°C)... The asymmetry is detectable in all
> seasons and in most of the regions studied." — Karl et al. 1993,
> BAMS

**Rag store / topic:** `data/rag/temp_methodology.duckdb` /
`dtr_asymmetry`

**Paraphrase as written:** convert prose-style "(Karl et al. 1993)"
→ "[@karl_etal1993NewPerspective]"

**Why warranted:** vignette already names Karl 1993 in prose. **DTR
asymmetry is STRONGER in Peace than in Kootenay** — the regional
DTR narrowed by 0.4 °C cumulative (Peace L246-248) vs 0.2 °C in
Kootenay. Direct visible match in the dtr plot.

---

## 4. Pepin 2015 + Rangwala-Miller 2012 — high-elevation/latitude amplification (Interpretation, L859-864)

**Vignette excerpt (current):** "the northern, higher-elevation
ecoregions (Omineca Mountains, Boreal Mountains and Plateaus)
warmed about 0.2 °C more than the southern Fraser Basin, consistent
with the well-documented pattern of high-latitude and
high-elevation amplification — but it is small relative to the
regional signal."

**Source quotes (#58 archive, `elevation_dependent_warming`):**
> "growing evidence that the rate of warming is amplified with
> elevation, such that high-mountain environments experience more
> rapid changes in temperature than environments at lower
> elevations." — Pepin et al. 2015

> "it is still uncertain whether mountainous regions generally are
> warming at a different rate than the rest of the global land
> surface, or whether elevation-based sensitivities in warming
> rates are prevalent within mountains." — Rangwala & Miller 2012

**Rag store / topic:** `data/rag/temp_methodology.duckdb` /
`elevation_dependent_warming`

**Paraphrase as written:** "the northern, higher-elevation
ecoregions (Omineca Mountains, Boreal Mountains and Plateaus)
warmed about 0.2 °C more than the southern Fraser Basin, consistent
with the elevation-dependent warming signal documented at
mid-latitude mountain sites
[@pepin_etal2015Elevationdependentwarming], though the regional
evidence base remains heterogeneous and not every mountain region
shows the same pattern [@rangwala_miller2012Climatechange]."

**Why warranted:** Interpretation paragraph explicitly invokes
"high-latitude and high-elevation amplification." Per-ecoregion
trend table (Per-Ecoregion Variation section) shows the
0.2 °C-more-warming signal in BMP/Omineca vs Fraser Basin.

**Note:** placed at L853-864 (Interpretation) NOT at Spatial
Pattern L554-560. Peace's Spatial Pattern dominant gradient is
**east-west, windward-of-Rockies** — not elevation per se.
Pepin/Rangwala doesn't cleanly cover windward-slope amplification,
so we don't decorate the Spatial Pattern section.

---

## 5. Ficklin & Novick 2017 — VPD continental drying (Interpretation, L887-897)

**Vignette excerpt (current):** "Vapour pressure deficit — the gap
between how much water the air could hold and how much it actually
does — rose significantly in every ecoregion (p < 0.005 across all
five). Warmer air holds more water before saturating, and that
pulls moisture out of soil and vegetation through evaporation and
transpiration. Soil moisture is essentially flat in every
ecoregion — even where precipitation increased — because the
warmer atmosphere is drinking the extra water back."

**Source quote (#61 archive, `vpd_drying_continental`):**
> "spring, summer, and fall seasons exhibited the largest areal
> extent of significant increases in VPD... Significant increases
> in VPD have been caused by air temperature increases and
> relative humidity changes." — Ficklin & Novick 2017, JGR

**Rag store / topic:** `data/rag/precip_drying_methodology.duckdb`
/ `vpd_drying_continental`

**Paraphrase as written:** "Vapour pressure deficit — the gap
between how much water the air could hold and how much it actually
does — rose significantly in every ecoregion (p < 0.005 across all
five), mirroring the continental-scale drying that
@ficklin_novick2017Historicprojected documented for the United
States as a whole, driven by air-temperature increases and
relative-humidity changes."

**Why warranted:** **stronger Peace case than Kootenay.** Peace
shows VPD up significantly *despite* precipitation rising 3-4%
in 2 ecoregions — a pure evaporative-demand signal. Kootenay's
VPD-drying claim was supported by precipitation also declining;
here the air-temperature/RH-driven VPD increase OVERRIDES the
modest precip gain. This is the cleanest "atmosphere is drying
because it's getting warmer" attribution in either vignette.
Visible in cmp_combined table (VPD with positive Δ + p < 0.001
trend).

---

## 6. Mantua 2010 + Eaton & Scheller 1996 — climate-fish bridge (Interpretation, L925-938)

**Vignette excerpt (current):** "For the cold-water resident
salmonids the FWCP Peace supports — bull trout, Arctic grayling,
mountain whitefish, rainbow trout, kokanee — these signals
compound. Stream temperatures are likely rising in step with
warmer ambient air temperatures..."

**Source quotes (#58 archive, `climate_stream_temp_bridge`):**
> "Simulations predict rising water temperatures will thermally
> stress salmon throughout Washington's watersheds... combined
> effects of warming summertime stream temperatures and altered
> streamflows will likely reduce the reproductive success for many
> Washington salmon populations." — Mantua et al. 2010, Climatic
> Change

> "cold-water and cool-water species are predicted to lose
> substantially more thermal habitat than warm-water species."
> — Eaton & Scheller 1996, L&O

**Rag store / topic:** `data/rag/temp_methodology.duckdb` /
`climate_stream_temp_bridge`

**Paraphrase as written:** "Stream temperatures are likely rising
in step with warmer ambient air temperatures, with the combined
effects of warming summer stream temperatures and altered low
flows likely reducing thermally-suitable habitat for cold-water
species [@mantua_etal2010Climatechange;
@eaton_scheller1996Effectsclimate]..."

**Why warranted:** identical justification to #65 row 6. Load-
bearing for FWCP fish-passage planner audience. Peace's salmonid
list (bull trout, Arctic grayling, mountain whitefish, rainbow
trout, kokanee) overlaps heavily with the cold-water cohort
Eaton & Scheller 1996 covers.

---

## 7. Kang 2016 — Fraser freshet (Interpretation, L937-938)

**Vignette excerpt (current):** "the neighbouring Fraser Basin
documents the same kind of freshet advance (Kang et al. 2016) at
comparable magnitude."

**Source quote (#54 archive snow rag):**
> "10-day advances of the onset of the spring freshets for the
> Fraser River at Hope... declines persist during the recession
> to lower flows in autumn just when the salmon are migrating up
> the Fraser River." — Kang et al. 2016, Sci Rep

**Rag store / topic:** `data/rag/snow_methodology.duckdb` /
`bc_specific`

**Paraphrase as written:** convert "(Kang et al. 2016)" →
"[@kang_etal2016ImpactsRapidly]"

**Why warranted:** identical to #65 row 7. Format consistency
with the rest of the vignette. **Note:** Kang's Fraser AOI is
geographically adjacent to Peace headwaters (Fraser drains
southward from the same Continental Divide that the Peace
crosses), making this comparison especially direct.

---

## Out-of-audit observations

The 10 existing Snowpack-section `[@key]` markers from #54 are
intact and well-grounded — not re-audited here.

## Independent review agent — checklist

The Phase 3 review agent should verify, for each row above:
1. Source quote actually exists in cited paper (not hallucinated)
2. Paraphrase faithful to source — no overreach
3. "Why warranted" matches an actually-visible feature in plots/tables
4. No decoration; cite is load-bearing

Watch especially for:
- Pepin/Rangwala fit at L853-864 (interpretation paragraph, not
  spatial pattern) — verify the per-ecoregion trend table actually
  shows the 0.2 °C-more-warming signal in northern ecoregions
- Ficklin & Novick paraphrase faithfulness re Peace's "VPD up
  *despite* precip up" framing
