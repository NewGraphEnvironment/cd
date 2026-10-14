# Findings — cd_variables(): vpd unit is Pa but the data is hPa (#96)

## Issue context

**If we do it:** VPD anomalies, trends and `cd_summary()` tables print the unit the data is actually in. **If we never do:** every VPD label in cd output reads "Pa" over values that are hPa — off by 100× to any reader who takes the unit at its word.

## Problem

`cd_variables()` gives `vpd` the unit `"Pa"` (`R/cd_variables.R:46`, and the `unit` doc line at `:13`). The data is hPa:

- `R/cd_derive.R:93` — `@return SpatRaster of VPD in hPa.`
- `scripts/backfill_edh_all.py:26` — `vpd_YYYY.tif  hPa (Tetens from tmean + dewpoint)`
- both vignettes label trends `hPa/dec` by hand
- annual values in the bundled vignette data are ~1.5–4.2, which is hPa-scale (Pa would be ~100× larger)

`vpd` is `absolute`, so the anomaly unit is the value unit, and "Pa" reaches `cd_summary()`'s `Unit` column, `cd_plot_timeseries()` labels, and (since #93) raw-value plots.

## Proposed Solution

- `R/cd_variables.R`: `"Pa"` → `"hPa"`, and the doc line.
- Check whether any hand-set `hPa` label in the vignettes becomes redundant.
- NEWS: behaviour change — the `Unit` column for vpd changes.

Found by the plan review for #93.

## Exploration (plan mode, 2026-10-14)

What exploration found beyond the issue:

- **The wrong unit is also in written data.** Both `inst/vignette-data/*.rds` carry `unit = "Pa"` on every vpd row of each `ano` and `trn` table: 380 + 10 rows per AOI, in the regional, ecoregion and WSG lists. `meta_resolve()` (`R/cd_anomaly.R:178`) prefers a carried `unit` to the registry. So after a registry-only fix, both vignettes' trend tables (`cd::cd_summary(trn_tbl)`, peace-fwcp.Rmd:229, kootenay-lake.Rmd:237) would still print "Pa". **Decision (yours):** patch that column in place. No regen from S3, which stays pending for #123's grid and #126's columns.
- **Apart from vpd, every unit in the vignette data agrees with the registry.** I checked this with the current registry. So a test that the two agree is meaningful, and once the registry is fixed it fails on today's data.
- **The hand-set `vpd hPa/dec` labels in the vignettes stay.** They are column names in a hand-built wide table (peace-fwcp.Rmd:763, kootenay-lake.Rmd:859) and carry a `/dec` the registry cannot supply. That answers the issue's second bullet: neither label becomes redundant.
- No test or snapshot asserts "Pa".

## Errors Encountered

| Error | Resolution |
|-------|------------|
