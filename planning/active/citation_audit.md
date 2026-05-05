# Citation Audit — kootenay-lake.Rmd wire-up (#65)

One row per `[@key]` insertion proposed for `kootenay-lake.Rmd`.
This is the "what is where by who said what where" trail.

For each row:
- **Vignette excerpt** — the prose where the cite lands (with line ref)
- **Source quote / paraphrase** — the load-bearing quote from the cited paper
- **Rag store / topic** — where the quote was retrieved during lit-review mining
- **Paraphrase as written** — how the cite appears in the vignette
- **Why warranted** — what visible-in-vignette finding supports this cite

The independent review agent (Phase 3) reads this audit + verifies
each paraphrase against the source.

---

## 1. Hansen 2012 — 1951–1980 baseline (Trends section, L184)

**Vignette excerpt (current):** "Anomalies are computed against a
pre-warming reference period — 1951–1980, the three decades before
climate change accelerated. Saying a year is '+1.5 °C' means it was
1.5 °C warmer than the average year between 1951 and 1980."

**Source quote (from #63 archive findings.md, topic
`cumulative_impact_loaded_dice`):**
> "3-sigma extreme outliers, which covered much less than 1% of
> Earth's surface during the 1951–1980 base period, now typically
> cover about 10% of the land area." — Hansen et al. 2012, PNAS

**Rag store / topic:** `data/rag/interpretation_framing.duckdb` /
`cumulative_impact_loaded_dice`

**Paraphrase as written (proposed):** "Anomalies are computed against
a pre-warming reference period — 1951–1980, the three decades before
climate change accelerated. This is the same base period
@hansen_etal2012Perceptionclimate use to detect the emergence of
3-sigma summer-temperature outliers globally..."

**Why warranted:** vignette explicitly justifies the 1951–1980
choice; Hansen et al. 2012 is the strongest direct precedent (same
window, cumulative-impact framing). Visible in **all anomaly plots**
(every figure relative to the 1951–1980 baseline). Non-decorative —
load-bearing for the methodology choice.

---

## 2. Arguez & Vose 2011 — WMO climate normal definition (Trends, L195–199)

**Vignette excerpt:** "1981–present (45 years) — starts at the
beginning of the World Meteorological Organization's most recent
30-year 'climate normal' (1981–2010). This is the reference period
used in most published climate products, so it makes results easy
to compare against Intergovernmental Panel on Climate Change
reports and government climate summaries."

**Source quote (from #63 archive findings.md, topic
`baseline_window_methodology`):**
> "We propose that any potential alternative climate normal is the
> result of changing one or more of these five attributes...
> [WMO normals are] more useful as a comparison metric than as a
> predictor of expected future conditions in a changing climate."
> — Arguez & Vose 2011, BAMS

**Rag store / topic:** `data/rag/interpretation_framing.duckdb` /
`baseline_window_methodology`

**Paraphrase as written (proposed):** "1981–present (45 years) —
starts at the beginning of the World Meteorological Organization's
most recent 30-year 'climate normal' (1981–2010)
[@arguez_vose2011DefinitionStandard]."

**Why warranted:** vignette explicitly references the WMO standard;
Arguez & Vose 2011 is the canonical citation for that definition.
Visible in **the second slope row of the Trends table** (1981-start
trend window). One-cite, one-claim — minimal decoration.

---

## 3. Karl 1993 — DTR asymmetry (Daytime/Overnight Lows, L246)

**Vignette excerpt (current):** "Overnight minimums warming faster
than daytime maximums — the 'day-night asymmetry' — is one of the
textbook fingerprints of greenhouse warming (Karl et al. 1993)."

**Source quote (from #58 archive findings.md, topic
`dtr_asymmetry`):**
> "the rise of the minimum temperature has occurred at a rate three
> times that of the maximum temperature during the period 1951-90
> (0.84°C versus 0.28°C). The decrease of the diurnal temperature
> range is approximately equal to the increase of mean temperature.
> The asymmetry is detectable in all seasons and in most of the
> regions studied." — Karl et al. 1993, BAMS

**Rag store / topic:** `data/rag/temp_methodology.duckdb` /
`dtr_asymmetry`

**Paraphrase as written (proposed):** convert prose-style "(Karl et
al. 1993)" → "[@karl_etal1993NewPerspective]"

