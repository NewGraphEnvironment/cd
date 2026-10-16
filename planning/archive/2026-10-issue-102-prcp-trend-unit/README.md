## Outcome

The per-ecoregion roll-up tables in both regional vignettes labelled the precipitation trend as mm per year. It is a `cd_trend()` of `pct_normal` anomalies, so it is now `prcp %/yr`, "percent of the 1951-1980 baseline mean per year". The wording is "baseline", not "normal", because the articles keep "climate normal" for WMO 1981-2010. Checking the claims turned up more inherited Kootenay text, folded in at the plan gate and during review:
- The facet-prcp caption was copied from Peace and named BMP and NRM, neither of which is in the Kootenay AOI.
- PTR is Purcell Transitional Ranges, on the eastern edge, not "Pacific and Cascade Ranges" in the southwest.
- The vignette filters ecoregions to >50 km², so Thompson-Okanagan Plateau never appears in its trend figures or roll-up. The captions now describe the three ecoregions shown.

Both data-raw scripts now refuse to save data their prcp captions no longer describe. They read the vignette's own area filter, and accept it only in the exact shape the vignettes use. The shown per-ecoregion recipe passes `method = "pct_change"`. The data was not regenerated; every published number is unchanged.

The lesson came from five review rounds, each finding something inside the last fix: check a published claim against the rendered page, not the data behind it. The rds held four Kootenay ecoregions and the article drew three. Two independent paths decide what the article shows (the filtered trend results, and an unfiltered WSG overlap table), and each misled one round. The loop ended on an enumeration of every line that assigns `ecoregions` or `results` in both vignettes (findings.md, "Round 5").

Follow-ups:
- [cd#146](https://github.com/NewGraphEnvironment/cd/issues/146): five more inherited Kootenay sentences the data contradicts.
- fish_passage_peace_2025_reporting#50 and fish_passage_skeena_2025_reporting#21: the same mm/yr label in the report appendices.

## Measurement

From the committed `inst/vignette-data/*.rds` (v0.6.10), annual prcp ecoregion trends are `trend_on = "anomaly"` and `unit = "%"`. The slope is in percent of each ecoregion's 1951-1980 mean per year; Peace OMM is 0.052 %/yr.

Kootenay from 1951:

| Ecoregion | Slope (%/yr) | MK p |
|---|---|---|
| NCM | −0.121 | 0.030 |
| SBF | −0.110 | 0.061 |
| PTR | −0.141 | 0.010 |
| TOP (not shown) | −0.063 | 0.356 |

No Kootenay 1981 trend is significant (p ≥ 0.14). Peace BMP (p 0.023) and NRM (0.015) are the only significant ecoregions, both increasing.

Caption guards were tested by extracting each block from its file and running it against the committed rds and the context gpkg. The clean data passes. Every planted defect stops, each named by its claim: about 20 across the rounds, including a threshold change in the vignette that would show TOP, and filters prepended, appended or negated.

Wrong turns:
- The first render check printed the Kootenay roll-up's three rows, and nobody counted them.
- The first guard asserted four ecoregions from the rds, not the three the article draws.

Closed by: PR (this branch, `102-vignettes-per-ecoregion-prcp-trend-is-of`)
