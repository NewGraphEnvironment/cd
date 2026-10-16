# Code-check round 3: branch 102-vignettes-per-ecoregion-prcp-trend-is-of (HEAD 636b010)

## Findings

- **[severity: bug]** vignettes/kootenay-lake.Rmd:698 (facet-prcp caption): the claims "Precipitation declines in all four ecoregions" and "not in SBF or TOP" describe a facet that is not in the figure. The vignette filters `ecoregions <- ecoregions[ecoregions$area_km2 > 50, ]` (line 98). TOP is 26.1 km² in the context gpkg, in both the repo copy and the installed copy, so `results <- results[ecoregions$code]` (line 640) drops it, and `ano_all`, the facets and `trn_segs_prcp` hold only SBF, NCM and PTR. The branch's own render confirms it: `docs/articles/kootenay-lake.html` (built 2026-10-15 21:19, contains `prcp %/yr`) has roll-up rows NCM, PTR and SBF only, and "Ecoregion codes used in the table above: SBF ...; NCM ...; PTR ...". The caption therefore counts four panels in a three-panel figure and names a TOP panel the reader cannot find. The NCM/PTR/SBF clauses and the 1981 clause do hold for the three panels shown.

- **[severity: bug]** data-raw/kootenay_lake_vignette_data.R:113 (`ecoregions_are_ncm_sbf_ptr_top`, and `p51`/`p81` over `names(ecoregion_results)`): the guard checks the population that data-raw builds (the unfiltered gpkg, 4 codes), not the population the vignette renders (`area_km2 > 50`, 3 codes). It therefore stays green while the caption it guards is false. In Peace both files filter at `> 100`, so there the two lists agree by coincidence. In Kootenay they diverge (data-raw has no filter; the vignette has `> 50`). This is the round-2 fix (adding the "all four" count) asserting against the wrong list, which repeats the round-2 defect one level down.

- **[severity: bug]** vignettes/kootenay-lake.Rmd:893 (map-wsgs caption, rewritten on this branch): "small slivers belong to Thompson-Okanagan Plateau (TOP) on the western edge" names a fill the map does not draw. `geom_sf(data = ecoregions, aes(fill = name_tc))` (line 899) uses the filtered `ecoregions`, so TOP has no fill and no legend entry, here or in map-location (line 108). The PTR half is correct: its main 477 km² part shares 88 km of boundary with the AOI between 116.18 and 115.71 W, 49.29 and 49.54 N, in the south-east.

- **[severity: fragile]** planning/active/findings.md:87 (enumeration row "K 'all four ecoregions' -> `ecoregions_are_ncm_sbf_ptr_top`"): the claim is weaker than its clause. It verifies the rds keys, not what the figure shows, so the enumeration certifies the false clause above. The Kootenay names/positions table (findings.md, last section) also lists TOP without noting that the vignette drops it.

- **[severity: fragile]** cd#146 item 5 (an issue body this branch filed) says "the Kootenay one has no such filter". The Kootenay **data** script has none, but the **vignette** filters at > 50 km², so TOP is already absent from every per-ecoregion figure and table. Item 2's TOP value (1.71) is likewise not rendered. The issue's open decision ("whether Kootenay applies Peace's >100 km² filter (dropping TOP)") rests on this wrong premise. Edit the body.

### Mechanism

Every defect across the rounds comes from one cause: each claim was checked against a source upstream of the rendered article, not against what the reader sees. Those sources were the issue's wording ("normal", in the plan review), the findings table and the rds (round 2's "all four" count, and now the caption's TOP), and the data-raw `ecoregions` object (this round's guard). The two lists that happen to agree are data-raw's ecoregion set and the vignette's filtered `ecoregions`. They agree in Peace (both `> 100`) and differ in Kootenay (none vs `> 50`). Every place this branch reaches through that mechanism:

1. kootenay-lake.Rmd:698 facet-prcp caption ("all four", "not in SBF or TOP")
2. kootenay-lake.Rmd:893 map-wsgs caption (TOP western-edge sliver)
3. kootenay-lake.Rmd:603-610 per-ecoregion intro (edited on this branch): "averages over four ecoregions" is true of the regional AOI mean, but the next sentence ("we run the same pipeline on each ecoregion polygon individually") leads into results for three. This one is pre-existing in substance.
4. data-raw/kootenay_lake_vignette_data.R claim block (all of `p51`/`p81`/`ecoregions_are_ncm_sbf_ptr_top`)
5. planning/active/findings.md enumeration row and Kootenay table
6. cd#146 item 5 (and item 2's TOP figure)

Two consistent fixes. (a) Apply the vignette's `area_km2 > 50` filter in the data-raw assertion block, assert `setequal(codes, c("NCM","SBF","PTR"))`, and reword the caption to "all three ecoregions shown ... not in SBF". (b) Remove the vignette's filter so TOP is rendered (that is the cd#146 decision). Either way, the guard's population must be the vignette's.

### Verified true (no finding)

- The pct_normal anomaly is `value / baseline_mean * 100 - 100` (R/cd_anomaly.R:137-138), so "percent of the 1951-1980 baseline mean per year" and `prcp %/yr` are correct. Every prcp `trn` row in both rds files is `trend_on = "anomaly"`, `anomaly_type = "pct_normal"`.
- Kootenay 1951: NCM -0.121 (p 0.030), SBF -0.110 (0.061), PTR -0.141 (0.0096), TOP -0.063 (0.356). Every 1981 p is >= 0.14. At p < 0.05 the significance clauses hold.
- n_years is 75 for the 1951 window and 45 for the 1981 window (data 1950-2025).
- The gpkg names NCM and PTR as NORTHERN COLUMBIA MOUNTAINS and PURCELL TRANSITIONAL RANGES. TOP lies at the AOI's west edge (118.51 W).
- Peace: BMP and NRM are the only p < 0.05 trends (0.023 and 0.015), both positive. The prose "p = 0.02 and 0.01" matches. Peace's vignette and data-raw both filter at > 100 km², so the populations agree.