**Why warranted:** vignette already names Karl et al. 1993 in prose
— this just promotes it to a proper citation. DTR figure
(`plot-dtr` chunk, Fig caption mentions "the textbook day-night
asymmetry shows up here") visualizes the exact effect Karl 1993
documented. Direct match.

---

## 4. Pepin 2015 + Rangwala & Miller 2012 — elevation-dependent warming (Spatial Pattern, L581–587)

**Vignette excerpt (current):** "Warming is not spatially uniform
across the region. Total departures range from about +1.2 °C at
the lowest-warming pixels to +2.2 °C at the highest, with a
regional mean near +1.7 °C. Higher-elevation pixels tend to show
stronger warming — the high-elevation amplification signal that
shows up consistently at mid-latitude mountain sites — but the
gradient is mixed enough that no single axis (north-south or
east-west) carries the full pattern."

**Source quotes (from #58 archive findings.md, topic
`elevation_dependent_warming`):**
> "growing evidence that the rate of warming is amplified with
> elevation, such that high-mountain environments experience more
> rapid changes in temperature than environments at lower
> elevations. Elevation-dependent warming (EDW) can accelerate the
> rate of change in mountain ecosystems, cryospheric systems,
> hydrological regimes and biodiversity." — Pepin et al. 2015,
> Nature Climate Change

> "it is still uncertain whether mountainous regions generally are
> warming at a different rate than the rest of the global land
> surface, or whether elevation-based sensitivities in warming
> rates are prevalent within mountains." — Rangwala & Miller 2012,
> Climatic Change

**Rag store / topic:** `data/rag/temp_methodology.duckdb` /
`elevation_dependent_warming`

**Paraphrase as written (proposed):** "Higher-elevation pixels tend
to show stronger warming — consistent with the elevation-dependent
warming (EDW) signal documented at mid-latitude mountain sites
[@pepin_etal2015Elevationdependentwarming], though the regional
evidence base is heterogeneous and not every mountain region shows
the same pattern [@rangwala_miller2012Climatechange]..."

**Why warranted:** spatial-pattern map (Figure under L597-625)
visibly shows elevation-correlated departure values. Vignette's
existing prose introduces "high-elevation amplification" — needs
the EDW reference. Pepin 2015 = primary, Rangwala & Miller 2012 =
caveat (the heterogeneity acknowledgment matters because the
vignette itself notes "the gradient is mixed enough"). Two cites,
one for the affirmation + one for the caveat — non-decorative.

---

## 5. Ficklin & Novick 2017 — VPD continental drying (Interpretation, L984–994)

**Vignette excerpt (current):** "The atmosphere is drying. Vapour
pressure deficit — the gap between how much water the air could
hold and how much it actually does — is up significantly across
the region. Combined with declining precipitation, this is a
'double-dipping' signal: less water arriving as precipitation,
*and* warmer air pulling more water out of soil and vegetation
through evapotranspiration."

**Source quote (from #61 archive findings.md, topic
`vpd_drying_continental`):**
> "spring, summer, and fall seasons exhibited the largest areal
> extent of significant increases in VPD, which was largely
> concentrated in the western and southern portions of the U.S.
> Significant increases in VPD have been caused by air temperature
> increases and relative humidity changes, especially during the
> summer season in the southern portion of the U.S., over the
> historical time period." — Ficklin & Novick 2017, JGR

**Rag store / topic:** `data/rag/precip_drying_methodology.duckdb` /
`vpd_drying_continental`

**Paraphrase as written (proposed):** "Vapour pressure deficit —
the gap between how much water the air could hold and how much it
actually does — is up significantly across the region, mirroring
the continental-scale drying that @ficklin_novick2017Historicprojected
documented across the western United States, driven by combined
air-temperature increases and relative-humidity declines."

**Why warranted:** Recent-vs-Pre-warming table (L533-572,
`cmp_combined`) shows VPD with positive Δ absolute and a
significant trend p — directly visible. The vignette's
"double-dipping" framing is the same air-T-up + RH-down combination
Ficklin & Novick 2017 attribute the western-US VPD rise to. Direct
methodological match for the vignette's load-bearing claim.

---

## 6. Mantua 2010 + Eaton & Scheller 1996 — climate→stream-temp→fish bridge (Interpretation, L1012–1018)

**Vignette excerpt (current):** "For the cold-water resident
salmonids the Kootenay Lake region supports — bull trout, Gerrard
rainbow trout, mountain whitefish, kokanee — these signals
compound. Stream temperatures are likely rising in step with
warmer ambient air temperatures; the evapotranspiration imbalance
means low-flow conditions in late summer are not being relieved
(precipitation is falling, not rising as in the Peace); the
cold-water input that high-elevation snowpack provides to streams
during the warmest, most thermally stressful weeks of summer is
dropping in parallel with summer SWE..."

**Source quotes (from #58 archive findings.md, topic
`climate_stream_temp_bridge`):**
> "Simulations predict rising water temperatures will thermally
> stress salmon throughout Washington's watersheds, becoming
> increasingly severe later in the twenty-first century... combined
> effects of warming summertime stream temperatures and altered
> streamflows will likely reduce the reproductive success for many
> Washington salmon populations." — Mantua et al. 2010, Climatic
> Change

> "The effects of climate warming on the thermal habitat of 57
> species of fish of the U.S. were estimated... cold-water and
> cool-water species are predicted to lose substantially more
> thermal habitat than warm-water species." — Eaton & Scheller
> 1996, L&O

**Rag store / topic:** `data/rag/temp_methodology.duckdb` /
`climate_stream_temp_bridge`

**Paraphrase as written (proposed):** "Stream temperatures are
likely rising in step with warmer ambient air temperatures, with
the combined effects of warming summer stream temperatures and
altered low flows likely reducing thermally-suitable habitat for
cold-water species
[@mantua_etal2010Climatechange; @eaton_scheller1996Effectsclimate]..."

**Why warranted:** this is the load-bearing climate→fish bridge
for the FWCP fish-passage-planner audience. Visible in **summer
Tmax warming** (Trends section, table) + **summer SWE collapse**
(Snowpack section). Without this cite, the assertion that "stream
temps rise → cold-water species lose habitat" is unsupported.
Mantua 2010 = PNW regional anchor, Eaton & Scheller 1996 = the
foundational cold/cool/warm-water-species thermal-habitat
methodology.

---

## 7. Kang 2016 — Fraser freshet advance (Interpretation, L1024–1025)

**Vignette excerpt (current):** "The neighbouring Fraser Basin
documents the same kind of freshet advance (Kang et al. 2016) at
comparable magnitude."

**Source quote (already cited in vignette at L311 as
`@kang_etal2016ImpactsRapidly`; from snow rag, archive #54
findings.md):**
> "10-day advances of the onset of the spring freshets for the
> Fraser River at Hope... declines persist during the recession
> to lower flows in autumn just when the salmon are migrating up
> the Fraser River." — Kang et al. 2016, Sci Rep

**Rag store / topic:** `data/rag/snow_methodology.duckdb` /
`bc_specific`

**Paraphrase as written (proposed):** convert prose "(Kang et al.
2016)" → "[@kang_etal2016ImpactsRapidly]" or
"[-@kang_etal2016ImpactsRapidly]" depending on narrative form

