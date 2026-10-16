## Clean
No issues found.

Verified against the committed data and code (round 1, branch 102-vignettes-per-ecoregion-prcp-trend-is-of):

- Unit: `R/cd_anomaly.R:137-138` pct_normal anomaly = value / baseline_mean * 100 - 100 (capped); both `data-raw/*_vignette_data.R` use `baseline_years = 1951:1980` and `cd_trend(ano, trend_start = c(1951, 1981))`. Ecoregion prcp `trn` rows carry `trend_on = "anomaly"`, `anomaly_type = "pct_normal"`, `unit = "%"` in both rds. So `prcp %/yr` and "percentage points of the 1951-1980 normal per year" are correct; the rollup's `get_75()` selects `trend_start == 1951`, matching the caption's 75-year window.
- Kootenay facet-prcp caption, from `inst/vignette-data/kootenay_lake.rds`: 1951 slopes NCM -0.121 (p 0.030), SBF -0.110 (p 0.061), PTR -0.141 (p 0.010), TOP -0.063 (p 0.356): all four negative, significant at 0.05 only in NCM and PTR. 1981 p-values 0.278, 0.140, 0.323, 0.343: none significant. The facet plot has exactly four ecoregions (gpkg `ecoregions` has 4 rows). Dashed = 1951 window via the alphabetical linetype mapping, consistent with the caption. Consistent with the surrounding prose (:614-616 region-wide decline, consistent across ecoregions; Interpretation section).
- PTR name: gpkg `name` = "PURCELL TRANSITIONAL RANGES"; no "Pacific and Cascade" string left outside planning/. Position: the main PTR piece (476 of 494 km2 in the AOI) spans lon -116.19 to -115.705, lat 49.26-49.54; the AOI's east boundary is at -115.62 (lat 49.25) and -115.71 (lat 49.5), so it abuts the eastern edge. TOP (26 km2) xmin -118.509 = AOI xmin, so "western edge" holds; it lies wholly in LARL.
- Peace facet-prcp caption (unchanged): BMP p 0.023, NRM p 0.015 increases; others not significant. Holds.
- Downstream issues fish_passage_peace_2025_reporting#50 and fish_passage_skeena_2025_reporting#21 exist, are open, titled for this work; both repos PUBLIC. Cited lines (peace 0720:609/621, skeena 0710:758/769, climate_departure.R:329) match origin/main.
