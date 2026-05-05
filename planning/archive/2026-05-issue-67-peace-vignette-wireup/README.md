# Archive: Wire up peace-fwcp.Rmd citations from 3-split lit reviews (#67)

## Outcome

Second downstream consumer of the climate-departure 3-split lit
reviews (companion to #65/v0.2.5 kootenay-lake wire-up). 7
insertions (8 unique new keys + 1 reuse) into `peace-fwcp.Rmd`
non-snow interp paragraphs, sparingly applied per
`feedback_vignette_citations_sparse.md` philosophy. Released as
**v0.2.6** (patch).

## Citations added

Same 7-row pattern as #65 with two AOI-specific tweaks:

| # | Vignette section (line) | Citation key | Notes |
|---|---|---|---|
| 1 | Trends (L176) | `@hansen_etal2012Perceptionclimate` | Same as #65 |
| 2 | Trends (L186) | `@arguez_vose2011DefinitionStandard` | Same as #65 |
| 3 | Daytime/Overnight (L238) | `@karl_etal1993NewPerspective` | DTR narrowing **stronger** here (0.4 °C) than Kootenay (0.2 °C) |
| 4 | Interpretation/warming (L859) | `@pepin_etal2015Elevationdependentwarming` + `@rangwala_miller2012Climatechange` | **Different placement vs #65:** at Interpretation, not Spatial Pattern. Peace's dominant warming gradient is E-W (windward-of-Rockies), not pure elevation; EDW cite fits the explicit "high-latitude/high-elevation amplification" claim in the Interpretation paragraph. |
| 5 | Interpretation/drying (L887) | `@ficklin_novick2017Historicprojected` | **Stronger Peace case than Kootenay** — VPD up across all 5 ecoregions *despite* precipitation rising 3-4% in 2 of them. Pure VPD-driven evaporative-demand effect. |
| 6 | Interpretation/salmonids (L925) | `@mantua_etal2010Climatechange` + `@eaton_scheller1996Effectsclimate` | Same as #65 |
| 7 | Interpretation/Fraser (L937) | `@kang_etal2016ImpactsRapidly` | Convert prose ref; Kang's Fraser AOI directly comparable to Peace headwaters |

## Independent verification

Spawned an Explore subagent before merge. **All 7 rows passed
with zero edits or removals required** — a stronger pass than
the #65 review (which caught one minor scope nit on Ficklin).
Agent specifically validated:

- Ficklin & Novick 2017 mechanism (air-T + RH → VPD) applies
  faithfully to Peace's "VPD up despite precip up" framing
- EDW cite at Interpretation (not Spatial Pattern) is appropriate
  given the small but real 0.2 °C ecoregion gradient + Rangwala
  caveat
- Mantua's Washington-State scope used as PNW regional reference,
  not over-claimed as a direct BC-Peace study

## `vignettes/references.bib` no-op

Peace-fwcp and kootenay-lake use the **same 18 citation keys** —
the union is the same set since both vignettes draw from the
identical climate collection. Bib regen via
`rbbt::bbt_update_bib(path_rmd = "vignettes/peace-fwcp.Rmd", ...)`
produced no diff. References infrastructure committed in v0.2.5
covers both vignettes.

## Notable execution wrinkle

**EDW cite location decision.** Peace's Spatial Pattern section
describes "windward-slope amplification along the Continental
Divide" — geographic, not elevation-based. Pepin/Rangwala don't
cleanly cover windward-slope effects, so we did NOT decorate the
Spatial Pattern with an EDW cite. The Interpretation paragraph
(which explicitly invokes "high-latitude and high-elevation
amplification") is where the EDW cite landed. This kind of
discrimination — citing only where the paper genuinely supports
the claim — is exactly what the
`feedback_vignette_citations_sparse.md` philosophy calls for.

## Closing ref

- Issue: NewGraphEnvironment/cd#67
- PR: NewGraphEnvironment/cd#68 (squash `d1269d3`, merged 2026-05-05)
- Release: v0.2.6 (tag pushed)

## What's next

- **Both regional vignettes now have full citation backbones**
  for the climate-departure analysis (snow, temperature,
  precip+drying, framing). The 3-split lit reviews are closed
  loop end-to-end.
- **Open follow-ups:**
  - FWCP Peace cross-references in `kootenay-lake.Rmd`
    (L528, L973, L996) — small scrub per
    `feedback_thorough_cross_reference_removal.md` memory
  - #59 BEC zone shifts tracker — natural next pickup if reporting
    needs warrant
