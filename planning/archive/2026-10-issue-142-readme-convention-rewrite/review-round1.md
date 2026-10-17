# Code-check round 1: branch 142-readme-add-daily-point-temperatures-and (vs main @ 59a5122)

Reviewer read every changed file in full, the readme.md and writing.md conventions, the R sources behind each claim, the live catalog and daily manifest, live COG tags, wet's origin/main, bcgov/bc_climate_anomaly. Built the pkgdown home and ran `pkgdown::check_pkgdown()` on a `git archive HEAD` copy in the scratchpad (no problems found; NOTICE.html built; README links rewritten to LICENSE.html / NOTICE.html; no unexpected root pages). Every external link in README.md and NOTICE.md answers 200.

Disclosure: one `gdalinfo -stats` on `inst/extdata/example_climate.tif` wrote an `.aux.xml` sidecar into the repo. It was deleted right away, and `git status` showed the tree clean afterwards. Nothing else in the repo was touched.

## Findings

- **[false-claim, low]** `_pkgdown.yml:46-47` (Cache section): "Each file is downloaded once and read locally after that." `cd_cache_fetch()` revalidates with a HEAD on every call and downloads again when the ETag changes, so a republished file is downloaded again. The README says the opposite, correctly: "downloaded again only when they are republished". Two published texts disagree, and the pkgdown one is wrong. Fix: e.g. "Each file is downloaded once, and again only when it is republished."

- **[false-claim, low]** `_pkgdown.yml:48-56` ("Building the published data": "The catalog is built and published by a scheduled workflow; users do not need these"). The section lists `cd_fetch()` and `cd_derive()`, and neither is called anywhere in `scripts/`. They are the CDS-based fallback: `cd_fetch` downloads from the Copernicus CDS, and `cd_derive` builds tmax/tmin by its own route, not the local-day route the published layers use. CLAUDE.md says they ship "for users who want a CDS-based fallback, but are not what runs in CI". Under this heading they read as part of what builds the published data, which they are not. Fix: either give them their own line ("an alternative CDS route; not used for the published catalog"), or move them out of the section. `cd_aggregate`, `cd_cog_write`, `cd_stac_catalog` and `cd_s3_push` are used by `pipeline_*_edh.R`, so the claim holds for those.

- **[false-claim, low]** `README.md:84` "cd's variables and its ecoregion and watershed framing follow bcgov/bc_climate_anomaly". cd has 15 variables, and 8 of them are snow (swe, snowfall, snowmelt, snow_cover, swe_max, snowfall_fraction, snowmelt_doy_50, snowmelt_rate_peak). bc_climate_anomaly's `app.R` has no snow variable: "snow"/"swe" match 0 times, while tmean, tmax, tmin, prcp, vpd, rh and soil all appear. The quantifier covers the whole set, and only the 7 core variables follow it. Fix: "cd's core climate variables …" (or "its temperature, precipitation, humidity and soil-moisture variables").

- **[fragile / convention gap, low]** `README.md:88` "Cite cd with `citation("cd")`", together with the `update-citation-cff.yaml` change (commit cfe7745, "NGE as a citation author"). `citation("cd")` reads `inst/CITATION`, whose `author =` keeps only `"aut"` roles. Rendered from this branch's DESCRIPTION it gives "Irvine A (2026). _cd: …_. New Graph Environment Ltd." with NGE only as `organization`, not as an author. After the workflow runs, CITATION.cff will list NGE as an author. The README points readers to the citation that leaves NGE out, which readme.md §9 requires ("Citation from CITATION.cff, with New Graph Environment Ltd. as an author"). link's inst/CITATION is identical, so this is a fleet pattern, not something this branch introduced. Either add `"cph"` to the inst/CITATION filter, or accept it and say so.

