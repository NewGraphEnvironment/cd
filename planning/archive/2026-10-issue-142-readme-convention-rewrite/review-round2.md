# Code-check round 2: branch 142-readme-add-daily-point-temperatures-and (vs main @ 59a5122)

Reviewer read every changed file in full (README.md, NOTICE.md, DESCRIPTION, man/cd-package.Rd, _pkgdown.yml, data-raw/readme_figure.R, both workflow diffs), viewed the figure, and read soul's readme.md. It checked round 1's four fixes against the code and data. The bundled gpkgs were inspected from copies in the scratchpad: layers and row counts read with sqlite3, provenance traced through data-raw/. The vignette rds files were read with readRDS and hold no sf geometry. BC Data Catalogue licences were read from the CKAN API. All 14 external links in README.md and NOTICE.md answer 200. Nothing in the repo was written except this file.

## Findings

- **[false-claim / licence gap, low]** `NOTICE.md:18`: "It also redistributes, in `inst/extdata/example_aoi_*.gpkg` and `inst/extdata/context_*.gpkg`, watershed groups, lakes, rivers and streams from the BC Freshwater Atlas and ecoregions …, under the Open Government Licence – British Columbia." The glob `example_aoi_*.gpkg` matches `example_aoi_fwcp_peace.gpkg`. That file holds neither Freshwater Atlas nor ecoregion data. It is the Fish & Wildlife Compensation Program's Peace Region boundary, read from a local file (`data-raw/example_aoi_fwcp_peace.R`: `~/Projects/gis/sern_peace_fwcp_2023/fwcp_peace_region.geojson`), with no recorded origin or licence. Round 1's fix 4 brought this file under the OGL-BC sentence by glob, so it now reads as OGL-BC data. The other three `example_aoi_*` files are derived from FWA (watershed groups via bcdata/fwapg), which checks out. Suggested fix: add `example_aoi_fwcp_peace.gpkg` to cd#151 beside example_climate.tif, towns and highways. Optionally name the three FWA AOI files in NOTICE rather than globbing. (`example_aoi.gpkg` falls outside the glob, which is correct: it is a plain bbox.)

No other defects. Round 1's fixes 1–3 are correct as written (verdicts below).

## Round 1 fixes reviewed

1. `_pkgdown.yml` Cache desc, "Files are cached after the first read and downloaded again only when they are republished": true. `cd_cache_fetch()` downloads again only on a refresh, or when the ETag differs (size when there is no ETag). With revalidation off, or when the HEAD fails, it serves the local copy. "Only when" is a necessary condition, and the code honours it. The wording matches README.md:52. One edge, pre-existing and outside the diff: the cache key is `rlang::hash(href)`, so an rlang release that changed the hash would re-download unchanged files. Not flagged.
2. "Publishing the catalog" (cd_aggregate, cd_cog_write, cd_stac_catalog, cd_s3_push): each is called by `scripts/pipeline_stage3_edh.R` / `pipeline_update_edh.R`, the scheduled workflow's entry points. True. "Downloading from the Copernicus Climate Data Store" (cd_fetch: CDS monthly means plus daily stats; cd_derive: from cd_fetch's GRIBs): true. "The published catalog is not built this way": true, since neither is called in scripts/ (only a comment in backfill_edh_all.py names cd_derive).
3. README "cd's core climate variables and its ecoregion and watershed framing follow bcgov/bc_climate_anomaly": true. Its app.R names tmean, tmax, tmin, prcp, vpd, rh and soil_moisture, has no snow variable, and mentions watershed 19 times and ecoregion/ecoprovince 25 times.
4. NOTICE redistribution lists: `inst/extdata/example_daily/` comes from cd's own daily cube (`data-raw/example_daily.R`), 2002, so true. `inst/vignette-data/` holds 3 rds files of series and tables (no geometry) and 3 tifs of departures and normals from cd's catalog, so true. The OGL-BC paragraph: FWA Watershed Groups, Lakes, Rivers and Stream Network and the Ecoregion Ecosystem Classification are all "Open Government Licence - British Columbia" in the BC Data Catalogue API, so true for those layers. The `bc` outline in context_northern_bc.gpkg is a union of FWA watershed groups, so it is covered. The attribution sentence is the OGL-BC wording. The one exception is the finding above. Towns and highways are cd#151 (accepted).

## Claims enumerated (verdict)

