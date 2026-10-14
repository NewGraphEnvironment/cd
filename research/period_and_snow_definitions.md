# What a published period and the snow variables mean

**Verified:** 2026-10-14 · **Issues:** #137 (found while writing captions for the northern BC vignette), #48 (the snow variables) · **Produced by:** reading `R/cd_aggregate.R`, `scripts/pipeline_stage3_edh.R` and `scripts/backfill_edh_snow.py` (lines 20–30 and 280–299), then checking the bundled values in `inst/vignette-data/northern_bc.rds`

What the catalog's COGs hold, in the words a caption has to use. Each item here was a near miss in #137, where a caption written from the variable's name said something the data does not.

## Seasons are calendar-year groups of months

`cd_aggregate()` builds the seasons from one calendar year's 12 monthly bands. So **"winter" for year Y is January, February and December of Y**, not a contiguous December-to-February winter. Winter 2023 is January–February 2023 plus December 2023, parts of two winters.

- Over a 10-year mean this hardly matters: it shifts one December at each end.
- For a single year, or a 3-year mean, it does. Never label a dot "winter 2022–23".
- A caption should say "December, January and February of the same calendar year".

## `swe_max` is a mean of cell peaks

For each grid cell, `swe_max` is the calendar year's maximum daily snow water equivalent. An area's value is the mean of those cell peaks over the polygon, not the peak of the area-mean snowpack, which would be smaller, because cells peak on different days. So:

- The absolute mm values overstate a basin's peak.
- Percent-of-normal and change figures are unaffected in direction, and are the safer numbers to quote.
- "2023" is the spring-2023 peak, from the winter of 2022–23.

## `snowmelt_doy_50` is half of the year's melt, not half of the peak

It is the day of year by which half of that **calendar year's total snowmelt** has happened. Mid-winter melt and October–December melt count, so it is not "the date half the peak snowpack is gone".

- Plain wording: "the date by which half of the year's snowmelt had happened".
- Convert an area-mean day of year to a calendar date with a fixed non-leap year.
- A negative change means earlier.

## A 3-year window is one year plus noise

Measured on the three northern BC watershed groups (#137), 2023–2025 against 1951–1980. 2023 was exceptional: annual precipitation −15 to −19 %, and winter +5.2 to +5.6 °C. Two consequences:

- In two of the three groups, the 3-year mean of annual precipitation is below normal only because of 2023 (Bulkley −17 / +2 / +3 %).
- "Winter warmed most" holds for the 3-year mean but not in 2025, when winter warmed least.

The northern BC vignette therefore states a last-three-years direction only when the mean **and** at least 2 of the 3 years agree (`last3_holds()` in `data-raw/northern_bc_vignette_data.R`). Use the same test for any short-window statement.
