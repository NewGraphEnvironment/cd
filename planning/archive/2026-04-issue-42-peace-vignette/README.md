# Archive: FWCP Peace Region vignette (#42)

## Outcome

Added a second worked example to `cd` showing the consumer pipeline on a
regional administrative AOI (~73,000 km², ~11× KOTL). Released as
**v0.1.2** (patch — vignette + docs).

The vignette consolidated the regional analysis with a per-ecoregion
breakdown across the 5 BC ecoregions intersecting the FWCP Peace Region
(faceted time-series carrying both 75-yr and 45-yr Theil-Sen trend lines,
wide roll-up table). Added day-night asymmetry section confirming the
textbook signal does show up here (tmin warming faster than tmax),
unlike KOTL where the diurnal range is flat. Three-finding interpretation:
warming is broad and uniform, precipitation increases significantly only
in the two northernmost ecoregions, atmosphere is drying via vapour
pressure deficit despite increased precipitation in places.

## Key findings worth remembering

- For the FWCP Peace Region, all five ecoregions warm at ~0.3 °C/decade
  with virtually identical trajectories (spread 0.21 °C cumulative
  across 5 ecoregions over 75 years). Per-ecoregion breakdown
  confirms uniformity rather than revealing variation — but it reveals
  variation on **precipitation**: BMP and NRM (the two northernmost)
  show statistically significant precipitation increases; the southern
  three show no significant change. That contrast is washed out at the
  regional scale.
- Vapour pressure deficit is up significantly in every ecoregion
  (p < 0.005). This is the most ecologically loaded finding — soil
  moisture stays flat even where precipitation went up, because
  warmer air pulls moisture out of soils faster than the extra rain
  refills them.
- The Peace drains north to the Arctic via the Mackenzie. Pacific
  salmon do not naturally occur in the Peace drainage. Resident
  salmonids supported by FWCP: bull trout, Arctic grayling, mountain
  whitefish, rainbow trout.
- `tools::toTitleCase(tolower(name))` for converting ALL-CAPS BCDC
  names ("OMINECA MOUNTAINS" → "Omineca Mountains") in legends.
- For tables wrapped in `kableExtra::kable_styling()`, set
  `caption = NA` on the inner `knitr::kable()` call and pass the
  caption via `tab.cap` chunk option to avoid bookdown's double
  "Table N: Table M:" rendering.

## Related issues filed during this work

- #43 — `cd_compare()` to add a window-vs-window p-value (proper test,
  not the trend-p proxy currently used in the vignette)
- Per-WSG breakdown deferred — separate issue to be filed when needed

## Closing ref

- Issue: NewGraphEnvironment/cd#42
- PR: NewGraphEnvironment/cd#44 (merged 2026-04-30)
