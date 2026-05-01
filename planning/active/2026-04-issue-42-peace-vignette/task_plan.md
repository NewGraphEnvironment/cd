# Task Plan — FWCP Peace Region vignette (#42)

## Goal

Add a second worked example to `cd` showing the consumer pipeline on a large regional AOI (~170,000 km²), reusable as a template for the SERN FWCP Peace 2024 report.

## Iteration 1 — regional polygon only

- [ ] Bundle AOI: copy `~/Projects/gis/sern_peace_fwcp_2023/fwcp_peace_region.geojson` to `inst/extdata/example_aoi_fwcp_peace.gpkg`. Document via `data-raw/example_aoi_fwcp_peace.R`.
- [ ] Create `vignettes/peace-fwcp.Rmd` mirroring KOTL structure, stripped of interpretation:
  - YAML: bookdown::html_document2, `number_sections: false`
  - Setup chunk: load `cd`, `sf`, `terra`, `dplyr`, `ggplot2`
  - Load AOI from `system.file()`
  - Overview map (AOI on BC outline)
  - `cd_catalog()` → table
  - `cd_extract()` → ts table
  - `cd_baseline()` (1981–2010 WMO) + `cd_anomaly()`
  - `cd_trend(trend_start = c(1951, 1981))`
  - `cd_summary()` table
  - One time-series plot per major variable (tmean, prcp)
- [ ] Add `bookdown` + any extras to `Suggests` if missing (already there)
- [ ] Render local: `devtools::build_rmd("vignettes/peace-fwcp.Rmd")` or knit interactively
- [ ] Open html, user reviews
- [ ] Commit incrementally with `Relates to #42` (not Fixes — iter 2 still pending under same or future issue)

## Iteration 2 — per-WSG breakdown (future, separate issue)

- [ ] Query fwapg via newgraph db: `whse_basemapping.fwa_watershed_groups_poly ∩ fwcp_peace_region`
- [ ] Use `fresh::frs_clip()` for edge-case-aware clipping
- [ ] Per-WSG trend table + small-multiples map
- [ ] Discuss whether to ship per-WSG zonal extracts as cached data

## Out of scope (this issue)

- Interpretation prose / ecological framing (separate session, like KOTL got)
- Shiny app
- Per-WSG analysis
