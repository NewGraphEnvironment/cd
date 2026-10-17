# Code-check round 3: branch 142-readme-add-daily-point-temperatures-and (vs main @ 59a5122)

The reviewer read README.md, NOTICE.md, DESCRIPTION, _pkgdown.yml, data-raw/readme_figure.R, the diffs to man/cd-package.Rd and both workflows, and viewed the figure. Every gpkg was inspected from a copy in the scratchpad (layers, columns and row counts via sqlite3). Each bundled file was traced to its `data-raw/` script. The vignette rds files were read with readRDS. The live daily cube was read over /vsicurl/ into a scratch R session. Nothing in the repo was written except this file.

## Mechanism

All five earlier findings share one assumption: **a label or a category (a glob, a group heading, a familiar member) was taken to stand for its members, and nothing checked the members.** "downloaded once" described the usual cache path. A "Building the published data" heading took in a function the pipeline never calls. "cd's variables" was written from the core seven. A NOTICE line about "cd's ERA5-Land product" took in a file from another source. `example_aoi_*.gpkg` matched by name and not by content.

Round 2's fix applied the same assumption one level down. It treated **the FWCP boundary as one file**, `example_aoi_fwcp_peace.gpkg`, and moved that file to #151. But the boundary is also geometry, and geometry flows into whatever is clipped or masked by it. The enumeration table follows each file's *source tables*, not the *geometry operations* applied to them. So any file whose content was cut by a boundary of a different licence is labelled with its source tables' licence alone.

## Findings

- **[false-claim, low] `NOTICE.md:21`**: "`inst/extdata/context_fwcp_peace.gpkg` … (every layer except `towns` and `highways`)" under OGL-BC. In that file, `rivers`, `streams` and `ecoregions` are **clipped to the FWCP Peace boundary**, the very boundary round 2 moved to #151 as of unknown licence:
  - `data-raw/example_context_fwcp_peace.R:19` reads `example_aoi_fwcp_peace.gpkg`.
  - `:62-70` builds rivers as `ST_Intersection(geom, <FWCP union>)`.
  - `:76-82` builds streams the same way.
  - `:130-131` builds ecoregions as `st_intersection(ecoregions_bc, aoi_3005)`, and `area_km2` is the clipped area.

  The outer edges of those three layers *are* the FWCP boundary, so the file redistributes it inside layers NOTICE labels OGL-BC. `lakes` (bbox `ST_Intersects`, not clipped) and `wsgs` (selected by a code list, not clipped) are pure FWA. Downstream of the clipped ecoregions are `inst/extdata/peace_wsg_ecoregion_commentary.csv` (`data-raw/peace_wsg_ecoregion_commentary.R:23,32` intersects with that layer) and `inst/vignette-data/peace_fwcp.rds`. The boundary also reaches `inst/vignette-data/peace_fwcp_departure_tmean.tif`, which NOTICE lists only as modified ERA5-Land: it is `terra::mask(departure, aoi)` with `aoi` = the FWCP boundary (`data-raw/peace_fwcp_vignette_data.R:30-31,137`). #151 names only `example_aoi_fwcp_peace.gpkg`.

  Suggested fix: in NOTICE, list `context_fwcp_peace.gpkg` as `lakes` and `wsgs` only, or add "clipped to the FWCP Peace boundary (see #151)". Extend #151's FWCP bullet to the files that carry the boundary: the clipped layers in `context_fwcp_peace.gpkg`, the masked `peace_fwcp_departure_tmean.tif`, and the derived `peace_wsg_ecoregion_commentary.csv` and `peace_fwcp.rds`.

- **[false-claim, low] `planning/active/review-round2.md` enumeration, and `NOTICE.md:16-22` coverage.** The table closes with "Every file is either named in NOTICE under a verified licence, own work, or in #151". Three rows contradict it:
  - `peace_wsg_ecoregion_commentary.csv` reads "covered by OGL statement", but NOTICE's OGL list does not name it.
  - `vignette-data/*.rds` reads "CC BY 4.0 + OGL / yes", but NOTICE names `inst/vignette-data/` only under ERA5-Land. `kootenay_lake.rds$wsg_eco_overlap` and the ecoregion `area_km2` values are computed from FWA and ecoregion geometry.
  - `vignette-data/*.tif` reads CC BY only, but each is masked to an AOI. Two of those AOIs are FWA-derived (OGL) and one is FWCP (above).

  So NOTICE's "in:" lists omit OGL-derived content in the csv and in vignette-data. The closing OGL attribution sentence is present, so the practical gap is small. The table header's "(18)" is also wrong: its rows cover 20 data files (21 under `inst/` with `inst/CITATION`). All 20 have a row, so the population is complete.

No other defects.

## Where the mechanism reaches, checked place by place

