## Outcome

Added `vignettes/northern-bc.Rmd`, a 400-line plain-language story of how the weather changed in the Bulkley, Nechako and Parsnip watershed groups against 1951–1980, with three local data-raw generators and 41 KB of bundled data. It contains a map, a scorecard, figures for temperature, seasons, snow and the upper vs lower Bulkley (split at Houston above the Morice confluence, 2,320 km² upper), and a stream-and-fish table whose six citations were checked against their PDFs. The lesson that shaped most of the work: **a caption written from a variable's name, or from one window's mean, is often false.**

- "Winter" is a calendar-year group, and `snowmelt_doy_50` is half of the year's melt (see [research/period_and_snow_definitions.md](../../../research/period_and_snow_definitions.md)).
- "Winters warmed most" and "the last three years were drier" both rested on 2023 alone.
- Three review rounds kept finding sentences whose checks tested a different window or a weaker statement than their words. That ended only once the page had one rule (a last-three-years sentence needs the mean and 2 of 3 years; quantities printed, not worded) and an enumeration mapped all 84 quantifier and direction words in the rendered text to an asserted claim (`claims-enumeration.md`).

The plan review also caught that `devtools::check()` never builds vignettes here (no `VignetteBuilder`), so the gate is `pkgdown::build_article()` after an install. Follow-ups: #139 (swe_max anomaly type; cd_compare's 11-year "decade") and #140 (the GNS table is gone from fwapg).

## Measurement

`data-raw/northern_bc_vignette_data.R` against the live catalog, 2026-10-14 (34 s with a warm cache); windows 2016–2025 and 2023–2025 against 1951–1980.

- **Probe table:** the issue's planning numbers reproduce to their rounding for all three groups, so the planning probe and the shipped script agree.
- **Warmer than any normal year:** 7 / 5 / 4 of the last 10 years (Bulkley / Nechako / Parsnip), as planned.
- **Three-year warming with and without 2023:** +2.6 / +2.4 / +2.3 °C with it, +2.1 / +1.9 / +1.7 °C without. The warming does not depend on one year; the precipitation statements did, and were rewritten.
- **Seasons, 10 years:** summer warmed more than winter in the Bulkley (+2.3 vs +2.0 °C) and the Parsnip (+1.9 vs +1.7 °C). The issue's planned figure title "Winters warmed most" was dropped.
- **Winter precipitation:** −2 to −5 % over 10 years, so the planned "more winter rain → more winter high flows" row was cut.
- **Upper vs lower Bulkley:** warming +1.86 vs +1.97 °C; peak snowpack −9.2 vs −8.1 %; normal precipitation 758 vs 1,055 mm; normal peak snowpack 293 vs 534 mm. This confirmed the issue's median-longitude story on the Houston split.
- **Grid cells touched:** 156 (BULK), 81 (NECR), 112 (PARS), 49 (upper Bulkley).

## Evidence

The `planning/archive/2026-10-issue-137-northern-bc-vignette/review-*` files: the plan review, the reference check, and code-check rounds 1–3.

Closed by: PR for branch `137-vignette-a-plain-language-climate-story-for`