**Why warranted:** existing prose-style author ref — just convert
to consistent `[@key]` format. Kang 2016 is already cited
elsewhere in the vignette in the same format we're targeting. This
is consistency cleanup, not new attribution.

---

## Out-of-audit observations

- **3 FWCP Peace cross-references** at L528, L973, L996 should
  not be in this stand-alone vignette per
  `feedback_thorough_cross_reference_removal.md` memory. Out of
  scope for #65 (citation wire-up only); flagged in progress.md
  as a separate follow-up issue worth filing.
- The existing 14 Snowpack-section `[@key]` markers from #54 are
  intact and well-grounded — not re-audited here.

## Independent review agent — checklist

The Phase 3 review agent should verify, for each row above:

1. The source quote actually exists in the cited paper (not
   hallucinated)
2. The paraphrase as written in the vignette is faithful to the
   source — no overreach, no claim the paper doesn't support
3. The "why warranted" reasoning matches an actually-visible
   feature in the vignette's plots/tables (not a feature claimed
   but not shown)
4. No BS — if a citation looks like decoration rather than
   load-bearing, flag it for removal

## Phase 3 — Review agent sign-off (2026-05-05)

Spawned an Explore subagent to verify each row. **All 7 rows
passed** scientific-integrity review: no hallucinated quotes,
paraphrases faithful, warrants visible in plots/tables, all cites
load-bearing. Agent flagged one minor scope concern:

- **Row 5 (Ficklin & Novick 2017):** initial paraphrase said
  "documented across the western United States" but the paper
  covers the entire continental US (1979–2013), with the
  strongest historical VPD increases concentrated in the
  western/southern portions. **Fixed in vignette** —
  "documented for the United States as a whole, with the
  strongest historical VPD increases concentrated in the western
  and southern portions, driven by combined air-temperature
  increases and relative-humidity declines." Now accurate to the
  paper's full scope.

No other edits or removals required. Agent's overall
recommendation: **keep all 7 cites as-is** (with the Ficklin
fix applied).
