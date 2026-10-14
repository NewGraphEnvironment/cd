# Baseline period: why cd's "normal" is 1951–1980

**Verified:** 2026-10-14 · **Issues:** #20 and #43 (set the `cd_compare()` default), #137 (re-asked the question for the plain-language vignette) · **Produced by:** a probe in the #137 planning session: `cd_extract()` from the live catalog (1950–2025) over the BULK, NECR and PARS polygons from `WHSE_BASEMAPPING.FWA_WATERSHED_GROUPS_POLY`, then window means. `data-raw/northern_bc_vignette_data.R` (#137) re-derives the 1951–1980 numbers, which matched on 2026-10-14 · **Status:** decided, 1951–1980 kept

## Decision

cd measures departure against **1951–1980**. It starts one year into the ERA5-Land record (which begins in 1950), so it is all but the earliest 30-year window this data holds and about as close as it gets to IPCC's pre-industrial baseline (1850–1900). It is also NASA GISS's base period, the one `hansen_etal2012Perceptionclimate` uses. Some warming had already happened by 1951–1980, so departures against it **understate** the change since pre-industrial times. Vignettes say so in plain words.

The archived lit reviews reached the same choice (`planning/archive/2026-05-issue-53-*`, `*-issue-58-*`, `*-issue-63-*`), calling it a defensible "alternative climate normal" (`arguez_vose2011`) on the early side of WMO's 1961–1990.

## What the alternatives are

The descriptions below come from the session's background knowledge and were **not** checked against WMO or IPCC documents. Verify them before quoting.

- **WMO climatological standard normals:** 30-year averages, recomputed every decade (currently 1991–2020). Canada's official normals follow them. They are an operational standard for national weather services: "what to expect now".
- **WMO's fixed reference for long-term climate-change monitoring:** 1961–1990.
- **IPCC AR6:** 1850–1900 for warming levels, and other periods (e.g. 1995–2014) for projections.
- 1951–1980 was **never** a WMO standard normal; WMO's fixed periods were 1901–30, 1931–60 and 1961–90. `cd_compare()`'s roxygen calling it "WMO-style" is wrong (fix in #137).

## The measured spread

Last 10 years (2016–2025) against each candidate:

| | vs 1951–1980 | vs 1961–1990 | vs 1991–2020 |
|---|---|---|---|
| BULK annual tmean | +1.94 °C | +1.58 °C | +0.58 °C |
| NECR annual tmean | +1.74 °C | +1.28 °C | +0.49 °C |
| PARS annual tmean | +1.57 °C | +1.18 °C | +0.41 °C |
| NECR peak snowpack (`swe_max`) | −12.2 % | −5.7 % | |
| BULK half-melt date (`snowmelt_doy_50`) | 13.2 days earlier | 11.0 days earlier | |
| BULK: years of the last 10 warmer than every year of the reference | 7 | 2 | |

The 1991–2020 column is the 2016–2025 departure less the 1991–2020 departure (1.36, 1.25 and 1.16 °C against 1951–1980). In other words, 1991–2020 already holds about 70 % of the warming.

The choice is material. The "warmer than any year back then" count changes most, because 1961–1990 includes the warm late 1980s. Any statistic built on the reference period's extremes has to name its period.

ERA5 assimilates satellite data from about 1979, so the early years are less constrained where stations are sparse. That weighs on 1961–1990 nearly as much as on 1951–1980 (18 of its 30 years are pre-satellite), so it does not separate them.
