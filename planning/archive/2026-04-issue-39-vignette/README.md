# Archive: vignette tmax/tmin + map clipping (#39)

## Outcome

Tightened the vignette in two ways: clipped all context layers and
departure rasters to the AOI watershed group polygon (no more features
extending past the basin), and added a "Daytime Highs and Overnight
Lows" section using the now-available tmax/tmin variables on STAC.

A critical re-read of the existing trend data caught two interpretation
bugs: precipitation was wrongly described as "weak" (-10.7% over 75
years, p=0.015 is real); soil drying was wrongly attributed to "stable
precipitation" (precip is down AND ET is up — both contribute). Fixed.

The day-night asymmetry that the textbook predicts (tmin warming faster
than tmax) does NOT show at Kootenay Lake — the diurnal range is flat.
Pivoted that section to focus on the strongest signal that DOES show:
summer daytime maximum (+2.8 °C since 1951), the temperature envelope
driving salmonid thermal stress in tributaries.

Released as **v0.1.1** (patch bump — vignette + docs).

## Key findings worth remembering

- Always look at the actual data before writing climate narrative. A
  textbook signal (day-night asymmetry) doesn't always apply to a
  specific watershed; the cd package's value is letting you check.
- For Kootenay Lake: anadromous salmon runs are blocked by lower-Columbia
  dams. Resident salmonids (kokanee, bull trout, Gerrard rainbow) and
  First Nations reintroduction efforts are the relevant species for
  thermal-stress framing — don't write "salmon" for KOTL.
- `cd_compare(method = "pct_change")` exists and is the right call for
  precipitation and soil moisture comparisons.
- bookdown::html_document2 auto-numbers section headers by default; use
  `number_sections: false` to disable for prose-style vignettes.
- terra::mask() accepts sf objects directly — no need to vect() first.

## Closing ref

- Issue: NewGraphEnvironment/cd#39
- PR: NewGraphEnvironment/cd#41 (merged 2026-04-15)