- **[licence gap, low; pre-existing, partly outside #142's NOTICE task]** `NOTICE.md`. The README's License line ("see NOTICE") makes NOTICE the place for third-party data terms, but NOTICE covers only ERA5-Land. Two other gaps:
  (a) The package also ships BC government data: FWA watershed groups in `inst/extdata/example_aoi_*.gpkg`, and ecoregions, lakes, rivers, highways, towns and the BC outline in `inst/extdata/context_*.gpkg` (from fwapg and the BC WFS via bcdata, per `data-raw/example_aoi_*.R` and `example_context_*.R`). That data is under the Open Government Licence – British Columbia, which requires an attribution statement, and none is given anywhere.
  (b) `inst/extdata/example_climate.tif` is not output of cd's EDH pipeline, which is what NOTICE's paragraph implies. `data-raw/example_climate_tmean.R` crops it from bc_climate_anomaly's `tmean_ano_annual_1950_+_res25.nc`, the Province's processing of CDS ERA5-Land at 0.25° (the file's pixel size is 0.25). bc_climate_anomaly has no licence file (GitHub reports `license: null`). Calling it "modified ERA5-Land data, under CC BY 4.0" is defensible as to the ultimate source, but the Province's intermediate product is not credited. The old README's acknowledgement credited it; the new one credits only the variable framing.
  Neither gap makes a sentence in the diff false. Both are real attribution gaps in the file this branch introduces for that purpose.

## Claims checked (verdict)

README.md
1. Tagline "Climate departure for BC: how far the climate of any area has moved from any baseline, from ERA5-Land": true. It matches the GitHub About exactly (`gh repo view`), and the DESCRIPTION Title is consistent with it.
2. "air temperature, precipitation, humidity, soil moisture and snow, by season and year since 1950": true. The live catalog has 59 items: 11 variables × {annual, winter, spring, summer, fall} plus 4 annual-only, and every item starts 1950-01-01.
3. "compared with whatever reference period you choose, with the trend and how much it has moved": true (`cd_baseline(baseline_years=)`, `cd_trend`, `cd_summary` Total Change).
4. "public catalog that needs no account": true. `cd_catalog_default()` is the public https S3 URL, and the catalog fetched anonymously.
5. "daily air temperature at any point in the province": true. The cube covers 47.95–60.05 N, 140.05–113.95 W, and the manifest lists 228 files, 1950–2025. Coastal no-data cells move to a neighbour, as documented.
6. "baseline and trend steps take any annual series, such as streamflow or stream temperature": true (`?cd_anomaly` input contract; wet's `wet_window_stats`/`wet_temp_gsdd` feed them).
7. Figure alt "1950 to 2025 … dashed trend line rising about 1.9 degrees": true. The image shows 1950–2025 bars and a dashed line from about −0.35 to about 1.53. The first trend line is dashed (`cd_plot_timeseries`).
8. Caption "Red years were warmer, blue cooler; dashed line is the trend since 1951": true. The fill is `>= 0` → `#d73027`, else `#4575b4`, and `trend_start = 1951`.
9. "The example below also needs sf, Kendall and zyp": true. Only `cd_trend` calls `check_installed(c("Kendall","zyp"))`, sf is needed for `st_read`, and the example does not plot.
10. Pin `@vX.Y.Z`: tags of that form exist (v0.6.12 latest).
11. "This is the run behind the figure above": true. Same code as `data-raw/readme_figure.R` (accepted).
12. Pasted output (Mean temperature, Annual, 0.025, 75, 1.9, °C, 0): consistent with `cd_summary()` (75 = 1951–2025; Total Change = round(slope × n, 1); long_name). Output accepted as a real run.
13. "Files are cached after the first read and downloaded again only when they are republished": true for `cd_extract` (default `cache = TRUE`, ETag revalidation).
14. "Extracted rows record which commit of cd built each file": true. `cd_sha` is read from the file's `CD_SHA` tag, and the live `tmean_annual.tif` and `daily/tmean_daily_1950.tif` both carry `CD_SHA`. All 59 catalog items carry `processing:software.cd`.
15. Learn-more titles and URLs: they match the three `vignettes/*.Rmd` titles and all answer 200. The one-line descriptions are consistent with CLAUDE.md.
16. Ecosystem: wet's role matches wet's About verbatim. "cd computes the departures from wet's yearly station values": true (wet docs and vignette call `cd::cd_baseline/anomaly/trend`).
17. ERA5-Land, ECMWF for C3S, read from EDH: true (producer). The CC BY 4.0 licence is confirmed on the CDS catalogue API (`license: CC-BY-4.0`). The Muñoz-Sabater 2021 DOI resolves.
18. "Mann-Kendall tests with Theil-Sen slopes, from Kendall and zyp": true (`Kendall::MannKendall`, `zyp::zyp.sen`).
19. "cd's variables … follow bc_climate_anomaly": partly false (finding 3). "Shiny app by the Province … (Aseem Sharma and contributors)": consistent (its sole contributor is aseemsharma1, and the app's watermark names the BC Ministry of Forests).
20. Citation via `citation("cd")`: works, but leaves NGE out as an author (finding 4).
21. License "MIT © NGE … ERA5-Land data it ships and publishes are CC BY 4.0": true as far as it goes (finding 5 covers the non-ERA5 data).

NOTICE.md
22. CC BY 4.0 and the "Contains modified Copernicus Climate Change Service information" wording: true.
23. ERA5-Land reference (ESSD 13, 4349–4383): correct.
24. "reads from EDH, aggregates and derives (seasonal and annual means and totals, VPD, RH, soil moisture, snow metrics, daily local-day air temperature), publishes to s3://stac-era5-land": true for the published data. Not how `example_climate.tif` was made (finding 5b).
25. Redistributed-file list: all three paths exist and are ERA5-Land-derived. No other ERA5-derived data file is tracked (git ls-files). The README figure is derived output, not data.

DESCRIPTION / man/cd-package.Rd
26. Title and Description: each clause is true (STAC of COGs, daily at points, any annual series, "Includes the functions that build and publish the catalog" = `cd_cog_write`/`cd_stac_catalog`/`cd_s3_push`/`cd_aggregate`, used by the pipelines). The Rd matches DESCRIPTION.

_pkgdown.yml
27. All 25 exports are indexed, and `check_pkgdown()` finds no problems.
28. "Climate series for an area, or daily air temperature at points": true.
29. Departures desc: true.
30. Cache desc: false (finding 1).
31. Building desc: misleading for cd_fetch/cd_derive (finding 2).

Workflows
32. `pkgdown.yaml` allowlist + NOTICE: correct. pkgdown renders NOTICE.html, and the guard strips both extensions.
33. `update-citation-cff.yaml` `authors_roles = c("aut","cre","cph")`: cffr 1.4.2 accepts it. Tested on a copy of DESCRIPTION, it yields Irvine plus `name: New Graph Environment Ltd.`, and the title updates.

data-raw/readme_figure.R
34. Runs from the checkout (`load_all`), opaque white png, and the example block is identical to the README. No defects. The top-level `cd_summary(trn)` autoprints and the table is then printed again, which is harmless.

## Triage (session)

| Finding | Disposition |
|---|---|
| pkgdown Cache desc "downloaded once" | Fixed: same wording as README |
| `cd_fetch`/`cd_derive` under "Building the published data" | Confirmed (only a comment in `backfill_edh_all.py:207` names `cd_derive`); split into "Publishing the catalog" and "Downloading from the Copernicus Climate Data Store" |
| "cd's variables follow bc_climate_anomaly" | Fixed: "core climate variables" |
| `citation("cd")` lists NGE as organization, CFF as author | Accepted: `inst/CITATION` pattern shared with link; cross-repo rule in soul#426 territory |
| NOTICE: example_climate.tif not cd's ERA5-Land; BC data unattributed | Fixed: example_climate.tif removed from the ERA5-Land list; FWA + ecoregions attributed under OGL-BC (licences read from the BC Data Catalogue API). GNS towns and DRA highways are "Access Only", and bc_climate_anomaly has no licence: filed #151 |
