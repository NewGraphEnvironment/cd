# Task: README: add daily point temperatures and any-series consumers; drop internal function (#142)

The architecture and data sections are accurate (v0.6.7), but recent consumer capabilities are missing, and one function listed as part of the API is internal.

Scope set at the plan gate (2026-10-17): rewrite the README to soul's `readme.md` convention — simple, plain language, a figure from committed code, not too much detail. Function tables, roadmap, caching section and the data inventory come out; the VPD unit fix stays in NEWS.

## Phase 1: Figure from committed code

- [ ] `data-raw/readme_figure.R` (local only, `pkgload::load_all()`): live catalog, `example_aoi_kotl.gpkg` (Kootenay Lake watershed group, ~9,300 km²), annual tmean, `cd_baseline(1951:1980)` -> `cd_anomaly()` -> `cd_trend(trend_start = 1951)` -> `cd_plot_timeseries()`; writes `man/figures/readme-kotl-tmean.png` (opaque white background) and prints the `cd_summary()` table for the README example
- [ ] Check the PNG at its published width (~700 px column): type legible, no transparency

## Phase 2: README rewrite, in the convention's order

- [ ] Title line with hex sticker (`alt` text added), lifecycle-experimental badge, one-line tagline
- [ ] Opening: what cd is (how far BC's climate has moved from a chosen baseline, for any area), the data (ERA5-Land reanalysis since 1950, served as a public self-updating catalog, no credentials), what it informs (which watersheds are warming or losing snow, for restoration planning and monitoring); one clause each for daily point temperatures (stream-temperature and degree-day work), any annual series (streamflow, stream temperature), and each value naming the file build it came from
- [ ] Figure + alt text + one-line caption
- [ ] Installation, then the "under active development / see NEWS / pin `@vX.Y.Z`" line
- [ ] Example: the Phase 1 code with a `1951:1980` baseline, shown with its real pasted `cd_summary()` output; one sentence that files are cached after first read
- [ ] Learn more: one line per vignette (peace-fwcp, kootenay-lake, northern-bc), then the function reference
- [ ] Ecosystem: cd, wet (and gq only if a vignette uses it), roles worded as in link's README
- [ ] Data and methods it builds on: ERA5-Land (Copernicus/ECMWF) via DestinE Earth Data Hub with the Copernicus attribution sentence, Mann-Kendall / Theil-Sen, and the `bcgov/bc_climate_anomaly` inspiration (replaces Acknowledgements)
- [ ] Citation (points to `CITATION.cff` / `citation("cd")`) and License
- [ ] Record word count before/after in findings.md

## Phase 3: Texts that travel with the README

- [ ] DESCRIPTION `Title` in step with the tagline; `Description` in step with the opening (drops the stale "download ERA5-Land monthly means"), ends "Under active development."; `devtools::document()`
- [ ] `update-citation-cff.yaml`: `cff_create(authors_roles = c("aut", "cre", "cph"))` so New Graph Environment Ltd. is a citation author
- [ ] GitHub About via `gh repo edit NewGraphEnvironment/cd --description "…"`, same words as the tagline

## Phase 4: Grouped reference index

- [ ] `_pkgdown.yml` `reference:` sections: Read the data (`cd_catalog`, `cd_catalog_default`, `cd_crop`, `cd_extract`, `cd_extract_daily`, `cd_variables`, `cd_periods`, `cd_seasons`); Departures and trends (`cd_baseline`, `cd_anomaly`, `cd_compare`, `cd_trend`, `cd_summary`); Plots (`cd_plot_*`); Cache (`cd_cache_*`); Publishing the data, for maintainers (`cd_fetch`, `cd_derive`, `cd_aggregate`, `cd_cog_write`, `cd_stac_catalog`, `cd_s3_push`)
- [ ] `pkgdown::check_pkgdown()` clean; `pkgdown::build_home()` locally and look at the rendered page and figure

## Phase 5: Close out

- [ ] Edit #142's body: scope is the convention rewrite; VPD fix left to NEWS
- [ ] Mechanical checks: every function the README names is exported; every link resolves
- [ ] `/code-check branch` with every README/DESCRIPTION claim enumerated against code

## Validation

- [ ] Tests pass
- [ ] `/code-check` clean (each commit, or once over the branch with `/code-check branch`)
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