README.md
- Tagline: same text as the GitHub About (`gh repo view`) and consistent with the DESCRIPTION Title. True.
- Opening, "air temperature, precipitation, humidity, soil moisture and snow, by season and year since 1950 … whatever reference period … the trend and how much it has moved": true (variables registry, `cd_baseline(baseline_years=)`, `cd_trend`, Total Change).
- "public catalog that needs no account": true (anonymous https S3).
- "daily air temperature at any point in the province": true (`cd_extract_daily`, cube on the 121 × 261 BC grid).
- "baseline and trend steps take any annual series, such as streamflow or stream temperature": true (`?cd_anomaly` contract; wet feeds them).
- Figure: alt text and caption match the image (1950–2025 bars; red `>= 0`, blue below; dashed trend from about −0.35 to about 1.53 ≈ 1.9; trend since 1951 = `trend_start = 1951`). The opaque white background comes from `png(bg = "white")`. Made by the committed `data-raw/readme_figure.R`. True.
- Install: pak line, a pin placeholder, and a NEWS link (200). "Also needs sf, Kendall and zyp": true. `cd_trend` calls `check_installed(c("Kendall","zyp"))` and the example calls `sf::st_read`. Nothing else in the example needs a Suggests package.
- Example: signatures match (`cd_extract(catalog, aoi, variables, periods)`, `cd_baseline(x, baseline_years)`, `cd_anomaly(x, baseline)`, `cd_trend(x, trend_start)`, `cd_summary(trend)`). The code is identical to the script block. The output was accepted.
- "Files are cached … downloaded again only when they are republished": true (see fix 1).
- "Extracted rows record which commit of cd built each file": true (`cd_sha` from the file's `CD_SHA` tag).
- Learn more: the three titles match `vignettes/*.Rmd` titles, the URLs answer 200, and the descriptions are consistent with the vignettes. True.
- Ecosystem: wet's role is word-for-word as in wet's README and About. cd's row matches wet's README row for cd. "cd computes the departures from wet's yearly station values" is the same sentence wet's README uses. True.
- Data and methods: ERA5-Land by ECMWF for C3S, read from EDH, is true of the producer. CC BY 4.0 and "modified Copernicus … information" are true. Mann-Kendall / Theil-Sen via Kendall and zyp is true. The bc_climate_anomaly sentence is true (fix 3).
- Citation `citation("cd")`: works. The NGE role gap was accepted.
- License: MIT © NGE, and the LICENSE.md and NOTICE.md links exist. The ERA5-Land CC BY 4.0 line is true. example_climate.tif is cd#151, accepted.

NOTICE.md
- ERA5-Land licence, attribution wording and Muñoz-Sabater 2021 reference (ESSD 13, 4349–4383; the DOI resolves): true.
- "reads from EDH, aggregates and derives (…), publishes to s3://stac-era5-land": true of the published data.
- Redistributed data: see fix 4 and the finding.

DESCRIPTION / man/cd-package.Rd
- Title and Description: each clause is true. The Rd matches DESCRIPTION.

_pkgdown.yml
- All 25 NAMESPACE exports are indexed, each exactly once (the `starts_with("cd_cache_")` selector covers 4).
- "Read the data", "Departures and trends", Cache, Publishing and CDS descriptions: true (above).

Workflows
- `pkgdown.yaml`: "NOTICE" added to the allowlist. Correct, since NOTICE.md renders to NOTICE.html.
- `update-citation-cff.yaml`: `authors_roles = c("aut","cre","cph")` is what readme.md §9 prescribes.

data-raw/readme_figure.R
- Loads the checkout (`load_all`). `system.file()` resolves to the source inst/ under pkgload, and the PNG is opaque. No defects.

## Triage (session)

Finding confirmed (`data-raw/example_aoi_fwcp_peace.R:3,12` reads a local geojson); it sits inside round 1's fix 4, so the loop now ends only on an enumeration. Fix: NOTICE names each OGL file instead of a glob; `example_aoi_fwcp_peace.gpkg` added to #151.

### Enumeration: every bundled data file (18) against NOTICE

| File | Source (data-raw) | Licence | In NOTICE |
|---|---|---|---|
| extdata/context_fwcp_peace.gpkg | FWA lakes/rivers/streams/wsgs, ecoregions (OGL); towns GNS, highways DRA (Access Only) | OGL + #151 | yes, minus towns/highways |
| extdata/context_kootenay_lake.gpkg | same layers | OGL + #151 | yes, minus towns/highways |
| extdata/context_northern_bc.gpkg | FWA rivers/lakes, `bc` = union of FWA wsgs; towns GNS | OGL + #151 | yes, minus towns |
| extdata/example_aoi_fwcp_peace.gpkg | local FWCP boundary geojson | unknown | no — #151 |
| extdata/example_aoi_kootenay_lake.gpkg | bcdata FWA watershed groups | OGL | yes |
| extdata/example_aoi_kotl.gpkg | bcdata 51f20b1a (FWA watershed groups) | OGL | yes |
| extdata/example_aoi_northern_bc.gpkg | FWA watershed groups + stream network (fwapg) | OGL | yes |
| extdata/example_aoi.gpkg | hand-made bbox | none (own) | n/a |
| extdata/example_catalog.json | STAC metadata for example_climate.tif | none (own) | n/a |
| extdata/example_climate.tif | bc_climate_anomaly NetCDF | unknown | no — #151 |
| extdata/example_daily/{tmean,tmax,tmin}_daily_2002.tif (3) | cd daily cube (ERA5-Land) | CC BY 4.0 | yes |
| extdata/peace_wsg_ecoregion_commentary.csv | overlap % computed from bundled wsgs × ecoregions, plus authored text | own, derived from OGL | covered by OGL statement |
| vignette-data/*.tif (3) | cd catalog (ERA5-Land) | CC BY 4.0 | yes |
| vignette-data/*.rds (3) | cd extracts (ERA5-Land) + AOI names/areas from FWA/ecoregions | CC BY 4.0 + OGL | yes |

Every file is either named in NOTICE under a verified licence, own work, or in #151. Nothing listed in NOTICE carries data outside its stated licence.
