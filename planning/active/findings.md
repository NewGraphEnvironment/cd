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

`R/cd_anomaly.R:137-138`: `pct_normal` anomaly = `value / baseline_mean * 100 - 100` (capped), the percent departure from the baseline mean. A `cd_trend()` slope on it is therefore percent of the 1951-1980 baseline mean per year, which is what the column header (`prcp %/yr`) and caption say (the caption said "percentage points of the 1951-1980 normal" until the plan review; the vignettes keep "climate normal" for WMO 1981-2010).

## Both windows, annual prcp, ecoregion trends (slope %/yr, MK p)

| ecoregion | 1951 | 1981 |
|---|---|---|
| NCM | -0.121, 0.030 | -0.122, 0.278 |
| SBF | -0.110, 0.061 | -0.217, 0.140 |
| PTR | -0.141, 0.010 | -0.069, 0.323 |
| TOP | -0.063, 0.356 | -0.140, 0.343 |
| OMM | 0.052, 0.421 | -0.012, 0.930 |
| BMP | 0.144, 0.023 | -0.008, 0.961 |
| CRM | 0.077, 0.253 | 0.013, 0.945 |
| FAB | 0.032, 0.634 | 0.030, 0.837 |
| NRM | 0.156, 0.015 | -0.033, 0.732 |

Peace's facet-prcp caption (BMP, NRM significant increases) holds. Kootenay's new caption: all four decline from 1951; significant in NCM and PTR; no 1981 trend significant.

## Kootenay ecoregion names and positions (inst/extdata/context_kootenay_lake.gpkg, intersected with the AOI)

| code | name | km² in AOI | centroid lon, lat |
|---|---|---|---|
| NCM | Northern Columbia Mountains | 19441 | -117.05, 49.84 |
| SBF | Selkirk-Bitterroot Foothills | 4201 | -117.87, 49.39 |
| PTR | Purcell Transitional Ranges | 494 | -115.98, 49.42 |
| TOP | Thompson-Okanagan Plateau | 26 | -118.43, 50.06 |

AOI bbox lon -118.51 to -115.52. The vignette called PTR "Pacific and Cascade Ranges" and put it with TOP "in the southwest"; PTR is on the eastern edge. Found while writing the facet-prcp caption, folded into Phase 2.

## Caption assertions: enumeration (code-check round 2 found a gap inside the round-1 fix)

Every clause of the two facet-prcp captions, and the unit claim behind the roll-up's `prcp %/yr` header, mapped to the `data-raw` claim that checks it:

| caption clause | claim |
|---|---|
| roll-up `prcp %/yr`: slopes are trends of pct_normal anomalies | `prcp_trend_pct_of_baseline` (both) |
| K "all four ecoregions" (and SBF, TOP named) | `ecoregions_are_ncm_sbf_ptr_top` |
| K "Northern Columbia Mountains (NCM)", "Purcell Transitional Ranges (PTR)" | `ncm_ptr_names` |
| K "declines in all four ... over the full record" | `prcp_declines_everywhere` |
| K "significant in NCM and PTR, not in SBF or TOP" | `prcp_significant_ncm_ptr` |
| K "None of the 45-year trends is significant" | `prcp_none_significant_1981` |
| P "The two northernmost ecoregions (BMP, NRM)" | `bmp_nrm_northernmost` (centroid latitude) |
| P "show statistically significant ... increases" | `prcp_significant_bmp_nrm`, `prcp_bmp_nrm_increase` |
| P "the others do not" | `prcp_significant_bmp_nrm` (set equality) |

Not asserted, on purpose: the "Dashed line is the 75-year trend; solid line is the 45-year" sentence is a property of the plotting code, not the data; PTR/TOP edge positions in the Kootenay intro and map caption come from the context gpkg, which `data-raw/example_context_kootenay_lake.R` builds, not from this script's outputs.

Mutation table, run on each block extracted from its file, with `ecoregion_results` from the committed rds and `ecoregions` from the gpkg (Peace filtered >100 km²): clean data passes in both, and each of 11 mutations stops naming its claim (SBF significant, TOP slope up, NCM 1981 significant, TOP dropped, NCM p NA, PTR renamed, `trend_on = "value"`, OMM significant, NRM slope down, FAB moved north of NRM, `anomaly_type = "pct_point_diff"`). `claims %in% TRUE` makes an NA claim a named failure rather than an `if (NA)` error.
