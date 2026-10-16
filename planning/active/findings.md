# Findings — Vignettes: per-ecoregion prcp trend is % of normal per year but labelled mm/yr (#102)

## Issue context

**If we do it:** the per-ecoregion roll-up tables in both vignettes label the precipitation trend in the unit it is actually in. **If we never do:** readers (and the fish_passage report appendices ported from these vignettes) read a percent-of-normal slope as millimetres per year.

## Problem

The per-ecoregion roll-up builds its prcp column from `res$trn`, which `data-raw/*_vignette_data.R` computes with `cd_trend(ano, ...)` — a trend of **anomalies**. prcp's anomaly type is `pct_normal`, so the slope is **% of normal per year**, but the column is named `` `prcp mm/yr` `` and the caption says "annual precipitation trend (mm per year)":

- `vignettes/peace-fwcp.Rmd:761` and the caption at `:775` (lines as of v0.6.10)
- `vignettes/kootenay-lake.Rmd:857` and the caption at `:871`

Measured from the committed `inst/vignette-data/peace_fwcp.rds`: the first ecoregion's annual prcp trend from 1951 has slope `0.0521`, on anomalies carrying `anomaly_type = "pct_normal"`, `unit = "%"`.

The plan review for #97 reports that the same label was ported into the `fish_passage_peace_2025_reporting` and `fish_passage_skeena_2025_reporting` appendices; not verified here.

## Proposed Solution

- Rename the column to `` `prcp %/yr` `` (or `% normal/yr`) and fix both captions; or, where mm/yr is what the prose wants, trend `ts` (raw values) instead of `ano` for prcp.
- Check the downstream appendices for the same label.

Found by the plan review for #97.

## Measured 2026-10-16 (committed rds, v0.6.10)

Ecoregion `trn` rows for prcp, annual, are `trend_on = "anomaly"`, `anomaly_type = "pct_normal"`, `unit = "%"` in both files.

| file | ecoregion | start | slope | MK p |
|---|---|---|---|---|
| peace_fwcp.rds | OMM | 1951 | 0.0521 | 0.4208 |
| kootenay_lake.rds | NCM | 1951 | -0.1208 | 0.0301 |
| kootenay_lake.rds | SBF | 1951 | -0.1100 | 0.0607 |
| kootenay_lake.rds | PTR | 1951 | -0.1410 | 0.0096 |
| kootenay_lake.rds | TOP | 1951 | -0.0631 | 0.3555 |

So the Kootenay `facet-prcp` caption ("two northernmost ecoregions (BMP, NRM) show statistically significant precipitation increases") is wrong on every count: wrong ecoregions, wrong direction. NCM and PTR are significant decreases.

## Downstream (verified on origin/main, both repos PUBLIC)

- `fish_passage_peace_2025_reporting/0720-appendix-climate-departure.Rmd:609` (`prcp mm/yr`) and caption `:621`; `trn` comes from `cd_data`'s ecoregion `trn`
- `fish_passage_skeena_2025_reporting/0710-appendix-climate-departure.Rmd:758` and caption `:769`; `scripts/gis/climate_departure.R:329` builds it with `cd::cd_trend(ano, ...)`

## Errors Encountered

| Error | Resolution |
|-------|------------|

## pct_normal anomaly scale

`R/cd_anomaly.R:137-138`: `pct_normal` anomaly = `value / baseline_mean * 100 - 100` (capped), the percent departure from the baseline mean. A `cd_trend()` slope on it is therefore percentage points of the 1951-1980 normal per year, which is what the new column header (`prcp %/yr`) and caption say.
