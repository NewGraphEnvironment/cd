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

Peace's facet-prcp caption (BMP, NRM significant increases) holds. Kootenay: all four decline from 1951; significant in NCM and PTR; no 1981 trend significant. The article shows only three of them (TOP filtered out, see the enumeration below), and the shipped caption says so.

## Kootenay ecoregion names and positions (inst/extdata/context_kootenay_lake.gpkg, intersected with the AOI)

| code | name | km² in AOI | centroid lon, lat |
|---|---|---|---|
| NCM | Northern Columbia Mountains | 19441 | -117.05, 49.84 |
| SBF | Selkirk-Bitterroot Foothills | 4201 | -117.87, 49.39 |
| PTR | Purcell Transitional Ranges | 494 | -115.98, 49.42 |
| TOP | Thompson-Okanagan Plateau | 26 | -118.43, 50.06 |

AOI bbox lon -118.51 to -115.52. The vignette called PTR "Pacific and Cascade Ranges" and put it with TOP "in the southwest"; PTR is on the eastern edge. Found while writing the facet-prcp caption, folded into Phase 2.

## Caption assertions: enumeration (rounds 2 and 3 found gaps inside earlier fixes)

**Mechanism (round 3):** every check on this branch, mine and the reviewers', was made against something upstream of the rendered article: the rds, data-raw's `ecoregions`, the findings table. `kootenay-lake.Rmd:98` keeps only ecoregions over 50 km², so TOP (26 km²) is in the rds but in no Kootenay per-ecoregion trend figure or roll-up table. (It does appear in the WSG × ecoregion overlap table, which is built from data-raw's unfiltered set: round 4.) The vignette showed three panels while the caption said "all four ... not in SBF or TOP", and data-raw's unfiltered ecoregion set agreed with the vignette's only in Peace (both filter at 100 km²). The first render check printed the roll-up's three rows and nobody counted them.

**Remedy:** each data-raw block reads the vignette's own area threshold (`vignette_min_km2()`, a regex on a bare `ecoregions$area_km2 > N, ]`, anchored to the whole statement; Peace's data script also filters with it) and asserts on the ecoregions the vignette shows. The final check is the rendered page: `facet-prcp-1.png` has three panels (SBF, NCM, PTR), and the codes line lists those three.

| caption clause (as rendered) | claim |
|---|---|
| roll-up `prcp %/yr`: slopes are trends of pct_normal anomalies | `prcp_trend_pct_of_baseline` (both, shown ecoregions) |
| K "all three ecoregions shown" | `shown_are_ncm_sbf_ptr` (from the vignette's threshold) |
| K "Northern Columbia Mountains (NCM)", "Purcell Transitional Ranges (PTR)" | `ncm_ptr_names` |
| K "declines in all three ecoregions shown over the full record" | `prcp_declines_everywhere` |
| K "significant in NCM and PTR, not in SBF" | `prcp_significant_ncm_ptr` |
| K "None of the 45-year trends is significant" | `prcp_none_significant_1981` |
| P "The two northernmost ecoregions (BMP, NRM)" | `bmp_nrm_northernmost` (centroid latitude, among shown) |
| P "show statistically significant ... increases" | `prcp_significant_bmp_nrm`, `prcp_bmp_nrm_increase` |
| P "the others do not" | `prcp_significant_bmp_nrm` (set equality over shown) |

Not asserted, on purpose: the dashed/solid sentence is plotting code; the PTR "eastern edge" in the intro and map caption comes from the context gpkg (`data-raw/example_context_kootenay_lake.R`), not this script; the map caption no longer mentions TOP, which the filtered map does not draw.

Mutation table (blocks extracted from the files; `ecoregion_results` from the committed rds; `ecoregions` from the gpkg, Peace filtered >100 km²): clean passes in both; a significant TOP trend passes (TOP is not shown, correctly). Each of these stops: SBF significant, PTR slope up, NCM 1981 significant, PTR dropped (on `NROW(r) == 1`), NCM p NA, PTR renamed, `trend_on = "value"`, the Kootenay vignette's threshold lowered to 10 (TOP shown), OMM significant, NRM slope down, FAB moved north of NRM, `anomaly_type = "pct_point_diff"`, and the Peace threshold raised past every ecoregion.

Round 4 additions to the mutation table (`scratchpad t4.R`): the Kootenay filter extended in place (`> 50 & code != "PTR", ]`) stops on the regex; Peace's vignette threshold lowered to 60 (PRB shown, absent from the rds) stops on `NROW(r) == 1`; thresholds read as 50 and 100.

## Round 5: the threshold reader, enumerated

`vignette_min_km2()` reads source text, so it is checked against the full set of lines that could change which ecoregions the vignette shows. Measured in both Rmds with `grep -nE` for assignments to `ecoregions` and `results`: exactly `ecoregions <- st_read(...)`, `ecoregions <- ecoregions[ecoregions$area_km2 > N, ]`, two `results <- lapply(...)` (the eval=FALSE recipe and the rds load) and `results <- results[ecoregions$code]` (kootenay-lake.Rmd:97,98,621,637,641; peace-fwcp.Rmd:91,92,606,622,626). The reader now requires that shape: one whole-line bare filter, two `ecoregions <-` lines (one `st_read`), one `results <- results[` line, and it is `results[ecoregions$code]`. Mutations, each stopping: condition prepended, negated, appended; a second `ecoregions` filter; a second `results` subset; the subset changed; the filter removed. Clean reads 50 and 100.

Residual, accepted: an assignment by `=` or in place (`ecoregions[...] <-`) is outside what the reader sees; the rendered page remains the final check.

Accepted, not changed: the shown recipe passes all variables to `cd_compare(method = "pct_change")`, which gives NA and one warning for variables without a real zero (#138). That is the designed behaviour, and the two columns the roll-up reads are unaffected.