| Place | Claim about a set | Members checked | Verdict |
|---|---|---|---|
| NOTICE:3 | "cd's climate data are derived from ERA5-Land" | example_climate.tif is not | accepted (#151) |
| NOTICE:9 | derived variables list | registry: means/totals, vpd, rh, soil, snow metrics, daily | true |
| NOTICE:13 | example_daily/ = ERA5-Land daily 2002 | 3 tifs, `data-raw/example_daily.R` | true |
| NOTICE:14 | vignette-data = modified ERA5-Land | 3 tif (cd_crop of the catalog), 3 rds (no sf geometry; all classes read) | true, but they also carry OGL/FWCP-derived content (finding 2) |
| NOTICE:20 | 3 example_aoi files = watershed groups and watersheds | kootenay_lake = union of 4 FWA WSGs; kotl = FWA WSG (bcdc 51f20b1a); northern_bc = 3 WSGs + 2 Bulkley parts (FWA watershed at measure) | true |
| NOTICE:21 | context_* every layer except towns/highways | kootenay_lake: clipped by the FWA AOI, so OGL; northern_bc: rivers, lakes, `bc` from FWA; fwcp_peace: rivers/streams/ecoregions clipped by FWCP | **false for fwcp_peace** (finding 1) |
| README:9 | "air temperature, precipitation, humidity, soil moisture and snow … since 1950" | 15 variables; one contiguous span | true |
| README:9 | "daily air temperature at any point in the province" | live cube 2002 band 1, 20,000 random points in FWA-BC: 220 fall in no-data cells, 9 have no data in the 3×3 window (0.045%); `cd_extract_daily` documents the fallback and the NA warning | true in substance |
| README:9 / DESCRIPTION | baseline and trend steps take any annual series | `?cd_anomaly` contract | true |
| README:46 | "Files are cached after the first read" | `cd_extract(cache = TRUE)` and `cd_extract_daily(cache = TRUE)` defaults; `cd_cache_fetch` ETag | true |
| README:46 | "Extracted rows record which commit … built each file" | `cd_sha` from the file's `CD_SHA` tag in both extractors | true |
| README:73 | Mann-Kendall / Theil-Sen from Kendall and zyp | `R/cd_trend.R:74-75` | true |
| README:73 | core variables follow bc_climate_anomaly | R2 verified | true |
| README:81 | "The ERA5-Land data it ships and publishes are CC BY 4.0" | ERA5-derived files only | true |
| README fig/caption/alt | 1950–2025, red warmer / blue cooler, trend since 1951, ~1.9 | PNG viewed; slope 0.025 × 75 years | true |
| _pkgdown "Read the data" | series for an area, or daily at points | 5 functions | true |
| _pkgdown "Departures and trends" | "These take any annual series in cd's long format" | cd_summary takes a trend table, cd_anomaly takes a series plus a baseline | true as a chain reading; not flagged |
| _pkgdown Cache | revalidation wording | R2 verified | true |
| _pkgdown Publishing | the scheduled workflow uses these | cd_aggregate and cd_cog_write in stage3 and update; cd_stac_catalog; cd_s3_push (also pushes the daily cube via `_publish.R:274`) | true |
| _pkgdown CDS | not how the catalog is built | not called in scripts/ | true |
| DESCRIPTION / Rd | each clause | as above | true; the Rd matches |
| pkgdown.yaml allowlist | adds NOTICE | NOTICE.md renders to NOTICE.html | correct |
| update-citation-cff | `authors_roles =` | cffr 1.4.2 has the argument; the workflow installs current cffr | correct |
| Pin advice | `@vX.Y.Z` | tags are `v0.6.x` | true |

## Triage (session)

Both findings confirmed against `data-raw/example_context_fwcp_peace.R` and `peace_fwcp_vignette_data.R`. The per-file NOTICE kept gaining qualifiers (convention: consider dropping the claim), so NOTICE now makes no per-file claims: it names each **source** with its licence, and points unresolved ones to #151. #151's FWCP bullet widened to every file clipped or masked to the boundary.

### Terminal enumeration: every external source read by `data-raw/` (7)

From a grep of every `bcdc_query_geodata()`, `FROM <schema.table>`, `st_read()`, `rast()`, `cd_catalog()`/`cd_extract*()` call in `data-raw/example_*.R`, `*_vignette_data.R` and `peace_wsg_ecoregion_commentary.R` (the vignette and commentary scripts read only cd and the bundled gpkgs):

| Source | Read by | NOTICE row |
|---|---|---|
| ERA5-Land (cd catalog, daily cube) | example_daily, *_vignette_data | CC BY 4.0 |
| FWA wsgs/lakes/rivers/streams (bcdata, fwapg) | example_aoi_*, example_context_* | OGL-BC |
| Ecoregions `d00389e0` | example_context_fwcp_peace, _kootenay_lake | OGL-BC |
| GNS geographical names | example_context_* | #151 |
| DRA `transport_line` | example_context_fwcp_peace, _kootenay_lake | #151 |
| FWCP boundary (local geojson) | example_aoi_fwcp_peace (+ files clipped/masked to it) | #151 |
| bc_climate_anomaly NetCDF | example_climate_tmean | #151 |

7 of 7 sources have a NOTICE row. `example_aoi.gpkg` and `example_catalog.json` are hand-made. Loop ends on this enumeration.
