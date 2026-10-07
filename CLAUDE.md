# cd — Climate Departure

R package for climate departure analysis from ERA5-Land reanalysis data. Computes anomalies for custom areas of interest with flexible baselines and trend statistics.

## Fork / Upstream Status

- **Origin:** `NewGraphEnvironment/cd` (public — verify with `gh repo view --json isPrivate` before trusting this line)
- **No upstream** — this is an original package
- **SRED:** `NewGraphEnvironment/sred-2025-2026#23`

## Repository Context

**Primary Language:** R (consumer-side) + Python (producer-side, EDH backfillers)
**Framework:** R package (devtools, testthat 3e, pkgdown)
**Spatial:** `terra`, `sf`
**Data:** ERA5-Land via [DestinE Earth Data Hub (Zarr)](https://earthdatahub.destine.eu/), served as COGs on S3 via STAC
**S3 Bucket:** `stac-era5-land` (us-west-2)
**pkgdown:** `newgraphenvironment.com/cd/`

## Architecture

**Producer** (GitHub Action, monthly): Python backfillers fetch hourly Zarr from EDH, aggregate, derive (VPD/RH/soil); R stage 3 writes COGs and pushes the STAC catalog:
`scripts/backfill_edh_*.py` → `scripts/pipeline_stage3_edh.R` → `scripts/pipeline_update_edh.R` (the GH Action's monthly entry point) → `cd_cog_write()` → `cd_stac_catalog()` → `cd_s3_push()`

The cron is monthly but the **unit of publication is a whole calendar year** — both backfillers write only when a year has all 12 months, and `pipeline_update_edh.R` derives its target from the band names of all 59 live COGs (#119). With ERA5-Land's 2-3 month latency that means the catalog advances roughly once a year, and the other ~11 monthly runs correctly do nothing. They are not free, though: `.compute()` precedes the 12-month check, so each one fetches and discards a partial year (#84).

**A publish is all 59 COGs or nothing (#89).** `cd_stac_catalog()` lists only the directory it is given, and the push replaces the live `catalog.json` outright, so a COG the run skipped would drop out of the catalog while its `.tif` stayed on S3, present and unreachable. Both pipelines therefore run `publish_problems()` (`scripts/_lib.R`) before building the catalog: every expected COG written this run and on disk, nothing else in the directory, one contiguous span of years covering the live ones. They also run `catalog_problems()` on the catalog just written. `pipeline_update_edh.R` runs `catalog_problems()` on the live catalog in STEP 1 as well, since an incremental run cannot repair a live catalog that is not the full set: that takes stage 3. **The sync itself is not atomic (#119)**: one that dies partway leaves some COGs a year ahead, and the catalog behind with the rest, since `cd_s3_push()` aborts before it goes up. So STEP 1 reads the band names of all 59 live COGs (~40 s), not `tmean_annual`'s alone, and `live_spans()` targets the years every COG holds. STEP 4 then appends to each COG only the years it lacks, so the next run repairs the partial sync. Each publish then re-reads all 59 (bypassing GDAL's `/vsicurl/` cache, which would otherwise return STEP 1's view), and a live run exits 1 until that read-back shows the repair. The dry run only warns. The workflow's `concurrency` group keeps a second run from reading a sync still in progress as a dead one. `catalog.json` is written outside the COG directory and uploaded on its own with `aws s3 cp`, after the COG sync, then read back. The sync is `--size-only`, and a healthy update changes the catalog only from end year 2025 to 2026, the same byte count, so the sync would have skipped it.

**Second product: the daily air-temperature cube (#116).** `scripts/backfill_edh_daily.py` turns the same hourly `t2m` into local-day (fixed UTC−8) tmean/tmax/tmin and writes the published COGs itself (`write_cog()` in `_lib.py`, 16 px pixel-interleaved tiles so a point read fetches one ~125 KB tile) to `data/backfill/daily/{var}_daily_{YYYY}.tif`, 365/366 bands named `YYYY-MM-DD`. They publish to `s3://stac-era5-land/daily/` via `cd_s3_push(dir, prefix = "daily")` and are **not in `catalog.json`** — `cd_stac_catalog()` lists non-recursively — so `cd_catalog()`/`cd_extract()` never see them. `pipeline_update_edh.R` STEP D extends the cube on its own clock, before the annual path's early exits: a local year needs the first 8 hours of the next UTC year. Since #37 the annual path waits for the same hour, because the monthly tmax/tmin use the same local days, so the cube and the annual COGs advance together, about a month after the year's last UTC month lands. STEP 2 caps its candidate years at STEP D's probe (`latest_local`) and fetches nothing when that probe fails. Before fetching, it also confirms the live tmax/tmin history is local-day: each of the 10 keys must differ from its UTC-day twin under `_backup/tmax_tmin_utc_day/`, written by `scripts/tmax_tmin_republish.R`. Without that it exits 1 rather than append local-day years onto UTC-day history. Deleting that prefix blocks CI on purpose: it is the record. A daily failure lets the annual path run, then exits non-zero via `finish()`. The STEP D probe treats a missing year as an error only when none of the last four years is published — a never-built cube is a local 2-hour backfill, not a CI job. Why a cube rather than reading the Zarr: one point × 20 years took 201 s through xarray (chunks `[2880 h, 64, 64]`, so a point costs its whole tile), and terra/GDAL 3.13 is slower still — 39 s for 48 hours of one point. GDAL 3.8.5 (the one sf links) cannot read the store at all: it refuses the `bitround` filter. Measured 2026-10-06, `planning/archive/*issue-116*`. `cd_s3_push()` syncs `--size-only`, so a rebuilt year whose byte size happens not to change is not re-uploaded.

The historical `cd_fetch()` / `cd_derive()` R-side producer functions still ship (with tests) for users who want a CDS-based fallback, but are not what runs in CI. See v0.1.0 / #36 for the migration history.

**Consumer** (user-facing, local R):
`cd_catalog()` → `cd_crop()` → `cd_extract()` → `cd_baseline()` / `cd_anomaly()` / `cd_compare()` → `cd_trend()` → `cd_summary()`

**Key design decision:** Raw climate values on STAC (not pre-computed anomalies). All baseline/anomaly/trend computation consumer-side for maximum flexibility over reference periods and comparison windows.

**The consumer chain is not ERA5-only.** `cd_baseline()` → `cd_anomaly()` → `cd_trend()` → `cd_summary()` / `cd_compare()` take any series in the long format (`variable`, `period`, `year`, `value`, optional `anomaly_type`/`unit`/`long_name`) — other packages (wet's streamflow) target it. The contract lives in `?cd_anomaly`; the rules live in four helpers in `R/cd_anomaly.R` (`series_check`, `meta_resolve`, `meta_check`, `label_disambiguate`). Call them from any new consumer function rather than reading `cd_variables()` directly — per-function copies are what three review rounds kept finding broken (#92). Anything that labels several variables side by side (a table, facets) passes the labels through `label_disambiguate()`, which appends ` (variable)` to a `long_name` several stations share; `cd_summary()` and `cd_plot_comparison()` both do (#98). `cd_plot_timeseries()` does not — it plots one variable the caller chose, so the station belongs in its `title`.

**A trend table can mix scales.** Since #97 every `cd_trend()` row carries `trend_on` (`"value"` / `"anomaly"`), and `bind_rows(cd_trend(x), cd_trend(ano))` is a legal input. Any consumer of a trend table reads it with `col_or_na(trend, "trend_on")`: a missing or `NA` `trend_on` (hand-built tables, tables saved before 0.5.2) must not error. `cd_summary()` reads a missing `trend_on` as anomaly; `cd_plot_timeseries()` draws it on either scale (#103). A trend table can also hold several windows (`trend_start = c(1951, 1981)`); `cd_summary()` then adds a `Start` column, as it adds `Trend on` for mixed scales — both only when the table needs them, so single-window, single-scale tables keep their shape (#106). A trend table with no rows — every series under 3 years in its window — still carries every column, with key types as the input's, so consumers need no empty-table special case (#101).

## Function Prefix

All functions use `cd_*` prefix. Naming convention: `noun_verb` (e.g., `cd_cog_write` not `cd_write_cog`). Exceptions where a family should sort together: `cd_plot_*`, and `cd_extract_daily()` beside `cd_extract()` (chosen at the #116 plan gate).

## EDH (DestinE Earth Data Hub)

Producer pulls hourly ERA5-Land Zarr from EDH for the BC bbox (~48-60° N, 114-140° W) and aggregates to monthly / seasonal / annual on a single EPSG:4326 grid. Python only on the producer side (Zarr ecosystem maturity); R consumer-side reads the COGs over `/vsicurl/`.

Token lookup order: `EDH_TOKEN` env var, then `~/.Renviron`. Configured in CI via secret.

Key gotchas:
- Temperature in Kelvin (subtract 273.15)
- Precipitation in m/day (× 1000 × days_in_month → mm/month)
- Snow accumulation variables (`snowfall`, `snowmelt`) reset at 06:00 UTC each day — diff-and-clamp logic lives in `scripts/backfill_edh_snow.py` (#48)
- tmax/tmin use **local days** at a fixed UTC−8 (`LOCAL_OFFSET_H` in `_lib.py`), in both the daily cube (#116) and the monthly COGs (#37): no DST, and the MST corner of eastern BC is an hour off. tmean/vpd/rh/soil stay on UTC months. #37 predicted that UTC days bias tmax low; measured, they bias it **high**, by 0.5-0.8 °C. A UTC day runs 16:00-16:00 PST, from one afternoon peak to the next, so a hot afternoon counts twice. Local days lower tmin too (0.15-0.42 °C), since a midnight day holds two partial nights. Numbers: `research/tmax_tmin_day_boundary.md`
- EDH fails transiently mid-run — a truncated chunk (`aiohttp.ClientPayloadError`) or a `502` on one chunk, four times in the 76-year daily build. aiohttp's errors do not subclass `OSError`, so `with_retry()` names `aiohttp.ClientError` explicitly; a retry of a year-sized `.compute()` re-fetches the whole year. Store layout and read costs: `research/edh_era5_land_store.md`
- xarray keeps source attrs through `resample()` and arithmetic, and `rio.to_raster()` writes every attr as a file tag — reset `attrs` before writing, or a °C raster says `units=K` (#116, code-check round 1)

## Climate Variables (15 total since v0.2.0)

**Core climate (7):** all monthly natives, also seasonal + annual

| Variable | Units | Anomaly Type |
|----------|-------|--------------|
| tmean | °C | absolute |
| tmax | °C | absolute |
| tmin | °C | absolute |
| prcp | mm | pct_normal |
| vpd | hPa (Tetens-derived) | absolute |
| rh | % (temp+dewpoint-derived) | absolute |
| soil_moisture | m³/m³ (4-layer mean) | pct_normal |

**Snow monthly natives (4):** also seasonal + annual

| Variable | Units | Anomaly Type |
|----------|-------|--------------|
| swe | mm | pct_normal |
| snowfall | mm w.e. | pct_normal |
| snowmelt | mm w.e. | pct_normal |
| snow_cover | % | pct_point_diff |

**Snow annual derived (4):** annual only

| Variable | Units | Anomaly Type |
|----------|-------|--------------|
| swe_max | mm | pct_normal |
| snowfall_fraction | % | pct_point_diff |
| snowmelt_doy_50 | day-of-year | absolute |
| snowmelt_rate_peak | mm/day | absolute |

The `pct_point_diff` anomaly type is for already-percentage variables (treats anomaly as percentage-point difference, not relative percent).

## Season Definitions

Configurable via `cd_seasons()`. Default: standard meteorological (DJF, MAM, JJA, SON). Override for custom seasons (e.g., wet/dry, growing season).

## Development Workflow

1. Branch per issue (or group): `N-description` (use `/planning-init <N>`)
2. PWF baseline (task_plan.md / findings.md / progress.md) committed first
3. Build → test → `/code-check` → atomic commits with `Fixes #N` (each commit updates the matching task_plan checkbox)
4. PR (`/gh-pr-push`) — SRED tag (`Relates to NewGraphEnvironment/sred-2025-2026#23`) goes in the PR body, not on issues
5. Merge + release (`/gh-pr-merge`) — bumps DESCRIPTION + NEWS, tags, watches CI
6. Archive — `planning/active/` → `planning/archive/<YYYY-MM-issue-N-slug>/` with a one-paragraph README per directory

## Scripts (current)

**Producer (EDH):**
- `scripts/backfill_edh_all.py` — all 7 core climate variables (tmean, tmax, tmin, prcp, dewpoint→VPD/RH, soil moisture)
- `scripts/backfill_edh_tmax_tmin.py` — monthly tmax/tmin history from the local-day cube on disk (no EDH fetch); new years in CI come from `backfill_edh_all.py` by the same `local_daily()` → `monthly_from_daily()` chain (#37)
- `scripts/tmax_tmin_republish.R` — one-off republish of the 10 tmax/tmin COGs (#37): backs up the live ones to `s3://stac-era5-land/_backup/tmax_tmin_utc_day/` (never overwritten), uploads with `aws s3 cp` verified by ETag, leaves `catalog.json` alone
- `scripts/backfill_edh_snow.py` — 4 snow natives + 4 derived (#48); handles ECMWF accumulation reset
- `scripts/backfill_edh_daily.py` — daily local-day tmean/tmax/tmin cube (#116); `--check` prints `latest_complete=YYYY` for STEP D
- `scripts/test_lib.py` — offline tests for `_lib.py` (`uv run scripts/test_lib.py`); local only, no workflow runs it
- `scripts/_lib.py` — shared safeguards (single-instance pgrep guard, exponential backoff, atomic write, timestamped logging, EDH token loader)
- `scripts/pipeline_stage3_edh.R` — monthly TIFs → COGs + STAC + S3 push; refuses to build the catalog unless this run wrote all 59 COGs (and the COG dir holds nothing else), because a partial monthly dir (e.g. tmax/tmin only, after a regen) would otherwise replace the live catalog
- `scripts/pipeline_update_edh.R` — monthly GH Action entry point (incremental); the same all-59 guard before STEP 5 (#89)
- `scripts/qa_monthly.R` — month-end QA cross-check

**Misc:**
- `scripts/rag_snow_methodology_build.R` / `rag_snow_methodology_query.R` — ragnar lit review (#54)
- `scripts/rag_departure_framing_build.R` — ragnar store for departure framing
- Naming: `rag_<topic>_<verb>.R` (`noun_verb`, mirrors the `cd_*` function convention)
- `data-raw/make_hexsticker.R` — hex sticker (reads from DESCRIPTION)
- `data-raw/example_*.R` — bundled AOIs + context geodata for vignettes

## Vignettes

Two regional reporting vignettes in `vignettes/`:
- `peace-fwcp.Rmd` — FWCP Peace Region (~73,000 km², 16 WSGs across 5 ecoregions)
- `kootenay-lake.Rmd` — southern Kootenays (~24,200 km², 4 WSGs across 4 ecoregions; sharp east-west precip gradient)

Both share the same structure (Area of Interest → Trends → Snowpack → Spatial Pattern → Per-Ecoregion → WSGs Across Ecoregions → Interpretation). Heavy data is precomputed by `data-raw/<vignette>_vignette_data.R` into `inst/vignette-data/<vignette>.{rds,tif}` so pkgdown CI doesn't re-fetch from S3 on every render. ASWS QA cross-checks are in `data-raw/qa_snow_validation*.R` — run locally only, results land in `planning/archive/<issue>/`.

**Bibliography regen.** After adding or removing `[@key]` markers in either vignette, regenerate `vignettes/references.bib` from Zotero/BBT by running `Rscript data-raw/regenerate_bib.R`. Pulls source records via rbbt → BBT, writes the union of keys across both vignettes. Requires Zotero running with BBT enabled (BBT 9.x for Zotero 8/9). CI does not run this — the bib is committed and pkgdown reads the static file.

**Chunk pattern (v0.2.8).** Visible code in both vignettes is dominated by `cd::cd_*()` calls — the package showcase. Boilerplate (ggplot AOI maps, Spatial Pattern map, kableExtra wrappers, facet-plot recipes) is hidden via `echo = FALSE`. Heavy cd recipes (`cd_extract`, `cd_baseline + cd_anomaly + cd_trend + cd_summary`, `cd_compare`, per-ecoregion + per-WSG loops) are lifted into shown `eval = FALSE` companion chunks above the actual data-load chunks (named `<chunk>-recipe` shown / `<chunk>-load` or `<chunk>-table` or `<chunk>-reshape` hidden). Reader sees: cd recipe → output → narrative. Snow plot chunks (`snow-swe-max` etc) stay fully visible since they're already pure cd_*() calls. All cd function calls use `cd::` namespace prefix for explicit package attribution.

The two-vignette template is the foundation for additional regional reporting appendices (cf #47) — port directly to a `fish_passage_<region>_<year>` reporting context.

## Data Directories (gitignored)

- `data/backfill/` — overnight backfill working data
- `data/rag/` — ragnar DuckDB stores

## CI considerations

- `data-raw/*.R` runs **locally only** — never on CI. Outputs land in `inst/extdata/` or `inst/vignette-data/` and are committed.
- `bcsnowdata` (used by ASWS QA scripts) is GitHub-only — **never** add it to DESCRIPTION Suggests; pak can't resolve it on the pkgdown runner. Same for any other GitHub-only package.
- **CI cannot commit a gitignored path.** `logs/*.log` is ignored, so the old "commit the run log back to main" step in `climate-update.yml` staged nothing, skipped the commit, and only ever reached `git push` — which 403s during `git-receive-pack` ref advertisement even with nothing to push. Four months of red runs. Use `actions/upload-artifact@v4` for run output and keep the token `contents: read` (#78).
- **`setup-r-dependencies@v2` installs dependencies, not the package.** Any workflow running a `scripts/*.R` entry point that calls `library(cd)` needs `extra-packages: local::.`, or the script falls through to a `devtools::load_all()` that isn't installed on the runner (#78).
- **Probe credentials at the top of long jobs.** `pipeline_update_edh.R` STEP 0 checks EDH auth and round-trips an S3 sentinel object before any work, turning a stale `EDH_TOKEN` from a six-hour failure into a four-second one. `aws sts get-caller-identity` alone is not enough — it proves the keys parse, not that the bucket is writable. EDH's HTTP Basic auth needs `httpauth = 1L` on the curl handle; libcurl otherwise waits for a `WWW-Authenticate` challenge EDH never sends.
- **A single 403 from EDH at STEP 0 is not evidence of anything — re-dispatch before diagnosing.** Measured `2026-09-07`: the weekly dry-run died on `EDH rejected the token (HTTP 403)` at 12:00 UTC; a workflow_dispatch at 16:51 UTC, same secret and same commit, got **HTTP 200**. Transient. Before that re-run, two plausible causes had been argued from the log alone — an expired token (wrong: the standard key never expires and the classic key had seven months left) and free-tier quota exhaustion (wrong: quota resets on the 1st and would not clear mid-month). The probe makes this worse by collapsing every status >= 400 into one message, so 401, 403 and 404 are indistinguishable (#83) — and it has no retry, so one blip auto-files a failure issue. A dry-run costs about two minutes and one HEAD request; run it first.
- **A weekly dry-run cron is cheap insurance.** It proves the plumbing between monthly live runs *and* keeps the workflow active — GitHub auto-disables scheduled workflows after 60 days of repo inactivity, a silent failure no notification catches.
- **Close the auto-filed failure issue when the cause is fixed.** `climate-update.yml` dedups by label: it comments on *any* open issue tagged `climate-update-failure` and only opens a new one when none exists. A resolved-but-open thread therefore captures every future incident — a November failure lands as a comment on an August ticket describing a fixed cause, which reads as old news and gets skimmed. Deduping is the right design; it just assumes the thread is closed on resolution, and nothing enforces that. Caught in #79, which stayed open after #78 fixed its root cause.


<!-- BEGIN SOUL CONVENTIONS — DO NOT EDIT BELOW THIS LINE -->


# Cartography

## Style Registry

Use the `gq` package for all shared layer symbology. Never hardcode hex color values when a registry style exists.

```r
library(gq)
reg <- gq_reg_main()  # load once per script — 51+ layers
```

**Core pattern:** `reg$layers$lake`, `reg$layers$road`, `reg$layers$bec_zone`, etc.

### Translators

| Target | Simple layer | Classified layer |
|--------|-------------|-----------------|
| tmap | `gq_tmap_style(layer)` → `do.call(tm_polygons, ...)` | `gq_tmap_classes(layer)` → field, values, labels |
| mapgl | `gq_mapgl_style(layer)` → paint properties | `gq_mapgl_classes(layer)` → match expression |

### Custom styles

For project-specific layers not in the main registry, use a hand-curated CSV and merge:

```r
reg <- gq_reg_merge(gq_reg_main(), gq_reg_custom("path/to/custom.csv"))
```

Install: `pak::pak("NewGraphEnvironment/gq")`

## Map Targets

| Output | Tool | When |
|--------|------|------|
| PDF / print figures | `tmap` v4 | Bookdown PDF, static reports |
| Interactive HTML | `mapgl` (MapLibre GL) | Bookdown gitbook, memos, web pages |
| QGIS project | Native QML | Field work, Mergin Maps |

## Key Rules

- **`sf_use_s2(FALSE)`** at top of every mapping script
- **Compute area BEFORE simplify** in SQL
- **No map title** — title belongs in the report caption
- **Legend over least-important terrain** — swap legend and logo sides when it reduces AOI occlusion. No fixed convention for which side.
- **Four-corner rule** — legend, logo, scale bar, keymap each get their own corner. Never stack two in the same quadrant.
- **Bbox must match canvas aspect ratio** — compute the ratio from geographic extents and page dimensions. Mismatch causes white space bands.
- **Consistent element-to-frame spacing** — all inset elements should have visually equal margins from the frame edge
- **Map fills to frame** — basemap extends edge-to-edge, no dead bands. Use near-zero `inner.margins` and `outer.margins`.
- **Suppress auto-legends** — build manual ones from registry values
- **ALL CAPS labels appear larger** — use title case for legend labels (gq `gq_tmap_classes()` handles this automatically via `to_title()` fallback)

## Self-Review (after every render)

Read the PNG and check before showing anyone.

### Placement

1. Correct polygon/study area shown? (verify source data, not just the bbox)
2. Map fills the page? (no white/black bands)
3. Keymap inside frame with spacing from edge?
4. No element overlap? (each in its own corner)
5. Legend over least-important terrain?
6. Consistent spacing across all elements?
7. Scale bar breaks appropriate for extent?

### Does it communicate?

Every check above is about **where elements sit**. A map can satisfy all seven
and still fail to say what it is about — so these are not optional extras, they
are the half of the review that the placement list structurally cannot reach.

8. **Is every prominent feature in the legend?** Work the other direction from
   the usual one: rank what draws the eye *in the rendered image*, then confirm
   each of the top few appears in the legend. Building the legend from the layer
   list instead answers "did I list my layers", which is a different question and
   always says yes.
9. **Is the subject obvious to someone who has never seen this area?** An AOI
   that renders identically to its surroundings is not delineated by a thin
   boundary line — the reader has to be told where to look. Containment (a fill,
   a dimmed exterior, a mask) is what does it.
10. **Does the symbology have a hierarchy, or is it flat?** If one class holds
    the great majority of the features, it will dominate regardless of how
    correct its size is. Ask what the map is *for* and de-emphasise or filter
    accordingly — and say in the caption or prose that you did.
11. **Does the basemap earn its contrast cost?** A basemap that adds no readable
    terrain is not neutral: it lowers the contrast of everything drawn over it.
    Blend parameters that mute it into a flat field are worse than no basemap.
12. **Is the type sized for the width it is published at, not rendered at?** A
    7 in figure squeezed into a ~700 px column loses roughly 40% — text set at
    `size = 0.5` for the render lands at a few pixels on the page. Check the
    figure at its delivered width.

### Why this half exists

Added 2026-08-26 after gq's flagship vignette map was reported as passing all
seven placement checks and was, on being looked at, unreadable: 89% of its point
symbols were one modelled class, the basemap was a featureless grey field, the
AOI was indistinguishable from its surroundings, and the single most prominent
feature on the map — a bright red 397-feature habitat network — **was not in the
legend at all**, while the prose beneath the figure described its styling in
detail (gq#61).

The seven checks had returned green, accurately. They were simply not asking.

See the `cartography` skill for full reference: basemap blending, BC spatial data queries, label hierarchy, mapgl gotchas, and worked examples.

## Land Cover Change

Use [drift](https://github.com/NewGraphEnvironment/drift) and [flooded](https://github.com/NewGraphEnvironment/flooded) together for riparian land cover change analysis. flooded delineates floodplain extents from DEMs and stream networks; drift tracks what's changing inside them over time.

**Pipeline:**

```r
# 1. Delineate floodplain AOI (flooded)
valleys <- flooded::fl_valley_confine(dem, streams, area_field = "upstream_area_ha")

# 2. Fetch, classify, summarize (drift)
rasters   <- drift::dft_stac_fetch(aoi, source = "io-lulc", years = c(2017, 2020, 2023))
classified <- drift::dft_rast_classify(rasters, source = "io-lulc")
summary    <- drift::dft_rast_summarize(classified, unit = "ha")

# 3. Interactive map with layer toggle
drift::dft_map_interactive(classified, aoi = aoi)
```

- Class colors come from drift's shipped class tables (IO LULC, ESA WorldCover)
- For production COGs on S3, `dft_map_interactive()` serves tiles via titiler — set `options(drift.titiler_url = "...")`
- See the [drift vignette](https://www.newgraphenvironment.com/drift/articles/neexdzii-kwa.html) for a worked example (Neexdzii Kwa floodplain, 2017-2023)


# CI Monitoring

When this repo has GitHub Actions workflows, scan recent runs on session start. Catches failed pkgdown deploys, broken vignette builds, and stale citation regenerations that would otherwise linger until the user manually checks.

## On Session Start

```bash
gh run list --limit 5 --json status,conclusion,name,createdAt,databaseId \
  --jq '.[] | select(.conclusion == "failure")'
```

If any failures since the last visit, surface to the user before starting other work:

> Workflow `<name>` failed `<time>` ago (run `<id>`). Investigate with `gh run view <id> --log-failed`. Fix or proceed with current task?

User decides; do not auto-fix.

## Particular Failures Worth Naming

- **pkgdown** — docs site on GitHub Pages broken
- **R-CMD-check** — package may not install
- **Vignette / build-vignettes** — vignette docs incomplete
- **update-citation-cff** — CITATION.cff stale

## Why This Matters

Without this scan, post-merge workflow failures linger until someone (often the user) notices a stale docs site or a missing vignette. The session-start sweep catches them on the first re-entry into the repo.

## Pairs with `/gh-pr-merge`

The skill watches workflows triggered by a fresh merge in real time — that's the targeted catch. This convention is the backstop for failures that landed when no one was watching (merges via web UI, scheduled triggers, manually-triggered workflows).

## A green run does not mean the site is current

CI conclusion and published content are two different facts. Check the second one
directly when it matters — the deploy commit, not the run status:

```bash
git fetch -q origin gh-pages && git log -1 --format='%s' FETCH_HEAD
# "Deploying to gh-pages from @ owner/repo@<sha> 🚀"  <- is <sha> your HEAD?
```

GitHub can create a workflow run minutes after the push that triggered it, and
out of order with a later push. Observed 2026-08-26 in `fly`: `7a7700c` built and
deployed at 17:21, then its own *parent* `be77eca` had its run created at 17:22:52
— twelve minutes after that push — and deployed over it. Both runs green, `gh run
list` all success, published site one commit stale.

Things that do **not** fix this, so don't reach for them:

- `cancel-in-progress: true` — cancels an *overlapping* run. Here the runs never
  overlapped (`created == started` on both, second created after first finished),
  so there was nothing to cancel.
- A `concurrency:` group — the r-lib pkgdown template already sets one at the job
  level (`group: pkgdown-${{ github.event_name != 'pull_request' || github.run_id }}`).
  Grepping for a top-level `concurrency:` key misses it and invites a redundant
  "fix". Serializing runs doesn't order events that arrive late.

There is no workflow-side fix, because the reordering happens before the workflow
exists. The remedy is detection: check the deploy provenance, and re-dispatch
(`gh workflow run <file> --ref main`) if it's behind. Harmless when the stale
commit changed nothing the site publishes — confirm via `.Rbuildignore` / `_pkgdown.yml`
rather than assuming.

## Don't push to the default branch between a merge and its CI settling

The r-lib templates set `concurrency` with `cancel-in-progress: true`, so a second push
to `main` cancels the first push's still-running workflows. That is correct behaviour and
it is not the problem; the problem is that a **cancelled** run and a **failed** run look
the same in the status column, so a routine follow-up push turns a green merge into
something the next person has to go read a log about — and the log does not exist.

The routine follow-up is the one that bites, because it is the one nobody counts as a
push: a `CLAUDE.md` drift sync, a typo fix, a `.gitignore` line. `/compact-prep` step 6
runs `claude_md_drift.sh apply`, which **pushes**, and after `/gh-pr-merge` that lands
seconds after the merge.

Order them: watch the merge's runs to completion, *then* push anything else. Measured
2026-09-08 in gq — the merge's pkgdown and R-CMD-check were allowed to finish green and
the deploy provenance checked before the sync went out, and the sync's own runs then went
green on their own SHA. Holding it cost about three minutes.

Where a push has already gone out and cancelled something, `/gh-pr-merge` step 10 has the
reading: `cancelled`/`skipped` is `⊘ superseded`, not `✗ failed`, and the thing to confirm
is that the **newer** SHA's run passed. Do not re-dispatch the cancelled one.

## Don't use `gh run watch` to wait

It polls hard enough to trip GitHub's *secondary* rate limit, which `gh api
/rate_limit` does not report — every primary bucket reads full while calls return
403. Retrying extends it. Poll sparsely with `gh run view <id> --json status,conclusion`,
and prefer `git fetch` over the REST API for anything git can answer.

## A setup failure and a build failure look identical in the status column

`gh pr checks` and the Actions UI report one word per job. A run that died fetching its
own toolchain and a run that died because the code is broken both read `fail`, and only
the second says anything about what you just shipped.

```
Error in download.file(...) : status was 'SSL connect error'
download of package 'pak' failed
Error in loadNamespace(x) : there is no package called 'pak'
```

That is `setup-r-dependencies` failing before the package was ever built. Seen
2026-09-02 on a tagged spacehakr release, where the same workflow had passed on the merge
commit minutes earlier with identical content — the natural but wrong reading is "the
release is broken".

**Read which step failed before drawing a conclusion**, especially on a release commit
where the instinct is to distrust the tag:

```bash
gh run view <id> --log-failed | grep -iE 'error|fatal' | head
```

If it died in dependency setup, rerun once. If it dies the same way again it is the
upstream CDN, and the honest move is to say so and stop — not to keep spending runs on
something no change in the repo can fix.

## A job-level `concurrency` group must vary with the matrix, or the jobs cancel each other

`concurrency` at the **job** level is evaluated **per matrix job**, so a group string that
does not vary with the matrix puts every runner in one group — and with
`cancel-in-progress: true` they cancel each other. At most one platform runs per push,
which is the entire justification for having a matrix.

```yaml
# WRONG: identical for all three entries
concurrency:
  group: check-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

# right
  group: check-${{ github.workflow }}-${{ github.ref }}-${{ matrix.config.os }}
```

`fail-fast: false` does not help — that governs failures, not cancellation.

**It fails in the quiet direction.** A cancelled run reports `cancelled`, not `failure`,
which `/gh-pr-merge` step 10 correctly reads as `⊘ superseded` — so two platforms that
never ran look like two platforms that were superseded by a newer push. Nothing is red and
nothing says the coverage was lost.

The decisive evidence is GitHub's own context-availability table: `matrix` is listed for
`jobs.<job_id>.concurrency` and **not** for the top-level `concurrency`. If it were not
evaluated per job, the context could not be in scope there.

```bash
curl -s https://raw.githubusercontent.com/github/docs/main/content/actions/reference/workflows-and-actions/contexts.md \
  | grep 'concurrency'
```

Cheapest confirmation on a live workflow: the first run's job list. Three jobs
`in_progress` at once is the pass; one running while two read `cancelled` is this.

The entries above concern cancellation **between pushes**, which is the behaviour you
want. This is cancellation **within one push**, which is never what you want.

*4 lines of evidence for this rule are in `conventions/ci-monitoring.md`, which `/code-check` reads in full.*


## A push `paths:` filter skips an empty commit, and dispatch and schedule run only from the default branch
Before planning to re-run a workflow on a feature branch, check how it is triggered. An empty commit (`git commit --allow-empty`) changes no files, so a `push` trigger with a `paths:` filter skips it, and the skip is silent: no run is created, so nothing reports anything. `workflow_dispatch` only works for a workflow file already on the default branch, and `schedule` only fires from there. So a branch-only workflow is re-run in one of three ways: push trigger with no `paths:` (the branch filter scopes it), `gh run rerun <id>`, or a commit that touches a filtered path.

*1 line of evidence for this rule is in `conventions/ci-monitoring.md`, which `/code-check` reads in full.*

## A commit pushed by the Actions token starts no workflow, so wait on the SHA you pushed
Key a CI waiter on the SHA you pushed, never on the default branch's tip: a bot commit made with `GITHUB_TOKEN` (an `update-citation-cff` auto-commit, a docs regen) lands on top of yours and, by GitHub's design, triggers no workflow run, so a loop waiting for runs on the tip waits forever.

The tip moves seconds after a release push, which is exactly when a waiter is started. The bot commit also needs no check of its own when it only touches a file the site does not publish; confirm the deploy provenance instead (the `gh-pages` subject names the SHA that was built).

*1 line of evidence for this rule is in `conventions/ci-monitoring.md`, which `/code-check` reads in full.*

# Code Check — R
Traps in R: the language and base/utils behaviour, package internals (`R CMD build`, `.Rbuildignore`, roxygen, lintr, `data-raw/`, testthat, pak), and the DBI/duckdb/arrow data layer.

*Index only: each rule's heading and first sentence. The full text is `~/Projects/repo/soul/conventions/code-check-r.md`; read it before writing or reviewing code in its area. `/code-check` loads it in full.*

### Read-back shape must match write-back shape
A script that reads a file, transforms it, and writes it **back to the same path** is idempotent only if the reader accepts the shape the writer produces.

### Moving prose into a code chunk hides it from tools that scan the document
- Tools that scan an R Markdown document for prose — citation detection, cross-references, spell-check, word counts — skip code chunks.

### `fs::dir_ls(glob = )` matches the FULL path, so a bare filename pattern matches nothing
- `fs::dir_ls(dir, glob = "form_*.gpkg")` returns **zero** for a directory full of `form_*.gpkg` files.

### `glue()` trims common leading whitespace
- `glue::glue()` strips the common indentation of its input, so a template whose output must preserve exact indentation (XML, YAML, Makefiles, Python) comes out subtly wrong — valid-looking, wrongly indented.

### `f(g(x)) <- v` needs a `g<-`, not an evaluated `g(x)`
- R parses **any** call on the left of `<-` as a replacement function, all the way down.

### A replacement function on an `xml_missing` node is a silent no-op
`xml2::xml_find_first()` returns an `xml_missing` object when nothing matches — not `NULL`, not an error.

### `download.file(quiet = TRUE)` never tells you the HTTP status — read it from `curl`
Read an HTTP status from `curl::curl_fetch_disk()`'s `status_code`, never from `download.file()` messages, whose first warning unwinds a `tryCatch` before the status arrives and whose quiet error omits it.

### `on.exit()` at a script's top level never fires
- `on.exit()` registers a handler on the *current frame*.

### A `data-raw/` script must load the source tree, not the installed package
- `requireNamespace("pkg")` succeeds whenever **any** version is installed, so a guard shaped like `if (!requireNamespace("pkg")) pkgload::load_all()` silently runs against the installed one.

### `lintr` also resolves against the installed package, not the source tree
A lint warning of `no visible binding` for a constant added on this branch is usually the installed package being stale; check `exists(name, asNamespace(pkg))` and reinstall before changing any code.

### Regenerated binaries churn git even when nothing changed
- Formats that embed a creation timestamp or other run-varying metadata produce a different file on every rebuild.

### Tests that silently do not run
`expect_snapshot()` **skips on CRAN**, and `testthat` treats a non-interactive run as CRAN by default.

### A `skip_if_not()` skips only its own `test_that()` block
Before blaming a failure, or its absence, on a skip, find the `test_that()` block the skip sits in.

### `expect_gt()` and friends take no `info` argument
`expect_true()`, `expect_false()` and `expect_equal()` accept `info =`; the comparison expectations — `expect_gt`, `expect_lt`, `expect_gte`, `expect_lte` — do not, and passing one is an **error**, not a warning:

### pak Behavior
- pak stops on first unresolvable package — all subsequent packages are skipped

### Reproducibility
- Branch pins (`pkg@branch`) are not reproducible — document why used; the fuller pin policy (no suffix by default, never a bare SHA) is under "Two repos pinning the same remote" below

### A duplicate knitr chunk label fails the build, and reading the diff will not find it
Chunk labels must be unique **within a document**.

### `R CMD build` ships every top-level directory not in `.Rbuildignore`
- Internal coordination directories — `comms/`, `research/`, `planning/`, `dev/` — land in the tarball and therefore in the library of anyone installing from GitHub.

### `R CMD build` ships the `.git` FILE when you build from a worktree
A package built from a `git worktree` ships `.git` (a file holding the developer's absolute path), because R excludes only a `.git` directory; list `^\.git$` in `.Rbuildignore`.

### `.Rbuildignore` has no comment syntax — every line is a live regex
`tools:::inRbuildignore` loops over every non-empty line and ORs `grepl()` of it against the file list.

### Base name shadowing in formal args
- Avoid `names`, `length`, `data`, `c`, `t`, `T`, `F`, etc. as formal argument names.

### Cross-function consistency for label/string normalization
- When two functions in the same package both decide whether a string is a "system value" (or any normalized form), they MUST use the same comparison.

### `$` on a list partial-matches, so a longer sibling key answers for a missing one
- `x$foo` on a list returns `x$foo_bar` when `foo` is absent and `foo_bar` is the only key with that prefix.

### A database driver's value is not a base R type — and it fails twice
A column fetched through DBI does not arrive as the base type its SQL type suggests.

### arrow dplyr backend: no grouped slice — bridge to duckdb
- arrow's dplyr backend errors on grouped `slice_max`/`slice_min` (`arrow_not_supported("Slicing grouped data")`).

### as.POSIXct on a Date pins UTC midnight; on a character it uses the machine zone
Construct instants explicitly: a `Date` always becomes UTC midnight whatever `tz =` says, and a character with no zone is read in the machine's zone, so pass `tz =` at parse time.

### as.POSIXct on character infers ONE format for the whole vector
- `as.POSIXct(x)` on a character vector picks a single format by finding the first candidate that parses **every** element — and `strptime` **ignores trailing characters**.

### Inserting a helper between a roxygen block and its function rebinds `@export`
- roxygen2 attaches a block to **whatever object follows it**.

### open_dataset(unify_schemas = TRUE) requires aligned types
- Cross-prefix/file schema unification only merges what types allow: `timestamp[us, tz=UTC]` will not merge with naked `timestamp[us]`, `Grade: string` not with `Grade: double`.

### duckdb larger-than-memory dedup: shard the work — settings won't save you
- duckdb's **window operator** (QUALIFY row_number ...) does not spill enough to survive big partitions (OOM'd an 8 GB limit on a ~124M-row input).

### `nzchar(NA)` is TRUE — non-empty checks silently pass NA
- `nzchar(NA)` returns `TRUE`, so the natural "is this cell filled in" test — `all(nzchar(trimws(x)))` — waves through a column full of `NA`.

### A `for` loop that builds `aes()` captures the loop variable lazily
`aes()` quotes its arguments, so `aes(fill = lab[i])` is not evaluated until the plot is drawn — by which time `i` holds its **last** value.

### `paste()` with a zero-length argument returns length ONE, not zero
`paste0("x", character(0))` is `"x"`, so a key built per element gains one phantom member when the vector is empty; guard the empty case before building keys.

### `strsplit()` drops a trailing empty field, so a trailing separator vanishes
Leading empties survive and trailing ones do not, which is what makes it hard to reason about from memory.

### `identical()` on two reader results tests the reader, not the file
`identical(read_csv(f), read_csv(f))` can be **FALSE** for the same unchanged bytes: readr tibbles carry a `problems` attribute — an external pointer — that differs between reads (readr 2.2.0; `spec` is identical, measured).

### Under `R CMD check`, tests run from a temp dir against the INSTALLED package
Two shapes, both green under `devtools::test()` and broken under `R CMD check`, `devtools::check()`, a tarball check, or an installed-tests run — the direction that costs the most time.

### `dbConnect(SQLite(), path)` CREATES the file, so a read has a write side effect
SQLite creates a database on connect.

### CSV whitespace: `trim_ws` and `strip.white` do not do what the name suggests
- `readr::read_csv()` defaults to **`trim_ws = TRUE`** and silently strips leading and trailing whitespace.

### `R CMD check` rejects a filename containing a space
- "checking for portable file names" fails on any file in the built package whose name has a space.

### `sort()` and `order()` collate by `LC_COLLATE`, so a canonical form is locale-dependent
Character sorting in R is locale-sensitive by default, which makes any *canonical* string built by sorting — an XML node with its attributes ordered, a joined key, a manifest — a function of the session's locale rather than of the data:

### A library call that dispatches on a global option is not a pure function
A function whose *units* or *algorithm* are chosen by a session-wide setting behaves differently depending on what the caller did before reaching your code.

### `identical(-0, 0)` is TRUE in R, and the two still digest differently
A hash over R's serialized bytes — which is what `digest::digest()` takes by default — separates positive and negative zero, even though every value comparison says they are the same.

### Two repos pinning the same remote at different tags is an unsolvable install
`Remotes:` pins are per-repo, but resolution is global.

### `file(open = "wb", encoding = )` does not re-encode on write
The `encoding` argument to `file()` governs how bytes coming *in* are interpreted.

### A scalar helper called from `glue()` or `mutate()` recycles instead of erroring
`glue()` vectorises over its inputs.

### Never name a durable artifact by a hash the library reserves the right to change
`rlang::hash()` carries **no cross-version stability guarantee**, and rlang says so in its own NEWS for 1.3.0:

### `vapply(..., USE.NAMES = FALSE)` strips ALL dimnames, row names included
A named `FUN.VALUE` looks like it guarantees row names on the returned matrix.

### `source()`ing a config into the render environment leaks it into the next render
`source(params$config)` inside an Rmd puts every config value into the environment `render()` evaluates in.

### One very long table cell hangs paged.js, and it presents as a Chrome timeout
A ~600-character free-text field in a `kable` cell wedged `pagedown::chrome_print` indefinitely.

### `stats::aggregate()` has three separate silent behaviours, and each fails in a different direction
All three measured on R 4.5, all three met inside one 800-line script (drift#67).

### `deparse(body(f))` excludes formal defaults, so a body scan cannot see a default
A guard that scans function bodies for a forbidden literal is blind to that literal in a **signature**.

### `deparse()` re-encodes non-ASCII, so it answers about itself rather than the file
Scan R source for non-ASCII the way `R CMD check` does (`tools:::.check_package_ASCII_code()`: raw lines, comments skipped), not through `parse()` and `deparse()`, which turn `\uXXXX` escapes into literal characters and back.

### `package_version()` errors on a pre-release version string
`package_version("3.9.0beta1")` raises rather than returning `NA`, so strip a pre-release suffix before asserting a version floor.

### `tryCatch(warning = )` DISCARDS the value the expression produced
A `warning =` handler is not a filter — it replaces the whole expression, so a call that **succeeded** and merely warned returns the handler's value and the result is thrown away.

### `match()` treats NA as a matchable VALUE, so two unknowns join to each other
`match(NA, c("1", NA))` is **2**.

### `expect_message(expr, regexp)` checks only the FIRST condition, so a progress line hides the message under test
testthat 3e captures the first message the expression emits and matches the regexp against **that one**.

### `pak` refuses to install a package that needs no compiler
`pak::pak()` routes through `pkgbuild::check_build_tools()`, which fails with *"Could not find tools necessary to compile a package"* whenever `xcode-select -p` points at `/Applications/Xcode.app/...` while the Command Line Tools are what is actually installed — **regardless of whether the package has any compiled code**.

### `as.integer("NaN")` is `0`, and `as.integer(NaN)` is `NA`
The string round trip is the bug.

### `expect_false(identical(x, y))` cannot fail when the two are different types
`identical()` is type-strict, so it is already `FALSE` for any pair that differs in storage mode — and an assertion that the defect would make *true* then cannot fire.

### `unlist()` prefixes a `split()` group's name, so reassembling by name silently yields all-NA
Putting per-group results back in input order by naming them looks right and returns nothing:

### `tolerance` in testthat is RELATIVE, so it pins a published figure far more loosely than it looks
`expect_equal(x, 12.529, tolerance = 2e-2)` accepts anything within **two percent** — so a figure published to three decimals survives drifting to `12.629`.

### `cli` reads `{.name}` as a STYLE, not a variable, and a fold can swallow an interpolation
Two ways a `cli` message loses a value.

### `[[` on a named ATOMIC vector with an absent key is an error, not `NULL`
A list returns `NULL` for a missing `[[` key.

### `data.frame()` recycles a scalar against a zero-length column
It does not yield a 0-row frame — it raises, because a length-1 column and a length-0 column cannot be recycled together:

### A dot-prefixed column name can be swallowed by the verb's own formal
`mutate(x, .d = expr)` does not create a column called `.d`.

### `summarise()` and `mutate()` evaluate in order, so a later argument sees the summarised column
Once `frames = sum(frames)` has run, `frames` inside the next argument is that one-row sum, not the group's vector.

### `\<` and `\>` are word boundaries in R's default regex, not escaped `<` and `>`
Leave `<` and `>` unescaped when you build a pattern from data.

### `tempfile()` lives in the session tempdir, so a path printed in an error names a file R is about to delete
R removes its session `tempdir()` on exit, including after `stop()`.

### R's `yaml` returns a mixed int/float sequence as a list, not a numeric vector
`yaml::read_yaml()` simplifies a sequence to a vector only when every element has the same type, so `[0.164, 9999]` comes back as `list(0.164, 9999L)` while `[0.0, 9999.0]` is `c(0, 9999)`.

### testthat's failure snapshots land in `tests/` and ride in on `git add -A`
testthat 3e writes `tests/testthat/_problems/*.R` and `tests/testthat/testthat-problems.rds` when tests fail.

### A pick whose `ORDER BY` ends on a key that is not unique in the group returns an arbitrary row
`DISTINCT ON (k) … ORDER BY k, a, b` is deterministic only if `(a, b)` is unique within each `k`.

### `sprintf("%g", x)` writes `Inf` and `NA` into SQL as bare words, which Postgres reads as column names
A numeric formatter such as `sprintf("%.10g", x)` has no SQL form for non-finite values, so an open-ended range (`c(min, Inf)`, typically a blank `max` filled with `Inf` by a params loader) produces `x <= Inf`, and Postgres fails with `column "inf" does not exist`.

### An `information_schema` lookup by the literal table name misses what Postgres resolves
`WHERE table_schema = 's' AND table_name = 'T'` compares the text you passed, but Postgres folds unquoted identifiers to lower case, puts temp tables in `pg_temp_N`, and resolves unqualified names through `search_path`.

### Rscript reads a script as it runs, so never edit a script while a run of it is in flight
Copy the script and run the copy (`cp scripts/x.R "$TMPDIR/x_frozen.R" && Rscript "$TMPDIR/x_frozen.R"`) for anything long-running, or leave the file alone until the run exits.

### A range total taken as the difference of two large running totals loses the small ranges
Sum a range directly (segment tree, per-range `sum()`, or grouped sums) rather than as `cumsum[hi] - cumsum[lo]` when ranges are small relative to the running total.

### A `pkg::` call in a test passes `devtools::test()` and fails `R CMD check` if `pkg` is undeclared
`R CMD check` warns "'::' or ':::' import not declared from" for any package a test reaches with `::` that `DESCRIPTION` does not list, and under `error-on: "warning"` that reddens every runner.

### Inside a dplyr verb, a column named like a local variable wins
Inject a local value into a data-masked verb with `!!x` or `.env$x`, never a bare `x`: `transmute(d, aoi_id = id)` inside `for (id in ids)` reads the frame's own `id` column whenever one exists, with no warning, and the result is well-typed and plausible.

### `earthdatalogin`'s search and download calls overwrite the netrc when they find no Earthdata entry
Call NASA's CMR search with `curl` and download with `curl` given the netrc directly (`netrc = 1, netrc_file = <path>, cookiefile = ""` follows the URS redirect), or check `earthdatalogin:::has_edl_netrc()` yourself first.

### A fetcher's test helper must make the network fail, not just mock the reader
When a test mocks a downloader's reader and supplies fixture files, also mock the search and download functions to `stop()` by default, and re-mock them only in the tests that exercise that path.

### testthat 3e `expect_message()` returns the condition, not the expression's value
Assign inside the call, `expect_message(h <- f(x), "msg")`, never `h <- expect_message(f(x), "msg")`.

### `c()` dispatches on its first argument, so `c(NULL, <Date>)` is a plain number
Put a Date first when `c()` combines an optional piece with Dates: `c(NULL, <Date>)` takes the default method and returns a bare day count.

### `bind_rows()` of all-`NULL` is a 0 x 0 tibble, and a typed template must take its types from the rows' source
Bind per-group results under a zero-row template so an all-dropped result keeps its columns, and build that template's key columns from the same object the rows are built from (`combos$variable[0]`, not `character()`).

### `sample.int(prob =)` without replacement is not a probability-proportional draw, so weighting its result again double-counts
Draw a subsample to be design-weighted **uniformly** (`sample.int(n, k)`), or keep every unit.

### `system2(stdout = TRUE)` warns on a non-zero exit instead of raising, so a `tryCatch(error =)` around it never fires
Read the exit status off the result: `st <- attr(out, "status")`, which is `NULL` on success.

### Forked `parallel::mclapply()` workers segfault in `glm.fit` under macOS Accelerate BLAS
Fit models in parallel on socket workers (`parallel::makeCluster()` with `parLapply()`), not forks: with R linked to Accelerate's vecLib, `mclapply` children segfault inside `glm.fit` (`address 0x110, cause 'invalid permissions'`), and `mclapply` returns try-errors with a warning rather than stopping.

### `c(name = x)` keeps `x`'s own name, so a value from a named vector becomes `name.X`
Strip the name before you label it: `c(axis = unname(v[1]))` or `c(axis = v[[1]])`.

### `trace(exit =)` also fires when the function raises, and `returnValue()` then has no value
Give `returnValue()` a default and check its length: `trace(f, exit = quote(rec(returnValue(NULL))))`, then treat anything not length 1 as "no value".

### `Rscript -e` supplies `--args` itself, so adding your own shifts every argument by one
Write `Rscript -e 'expr' a b`, not `Rscript -e 'expr' --args a b`.

### `read.delim()` quotes by default, so a `"` in a field silently swallows rows
Read a TSV you wrote unquoted with `quote = "", na.strings = character(), comment.char = ""`.

### duckdb in R: the query that autoloads `icu` binds unreliably, so `LOAD icu` before it
Run `LOAD icu` on the connection before any query that needs it (`epoch()`, `year()`, a cast to `DATE` on a `TIMESTAMPTZ`), or use a function that needs no extension (`epoch_ms()`).

### `fs::path()` collapses the `//` after a URL scheme, so it cannot build URLs
Join a URL with `paste(base, key, sep = "/")` or `file.path()`, never `fs::path()`: `fs::path("https://x.ca/b", "k.tif")` is `"https:/x.ca/b/k.tif"`, because fs normalises the doubled separator, and the result is not a valid URL.

# Code Check — Shell
Tool-level traps in bash, sed, git and `gh`, and in the host toolchain those commands depend on.

*Index only: each rule's heading and first sentence. The full text is `~/Projects/repo/soul/conventions/code-check-shell.md`; read it before writing or reviewing code in its area. `/code-check` loads it in full.*

### `git diff a..b` compares TIPS; a change on `a` shows up as the branch's
Use three-dot `git diff a...b` for what a branch changed; two-dot compares the tips, so changes that landed on `a` show up as the branch's, inverted.

### git pathspec excludes: use the long form
- `:!path` is short-form magic, and git keeps parsing magic characters after the `!`.

### `sed 1d f1 f2 f3` strips only the FIRST file's header
`sed` treats multiple file arguments as one concatenated stream, so a line-address script applies once across the whole set rather than per file.

### `sed -n '/X/,$d' file` prints nothing at all
`-n` suppresses auto-print, and `d` only deletes — so nothing is ever emitted and the output is empty.

### Reading a file line-by-line drops the last line without a trailing newline
- `while IFS= read -r line; do ...; done < file` skips a final line that has no newline after it.

### Empty arrays under `set -u` on bash 3.2
- macOS still ships bash **3.2**, where `"${ARR[@]}"` on an empty array is an unbound-variable error under `set -u`.

### Quoting
- Variables in double-quoted strings containing single quotes break if value has `'`

### Heredoc precedence in pipelines
- `cmd1 | cmd2 <<EOF` — the heredoc binds to `cmd2` (the rightmost simple command).

### Paths
- Hardcoded absolute paths (`/Users/airvine/...`) break for other users

### Diagnose env/PATH problems in the shell that actually runs, not the ambient one
- Get ground truth **before** forming any theory: `env -i HOME=$HOME TERM=$TERM bash -lc 'echo $PATH | tr ":" "\n" | nl'` (swap in `zsh` to check the other side).

### Parallel writers sharing one output file interleave mid-record
- `xargs -P N ... >> shared_file` (or any fan-out where N processes append to the same fd/path) is only safe while each record fits in a single `write()`.

### `mktemp` template needs enough X's, and a failed `mktemp` leaves an empty var
- BSD/macOS `mktemp -d -t <name>` requires the template to contain at least 3 `X`s (`XXXXXX` is the safe default).

### `cmd dir/*` dies on ARG_MAX at scale — and only after the expensive work succeeded
- A glob expands to argv.

### A `curl` in a parallel fan-out needs `--max-time`
- Without it, one hung connection pins a worker slot indefinitely.

### BSD vs GNU sed/grep portability (macOS hits this constantly)
- macOS ships BSD `sed`/`grep`.

### On this Mac `stat` and `date` are GNU, so the same flag letter means something else
Here Homebrew puts GNU coreutils ahead of `/usr/bin`, so BSD-style `stat -f` and `date -r <epoch>` mean something else; prefer a flavour-free form (`find -newermt`, `python3`), or call the binary by absolute path.

### `&` binds to the whole `&&` list, so assignments never reach the parent
- `cmd1 && VAR=$(...) && nohup prog > "$VAR.log" & disown` backgrounds the **entire list**, not just `nohup`.

### `gh` CLI
- **`gh pr create` resolves branch from CWD, not `--repo`**.

### On a fork, `main` may track upstream by design — comparing it answers nothing
`gh api repos/ORG/REPO/compare/upstream:main...ORG:main` returning `ahead: 0, behind: 0, status: identical` reads as *"this fork has no local work"*.

### A destructive setup and its undo must not share one timeout-able command
Never chain a destructive setup and its undo (`git stash && slow && git stash pop`) in one timeout-able command; compare with `git show HEAD:path`, or restore from one `trap … EXIT` handler guarded by a flag set once the setup happened.

### `git checkout <path>` restores from the index, not from HEAD
After a `git add`, `git checkout <path>` reinstates the broken *staged* copy — so the "fix" reproduces the failure and reads as though the edit was wrong.

### A value validated with one numeric grammar and consumed with another
Normalise a numeric string once (digits only and at most 9 of them, then `x=$((10#$x))`, then a bounded range): `test` reads base 10, `$(( ))` reads a leading zero as octal and wraps past 2^63.

### `wait` with no argument waits for every background job in the shell
Wait on the PIDs you started (`wait "$pid"`), because a bare `wait` also blocks on every other background job in the shell.

### `if ! cmd; then rc=$?` captures the negation, not the command
Inside the branch, `$?` is the status of the `!` compound — which is **0 by construction**, because the negation succeeded.

### A `pgrep -f` waiter matches its own command line, so it never exits
Wait on a PID with `while kill -0 "$PID"; do sleep 30; done`, never on `pgrep -f "job"`, whose pattern matches the waiting loop's own command line so it never exits.

### `timeout` is GNU coreutils — a portable deadline
An assertion around something that might hang can only pass or hang, never fail (`code-check.md`, "Restore the bug and prove the guard fires").

### `aws s3 cp` cannot tell a missing key from a missing bucket
`aws s3 cp` gives one exit 1 and 404 text for a missing key and a missing bucket, so probe `s3api head-bucket` then `head-object`: only a 404 from a reachable bucket means absent; a 403 is permissions.

### A verification command can be shadowed by a shell function or alias
- The shell is initialized from the user's profile, so `diff`, `grep`, `ls`, `cat` and friends may resolve to a wrapper rather than the binary you assume.

### psql does not interpolate `:'var'` inside a dollar-quoted string, and `\quit N` exits 0
Two traps in the same file type, both of which read perfectly and fail at run time.

### A second `trap … EXIT` replaces the first
`trap` registers **one** handler per signal.

### A `local` statement cannot read a variable it is assigning in the same statement
`local a="$1" lab="$2" m="/tmp/marker_${lab}"` expands `${lab}` **before** `lab` is assigned.

### Inside an `EnterWorktree` session, the Bash tool refuses command text that names git
The harness applies an isolation guard to a session that entered a worktree: *"a worktree-isolated session's git operations must target its own worktree."*

### A `git filter-repo` seed carries the source repo's tags, and a path sed misses the language's path constructor
Two traps from seeding one repo out of another's history (fish_passage_template_reporting#236, 2026-09-02), both silent.

### `git check-ignore -v` prints the matching pattern, and its exit status is not a per-file verdict
`-v` reports the **last matching pattern**, negations included.

### `sips -Z` scales up as well as down
`sips -Z N` resamples so the longest side is N — in **either** direction.

### Assert capabilities, not versions — a tool upgrade can remove one silently
A tool upgrade across the fleet can remove a capability without reporting failure.

### An amd64-only image needs `--platform`, and it works on your machine because it is cached
`docker run` resolves from the local image store before it reaches a registry, so on an arm64 Mac an amd64-only image runs fine once pulled — **and the command that pulled it is not necessarily the one in the code.**

### Headless Qt in a container needs `QT_QPA_PLATFORM=offscreen`, and without it the run hangs or crashes
Pass `-e QT_QPA_PLATFORM=offscreen` to any `docker run` that starts QGIS or another Qt program with no display.

### `s3cmd ls` given several paths lists only the FIRST, and says nothing
Query one path per `s3cmd ls` call, or `--recursive` on the prefix and `grep`: given several paths it lists only the first, with exit 0.

### `grep -c` prints the count AND exits 1 when it is zero
Write `n=$(grep -c …) || n=0`, never `|| echo 0` inside the substitution: `grep -c` already prints `0` and exits 1, so that fallback appends a second line, while the bare assignment aborts a `set -e` script.

### A failed `git fetch` leaves the comparison you make next reading stale refs
`git fetch` and the check that follows it are two commands, and nothing links them.

### macOS `/usr/bin/awk` aborts when a regex meets a byte slice that cuts a multibyte character
Test a `substr()` slice with `==`, never with `~`, `match()` or `sub()`: the stock macOS awk counts bytes in `substr()` but converts a regex operand to wide characters, and a partial UTF-8 sequence kills the whole program.

### A variable in a sed replacement is parsed, so its `\` and `&` are not literal
Never interpolate data into the replacement half of `sed "s#…#$var#"`: sed reads `\(` as `(`, and `&` as the whole match, so the line written is not the value held.

### A fetch can fail and still deliver the commit, so when you need an object, test the object
When the goal is a specific commit, resolve its sha first (`git ls-remote`) and test `git cat-file -e "$sha^{commit}"` after the fetch rather than the fetch's exit status.

### A default `GIT_SSH_COMMAND` outranks the machine's own ssh choice
Supply a default ssh command only when `GIT_SSH_COMMAND`, `core.sshCommand` and `GIT_SSH` are all unset.

### `curl -o` without `-L` saves the redirect page as the download
`curl` does not follow redirects unless it is given `-L`, and it exits 0 on a 3xx.

### `conda run` captures its child's output, so a pipe gets nothing
`conda run -n env cmd` buffers the child's stdout and re-emits it, and that re-emission does not reach a pipe.

# Code Check — Spatial
terra, sf, bcdata, GDAL/OGR CLIs.

*Index only: each rule's heading and first sentence. The full text is `~/Projects/repo/soul/conventions/code-check-spatial.md`; read it before writing or reviewing code in its area. `/code-check` loads it in full.*

### Negative coordinates get parsed as CLI options — every BC bbox hits this
- BC longitudes are all negative, so `--bounds -124.73 49.485 -124.595 49.565` fails with `Error: No such option: -1`.

### bcdata: an empty result raises AttributeError, it does not return an empty collection
- A bbox query matching nothing exits non-zero with `AttributeError: You are calling a geospatial method on the GeoDataFrame, but the active geometry column to use has not been set.` — geopandas complaining about an empty frame, several layers below the query.

### bcdata: `BBOX()` rejecting a bbox that is a length-4 numeric vector — seen once, unquoting fixed it
If `bcdata::BBOX()` rejects a length-4 numeric bbox as not a length-4 numeric vector, try unquoting it with `!!`; this was seen once and the mechanism is not established.

### terra: operator dispatch and edge cases in package code
- **SpatRaster `%in%` is not dispatched when terra is *imported* (only when *attached*).**

### terra: `extract()` returns no row for ground beyond the raster, and counts cells by centre
- Two traps in one call, and both make a partial result look complete.

### A `...` constructor may discard trailing arguments based on the class of the first one
- A constructor that takes `...` is free to branch on **what its first argument is** and build the result from that alone.

### terra: `mask()` is `touches = TRUE`, so two "clip to the polygon" routines disagree by a cell ring
Swapping one polygon clip for another looks like a refactor and is a **methodology change**.

### terra: `sources()` on a derived raster is `""` or a random temp path, never the input
- A raster that came out of `crop()`, `project()`, `mask()`, or arithmetic is **derived**, so it has no source file.

### `sf::st_as_binary()` returns a LIST of raw vectors, so `is.raw()` on it is FALSE
The obvious way to feed WKB into a canonicalizer is a `is.raw(x)` branch that hex-encodes it.

### Canonicalize geometry before hashing it — ring order and orientation are not fixed by topology
`code-check.md`'s cache-key row prescribes hashing WKB (`sf::st_as_binary(sf::st_geometry(x), endian = "little")`) rather than the sfc object.

### sf: `st_join(largest = TRUE)` ignores the join predicate
`st_join(largest = TRUE)` matches by intersection area whatever `join =` says, and drops zero-area geometries, so point and line overlays cannot use it.

### sf: name validation must account for the geometry column
- The active geometry column is a named entry in `names(x)`, but its name is **not fixed** — `"geometry"` from `sf::st_read()` of some sources, `"geom"` from a GeoPackage/PostGIS layer, `"geometry"` or `"_ogr_geometry_"` elsewhere.

### sf: `st_intersection()` / `st_difference()` return a GEOMETRYCOLLECTION that QGIS will not draw
- Intersecting or differencing two polygon layers yields a `GEOMETRYCOLLECTION` wherever the inputs *also* touch along a line or at a point.

### sf: reproject the polygon to get a lat/lon bbox, never transform the projected bbox corners
- To hand a geographic (EPSG:4326) bounding box to a bbox-filtered query (WFS/OGC features, `?bbox=`), reproject the whole AOI **geometry** then take its bbox: `sf::st_bbox(sf::st_transform(aoi, 4326))`.

### An offset regex must be anchored to a time, or a date looks like a zone
- Refusing or stripping a trailing UTC offset with something like `[+-][0-9]{2}(:?[0-9]{2})?$` also matches the end of a plain ISO date: `"2026-08-15"` ends in `-15`, which reads as a −15 hour zone.

### A reader that accepts a UTC offset may not be applying it
GDAL accepts a UTC offset in a GeoPackage `DATETIME` and silently drops it, returning wall-clock digits that are then read in the machine's zone, so one file gives a different instant on every machine.

### Ask the file about its field names, not R
`sf::st_read()` returns a data frame, and R makes column names syntactic on the way in.

### QGIS embeds a layer's style in the `.qgs`, so rewriting the `.qml` sidecar changes nothing
A `.qgs` carries each layer's style **inside** its `<maplayer>` node — the sidecar's children are copied in when the layer is declared.

### A GeoPackage is a SQLite database, and that leaks in three ways
Writing to one directly (a `layer_styles` row, an attribute fix) is a plain `INSERT` and needs no GDAL.

### The same leak reaches R and OGR SQL, and a GeoPackage's bytes are not its content
Edit a live GeoPackage through GDAL (`ogrinfo -sql`) rather than RSQLite, and assert row state rather than `dbExecute()`'s count, which includes trigger writes.

### Restoring a GeoPackage from a copy: refuse sidecars before the first read, delete them before the copy-back
A byte copy of the main file is a snapshot only when no `-journal`, `-wal` or `-shm` exists and the header is in rollback mode (bytes 18-19 = `01 01`).

### A coordinate stored as an attribute can disagree with the geometry it describes
A spatial layer that also carries `LATITUDE` / `LONGITUDE` columns has the same fact twice, and nothing keeps them consistent.

### GeoJSON in a projected CRS is silently non-portable
`sf::st_write()` and `ogr2ogr` will write GeoJSON from a projected object and emit a `crs` member naming it:

### `sf::st_perimeter()` needs lwgeom on projected data, and lwgeom is not a dependency of sf
An exported sf function whose body branches on `requireNamespace("lwgeom")` is an undeclared dependency: `R CMD check` does not report it, and a test suite cannot see it on a machine that happens to have lwgeom installed.

### terra keeps a result in memory whenever it fits, so a per-class loop over a large grid accumulates full-grid rasters
`ifel()`, `focal()`, arithmetic and `rasterize()` return in-memory SpatRasters whenever the result fits under `memfrac` (60% of RAM by default).

### `geom_sf(data = NULL)` draws nothing, silently
A `NULL` `data` argument does not error and does not warn — the layer inherits the plot's data, which for `ggplot()` with no global data is empty, so it contributes a **zero-row layer**.

### terra: `app()` calls a vector-tolerant `fun` once per CELL, and reads a 5-column return on a 5-column raster as transposed
Two contracts inside `terra::app()` that read as the opposite of what they are, both measured on terra 1.9.34 (drift#9, 2026-09-05):

### terra: `levels<-` and `coltab<-` copy before they strip; `set.cats(NULL)` is the in-place form
`levels<-` and `coltab<-` deep-copy before stripping, so a caller-untouched test cannot fail under them; `terra::set.cats(r, layer = i, value = NULL)` strips in place and mutates whatever raster it is given, so use it on a copy you own.

### terra `metags()`: the empty case is `NULL`, and the sidecar is half the artefact
Three measured facts about raster **container** metadata, all of which fail quietly (floodplains#83, 2026-09-05, terra 1.9.34 / GDAL 3.8.5).

### `ggmap`: a fixed `zoom` silently crops points off the basemap, and `calc_zoom()` does not fix it
`ggmap::get_map()` fetches ONE fixed-size image at whatever `zoom` it is given.

### terra: `zonal()` outside its six-function fast path materializes the WHOLE grid in R
`terra::zonal()` dispatches to C++ only when `fun` is one of `max`, `min`, `mean`, `sum`, `notNA`, `isNA`.

### sf: close a rotated ring by copying the first vertex, never by recomputing it
Rotating a polygon by multiplying its whole vertex matrix — `xy %*% rot` — looks exact, and for a ring built closed it is not.

### terra: `plot(type = "classes", levels =, col =)` maps colours by POSITION, per layer
A `levels`/`col` pair is not a value-to-colour mapping.

### terra: `wrap()` carries the tempfile basename in `varnames`, so a committed artifact churns
Set `varnames` and `longnames` before `wrap()` or writing a raster produced with `filename = tempfile()`, or the random tempfile basename makes a committed artifact change on every run.

### `terra::plot()` leaves the device in a state where a keyword-placed `legend()` draws nothing
`graphics::legend("topleft", …)` after a `terra::plot()` or `terra::plotRGB()` **silently draws nothing** — no error, no warning, and the rest of the figure renders normally.

### A name is not a key: `GNIS_NAME` matches features all over BC
`filter(GNIS_NAME == "Buck Creek")` returns every Buck Creek in the province.

### `sf::st_read()` on a KML drops `<SchemaData>`, silently
GDAL has two KML drivers and picks `KML` by default, which does not read the `<SchemaData>` block.

### GDAL applies `-srcnodata` and an alpha mask together, and the mask loses
Two ways of saying "these pixels are not data" reach `gdalwarp` independently, and giving it both is not an error — it is an instruction to do both.

### `parallel::mclapply()` over a remote raster aborts every fork on macOS, and the wrapper exits 0
GDAL's curl handles do not survive a fork.

### terra: `align()` defaults to `snap = "near"`, so the aligned window need not contain the input
`terra::align(e, r)` snaps each edge of `e` to the **nearest** cell boundary of `r`, which moves an edge *inward* as readily as outward.

### GDAL reserves 3,276 MB per process before reading a cell, and PSOCK workers outlive their master
Two independent reasons a parallel raster job uses far more memory than its data, both measured 2026-09-20 on a 64 GB machine (fly#58) while a sweep was killed four times.

### `terra::distance(x, target = NA)` measures FROM the NA cells, so every data cell reads 0
Reaching for it to answer "how far is each data cell from the nearest nodata" gives the opposite: `distance()` fills the **target** cells with their distance to the nearest non-target, so data cells come back `0` and any `dist < threshold` test is true everywhere.

### `summarise()` on a grouped `sf` returns an `sf`, and the geometry rides into your CSV
`dplyr::summarise()` dispatches to `summarise.sf` on an `sf` object.

### A raster's drawn footprint is its valid data, not its extent
Before comparing a rendered shape against a raster, get the raster's valid-data window, not its bbox.

### `sf::gdal_utils()` does not raise when GDAL cannot open the source
Test the result before parsing it: `gdal_utils("info", ...)` on a source GDAL cannot open - an unreachable url, a missing key - **warns and returns `character(0)` or `NA`**, and the next `jsonlite::fromJSON()` dies with *"invalid char in json text"*, which names nothing about the cause.

### A shift measured on one grid is wrong when applied on another
Apply a displacement in the CRS it was measured in: transform the point there, add the shift, transform back.

### Writing KML: `<color>` is `aabbggrr`, and a remote icon href renders nothing offline
Do the hex swap in **one** helper and omit `<Icon><href>` entirely.

### `rio cogeo validate` exits 0 when the file is NOT a valid COG
It reports the verdict in text and returns success either way, so the exit status carries no information at all:

### `terra::rast()` on a SpatRaster returns an empty template, not a copy
Pass a SpatRaster through as is (`if (inherits(x, "SpatRaster")) x else terra::rast(x)`): `rast(x)` on one builds a new raster with the same geometry and **no values**, so a function that normalises its input with `terra::rast()` silently receives an all-empty grid when handed an object rather …

### `terra::rasterize(filename = , datatype = <integer>)` writes the background as 0, not NA
Rasterise in memory and then `writeRaster(datatype = …)`: written directly through `filename` with an integer `datatype` (INT1U, INT2S), cells no polygon covers come out as 0, while the file's NoData is 255, so they read back as data (terra 1.9.46 and 1.9.50; rspatial/terra#2195).

### GDAL's `average` warp across a rotated CRS weights the wrong pixels; average in the target CRS instead
To take class fractions or means from a fine grid in one CRS onto a coarse grid in another, resample nearest onto a grid aligned with the target and `fact` times finer (`terra::disagg(terra::rast(target), fact)`), then `terra::aggregate(fact, mean)`.

### `terra::densify()` on lon/lat follows great circles, so a raster extent's parallel edges bow poleward
Pass `flat = TRUE` (with the interval in degrees) when densifying a lon/lat extent before projecting it.

### Planetary Computer STAC: a floodplain-scale read hits three limits a reach never does
Query a large AOI by its convex hull, re-sign items before each tile, and give `datetime` explicit times (`…T00:00:00Z/…T23:59:59Z`).

### gdalcubes reports failed chunk reads only on stderr, so a partial cube passes as complete
Do not guard on it by capturing output.

### terra reads a multi-variable gdalcubes NetCDF with its variables in alphabetical order
Select layers by name after `terra::rast()` of a `gdalcubes::write_ncdf()` output, never by position.

### terra's COG writer emits a `.aux.json` sidecar when the raster carries a time
Strip `time` (and `units`, `varnames`, `longnames`, `metags`, `scoff`) before `writeRaster(filetype = "COG")`, or have the publisher move `<file>.aux.json` with the raster.

### `sf::st_read()` promotes a mixed POLYGON/MULTIPOLYGON layer to all-MULTIPOLYGON
Read with `promote_to_multi = FALSE` whenever a layer will be written back.

### `sf::st_make_valid()` rewrites geometry that was already valid
Run it on the invalid rows only (`!st_is_valid(x)`), or keep the original geometry and use the made-valid copy just for the computation.

### terra: `unique()` and `freq()` on a factor return its labels, not its codes
Read a factor raster's codes from a copy with its levels stripped (`levels(y) <- NULL`, or `set.cats(y, layer = 1, value = NULL)` on a copy you own), never from `terra::unique(x)[, 1]` or `terra::freq(x)$value`: on a factor both return the active category's labels, so matching …

### A GDAL failure partway through `sf::st_read()` returns the rows read so far, with only a warning
Treat any warning during a read whose completeness matters as a failed read: wrap it in `withCallingHandlers(st_read(...), warning = function(w) stop(...))`, retry, then stop.

### `terra::project()` over a remote strip-organised TIFF issues a range request per strip, so download it first
Check `gdalinfo` for `Block=<width>x1` before reading a remote raster through `/vsicurl/`, and where it is strip-organised (one row per block, no overviews) download the whole file to a tempfile and read that.

### LidarBC tiles can carry an undeclared nodata of -3.4e38, which a mean takes as data
Clamp a LidarBC DEM or DSM to plausible elevations before any aggregate: `terra::clamp(r, -100, 5000, values = FALSE)`.

### bcdata returns a column whose values are all missing as character, not numeric
Coerce every field you do arithmetic on (`as.numeric(v$PROJ_AGE_1)`) right after `bcdata::collect()`.

### The BC WFS caps an un-paged `GetFeature` at 10,000 features and still answers HTTP 200
Hold any raw WFS read to the server's own count.

### bcdata's error text does not carry a WFS failure's cause, so read it from the response
To tell a throttle from any other bcdata failure, record the status off the request itself (wrap `crul:::crul_fetch`), not from the message.

### sf and terra can link different GDALs, so a probe through one says nothing about the other
Check `sf::sf_extSoftVersion()[["GDAL"]]` and `terra::gdal()` before concluding that "GDAL" cannot read something: one R session can hold two GDALs (a CRAN binary of sf bundles its own, terra built against Homebrew links another), and a driver or codec missing from one may be present in the …

# Code Check Conventions
Structured checklist for reviewing diffs before commit.

*Index only: each rule's heading and first sentence. The full text is `~/Projects/repo/soul/conventions/code-check.md`; read it before writing or reviewing code in its area. `/code-check` loads it in full.*

## Mechanisms
Fourteen shapes that keep producing bugs.

### A guard that fails toward pass
A check decides whether to do something consequential — cut a tag, run a migration, report a sweep clean.

### A fixture that cannot reach the failure mode
Hand-picked fixtures test the cases you thought of.

### A proxy is not the property
A condition that stands in for the thing you actually want.

### Verification that reads its own output
A check whose reference was produced by the thing it checks cannot disagree with it.

### A guard's scope, escape hatches, and remedies
Every guard grows the things that silently disable it.

### A fix lands in one of two callers that share a harness
Two entry points over one library, two workflows over one action, two scripts sourcing one shell lib.

### Restore the bug and prove the guard fires
A test that stays green against the code it was written to reject is decoration, and reading it will not tell you.

### A shared working tree, and what generators leave in it
A working tree has one checked-out branch.

### A wrapper's exit is not the work
A wrapper reports its own exit.

### Zero-length, empty, and unset are three different things
`paste0(character(0), "x")` is `"x"` — one phantom row from an empty frame.

### The probe is broken before the world is
When an ad-hoc probe reports that long-shipped code is broken, the prior belongs on the probe.

### Written data outlives the fix
Changing the writer changes nothing already written.

### Serialization loses meaning silently
Set `na=` and `null=` explicitly on every writer, because a serializer's default for no value is usually a valid-looking value (`"NA"`, `{}`, `'None'`) that every schema check accepts.

### One fact derived twice
A count taken from one artifact and the things counted produced from another, with a guard comparing the two.

## Rules that stand alone
General, and not an instance of a mechanism above.

### Do not edit files a long test run is reading
- `devtools::test()` (and most runners) load each test file **when they reach it**, not at launch.

### Test a persistent change through its per-process override first
A setting that is changed once and persists — `xcode-select -s`, a git config key, a registered default, an installed symlink — usually has an environment variable or flag that overrides it **for one process**.

### Adopting Existing Config
When importing config from one location into a canonical one (legacy `~/.bash_profile` → dotfiles repo, old script's env → repo, another project's `settings.json` → soul):

### Test the cold/create path of idempotent code, not just the warm no-op
- Idempotent provisioning code (a resolver-file writer, a config installer, a "create unless present" block) has two paths: the **cold** path that actually creates/writes, and the **warm** path that detects "already present" and skips.

### Fetch an expiring credential just before its first use, not at job start
Put the step that fetches short-lived credentials immediately before the first step that uses them.

### Do not write to an artifact a human is testing on
- Handing someone a deployed thing to test — a synced project, a staging database, a preview build — and then continuing to push changes into it makes two writers for one artifact.

### Percent-encode a URL at construction, not at consumption
- A URL built by string-concatenation from filenames inherits whatever those filenames contain.

### A preview flag is only safe if it previews
- `--dry-run`, `DRY=1`, `--plan` conventionally mean "show me what would happen".

### Bare `y`, `n`, `on`, `off`, `yes`, `no` are booleans in YAML 1.1
- The YAML 1.1 core schema resolves `y`, `Y`, `n`, `N`, `yes`, `no`, `on`, `off`, `true`, `false` (and their case variants) to **booleans**.

### Documentation Staleness
- Moving/renaming scripts: update CLAUDE.md, READMEs, usage comments

### An ordered dispatch makes severity ordering load-bearing, and nothing enforces it
A `CASE`, an `if/elif` chain, or any first-match dispatch that reports a *verdict* carries an unwritten invariant: every serious arm precedes every advisory one.

### A link to a repo-hosted artifact must be *tracked*, not merely present
When the published site **is** the repository — GitHub Pages serving `docs/`, or a `raw.githubusercontent.com` URL — the question "does this file exist" is the wrong predicate.

### An assertion that matches an interpolated value cannot see the claim around it
`expect_error(f(x), "some_column")` looks like it pins the guard.

### A pluralisation marker takes the quantity of whatever was substituted last
`cli`'s `{?a/b}` reads the most recent quantity in the string, and **any** substitution resets it — including a length-1 one that is not what the marker is about.

## Security

### Process Visibility
- Secrets passed as command-line args are visible in `ps aux`

### Secrets in Committed Files
- `.tfvars` must be gitignored (contains tokens, passwords)

### Firewall Defaults
- `0.0.0.0/0` for SSH is world-open — document if intentional

### Credentials
- Passwords with special chars (`'`, `"`, `$`, `!`) break naive shell quoting

### Gitleaks pre-commit hook
Configuration patterns and false-positive handling for the `gitleaks` pre-commit hook (kdot's Brewfile ships `gitleaks` + `pre-commit`; cyclops standardizes the hook):

### "Public bucket" ≠ listable: GetObject vs ListBucket
- A bucket policy granting only `s3:GetObject` on `bucket/*` makes exact-key fetches public but NOT listing — and dataset discovery (`arrow::open_dataset()`, duckdb globs, STAC `/vsicurl/` directory reads) requires `s3:ListBucket` on the **bucket ARN** (no `/*`; it's a bucket-level action).

## Spreadsheets and PDFs

### A stored value is not wrong just because the raw number looks wrong
Before reporting that a spreadsheet value is off by a factor, check the cell's **number format**.

### Verify PDF links from the annotations, not the extracted text
`pdftotext` returns anchor text, not the href.

### Extracted PDF text carries corrupted glyphs, and a tolerant parser turns them into wrong numbers
Never strip non-digits to clean a number extracted from PDF text: corrupted glyphs (an `O` for a `0`, a Private Use Area micron sign) become plausible wrong values, so anchor on the label and check against an independent identity.


# NGE Feature Workflow

For non-trivial issue-driven work, follow this checklist. Each step exists for a reason — skipping leads to rework, broken builds, and avoidable bugs that we've hit repeatedly.

## The Sequence

1. **Start with `/planning-init <N>`** — given an issue number, enters plan mode for codebase exploration, presents a phase breakdown for user approval, then scaffolds branch + PWF baseline with the approved phases. One command replaces the manual issue → explore → plan → branch → scaffold dance.
2. **Write robust tests first** — failing tests that reproduce the issue or document the new behavior. Tests are the contract; they fail until the work makes them pass.
3. **Name with intent** — functions, parameters, internal helpers carry the naming style of the package they live in. Look at existing exports as the guide; consistency over cleverness. For files rather than functions — shell scripts and operational R scripts under `scripts/` or `data-raw/` — the standard is the `noun_verb-detail` pattern in `newgraph.md`, noun first.
4. **Examples that run** — every exported function gets a runnable `@examples` block. Pkgdown renders them; CI executes them. An example that doesn't run is documentation rot.
5. **Code-check before each commit** — `/code-check` on staged diff. Catches what tests miss: edge cases, hard-coded paths, unguarded variables, security issues.
6. **Atomic commits** — each commit bundles code change + checkbox flip in `task_plan.md`. The diff and the progress live in the same commit; `git log -- planning/` tells the full story.
7. **`/planning-archive` when complete** — moves PWF to `archive/YYYY-MM-issue-N-slug/`, creates a fresh `active/`. Then `/gh-pr-push` opens the PR; `/gh-pr-merge` handles the release bookkeeping.

## Where the checkpoints are not

Step 1's plan approval is the authorization for every step after it. Run steps 2–7
through to the **open PR** without stopping to report between phases — the merge in
step 7 is outside the mandate unless the instruction includes it; put the decisions that
genuinely change what gets built at the plan gate, batched, with a recommendation
first; report once when the PR is open. The rule, its boundary (before a plan
exists, a question wants an answer) and its exceptions are `karpathy.md` §8.

## Re-read origin before you open the PR, not just before you cut the branch

Verifying local is current with origin (`code-check-shell.md`, "Before you *cut* a
branch") protects the branch point. It
says nothing about the build window, which is where a parallel session lands: measured
once, a second session filed, built and merged the same feature in 18 minutes, entirely
inside the first session's planning phase, and merged 15 seconds before its first
commit. Both sessions' pre-flight checks passed and both were correct when they ran; the
duplicate surfaced hours later as a version-bump conflict across eight files.

Before opening a PR, and again before merging:

```bash
git fetch -q origin
git log --oneline HEAD..origin/main          # what landed while you worked
git diff origin/main -- DESCRIPTION NEWS.md  # a version you did not bump
```

**A version bump you did not make is the tell**, and usually the only one — the tree is
clean, the branch is healthy, and nothing in git hints that someone solved your problem
an hour ago.

On a collision, do not resolve conflicts file by file. The merge conflict hides the
useful question, which is *which body of work survives*. Ask, then re-land the delta on
top of what shipped; two independent attempts at one problem are usually complementary
rather than redundant, and a mechanical resolution keeps whichever half git preferred.

## An issue number you did not file yet is somebody else's

GitHub allocates one sequence across issues **and** PRs, on creation. So a number
written down before the issue exists — a branch name, a code comment, a config header,
a commit trailer — is a reservation nobody honours, and in an active repo it will
eventually name a real issue about something else entirely.

That is the expensive direction. A number pointing at *nothing* is obvious; a number
pointing at a **stranger's issue** resolves, renders as a link, and reads as provenance.
Nothing downstream checks that the issue it names has anything to do with the code
beside it.

Measured 2026-09-08 in rtj. Work with no issue was branched as `322-sern-thompson-2026`
on a guess, and four `rtj#322` citations went into a `project.yml` header and two
shared-library comments. A parallel session then filed #322 — about a STAC registration
script. Every citation was wrong, all four looked fine, and the real issue for the work
(#319) went uncited until the merge.

- **Cite an issue only after it exists.** If the work has no issue and does not warrant
  one, write no number: a comment that explains itself is better than a wrong pointer.
- **Before merging, resolve every issue number the branch introduces** and check the
  title is about this work — one call, and it is the only thing that separates a good
  citation from a plausible one:

  ```bash
  git diff --stat origin/main...HEAD >/dev/null   # three-dot: the branch's own changes
  git diff origin/main...HEAD | grep -oE '(^\+.*)(rtj|rfp|gq|soul|link)#[0-9]+' \
    | grep -oE '[a-z_]+#[0-9]+' | sort -u
  # then, per hit:
  gh issue view <N> --repo NewGraphEnvironment/<repo> --json title -q .title
  ```

- **Name the branch for the work when there is no issue** (`sern-thompson-2026`), and
  rename it once one exists — `git branch -m` before the first push costs nothing.

Sibling of the section above: both are parallel sessions moving underneath work that
looked settled when it started.

## The version lives in one place

Do not restate the current version in `README.md` or `CLAUDE.md` prose. A version
string typed into prose drifts from the moment it is written — the release step
maintains `DESCRIPTION` and `NEWS.md`, and one report repo's
`CLAUDE.md` was found eight minor versions behind, its `README.md` one behind, with both
canonical files correct. Link to `NEWS.md` instead. Where a claim genuinely must stay in
prose, `/gh-pr-merge` step 7 greps for the previous version string outside the two
canonical files and updates the prose restatements it finds, reporting each.

## When to Skip

For one-line typo fixes, version-bump-only PRs, or trivial documentation edits, the full workflow is overhead. Use judgment. The threshold is roughly: **multi-step issue, multi-file change, or anything that requires scoping** → use the workflow.

## Skills That Slot In

- `/planning-init <N>` — start
- `/planning-update` — sync checkboxes mid-session
- `/code-check` — before every commit
- `/planning-archive` — when issue closes
- `/gh-pr-push` — open the PR
- `/gh-pr-merge` — merge with release bookkeeping

## Issue bodies get edited, not appended

When work changes what an issue should say, **edit the body**. Don't add a
comment that corrects it, and retitle when the scope moves.

**Why:** an issue is read as a spec by whoever picks it up. A body saying one
thing with a comment three screens down saying the opposite costs the reader the
reconciliation, every time.

**How to apply:** `gh issue view N --json body -q .body` into a file, revise,
`gh issue edit N --body-file`. Name what changed and why when the correction is
load-bearing — the goal is a body that reads correctly top to bottom, not an
erasure of history. Comments are for genuine commentary: a merge notice, a
cross-repo pointer, a question. Applies to PR bodies too. Commit messages are
immutable history and are never rewritten this way.

**The failure mode that keeps recurring: research findings feel like
commentary.** They are not — they are the spec. If a finding changes what
someone would *build*, it belongs in the body, with the durable version in
`research/` and the body linking to it. What `research/` holds, how a file is
named and what its header carries is `planning.md`, "`research/` — what is
known, outliving the issue that found it".

**Bodies drift at the moment work finishes, not while it is in flight.** Four
instances in a single day of rfp work, all of the same shape — the code learned
something and the issue did not:

| drift | what a reader saw |
|---|---|
| premise disproved by measurement | an issue arguing for a fix that was no longer needed |
| a conclusion asserted in the body but never landed in code | body and tree contradicting each other |
| the shape of the work moved during exploration | a spec describing a design nobody built |
| a decision made and shipped, body still listing options A–D | "decision needed" on a decision a year old |

Vigilance does not catch this, because the drift happens exactly when attention
moves to the merge. `/gh-pr-merge` reconciles at that moment — see its step 3b.

## Why This Exists

We've hit snags repeatedly when half-doing this — branches that mix concerns, tests bolted on after, code-check skipped (and then a bug ships in the diff), examples that fail in pkgdown. Each step is small; the cumulative reliability gain is real. The convention is here so it becomes the default expectation, not a thing the user has to remind every session about.


# LLM Behavioral Guidelines

<!-- Source: https://github.com/forrestchang/andrej-karpathy-skills/main/CLAUDE.md -->
<!-- Last synced: 2026-02-06 -->
<!-- These principles are hardcoded locally. We do not curl at deploy time. -->
<!-- Periodically check the source for meaningful updates. -->

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

Some rules here fence their citations in a `<!-- evidence -->` block, which a repo's
`CLAUDE.md` omits and `/code-check` reads in full. A new citation goes inside that
rule's block, creating one at the end of the rule if it has none; the remedy stays in
the rule. `code-check.md`'s header states the rule once, and
`skills/compact-prep/SKILL.md` step 5 carries the habit.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

## 5. You Have No Clock Between Tool Calls

**Every duration claim comes from `date`, never from how much waiting felt like
it happened.**

Background `sleep` returns immediately from the agent's side, and the number of
times you have polled is not evidence of elapsed time. Two consecutive tool
calls can be 15 seconds apart by the clock while feeling like ten minutes of
waiting.

The failure is stating it out loud before checking. Observed 2026-08: a CI run
was reported to the user as "pending for over an hour — unusually long, probably
a stuck runner", after roughly eight background sleeps. One `date -u` showed the
run was **three minutes old** and entirely normal. The whole diagnosis — stuck
runner, duplicate triggers, something wrong with the workflow — rested on a
duration that had been invented.

**How to apply:** before saying *any* duration — "still running after N
minutes", "this has been X a while", "longer than usual" — run `date -u` and
subtract a real start time. `gh run list --json createdAt` gives it for CI. If a
claim about slowness would change what the user does next, it needs a measured
number or it does not get made.

The same rule covers process state. `ps` and task-status listings have both been
observed wrong; check the artifact (an output file's size, its mtime, the
service's own API) rather than the wrapper.

### The same blind spot picks the wrong waiting tool

Not having a clock also makes a **chain of background sleeps** feel like
waiting when it is not. Observed 2026-08 on the same session as the above:
roughly a dozen `sleep 570; check` background tasks were spawned to wait out a
55-minute test suite and then CI. Two consecutive foreground checks printed the
*same minute* — no wall time had passed between them, because the sleeps run
detached and the polling happened around them rather than after them. Every one
of those tasks was waste, and killing them produced a batch of eleven
exit-code-144 notifications that read like failures.

Pick the instrument by how many answers you need:

| you need | use |
|---|---|
| one notification when a condition becomes true | `Bash(run_in_background)` with an `until` loop that exits |
| one per state change, ending on its own | `Monitor` with a command that emits and then exits |
| a value you must have before the next step | a **foreground** call, so the blocking is explicit |
| a long job that notifies when it exits | `Bash(run_in_background)` with the command as plain foreground text: no `&`, no `nohup` |

A repeated `sleep N; grep` is right in none of them. **Tell: if you are about to
spawn a second waiter for the same thing, the first one was the wrong shape.**

A `Monitor` filter must also match the failure states, not just the success
one — silence looks identical to "still running", so a watcher that greps only
for the happy path stays quiet through a crash.

**Never end a backgrounded call's command with a trailing `&`.** A trailing `&` (or
`nohup … &`) with nothing in the same command waiting on it, sent with `run_in_background`,
lets the wrapper exit at once, so the notification reports **exit 0** whatever the job
then does: once it killed the job, and in another session the job ran to completion. Either
way the notification says nothing about the job. Pick one mechanism from the table, never
two. A `&` whose job the same command goes on to wait for, as in `with_deadline()`
(`code-check-shell.md`), is not this, and nor is the `nohup … &` fix in that file's
"`&` binds to the whole `&&` list" rule when the call itself is not backgrounded.

*5 lines of evidence for this rule are in `conventions/karpathy.md`, which `/code-check` reads in full.*

### Don't edit files a long-running suite is still reading

`devtools::test()` and its equivalents load each test file **when they reach it**,
not at launch. A 30-minute run therefore reads whatever is on disk at that moment,
so edits made mid-run are half-applied and the result describes a tree that never
existed.

Cost two full Docker suites (~1 hour) on rfp#178, both reporting `FAIL 1`. The
failure was a test written *during* the run, executing against source from *before*
the fix that made it pass — nearly reported as a regression. **The tell is a moving
denominator:** 3490 passes, then 3496, then 3500, on "the same" tree.

Before a long run, commit. While it runs, do work that touches nothing it reads —
issue bodies, PR text, reading, planning. If an edit cannot wait, kill the run
rather than let it produce a result that has to be re-litigated. And when a long run
fails, get the `file:line` before forming any theory: a mid-flight edit and a real
regression look identical in a summary line.

**It is not only test runners.** `Rscript file.R` parses incrementally too, so editing
any long-running script mid-run resumes the parser at a byte offset into shifted
content. The tell is different and worse: a **syntax error quoting a line that does not
exist**, which reads as a defect in code that is fine. The moving-denominator tell above
needs two runs to see; this one arrives looking like an answer.

*6 lines of evidence for this rule are in `conventions/karpathy.md`, which `/code-check` reads in full.*

## 6. Subagents Are Evidence, Not Dependencies

**Spawn on your own judgment. Don't block on one. Don't trust its status. Verify its claims in both directions.**

### Spawning is your call, not the user's

Deciding to spawn a subagent is an engineering judgment, the same kind as choosing
to write a test or run a grep. **Do not ask permission for it.**

The user is usually not positioned to answer. Knowing whether a fan-out beats a
sequential read requires knowing the shape of the work — which you have and they do
not, so the question forces them to guess at a technical call. Under **Always Away**
it is worse than useless: the work stalls until they wake up, for an answer that was
yours to make. *"I wouldn't be in the know enough to know when that is"*
(airvine, 2026-08-27) is the whole problem in one line.

This does not soften §1's asks — *"if uncertain, ask"* and *"if something is unclear,
stop and ask"*. Those are about **what the user wants**: intent, scope, an ambiguous
requirement, a tradeoff only they can weigh. This is about **how you carry it out**.
Ask about intent; decide about mechanism. A question starting "should I use…" is
almost always the second kind, and almost always yours to answer.

#### Standing authorization: the harness bars the Agent tool by default on Opus 5

Sessions on Opus 5 carry a hardcoded instruction from the CLI itself —
*"Do not call the AgentTool unless the user requested it"* — alongside the same
line for workflows and deep-research. It is not a setting anyone here
misconfigured, and **it cannot be turned off locally**: the string is a literal in the
CLI bundle, gated by remote config. Nothing in `~/.claude/settings.json` reaches it, so
do not spend a turn looking there.

The symptom is a skill quietly doing less than it says: `/code-check` reporting
*"the subagent rounds did not run — your session instruction bars the Agent
tool"*, which is the review the command exists to perform. It reads as a
configuration problem, so the fix gets looked for in the wrong place.

**The clause is conditional, so this convention is the request.** Invoking a
skill that mandates subagents — `/code-check`'s three rounds, the Plan review in
`planning.md` — **is** the user requesting them. Spawn them. This paragraph is a
standing user instruction, written for exactly that purpose (airvine,
2026-08-29), and CLAUDE.md project instructions override default behaviour by
their own terms.

It authorizes the mandated spawns and nothing wider: the bounds in this section
still hold — two or three concurrent, about five per task, no fan-out from a
child — and a workflow or deep-research run fanning out dozens of agents remains
a spending decision that needs an explicit ask.

**Spawn without asking when:**

- A skill or convention mandates it — `/code-check`'s review rounds, the Plan review
  in `planning.md`. That decision is already made; re-asking it is friction carrying
  no information.
- You want fresh eyes on your own work. The mechanism and the measurements behind it
  are in `code-check/SKILL.md`.
- A sweep over many files will **locate** what matters faster than reading serially.
  The sweep finds candidates; it does not replace the read — `planning.md` is
  explicit that agents sometimes report existing files as absent, so read directly
  whatever you are going to act on.
- Independent items can run concurrently and nothing downstream needs them ordered.

**Do it yourself when:**

- One grep answers it.
- The work depends on conversation context a subagent will not have.
- You would sit idle waiting — spawn and keep working, or do it inline.

**Bounds and defaults you enforce yourself, rather than converting into questions:**

- **Two or three concurrent is the working default, and about five per task** is
  where spend stops being incidental. Concurrency and cumulative total are different
  quantities — `/code-check`'s three rounds plus a Plan review plus an ad-hoc sweep
  never exceeds three at once while spending well past a handful. Bound both.
- Past that total, **say so in your next message.** An escape you grant yourself
  silently is not a bound; it has to land in front of the user, after the fact.
- **Do not let a subagent fan out again.** Intent does not enforce this — the child
  decides what it calls — so use the structure: the `Explore` and `Plan` types are
  defined without the `Agent` tool and *cannot* spawn. `general-purpose` can, so when
  you use it (as `/code-check` does), put "do not spawn subagents" in the prompt. The
  one case on record (see "Don't block" below) never had a root cause established, which
  is exactly why this bound is structural rather than advisory.
- Unnamed, delivering by file — `planning.md` carries the mechanics.
- **Report after, not before.** Say what you spawned, and relay what it found (per
  `code-check/SKILL.md` — a subagent's report never reaches the user on its own). A
  user can object to a spawn that already happened; they cannot usefully approve one
  that has not.

**What is genuinely the user's call is budget, not mechanism.** A workflow or
deep-research run fanning out dozens of agents is a spending decision and needs an
explicit ask. Two or three reviewers is not — that is just doing the work.

The cost of a review is the visible half and the benefit is not. Two reviewers over one
conventions draft returned **20 findings** and caught **six** false factual claims in it.
None of that happens if the spawn waits on a user who is away.

*9 lines of evidence for this rule are in `conventions/karpathy.md`, which `/code-check` reads in full.*

### Don't block

Spawn a background subagent, then keep working on the lowest-risk part of the
task — scaffolding, data files, tests. When findings arrive, treat them as a
review of landed work rather than a precondition for starting it.

If a result genuinely must precede the next step, run it synchronously
(`run_in_background: false`) so the blocking is explicit and visible.

Three observed cases where waiting would have been the expensive choice:

- A research agent spawned 5 children and deadlocked for **~3 hours**, still
  reporting as "running". The user caught it, not the agent.
- A `Plan` agent asked to review a `task_plan.md` *before the baseline commit*
  returned after the issue was implemented, reviewed, merged and tagged.
- The same pattern on a later issue: findings arrived after all four phases had
  shipped. Because the work had not waited, this cost nothing — three findings
  were still new and landed as follow-up commits.

That last one is the shape to aim for. Concurrent review is not a degraded
version of blocking review; it is often better, because the reviewer reads real
code instead of a plan.

### Don't trust status

**Never report an agent as "still running" without evidence.** Agent status and
`TaskList` have both been observed to be wrong — `TaskList` reported "No tasks
found" for an agent that was alive and later replied. Check the output file's
mtime before claiming progress, and say what you checked.

**And never record a review as "Clean" on the strength of an idle notification.**
From the parent's side an idle ping is indistinguishable from an agent that had
nothing to say, so a lost review reads as a pass — a whole `/code-check` pass was once
reported as finding nothing while three reviews were stranded, one of which had found
a data-loss bug (measured 2026-08-25; the numbers are in `planning.md`, "Spawn review
agents UNNAMED"). Passing `name` turns a spawn into a persistent teammate that idles
instead of completing; pass it only for a collaborator you will keep messaging, and
shut it down when done. The rule that survives either spawn shape:
the reviewer **writes its findings to a file and reports only the path**, and a
missing or empty file means the round produced nothing and is re-run — never
"Clean". `planning.md` carries the mechanics; `code-check/SKILL.md` applies them.

### Verify claims, in both directions

Subagent output is evidence, not verdict. Both failure modes are real:

- **Acting on a wrong finding.** One labelled BLOCKER — "`glue()` will choke on
  the literal braces in this fragment" — was disproved by a 30-second probe,
  because glue does not re-parse interpolated values. Acting on it would have
  meant rewriting a working generator.
- **Dismissing a late review wholesale.** In that same review 2 of 9 findings
  were real, including a dead link. In a later one, a finding that a
  `path|layername=` check would delete KML/GPX layers was correct, and was
  confirmed against 207 real datasources before the fix landed.

The rule that separates them: **cheap probe first, then act.** Reproduce the
claim before you fix it, and before you dismiss it. A finding you cannot
reproduce is a finding you do not yet understand.

### Fan out inside one process

A workflow that shells out **once per item** costs one permission prompt per item,
unless the command happens to be allowlisted. The same work done **inside one
process** costs one prompt total, and nothing says so until the run is already
going. Measured 2026-09-04 (knowledge#4): a harvest script issuing two `curl` calls
per report inside each subagent meant hundreds of approvals across a run — the user
had flagged it as *"a big time suck last time"* without knowing the cause — while a
sibling script doing the same fetch-download-upload work with Python `urllib` in a
single process cost **one** prompt for the entire run. Same task, same volume, three
orders of magnitude apart in interruptions.

It breaks **Always Away** directly: an unattended run that stops for approval on item
3 of 200 has not failed loudly, it has gone idle, and the wrapper reports nothing.

- **Prefer one process doing N items over N processes doing one.** Loop inside the
  language runtime; shell out once, for the batch.
- Where a per-item subprocess is genuinely required, allowlist its command **before**
  the run, not one refusal at a time during it — the allowlist fixes the commands you
  predicted, and the one that blocks is the one you did not.
- Diagnostic: if a run keeps stopping for approval, look at whether the loop sits
  inside or outside the process boundary before adding allowlist entries.

---

## 7. Evidence, Not Impressions

**Measure before you characterise. Presence is not provenance. "Unknowable" is a
claim.**

Six principles that all fail the same way: something *feels* established — because
it is visible, because it is present, because someone said so — and gets offered
with the confidence of a measurement.

### Measure before you characterise

When a decision turns on **what something contains**, open it and count. Do not
describe it from its structure, from an issue's claim about it, or from a tag list.
A heading tells you a thing is *present*, never that it is *populated* — an empty
`<conditionalstyles/>` and one with rules look identical in a list of child names.

Four instances in one rfp session, each corrected by the user's follow-up question
rather than by review: a tradeoff described as three times its real size; an issue's
stale claim repeated as current; an installed version reported as sixteen releases
behind when a parallel session had updated it eighteen minutes earlier; and "nothing
on main addresses this" from a local `main` three commits behind — one `git fetch`
away from the truth.

**A measurement carries the time it was taken.** One made earlier in the same
session is not a current one, least of all for anything another session can change
underneath it. For anything git-backed, `git fetch` first: reading a local clone and
reporting it as the state of the world is the same error with a longer fuse.

**And before hand-rolling a parser for a probe, check whether the code already has
one.** A bespoke parser silently narrows the population it can see, and the result
looks like a measurement rather than a sample — worse than not measuring, because it
carries a number. Measured 10 of 80 with a hand-written matcher; routed through the
package's own resolver it was 14 of 117.

### Presence is not provenance

When something's **presence** is offered as evidence for **how it got there**, find
the fact that actually discriminates. A QGIS project's `3.30.1` stamp was offered as
evidence a desktop had opened it — but the template it was copied from carries that
stamp, so a never-opened project reads the same. What actually proved it was a
tracking key the template does not contain.

The tell: reaching for the *most visible* fact rather than the *discriminating* one,
because the visible fact is consistent with the conclusion. **Consistency is not
support.** Before offering "X shows Y", ask what else would produce X. If anything
would, X is not evidence.

When the user pushes back on an inference, re-derive rather than defend. The
conclusion often survives; the reasoning that reaches it is usually different.

*9 lines of evidence for this rule are in `conventions/karpathy.md`, which `/code-check` reads in full.*

### Documents that share an ancestor corroborate nothing

Sibling of the rule above, one level out: there a *fact* was consistent with the
conclusion, here several *documents* are. Finding the same claim in three places
feels like triangulation and is not — if one was written from another, they are one
source wearing three hats, and the agreement is a copy, not a confirmation.

**The tell is agreement with no independent derivation.** Ask of each restatement:
what did its author read? If the answer is "one of the others", the count is one.
Prose repeats; code does not, so the discriminating check is almost always to read
the thing the prose describes.

**The release note is where this costs the most, because its readers cannot check it.**
Where a release note is written from the issue rather than from the artifact, its numbers
have been copied rather than derived, and no reader is positioned to notice.

Five habits:

- **Derive every number in a release note from the artifact it describes**, at the moment you
  write it. Not from the issue, not from the last release's notes, not from memory.
- **For any sentence of the form "you can tell X by looking at Y", check that Y actually
  separates X from not-X.** A discriminator that fires on everything discriminates nothing,
  and it reads as helpful right up until someone relies on it. A checksum over a re-encoded
  artifact is the standing example: it answers "are my bytes current" and can never answer
  "did the values change".
- **A carve-out is a number too, and reasoning one from the shape of a literal understates
  it.** Run the check over the population before writing the exception. A literal naming two
  excluded items does not mean every other input is covered: it names *two*, so a one-item
  tree is always missing at least one of them — including each of those two, which are
  missing each other — and the coverage is **zero for every one-item tree**, not merely
  capable of being zero. That error runs in the direction that understates the reach of a
  defect, in the document a reader uses to decide whether to backport.
- **When a document states a quantity or a scope, read the code that produces it
  before repeating it.** Especially a status section — it describes a moment, and
  nothing fails when the moment passes.
- **When you find one instance stale, grep for the sentence, not the file.** A claim that
  sits in three documents is not fixed by repairing the one that was quoted; the other two
  still read as authoritative.

*39 lines of evidence for this rule are in `conventions/karpathy.md`, which `/code-check` reads in full.*

### "It can only be answered by testing" is a claim with an author

An issue or a colleague saying a question needs a field season, a device or a deploy
is stating a claim, not a property of the problem. Spend the cheap probe first.

rfp#186 opened with "three questions decide whether this is viable, and none can be
answered by reading." Two fell in about twenty minutes — one to reading a call
graph, one to re-reading a file already on disk — turning "run a field season, then
decide what to build" into "build it, then confirm one thing."

The claim is usually made by someone who knows the domain, at a moment before they
looked. Not wrong so much as **unexamined**, which is what lets it survive into the
plan. Then **bound what the probe closed**: reading a desktop plugin says nothing
about the mobile app. An over-claimed probe is worse than none.

*6 lines of evidence for this rule are in `conventions/karpathy.md`, which `/code-check` reads in full.*

### A real bug is not necessarily the reported bug

A defect found while investigating a symptom is **evidence, not the answer**. Before
offering it as the cause, check that it produces *exactly* the symptom described,
including the details that sound incidental.

Two confident wrong causes in a row on rfp#196 — a layer missing from a map theme
(a real bug, fixed) and a sub-pixel geometry (a real measurement). Both true;
neither explained the report. The actual cause was draw order, and the user named it
himself. The discriminating fact was in his words all along: *"as soon as I stop
tracking I can't see the track"* rules out both theories in one line.

Finding a genuine defect feels like finding *the* defect — the relief of having an
explanation is what stops the check. Write the reported symptom out and ask whether
the proposed cause produces **all** of it. Say which parts are still unexplained:
"this is a real bug and it may not be your bug" is honest and cheap.

### An enumeration is not a checklist

A probe listing what exists — subkeys present, columns found, files listed — answers
"what is here", never "what do we want". Scope arriving this way looks
evidence-backed, so it survives review.

On rfp#68, "the two Mergin subkeys that exist" became "the settings to verify",
then an item on a field checklist a human had to walk outdoors to complete. Nothing
in the codebase read or wrote `PhotoNaming`. Before a probe's output becomes work,
grep for each item and ask whether anything consumes it. When it duplicates
something already done another way, name the comparison — the existing approach
usually wins for a reason worth stating.


### A relative descriptor is meaningless without its anchor

"Upstream", "downstream", "above", "below", "before", "after", "parent" — each is
relative to something named **elsewhere in the document**, often paragraphs away and
sometimes only in a table. Resolve the anchor before drawing any inference from the
term.

Getting it wrong does not produce uncertainty, it produces a confident and specific
wrong answer — and it fails in the worst direction, because you now believe you have
*evidence* against a claim rather than merely lacking evidence for it.

Measured 2026-09-02. A field report read *"downstream sampling confirmed the presence
of coho"*. Taken as downstream of the crossing under discussion, it appeared to
disprove the user's recollection that coho were present above that crossing. The
sampling site was actually at a road crossing 1.5 km further up the stream, so its
"downstream" was still **1.1 km above** the crossing in question — the claim was true
and the correction nearly removed it from an email to the infrastructure owner, on the
one point the email existed to make.

**Where a source describes a sequence — crossings on a stream, releases in a
changelog, stages in a pipeline, commits on a branch — write the order out before
interpreting a single relative term in it.** The ordering is usually one sentence in
the source and takes seconds to find; the inference built on the wrong anchor survives
every later check, because nothing downstream re-examines it.


### A safeguard whose mechanism is a human reading a diff is not a control

When a design says "the writes are uncommitted, so the diff is the review", check
whether anyone reads diffs. Here nobody does — the user says "commit" without opening
one, stated plainly and confirmed 2026-08-28 — so every per-action confirmation loop
built on that premise was latency wearing the costume of a control. Two skills had one.

Gate on **blast radius** instead, because that fires without anyone reading anything: a
write that reaches one repo just happens; a write that reaches every repo (a soul
convention) may be appended to freely but edited or removed only through an issue. Where
a real check is needed, make it mechanical — a grep for a contradicting rule, an
assertion that nothing above the `CLAUDE.md` marker moved, a guard that resolves every
heading against a base SHA. Those are the controls; a prompt is not.

The user still wants a short, honest account of what was written. That is a report, not a
review, and confusing the two is how the loops got built.

### Not finding it is not evidence it does not exist

Before building a fetcher, harvester, backup or sourcing routine, **search the sibling
packages for the verb**. One command, and it is the difference between adding a function
and adding a second copy of one.

```bash
# Enumerate the org's installed packages rather than listing them: a hardcoded list
# named four packages; thirteen other org packages were installed on the machine this
# was measured on (2026-09-05), and the gap will grow again. Match
# on any URL-ish field, case-insensitively: RemoteUsername is set only by GitHub
# installs (a package installed from a local checkout has none) and the org name is
# not always cased the same. Forks of upstream packages come along; that is fine.
# `collapse` matters: paste() over fields that are all NULL is character(0), and
# `if` on a zero-length grepl() aborts the whole enumeration (measured, soul#171).
for p in $(Rscript -e 'for (p in rownames(installed.packages())) {
  d <- packageDescription(p)
  u <- paste(c(d$URL, d$BugReports, d$RemoteUrl, d$RemoteUsername), collapse = " ")
  if (grepl("newgraphenvironment", u, ignore.case = TRUE)) cat(p, "\n") }'); do
  echo "== $p"; grep -E "^export" "$(Rscript -e "cat(system.file(package='$p'))")/NAMESPACE" \
    | grep -iE "source|fetch|harvest|backup|manifest|download|ingest|store|snapshot|read|write|conform"
done
ls ~/Projects/repo/rtj/scripts/gis/     # operational drivers live here, not in a package
```

**Then read the README ownership table and the above-marker `CLAUDE.md` of any package
plausibly adjacent — exports understate remit.** A package README can state a remit no
export names: that it exists so a report does not have to harvest its own copy, that it
pins per-snapshot sources, schema, md5 and row count. The grep finds functions; the README
is the load-bearing artifact, and it is the one nothing prompts you to open.

The failure is not carelessness — it is that **a decision is invisible from where the work
is happening**. The tool exists, is correct, and is three repos away in a directory you had
no reason to open. So the path of least resistance builds it again, and the duplicate is
plausible precisely because the original was never visible.

**Tell:** you are about to write something whose name is a verb the ecosystem already does
somewhere. Fetch, sync, harvest, backup, source, register, publish.

Two corollaries worth holding:

- **A function existing in two places is worse than it existing in neither.** Two live
  copies drift silently, and the drift is invisible until someone has both installed.
- **Check what the *architecture* says, not just what exists.** Not every instance is
  duplicate code; a wrong-home *proposal* is the same failure, and an issue that already
  assigned the boundary settles it for less than arguing from first principles costs.

Sibling of *"An inventory is only complete relative to a boundary"* in `code-check.md`, one
step earlier: that one is about a search that was complete for the wrong scope, this is
about never having searched the scope where the answer lived.

*26 lines of evidence for this rule are in `conventions/karpathy.md`, which `/code-check` reads in full.*

#### The storage version: one store is not the world

The same error with buckets instead of packages. The shape is a single negative check
reported as a fact.

The most general case: **`aws s3` and `s3cmd` address different clouds and are invisible to
each other.** A repo whose backup script uses `s3cmd` has stores that no `aws s3 ls` will
ever list, so "I checked S3" is not a statement about where the data is.

Two habits, each one command:

- **Enumerate the stores before searching them.** `s3cmd ls` and `aws s3 ls` with no
  argument each list only their own provider's buckets; the backup script names the rest.
- **Prefer the definition to the artifact.** The job that stages data says what exists; a
  bucket only shows what some past run happened to leave.

A negative result is only ever as wide as the store you looked in. Stating it without that
qualifier is how a gap in your own search becomes a fact in an issue body.

And the same shape once more for **checkouts**: a `grep` across `~/Projects/repo` searches
the repos this machine happens to have, not the ecosystem. Repos are cloned per-machine and
the set differs between them, so a local grep that returns clean has answered a question
about this disk. Use `gh api -X GET search/code -f q="org:NewGraphEnvironment <term>"`,
and note it indexes **default branches only**, so a file on a feature branch is invisible to it
and needs `gh api repos/<owner>/<repo>/contents/<path>?ref=<branch>`.

*12 lines of evidence for this rule are in `conventions/karpathy.md`, which `/code-check` reads in full.*

## 8. Decisions Up Front, Then Run

**Ask at the plan gate. After approval, run to the PR. Before a plan exists, a question wants an answer.**

The first three subsections are one rule on one axis — *when* to come back to the
user — and they are only correct as a set; each was learned separately in a different
repo and re-derived, usually by getting one of them wrong first. The rest are
handover rules that belong beside them because they decide what the user is handed
when you do come back.

### After plan approval, run every phase to the PR

Plan approval is the authorization for every mechanical step after it. Run every
phase, commit atomically per phase, archive the PWF, push, open the PR, and report
**once**, at the end. Do not stop between phases to report progress: the decisions
that needed the user were taken at the gate, and a check-in that only reports
spends attention already committed. Under **Always Away** the cautious answer is the
wrong one — the work stalls on a question the user answered by approving the plan.

The instruction arrives as one short message covering many commits, reviews and
repos: *"Go all phases to PR"* (airvine). **The merge is a separate instruction** — *to the PR*
ends at the open PR, and `/gh-pr-merge` runs when the user invokes it or the
instruction says so.

Two things are inside the mandate; these are not:

- **Correcting the plan is inside it.** A review that disproves an approved design
  decision gets fixed mid-run and reported in the summary; that is the run working,
  not a reason to stop — unless the correction is itself a fork of the kind below (a
  key, an identifier, a schema), which goes back to the user. Blockers that cannot be resolved are filed as issues and
  named in the final report rather than held open.
- **Our own repos are inside it.** Filing issues, opening PRs and editing bodies in
  NGE repos is normal work.
- **Outward-facing actions are not** — see "Never post outside our own repos" below.
  Neither is anything a convention names as its own gate: the merge (airvine, 2026-09-05;
  `gh-pr-push/SKILL.md`, "Ask user before merging"), a change to the machine
  (`newgraph.md`, "State the plan before changing the machine"), or a push into an
  artifact a human is testing on (`code-check.md`). A push to the feature branch is
  inside the mandate.

*7 lines of evidence for this rule are in `conventions/karpathy.md`, which `/code-check` reads in full.*

### Before a plan exists, a question wants an answer

The same terseness that means "go" after approval means "answer me" before it. A
turn that ends in a question mark, with no approved plan, gets an answer and a
one-line offer of the work — not the first commit toward it. Twice in one day
(floodplains, 2026-09-02) a question was read as approval and editing started — once
after *"why not fix before publish?"*, and once after a gap had been explained, stopped
with *"do not take on 70. i want to understand"*. When the ask is to understand something, keep it short and concrete; a
worked example beats a taxonomy. *"small answers here"*, *"keep it short"* (airvine).

This is the boundary condition on the rule above, which is why they are one section:
a standing mandate to run autonomously, stated alone, is exactly what reads every
terse message as "go". **The mandate starts at plan approval.**

### What still interrupts, and where it goes

A decision that permanently shapes stored data — a key, an identifier, a schema
choice, a deprecation shim versus a hard rename — is the user's, and it goes to the
**plan gate**, batched, as two or three concrete options with the recommended one
first and the consequence stated. Two such forks put at one gate (flooded#47) were
both load-bearing and neither was derivable from the issue: the rename would also
have broken a production driver in another repo, which only the sweep surfaced.
Asked at the gate a fork costs one round-trip and buys the whole run; discovered
mid-execution it costs a stall with nobody there to answer it. Found mid-run, it is
still not the agent's to decide: ask it the same way — options, recommendation first,
phone-answerable — commit, and continue on the phases that do not depend on it while
the answer is outstanding (`planning.md`, "When Something Keeps Failing" — escalating
is not stopping).

During plan-mode exploration, keep a list of "this changes what I build" forks and
ask them together before `ExitPlanMode`. Questions are welcome; status updates are
not. Mechanism — whether to spawn reviewers, which regex, how to build a fixture — is
never a question (§6, "Spawning is your call"), and anything with a conventional
default is not one either: pick it, say so, move on.

### Never post outside our own repos without approval

Never post to a venue outside NGE's own repositories without the user's explicit
approval for that specific post — upstream GitHub issues and PR comments, mailing
lists, forums, third-party trackers. **Drafting is welcome and expected**: write the
comment, show it, wait. It is the sending that needs the word. *"Never post things
upstream without my explicit approval"* (airvine, 2026-09-02, after an offer to draft
comments on two of a vendor's upstream issues).

**Why:** an upstream comment is published under the organisation's name to a venue we
do not control, is indexed immediately, and cannot be unpublished. It is a
communications act, not an engineering one, and the judgement about tone, timing and
what we are willing to say in public is the user's.

- Our own repos are unaffected; filing and editing issues there is the standing
  disposition and needs no asking.
- **Reading upstream is unrestricted and worth doing.** Checking issue state before
  filing ours has caught a wrong citation in our own roxygen and found an upstream
  issue already proposing the feature we were about to request.
- Offer the draft in the reply, not as a fait accompli, and say plainly that nothing
  has been posted when the work obviously produced something postable.

### Hand the user bare commands

When the user must run a command themselves — an interactive login, a
sudo-needs-TTY operation, anything the Bash tool is blocked from running — give the
**bare command**, in a fenced block, ready to paste. Never prefix it with `!`.
*"Give me the cmd without the ! - that never works btw"* (airvine, 2026-08-21);
*"stop giving me the ! at the start. that doesn't work. i need the raw cmd"* (`cd`, 2026-08).

**Why, twice over.** Default session guidance proposes the `!` prefix as a way to run
a command in-session, so this recurs in every repo unless written down. On this
operator's terminals it either does not run at all, or — where it does — **it ran from
`$HOME` rather than the session's working directory** (one measurement, 2026-09-02), so a
handed-over relative path created the file somewhere nobody was looking. Absolute paths are right whichever
directory it resolves against. So:

- Emit the command plain. Applies to fenced blocks and inline commands alike.
- **Absolute paths** in any handed-over command that touches files
  (`~/Projects/repo/<repo>/…`), whichever form the user ends up running it in.
- Keep it paste-safe: prefer `grep`/`awk` over a nested `python3 -c "…"` inside a
  single-quoted remote command, so the quoting survives the trip.

**A file under `~/Downloads` is unreadable by the agent process, and no retry helps.**
`Read`, `cp` and `pdftotext` on `~/Downloads/*` all fail with `Operation not permitted`.
It is macOS folder protection (TCC) on the process, not a Claude Code permission mode, so
`/permissions` does not change it; Desktop and Documents behave the same. Do not retry
variants — ask for **one** copy into the repo, with absolute source and destination paths,
then continue from the copy. (Granting the terminal app Full Disk Access removes it on one
machine; the fallback stays for the next machine.)

*4 lines of evidence for this rule are in `conventions/karpathy.md`, which `/code-check` reads in full.*

### Link every issue and PR you name to the user

When a message to the user names an issue or a PR, make the number a link the user can
click: `[soul#191](https://github.com/NewGraphEnvironment/soul/issues/191)`,
`[soul PR #192](https://github.com/NewGraphEnvironment/soul/pull/192)`. Terminal output
renders markdown, so a bare `#191` costs the user a browser, a repo, and a click through
several pages to learn what it was — for every number in a report that may carry a
dozen. *"want to be able to follow up without opening new browser and clicking through
mult pages to find"* (airvine, 2026-09-05).

- **Issues under `/issues/N`, pull requests under `/pull/N`.** They are different paths,
  and the type is not always obvious from a number. When unsure, ask `gh` rather than
  guess — it returns the canonical URL for either:
  ```bash
  gh issue view 192 --repo NewGraphEnvironment/soul --json url -q .url \
    || gh pr view 192 --repo NewGraphEnvironment/soul --json url -q .url
  ```
- **Cross-repo references carry the repo**: `rfp#268`, never a bare `#268` from inside
  soul.
- **A bare `#N` is not ambiguous — it is a working link to the wrong repo.** The host
  resolves it against the session's own repo, so a bare number in a discussion *about* a
  different repo silently retargets, and the wrong repo's issue of that number can be close
  enough in subject to read as correct. Naming the collision in prose afterwards does not
  fix it; the link has to be re-qualified.
- **Spot-check a subset, not every link.** Before sending a report with many numbers,
  resolve two or three through `gh` — the ones you typed from memory or whose type you
  inferred — and let the rest ride. Checking all of them would slow every message; checking
  none is how a wrong repo or an issue-path link to a PR ships.
- **Scope is messages to the user** — terminal replies, the compact-prep report, PR and
  issue bodies where a reader lands from outside the repo. Commit messages and issue bodies
  read *on* GitHub autolink `#N` already; do not bloat those.

*5 lines of evidence for this rule are in `conventions/karpathy.md`, which `/code-check` reads in full.*

### Surface upstream defects; do not work around them

When a dependency or an external API misbehaves, surface it and ask rather than
coding around it. *"dont' do workarounds for things like zotero api problems. surface
and ask as there may be simple solution"* (airvine, 2026-09-03).

**Why:** a workaround hides the defect from whoever could fix it properly, and the user
often has upstream context or a simple fix the session lacks. Most of the dependencies
in question are **first-party** — an upstream bug is usually ours — so a local patch
is strictly worse than an issue: it leaves the bug in place for every other consumer
while making this repo look fine. Same instinct as `newgraph.md`'s "install missing
packages, don't workaround", applied to a *broken* dependency rather than a *missing*
one.

**How to apply:** reproduce it minimally, file an issue in the owning repo with the
repro and the exact lines, report it, and carry on if it is not blocking. The rule is
*do not hide it*, not *do not continue*: the day it was recorded, a search function
failed on a list column and broke a documented pipeline step; the local guard would
have taken minutes and hidden a bug affecting every consumer, so it was filed with a
three-line repro and the pipeline continued, since its data path did not use search.

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.


# pkgdown Publishing

What a pkgdown deploy puts on the public internet, and the two ways that has
already gone wrong.

## A pkgdown site publishes every root-level markdown file

`pkgdown:::package_mds()` renders **every** `.md` in the package root except a
hardcoded allowlist — `README`, `LICENSE`, `NEWS`, and two GitHub templates.
There is **no config option to exclude a file**.

So `CLAUDE.md` gets published. So would `INTERNAL.md`, `NOTES.md`, or a PWF
`task_plan.md` left at the root.

**Repo visibility does not protect you.** GitHub Pages serves publicly
regardless of whether the repo is private, and there is no private Pages mode
below Enterprise Cloud. A private repo with a pkgdown deploy has public docs.

Measured 2026-08-23: `CLAUDE.html` was live on six NGE sites. On `rfp` and `gq` —
both private repos, so their `CLAUDE.md` legitimately carried the internal-only
conventions — that put the SR&ED section on the public web: claim structure,
field code, fiscal year, and the consultant by name.

The visibility filter was working correctly the whole time. It rests on an
assumption pkgdown breaks: that a private repo's `CLAUDE.md` stays private.

### Remove it before the build, not after

There are three copies, not one:

| file | what it is |
|---|---|
| `CLAUDE.html` | the rendered page |
| `CLAUDE.md` | a **verbatim copy of the source**, served as-is |
| `search.json` | the full-text index, containing the text |

Deleting `docs/CLAUDE.html` after the build leaves the other two. It looks like a
fix and achieves nothing. Remove the file from the CI checkout **before**
`build_site()` runs:

```yaml
- name: Keep internal notes out of the published site
  run: rm -f CLAUDE.md
```

### Gate on a declared allowlist

Each repo states which extra root pages it *intends* to publish. Anything else
fails the build, so a new root markdown file cannot leak silently:

```yaml
- name: Fail if an unexpected page reached the site
  run: |
    allowed="404 authors index LICENSE LICENSE-text"   # + declared extras
    ...
```

Add to `allowed` only after deciding the page should be public. `link` publishes
`NOTICE` and `RUNBOOK` deliberately — it is a public repo and both are genuine
documentation. That is the decision the allowlist is meant to record.

Test the gate against **both** known answers before shipping it: it must exit
non-zero on a site that does contain the file, and zero on one that does not. A
guard that only ever returns one value is indistinguishable from a broken one.

## Deploy with `clean: true`

`JamesIves/github-pages-deploy-action` defaults matter here. With
`clean: false`, the action **never deletes** — every file ever deployed stays on
`gh-pages` forever, whether or not the source still produces it.

Two consequences, both observed:

- Removing a file from the repo does **not** unpublish it. Measured on `gq`:
  `task_plan.html`, `progress.html` and `findings.html` were still returning 200
  long after the PWF documents had been moved out of the root.
- A leak cannot be fixed by fixing the build. The stale copies need a separate
  explicit purge, which is a step people forget.

`clean: true` makes the deployed site equal to what the build produced, so
removing a file from source removes it from the web on the next deploy. That is
the property you want, and it makes the site auditable.

### Check before flipping it

`clean: true` deletes anything on `gh-pages` not present in `docs/`. Confirm
none of these exist first:

- **`CNAME`** — a custom domain file would be deleted and the domain would break.
  (NGE repos have none; the domain comes from the org site repo, and project
  sites inherit it as subpaths.)
- **`dev/`** — versioned docs from `development: mode: devel`, if the deploying
  build is not the dev one.
- **hand-added assets** not produced by the build. Favicons and web manifests
  under `pkgdown/favicon/` *are* produced by the build and are safe.

Use `clean-exclude` for anything that must survive.

```bash
gh api "repos/OWNER/REPO/contents?ref=gh-pages" --jq '.[] | "\(.type) \(.name)"'
```

## Removing something already published

1. **Stop generating it** — the pre-build removal above.
2. **Remove the deployed copy** — automatic once `clean: true` is in; otherwise
   an explicit purge.
3. **De-index** — a Search Console removal request per property, *after* the URL
   404s.

Do **not** add a `robots.txt` block first. Blocking crawl prevents crawlers from
seeing the 404, which keeps stale search entries alive longer than doing
nothing.

`gh-pages` history is not a problem the way normal git history is: on a private
repo the branch is not publicly browsable, and only the currently-served content
is public. Deleting the file genuinely ends the exposure — no history rewriting.

## pkgdown drops a footnote's body and keeps its marker

A pandoc footnote — `text[^k]` with a `[^k]: …` block — renders in an article as a
**superscript marker with no footnote section under it**. The marker is emitted
(`class="footnote-ref"`), the content is not, and nothing warns.

So the failure is silent and lands on exactly the material a footnote is for: the caveat, the
definition, the reconciliation. Measured 2026-09-06 in drift#66, where a footnote carrying the
reconciliation of two circulating hectare totals — the sentence that stops a reader treating them
as a disagreement — was absent from the published page while `rmarkdown::render()` of the same
source showed it fine.

- **Do not write footnotes in a pkgdown article.** Promote the content to a block quote, a
  parenthetical, or its own short paragraph. If it is worth a footnote it is usually worth being
  visible.
- **Check the rendered HTML, not the source.** The tell is a marker with nothing to jump to:

  ```bash
  grep -c 'footnote-ref' docs/articles/<name>.html     # markers emitted
  grep -c 'class="footnotes' docs/articles/<name>.html # section emitted — expect these to agree
  ```

Same family as the cross-reference gotcha already noted for vignettes (`\@ref(fig:…)` compiling
to a literal): bookdown output formats do not carry all of bookdown's machinery through pkgdown,
and each missing piece fails quietly in its own way. Verify anything structural — footnotes,
cross-references, numbered captions — against the built page the first time you use it.


# Planning Conventions

How Claude manages structured planning for complex tasks using planning-with-files (PWF).

## When to Plan

Use PWF when a task has multiple phases, requires research, or involves more than ~5 tool calls. Triggers:
- User says "let's plan this", "plan mode", "use planning", or invokes `/planning-init`
- Complex issue work begins (multi-step, uncertain approach)
- Claude judges the task warrants structured tracking

Skip planning for single-file edits, quick fixes, or tasks with obvious next steps.

## The Workflow

1. **Explore first** — Enter plan mode (read-only). Read code, trace paths, understand the problem before proposing anything. When the work codifies a pattern that already exists in multiple places (reference implementations across repos), read **every** reference in full, not just the canonical one — variation across references surfaces patches before v0.1 instead of as churn later (soul#52: reading all 4 references preempted 5 of the 7 fixes a dry-run would have found). Don't substitute Explore-agent summaries for direct reads; agents sometimes report existing files as absent.
2. **Plan to files** — Write the plan into 3 files in `planning/active/`:
   - `task_plan.md` — Phases with checkbox tasks
   - `findings.md` — Research, discoveries, technical analysis
   - `progress.md` — Session log with timestamps and commit refs
3. **Plan-review with the Plan agent — concurrently, not as a gate** — Once `task_plan.md` is scaffolded, spawn the Plan subagent (`Agent({subagent_type: "Plan", prompt: "..."}`) and ask it to critically review the task_plan against the issue body + actual codebase. Categorize findings as Blocker / Gap / Ordering / Assumption / Scope / Acceptance. The agent reads files fresh — it catches what you miss when you've been thinking about the design too long. Real example: caught 21 issues including hardcoded literals across 4 files not listed in the plan, untested DB column mismatches, and a baseline-cache-shadow that would have produced a 6-second no-op run.

   **Do not wait for it.** Spawn, then start the lowest-risk phase. Background agents have repeatedly returned late — in one case after the entire issue had shipped — so treating the review as a precondition stalls the work for as long as the agent takes (see `karpathy.md` §6). Fold findings in whenever they land: pre-baseline they edit the plan; mid-implementation they become follow-up commits — unless the finding is a stored-data fork of the kind `karpathy.md` §8 reserves for the user. A review that arrives after the code is written is not wasted — the reviewer reads real code instead of a plan, which is how one late review still contributed three fixes that no earlier reading had found. If you genuinely cannot proceed without the result, run it with `run_in_background: false` so the blocking is explicit.

   Verify before acting, in both directions. Findings have been confidently wrong (a "BLOCKER" disproved by a 30-second probe) and confidently right about things nobody suspected. Reproduce the claim first.

   **"Both directions" includes the reviewer's conclusions, not just its findings.**
   A review is wrong in the *alarming* direction loudly — a BLOCKER you probe and
   disprove costs one round-trip. It is wrong in the *reassuring* direction
   silently, because nothing prompts you to check a sentence telling you that you
   are finished. Measured 2026-08-30 in gq#77: round 4 fixed its own finding and
   characterised the residual as "definitional". Two commands showed it was not —
   the leftover axis had exactly one member and no margin, the same shape as the
   instance that reviewer had just fixed. Treat *"this is now terminal / complete /
   definitional"* as a claim with an author, exactly like an issue asserting a
   question can only be answered by testing.

   Corollary on when to stop: **convergence is not a reviewer saying you have
   converged.** Across four rounds on that PR, five instances of one defect class
   were found, and three separate "this is terminal now" claims — two of them mine
   — were wrong. What ended it was enumerating the complete candidate set and
   showing nothing sat above its source, not another round.

   **Spawn review agents UNNAMED.** Passing `name` to the `Agent` tool changes what you get: a named spawn becomes a persistent *teammate* that goes **idle** rather than completing, so there is no final report to auto-deliver and its output must be pulled with `SendMessage`. An unnamed spawn is a fire-and-return subagent whose report arrives on its own in the completion notification. Measured 2026-08-25 on one machine, one session, unchanged settings: the unnamed spawn returned in **6.4s**; three named reviewers returned nothing at all, sending only empty idle pings. Pass `name` only for a collaborator you intend to keep messaging, and shut it down when done — it pings indefinitely otherwise.

   That mis-spawn is what produced the silent-delivery failures below, so check `name` before suspecting settings. Teammate mode (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` + `teammateMode`, merged globally from `soul/settings/defaults.json`) shapes what a *named* spawn becomes; it is not by itself why findings go missing, and an unnamed spawn delivers fine with it enabled.

   **Get the findings into a file — but check who is doing the writing.** Message delivery has silently failed twice: one review arrived as idle notifications with no content, and one was routed to a different session on the user's phone, surfacing only because the user mentioned it. From this side an idle ping is indistinguishable from an agent that had nothing to say, so the loss is invisible. A file (`planning/active/review-<N>.md`) survives routing, survives the agent exiting, and is greppable later.

   **The `Plan` and `Explore` agent types have no Write tool, so they cannot write that file.** Both plan reviews on 2026-08-26 (gq#61, gq#40) were instructed to and were structurally unable to; one said so outright — *"I have no Write/Edit tools and am explicitly barred from creating files; an agent instruction can't lift that"* — and returned the full review as reply text instead. Both arrived intact, ~26 findings each. So:

   - **Read-only agent** (`Plan`, `Explore`): ask for the findings **in the reply**, then write them to `planning/active/review-<N>.md` yourself. The file is still the deliverable; you are just the one creating it.
   - **Agent type that can write**: put the file-path instruction in the first prompt, not as a follow-up.

   Asking for a file the agent cannot produce costs a round-trip, and — worse — sets you up to read an absent file as an absent review. Check the agent type's tools before writing the instruction.

   **A reviewer asked to prove a guard fires will patch your working tree, and that races
   your own test runs.** "Restore the defect and watch it go red" is the right instruction
   (`code-check.md`), and a subagent given it edits the same files the parent is testing.
   From the parent's side the result is a test run that reports failures belonging to
   nobody's code — the reviewer's planted defect, caught mid-flight. Tell reviewers to work
   in a copy (`cp -r` to a temp dir, or a worktree) and say so in the prompt; they honour it
   when asked. Then snapshot the files you care about and `cmp` them before **and after**
   every run whose result you intend to act on, so "the tree was intact for this
   measurement" is a fact rather than an assumption. Same hazard as a mid-flight edit in
   `karpathy.md` §5, arriving from an agent instead of from you.

   **Review the fixes, not just the code.** The second pass is where the value concentrates, because a fix written under a wrong assumption reproduces the same defect. Measured on gq#52: pass 1 found 13 defects, pass 2 found 7 more — including a blocker sitting *inside the fix* for pass 1's blocker, the same class twice (`lty`, then `fill_alpha`) because completeness was reasoned about rather than computed. Pass 3, scoped narrowly to the file edited most, found no new instances; **convergence is the signal to stop, not a fixed number of rounds.**

   Convergence is measured, not felt — a quiet round and an exhausted reviewer look
   identical. The rule that terminated trap#28 (five rounds; each of the first four
   found its best defect *inside the previous round's fix*) was to **enumerate the
   candidate set mechanically and show nothing sits above its source of truth**: parse
   the files and walk every `cli_abort`/`warning`/`stop` rather than recalling them, so
   "all of them are pinned" is a count. For the guards a fix introduced, the equivalent
   instrument is a mutation table (`code-check.md`, "Restore the bug and prove the guard
   fires"). `code-check.md` states the enumeration rule under "A guard's
   scope, escape hatches, and remedies" — terminate by enumeration, not by a reviewer
   saying you have converged. `/code-check` treats three rounds as the floor and keeps
   going while a round finds a defect inside the previous fix.

   Ask for the **mechanism**, not more instances. Pass 3's best finding was that an invariant was enforced by two lists happening to agree — which is what had produced instances two and three.

   The thing reviewers catch that self-probing does not is **interop**: 18 tests inspected a legend object and none handed it to the renderer, which rejected it outright. Ask the consumer.
4. **Lock naming before the baseline** — If naming feedback surfaces during planning (legacy filename, inconsistency with an existing file family), fold the rename into the convention + task_plan BEFORE the baseline commit, not as a follow-up. Pre-baseline it's free; retrofitting after implementation cascades (soul#52: `build_exec_pdf.R` → `run_pagedown_exec_summary.R` locked in pre-baseline meant zero downstream rework).
5. **Commit the plan** — After Plan-agent review + fixes. This is the baseline.
6. **Work in atomic commits** — Each commit bundles code changes WITH checkbox updates in the planning files. The diff shows both what was done and the checkbox marking it done.
7. **Code check before commit** — Run `/code-check` on staged diffs before committing. Don't mark a task done until the diff passes review.
8. **Archive when complete** — Move `planning/active/` to `planning/archive/` via `/planning-archive`. Write a README.md in the archive directory with a one-paragraph outcome summary and closing commit/PR ref — future sessions scan these to catch up fast. Where the work produced measurements, that README is also the evidence record; see below.

## The archive README is the measurement record

Debugging and benchmarking sessions are systematic investigation: a stated unknown, an
experiment, a number, a conclusion, and usually two or three informative dead ends. That
is SRED evidence, and it scatters — into PR bodies, issue comments, and log files whose
names encode a timestamp and nothing else. In six months the chain *we did not know X,
we measured Y, therefore Z* survives only in a chat transcript.

**The archive README is where that chain lives.** Not a separate run record: the PWF
triple already holds every part of it — the question in `task_plan.md`'s frame, the
method in `progress.md`, the numbers in `findings.md`, the dead ends in its "Errors
Encountered" table. A second document would restate all of it and be half-populated.
The README is the index over them.

So an archive README for work that produced measurements carries two more sections:

```markdown
## Measurement

m1 0.0391 vs cypher 0.0872 min/1k segments — hosts are 2.23x apart.
Moved the provincial estimate 5.0 h -> 4.3 h and changed how work packs across machines.

## Evidence

`data-raw/logs/study_area_run/20260831_19*` — four spins, one defect each.
```

Three rules on those sections:

- **Numbers carry units, and say what changed because of them.** A measurement nobody
  acted on is still worth recording if it turned an assumption into a number — say that
  too. "Confirmed the expected" is a real outcome.
- **Cite a prefix or glob, never a file list.** A list rots the moment a run is re-run;
  a prefix survives. This is why campaign subdirectories exist (`newgraph.md`, "Which
  logs to commit").
- **Keep the wrong turns.** A diagnosis made, retracted on a bad inference, then
  confirmed by measurement *is* the evidence of systematic investigation. Sanitising it
  into a tidy conclusion destroys exactly what makes the record worth keeping.

**The case this does not cover.** Measurement that predates an issue has no PWF to
attach to — `/planning-init` takes an issue number, and exploratory runs often *produce*
the issues rather than follow them. That measurement belongs in the issue or PR it
spawned, with the log directory's own README as the index. Do not build a third system
to close this gap. The *finding* it settles goes where every settled finding goes —
`research/`, next section — which is not a third record of the run but the one place its
verdict is kept current.

## `research/` — what is known, outliving the issue that found it

Three homes, one job each: **the PWF archive is the story, committed logs are the
measurements, `research/` is the durable verdict** — floodplains' `research/README.md`
had that framing before this section existed. A research file holds what is now *known*: a
settled method, a measured fact about an external system, a search that established an
absence — so that someone picking the work up months later does not re-derive it.
`planning/archive/<issue>/` holds what was *done*, in order, for one issue, and is rarely
opened by anyone who never saw that issue. The research file is the one they will look for.

What does **not** go there: a work log; a run record (Run / Hardware / Software /
Configuration blocks — that is the archive README's `Measurement` and `Evidence`, above);
the raw numbers (committed logs). Measured 2026-09-06 across the seven repos carrying a
`research/`, 40 topic files: link's `provincial_parity_2026_05_*.md` are four run records in
25 days, each dated by the run it records and carrying that run's setup and metrics, while
its living documents, `bcfishpass_methodology.md`,
`study_area_run.md` and `provincial_run_runbook.md`, are single files revised as the
knowledge moved. The second shape is the one that moves the state of knowledge; the first
duplicates the archive.

### One topic file, revised in place — git is the version record

`research/<topic>.md`, noun-first, **no date in the filename**. A new measurement that
changes what is known revises the topic file; it does not add a dated sibling.
`git log --follow research/<topic>.md` is the dated history, the archive README it cites
is the *why*, and the logs are the numbers — everything an R&D claim needs, with no second
copy of any of it.

Existing dated files — `20260711_…`, `…_2026_05_25.md` — are **not renamed**. They are
cited by path from `CLAUDE.md` files and from other conventions (`bookdown.md`,
`karpathy.md` §7), and a rename breaks the citation the way it breaks log evidence
(`newgraph.md`, "Which logs to commit"). Convergence is forward-only, and the README says
when.

### The header is the provenance, in prose

No research file in any repo carries YAML frontmatter and nothing consumes it, so
provenance is one line under the H1. floodplains' is the shape to adapt — it already carries
the date and the issues, and names its log prefix in the body:

```markdown
**Date opened:** 2026-07-11 · **Issue:** #8 · **drift:** 0.6.0 (`dft_stac_fetch(tile_size=)`,
drift#36) · **Status:** OPEN — design set, runs pending.
```

Three things the line must carry — `**Verified:** <date> · **Issues:** … · **Produced by:** …`
is the minimal form:

- **When it was last true.** The file's date, and a section-level date wherever one
  section is re-verified alone. A research file whose numbers cannot be re-derived ages
  into folklore, and one that states a scope or a quantity drifts silently when the code
  moves — three link documents, two of them research files, asserted a recompute "runs over
  every WSG in the schema" after two commits had changed it (`karpathy.md` §7, "Documents
  that share an ancestor corroborate nothing"). When code changes a behaviour a research
  file describes, grep `research/` for the sentence. Files written before 2026-09-06 gain
  the line when next revised; no fleet sweep is required.
- **What produced it.** The script path or log prefix for a measurement; the source list or
  reference-manager collection for a literature review. Never a number without its producer.
- **Which issues it came from and which it spawned.** The issue body links the research
  file (`feature-workflow.md`, "Issue bodies get edited, not appended"); the research file
  names its issues; and an archive README whose `Measurement` was distilled into a research
  file links it. Both ways, every time — one direction leaves the other end unfindable.

### The directory carries a README

An index: one row per file, what it covers — rfp's is the model. Where other repos hold
related work, a "Related work" list of links. Where two naming patterns coexist, the
cutover line in the form `newgraph.md` uses for logs:

```markdown
Naming: `<topic>.md`, revised in place, from 2026-09-06.
Files dated before that carry a `yyyymmdd_` prefix; they are not being renamed.
```

The README is the index. `CLAUDE.md` links the README once and cites an individual file
only where a rule depends on it. Twenty-three topic files with no README and a `CLAUDE.md`
citing four of them by path — link, measured 2026-09-06 — is the state this prevents.

### R packages and public repos

`research/` is top-level and excluded from the tarball: `^research$` in `.Rbuildignore`
(`code-check-r.md`, "`R CMD build` ships every top-level directory not in
`.Rbuildignore`"). Not `inst/notes/` or `inst/research/`, which ship inside the installed
package — the three packages carrying those (eight files, 2026-09-06) migrate by issue,
forward-only. In a package, `research/` is also where durable reference notes go, because
`docs/` belongs to pkgdown and `inst/` ships. And a public tool repo's `research/` is
public: report findings from internal work aggregated, never by the names of who it was for.

## Atomic Commits (Critical)

Every commit that completes a planned task MUST include:
- The code/script changes
- The checkbox update in `task_plan.md` (`- [ ]` -> `- [x]`)
- A progress entry in `progress.md` if meaningful

This creates a git audit trail where `git log -- planning/` tells the full story. Each commit is self-documenting — you can backtrack with git and understand everything that happened.

## File Formats

### task_plan.md

Phases with checkboxes. This is the core tracking file.

```markdown
# Task: <issue title> (#<N>)

<issue body — Problem section if present, otherwise first paragraph>

## Phase 1: [Name]
- [ ] Task description
- [ ] Another task

## Phase 2: [Name]
- [ ] Task description
```

Mark tasks done as they're completed: `- [x] Task description`

### findings.md

Append-only research log. Discoveries, technical analysis, things learned.

```markdown
# Findings

## [Topic]
[What was found, with source/date]

## Errors Encountered

| Error | Resolution |
|-------|------------|
```

### progress.md

Session entries with commit references.

```markdown
# Progress

## Session YYYY-MM-DD
- Completed: [items]
- Commits: [refs]
- Next: [items]
```

<!-- The Reboot Test and the error ledger below are adapted from -->
<!-- OthmanAdi/planning-with-files (MIT). Soul does not install or invoke that -->
<!-- plugin — the useful parts are carried here as text. Adapted 2026-08-26. -->
<!-- Same precedent as the attribution header in karpathy.md. -->

## The Reboot Test

The planning files exist so the work survives an interruption. Whether they
actually do is checkable: at any point mid-task, these five questions must be
answerable from the files alone, without the conversation.

| Question | Answer source |
|----------|---------------|
| Where am I? | Current phase in `task_plan.md` |
| Where am I going? | Remaining phases in `task_plan.md` |
| What's the goal? | The `# Task: <title> (#N)` frame and problem statement at the top of `task_plan.md` |
| What have I learned? | `findings.md` |
| What have I done? | `progress.md` |

If an answer lives only in the session, **write it down and commit it**. Written
is not sufficient: an uncommitted `findings.md` does not move between machines,
and a repo whose `planning/` is gitignored accepts `git add planning/` with exit
0 while tracking nothing — see Directory Structure below.

This is the operational check for the rule that every interruption should be a
resume point: a session death, sleep, or machine swap should cost a re-run at
most, never lost context. That rule states the goal; this tests it.

Run it before any long wait, before compaction, and before switching machines —
the moments that take a session without warning. `/compact-prep` and
`/planning-update` are where it gets run; this section is what it asks.

## Directory Structure

```
planning/
  active/          <- Current work (3 PWF files)
  archive/         <- Completed issues
    YYYY-MM-issue-N-slug/
```

If `planning/` doesn't exist in the repo, run `/planning-init` first.

**`planning/active/` must be tracked, not gitignored.** The atomic-commit rule
above requires each commit to carry its own checkbox flip in `task_plan.md`; an
ignored `active/` drops it silently, so `git log -- planning/` shows archives
appearing fully-formed with no history behind them. In-flight PWF also stops
surviving a move between machines.

The failure is quiet in both directions. `git add planning/` reports nothing and
exits 0 on an ignored path, and files tracked *before* the rule existed keep
being tracked — including through a `git mv` into the ignored directory. So a
repo can look like it is working right up until the first genuinely new PWF file,
which simply never appears in a commit.

Check rather than assume:

```bash
git check-ignore -v planning/active/task_plan.md   # expect no output
```

Found 2026-08-24 in gq, where the rule dated from the scaffold commit and the
#17 files had only survived because they predated their move into that
directory. gq and roli were the only 2 of 32 repos carrying it; roli still does.

## When Something Keeps Failing

Before a second attempt, name the failure class. A **deterministic** failure
returns the same result to the same inputs, so re-running unchanged only spends a
turn — change the inputs or change the approach. A **transient** failure
(network, a provider read, a rate limit, a resource still settling) is the case
where a re-run *is* the attempt: `code-check-infra.md` prescribes exactly that for a
tofu plan that falsely reports a resource deleted. The rule is not "never retry";
it is never retry unchanged while expecting a different answer.

Escalate rather than iterate once the approach itself is in question. Report what
was tried and the exact error, and hand over the commands to run — the user is
assumed to be away, so a question answerable from a phone beats a retry loop they
cannot see. Escalating is not stopping: commit the current state, then move to
the lowest-risk independent part of the plan while the question is outstanding.

Two classes escalate immediately rather than after retries, because further
attempts make them worse:

- **A clamped session.** Once a live credential has been read, later
  system-mutating commands are refused regardless of route — seven consecutive
  refusals across unrelated routes is the documented case (`newgraph.md`,
  "Reading a secret clamps the rest of the session"). Trying more phrasings is
  the failure mode, not the remedy, and `/permissions` does not clear it.
- **Rate limits.** Retrying extends the block (`ci-monitoring.md`).

### Log the errors that cost a retry

An error that took more than one attempt to get past goes in `findings.md`, so
one task does not hit the same wall twice:

```markdown
## Errors Encountered

| Error | Resolution |
|-------|------------|
| `fatal: Unimplemented pathspec magic '_'` | Long-form `:(exclude)path` |
```

That row is also what graduation looks like: it began as one task's blocker and
now lives in `code-check-shell.md` as a general rule about pathspec magic. Most rows
never make that trip and should not — the ledger's job is to stop one task
repeating itself.

When a failure does generalize, it graduates to the convention that owns its
class: the `code-check*.md` family for a bug class in a diff — `code-check.md` for a
mechanism, `-shell`, `-r`, `-spatial` or `-infra` for a tool quirk — `ci-monitoring.md` for CI
behaviour, the domain convention otherwise.

## Skills

| Skill | When to use |
|-------|-------------|
| `/planning-init` | First time in a repo — creates directory structure |
| `/planning-update` | Mid-session — sync checkboxes and progress |
| `/planning-archive` | Issue complete — archive and create fresh active/ |


# R Package Development Conventions

Standards for R package development across New Graph Environment repositories.
Based on [R Packages (2e)](https://r-pkgs.org/) by Hadley Wickham and Jenny Bryan.

**Reference packages:** When starting a new package, study these existing
packages for patterns: `flooded`, `gq`. They demonstrate the conventions below
in practice (DESCRIPTION fields, README layout, NEWS.md style, pkgdown setup,
test structure, hex sticker, etc.).

## Style

- tidyverse style guide: snake_case, pipe operators (`|>` or `%>%`)
- Match existing patterns in each codebase
- Use `pak` for package installation (not `install.packages`)
- Prefer `fs::` helpers over base R for filesystem path operations in build
  scripts and scaffolds: `fs::dir_create()` (creates parents by default, no
  `recursive`/`showWarnings` fiddliness), `fs::path()`, `fs::file_delete()`,
  `fs::file_exists()`, `fs::path_file()`. Avoids cross-platform separator
  issues and silent no-ops on empty paths.
- Prefix column name vectors with `cols_` for discoverability in the
  environment pane: `cols_all`, `cols_carry`, `cols_split`, `cols_writable`.
  Same principle for other grouped vectors (`params_`, `tbl_`, etc.)
- For SQL DDL+INSERT pairs that share a schema, use a single named
  vector as the source of truth. Both `CREATE TABLE` and
  `INSERT (cols) SELECT cols` derive their column lists from the same
  `cols_*` vector. Avoids drift between table shape and write
  projection — when columns change, you edit one place. Example:
  ```r
  cols_streams <- c(
    id_segment           = "integer NOT NULL",
    watershed_group_code = "varchar(4) NOT NULL",
    geom                 = "geometry(MultiLineStringZM, 3005)"
    # …
  )
  # CREATE TABLE consumes both names + types
  ddl_body <- paste(names(cols_streams), unname(cols_streams), sep = " ",
                    collapse = ", ")
  # INSERT consumes names only
  proj <- paste(names(cols_streams), collapse = ", ")
  ```

## Package Structure

Follow R Packages (2e) conventions:
- `R/` for functions, `tests/testthat/` for tests, `man/` for docs
- `DESCRIPTION` with proper fields (Title, Description, Authors@R)
- `DESCRIPTION` URL field: include both the GitHub repo and the pkgdown site
  so pkgdown links correctly (e.g., `URL: https://github.com/OWNER/PKG,
  https://owner.github.io/PKG/`)
- `NAMESPACE` managed by roxygen2 (`#' @export`, `#' @import`, `#' @importFrom`)
- Never edit `NAMESPACE` or `man/` by hand

## One Function, One File

Each exported function gets its own R file and its own test file:
- `R/fl_mask.R` → `tests/testthat/test-fl_mask.R`
- Commit the function and its tests together
- Use `Fixes #N` in the commit message to close the corresponding issue

## GitHub Issues and SRED Tracking

### Issue-per-function workflow

File a GitHub issue for each function before building it. This creates a
traceable record of what was planned, built, and verified.

### Branching for SRED

For new packages or major features, work on a branch and merge via PR:

```
main ← scaffold-branch (PR closes with "Relates to NewGraphEnvironment/sred#N")
```

This gives one PR that contains all commits — a single SRED cross-reference
covers the entire body of work. Individual commits within the branch close
their respective function issues with `Fixes #N`.

### Closing issues

Close function issues via commit messages — see Closing Issues in newgraph conventions.

## Testing

- Use testthat 3e (`Config/testthat/edition: 3` in DESCRIPTION)
- Run `devtools::test()` before committing
- Test files mirror source: `R/utils.R` -> `tests/testthat/test-utils.R`
- Test for edge cases and potential failures, not just happy paths
- Tests must pass before closing the function's issue
- Always grep for errors in the same command as the test run to avoid
  running twice:
  ```bash
  Rscript -e 'devtools::test()' 2>&1 | grep -E "(FAIL|ERROR|PASS)" | tail -5
  ```
  For error context: `grep -E "(ERROR:|FAIL )" -A 10 | head -25`

### Common pitfalls

- **`cli::cli_alert_warning()` is not `warning()`.** It's visual only —
  callers can't catch it with `withCallingHandlers(warning = ...)` and
  testthat's `expect_warning()` won't fire. When a function offers a
  `warn` mode that callers may want to react to programmatically, use
  `warning()`. Reserve `cli_alert_warning()` for FYI messages with no
  programmatic contract.

- **`expect_match(x, ..., all = FALSE)` passes silently on `character(0)`.**
  If the input is empty (e.g. no warnings fired), the assertion succeeds
  vacuously and defeats the test. Always pair with
  `expect_gt(length(x), 0)` first when input may be empty.

- **`skip_on_cran()` does not skip on GitHub Actions.** It skips when
  `NOT_CRAN` is unset — and `devtools`, `usethis`'s check workflow and
  `r-lib/actions` all set `NOT_CRAN=true`, precisely so your tests *do* run in
  CI. So a network test guarded only by `skip_on_cran()` runs on every push,
  and any upstream hiccup reddens the build for a reason unrelated to the
  change under review.
  - Use **`skip_on_ci()`** for a test that is meant for a human's machine — a
    live canary against a third-party service, something slow, anything whose
    failure needs a person to interpret it.
  - `skip_if_offline()` is not a substitute: it tests whether the network is
    reachable, not whether the *service* is behaving, and it calls
    `skip_if_not_installed("curl")`, so add `curl` to Suggests or the guard
    itself is what breaks.
  - Caught 2026-08 in gq#57 by self-review: a comment claiming "skipped off-CI"
    sat directly above code that did not skip off-CI. Read the guard, not the
    comment above it.

- **`testthat::test_file()` does NOT set `NOT_CRAN`, so re-running one file to
  diagnose a failure can execute none of it.** The mirror of the rule above, and
  the more dangerous direction: `devtools::test()` sets `NOT_CRAN=true`, so a
  `skip_on_cran()`-guarded test runs there and fails; re-running that same file
  with `testthat::test_file()` to investigate reports `SKIP` and looks like
  exoneration.

  ```
  devtools::test()                 -> [ FAIL 1 | PASS 4495 ]
  testthat::test_file("that.R")    -> [ FAIL 0 | SKIP 6 ]   Reason: On CRAN
  NOT_CRAN=true testthat::test_file("that.R") -> [ FAIL 0 | PASS 259 ]
  ```

  Only the third line is evidence. Measured twice on 2026-09-01 in rfp, both
  times while confirming whether a Docker-gated failure was a real regression —
  which is exactly when a false "it passes now" is most expensive. Prefix
  `NOT_CRAN=true` on any single-file re-run, or read the SKIP count rather than
  the FAIL count.

- **`local_mocked_bindings(.package = )` needs testthat >= 3.2.0.** A package
  pinned at `testthat (>= 3.0.0)` errors rather than skipping on an older
  install. Bump the pin when you first mock another package's binding.

## Examples and Vignettes

### Runnable examples on every exported function

Examples are how users discover what a function does. They must:
- **Actually run** — no `\dontrun{}` unless external resources are required
- **Use bundled test data** via `system.file()` so they work for anyone
- **Show why the function is useful** — not just that it runs, but what it
  produces and why you'd use it
- **Use qualified names** for non-exported dependencies (`terra::rast()`,
  `sf::st_read()`) since examples run in the user's environment

### Vignettes

At least one vignette showing the full pipeline on real data:
- Demonstrates the package solving an actual problem end-to-end
- Uses bundled test data (committed to `inst/testdata/`)
- Hosted on pkgdown so users can read it without installing

**Output format:** Use `bookdown::html_vignette2` (not
`rmarkdown::html_vignette`) for figure numbering. Requires `bookdown` in
Suggests and chunks must have `fig.cap` / `caption =` for numbered
figures and tables.

**Gotcha — cross-references don't resolve in vignettes.** `Table \@ref(tab:foo)`
and `Figure \@ref(fig:foo)` markers compile to a literal `\@ref(...)` in
the rendered HTML rather than a numbered link. Bookdown's cross-ref
machinery isn't fully wired through `html_vignette2` under pkgdown.
Use natural language instead — "the table below", "the floodplain map",
"the parameter table" — and let the captions speak for themselves. If
you need real numbered cross-refs, use `bookdown::html_document2`
(matches the cd-style report-appendix pattern) and accept that the
output is no longer a true package vignette.

**Vignettes that need external resources (DB, API, STAC):** Do NOT use
the `.Rmd.orig` pre-knit pattern — it breaks `bookdown` figure numbering
because knitr evaluates chunks during pre-knit and emits `![](path)`
markdown that bookdown can't number.

Instead, separate data generation from presentation:
1. `data-raw/vignette_data.R` — runs the queries, saves results as `.rds`
   to `inst/testdata/` (or `inst/vignette-data/`)
2. Vignette loads `.rds` files, all chunks run live during pkgdown build
3. Note at top of vignette: "Data generated by `data-raw/script.R`"
4. bookdown controls all chunks — figure numbers, cross-refs work

This is the same pattern as test data: `data-raw/` documents how the data
was produced, committed artifacts make vignettes reproducible without the
external resource.

### Test data

- Created via a script in `data-raw/` that documents exactly how the data
  was produced (database queries, spatial crops, etc.)
- Committed to `inst/testdata/` — small enough to ship with the package
- Used by tests, examples, and vignettes — one dataset, three purposes

## Documentation

- roxygen2 for all exported functions
- `@import` or `@importFrom` in the package-level doc (`R/<pkg>-package.R`)
  to populate NAMESPACE — don't rely on `::` everywhere in function bodies
- pkgdown site for public packages with `_pkgdown.yml` (bootstrap 5)
- GitHub Action for pkgdown (`usethis::use_github_action("pkgdown")`)

## lintr

Run `lintr::lint_package()` before committing R package code. Fix all warnings — every lint should be worth fixing.

### Recommended .lintr config

```r
linters: linters_with_defaults(
    line_length_linter(120),
    object_name_linter(styles = c("snake_case", "dotted.case")),
    commented_code_linter = NULL
  )
exclusions: list(
    "renv" = list(linters = "all")
  )
```

- 120 char line length (default 80 is too strict for data pipelines)
- Allow dotted.case (common in base R and legacy code)
- Suppress commented code lints (exploratory R scripts often have commented alternatives)
- Exclude renv directory entirely

## Dependencies

- Minimize Imports — use `Suggests` for packages only needed in tests/vignettes
- Pin versions only when breaking changes are known
- Prefer packages already in the tidyverse ecosystem

## Releasing

1. Update `NEWS.md` — keep it concise:
   - First release: one line (e.g., "Initial release. Brief description.")
   - Later releases: describe what changed and why, not function-by-function.
     Link to the pkgdown reference page for details — don't duplicate it.
   - Don't list every function; the pkgdown reference page is the single
     source of truth for what's in the package.
2. Bump version in `DESCRIPTION` (e.g., `0.0.0.9000` → `0.1.0`) — as the **final** commit of the branch, after verification numbers/tests are final. Mid-branch bumps are premature and churn: additional code changes end up bundled inside a "release" that already claimed the version.
3. Commit as "Release vX.Y.Z"
4. Tag: `git tag vX.Y.Z && git push && git push --tags`

## Repository Setup

### Branch protection

Protect main from deletion and force pushes:

```bash
gh api repos/OWNER/REPO/rulesets --method POST --input - <<'EOF'
{
  "name": "Protect main",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [
    { "actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always" }
  ],
  "conditions": { "ref_name": { "include": ["refs/heads/main"], "exclude": [] } },
  "rules": [ { "type": "deletion" }, { "type": "non_fast_forward" } ]
}
EOF
```

### Scaffold checklist

- `usethis::create_package(".")`
- `usethis::use_mit_license("New Graph Environment Ltd.")`
- `usethis::use_testthat(edition = 3)`
- `usethis::use_pkgdown()`
- `usethis::use_github_action("pkgdown")`
- `usethis::use_directory("dev")` — reproducible setup script
- `usethis::use_directory("data-raw")` — data generation scripts
- Hex sticker via `hexSticker` (see `data-raw/make_hexsticker.R`)
- Set GitHub Pages to serve from `gh-pages` branch

### dev/dev.R

Keep a `dev/dev.R` file that documents every setup step. Not idempotent —
run interactively. This is the reproducible recipe for the package scaffold.

## README

Keep the README lean:
- Hex sticker, one-line description, install, example showing *why* it's
  useful
- Link to pkgdown vignette and function reference — don't duplicate them
- Don't maintain a function table — it's just another thing to keep updated
  and pkgdown's reference page is the single source of truth

## LLM Workflow

When an LLM assistant modifies R package code:
1. Run `lintr::lint_package()` — fix issues before committing
2. Run `devtools::test()` with error grep — ensure tests pass in one call:
   ```bash
   Rscript -e 'devtools::test()' 2>&1 | grep -E "(FAIL|ERROR|PASS)" | tail -5
   ```
3. Run `devtools::document()` and grep for results:
   ```bash
   Rscript -e 'devtools::document()' 2>&1 | grep -E "(Writing|Updating|warning)" | tail -10
   ```
4. If the repo has a `_pkgdown.yml`, run `Rscript -e 'pkgdown::check_pkgdown()'`
   after adding or removing an export. A new export missing from the reference
   index is an **error**, not a note, so it reddens the pkgdown workflow after
   the PR is already open — the check costs a second locally and saves the round
   trip. (Adding to the index is usually right; `@keywords internal` is the
   alternative it names.)
5. Check `devtools::check()` passes for releases — capture results in one call:
   ```bash
   Rscript -e 'devtools::check()' 2>&1 | grep -E "(ERROR|WARNING|NOTE|errors|warnings|notes)" | tail -10
   ```


# Reference Management Conventions

How references flow between Claude Code, Zotero, and technical writing at New Graph Environment.

## Tool Routing

Three tools, different purposes. Use the right one.

| Need | Tool | Why |
|------|------|-----|
| Search by keyword, read metadata/fulltext, semantic search | **MCP `zotero_*` tools** | pyzotero, works with Zotero item keys |
| Look up by citation key (e.g., `irvine2020ParsnipRiver`) | **`/zotero-lookup` skill** | Citation keys are a BBT feature — pyzotero can't resolve them |
| Create items, attach PDFs, deduplicate | **`/zotero-api` skill** | Connector API for writes, JS console for attachments |

**Citation keys vs item keys:** Citation keys (like `irvine2020ParsnipRiver`) come from Better BibTeX. Item keys (like `K7WALMSY`) are native Zotero. The MCP works with item keys. `/zotero-lookup` bridges citation keys to item data.

**BBT citation key storage:** As of Feb 2025+, BBT stores citation keys as a `citationKey` field directly in `zotero.sqlite` (via Zotero's item data system), not in a separate BBT database. The old `better-bibtex.sqlite` and `better-bibtex.migrated` files are stale and no longer updated. Query citation keys with: `SELECT idv.value FROM items i JOIN itemData id ON i.itemID = id.itemID JOIN itemDataValues idv ON id.valueID = idv.valueID JOIN fields f ON id.fieldID = f.fieldID WHERE f.fieldName = 'citationKey'`.

**BBT citekey format is locally patched to strip `&`:** the `citekeyFormat` pref (`extensions.zotero.translators.better-bibtex.citekeyFormat` in `~/Library/Application Support/Zotero/Profiles/*/prefs.js`) has a `.replace(find = "&", replace = "")` segment added by hand. Without it, institutional authors containing `&` (e.g. "BC Species & Ecosystem Explorer", "WA Dept of Fish & Wildlife") leak `&` into the citekey, and pandoc's `@key` parser stops at `&` — so cites render broken in any bookdown/quarto build even though biblatex accepts the key. Reapply via Zotero → Tools → Run JavaScript: `Zotero.Prefs.set("translators.better-bibtex.citekeyFormat", val)` (also patch `citekeyFormatEditing` to match). Survives Zotero/BBT auto-updates; reverts only on a profile reset or a manual edit via the BBT preferences UI. Detect drift: `grep citekeyFormat ~/Library/Application\ Support/Zotero/Profiles/*/prefs.js` should show the `.replace(find = "&", ...)` chain. Teammates on Skeena/Fraser/restoration machines that hit the same `@key`-breaks-at-`&` drift should run the same `Zotero.Prefs.set`.

## Which routes are live by default

Measured 2026-09-04 on a freshly provisioned machine. Four of the six routes below were
dead, and each dead end costs a session time it has no reason to expect:

| route | state on a default setup |
|---|---|
| **Web API** | **works** — the route to use for writes; targets a collection directly via `"collections": [...]` and needs Zotero neither open nor restarted for the write itself |
| **read-only SQLite** | works, and remains the best route for *searching* (`/zotero-lookup`) |
| MCP `zotero_*` | unavailable until an API key is configured — the install script registers the server but never configures a key |
| Local API | `403 Local API is not enabled`, with and without the `Zotero-Allowed-Request` header |
| Connector `saveItems` | HTTP 500 on a minimal item with exactly the documented headers — a defect, not a permission; reads on the same port (`ping`, `getSelectedCollection`) are fine, and `getSelectedCollection` returns the whole collection tree in one call |
| JS runner (`zotero_run_js.sh`) | `osascript is not allowed assistive access` until the terminal has Accessibility |

**Zotero's server takes about 30 s after launch to respond.** An early failure does not
mean it is not running, which is exactly the wrong conclusion to draw at that moment —
wait and retry once before diagnosing.

The key's location, the password-manager item that holds it and the local port are
infrastructure identity and stay in machine-local memory, not here (soul#177).

**`immutable=1` serves a stale snapshot, so it cannot confirm a write landed.** The
read-only URI the skills prescribe —
`sqlite3 "file:$HOME/Zotero/zotero.sqlite?mode=ro&immutable=1"` — is right for
*searching*, and it is exactly wrong for *verifying*: `immutable` tells SQLite the file
cannot change, so it skips the WAL and the change counter and serves whatever it first
mapped. A write made through the Web API is invisible to it for as long as the process
lives, which reads as "the write failed" rather than "this reader cannot see it". Copy
the file first when the question is whether something landed, and note that a Web API
create also needs Zotero to **sync** before it is in the local database at all.

Three skills prescribe that URI (`zotero-lookup`, `zotero-api`, `lit-search`) and none
of them says this, which is why it is here rather than in one of them.

## Citation keys are BBT-auto-derived

**Never set `Citation Key:` in the `extra` field.** BBT honours it as a manual override,
and that breaks the convention that every key follows one formula: stable, reproducible,
the same key for the same paper on every collaborator's machine. Leave `extra` empty, or
use it only for other Zotero-supported fields (`Original Date:`, `tex.shorttitle:`).
Ten items created with hand-set keys in one lit review (cd#58, 2026-05-05) had to be
PATCHed clean after the user caught it.

- **Web API-created items get no key until Zotero restarts.** Sync alone does not trigger
  BBT. On macOS:
  ```bash
  osascript -e 'tell application "Zotero" to quit'; sleep 3; open -a Zotero; sleep 30
  ```
  Thirty seconds covered seven fresh items (cd#61); scale the wait with the batch.
- **Corporate-author guard.** CrossRef sometimes returns no individual authors (a paper
  bylined to a working group), so the POST lands with empty `creators` and BBT falls back
  to a `<title-prefix><year>` key. PATCH the individual authors from the paper's roster
  into `creators` before triggering the restart.
- **BBT and Zotero version lines are paired** — BBT 8.x for Zotero 7, 9.x for Zotero 8/9.
  If Zotero auto-disables BBT after an update, keys silently stop generating for new
  items; reinstall the matching line via Plugin Manager → gear → "Install Plugin From
  File…" from the BBT releases page.

`/lit-search` and `/zotero-api` point here; this is the authority (soul#43).

## Adding References Workflow

### 1. Search and flag

When research turns up a reference:
- **DOI available:** Tell the user — Zotero's magic wand (DOI lookup) is the fastest path
- **ResearchGate link:** Flag to user for manual check — programmatic fetch is blocked (403), but full text is often there
- **BC gov report:** Search [ACAT](https://a100.gov.bc.ca/pub/acat/), for.gov.bc.ca library, EIRS viewer
- **Paywalled:** Note it, move on. Don't waste time trying to bypass.

### 2. Add to Zotero

**Preferred order:**
1. DOI magic wand in Zotero UI (fastest, most complete metadata)
2. Web API POST with `collections` array (grey literature, local PDFs — targets collection directly, no UI interaction needed)
3. `saveItems` via `/zotero-api` (batch creation from structured data — requires UI collection selection)
4. JS console script for group library (when connector can't target the right collection)

**Collection targeting:** `saveItems` drops items into whatever collection is selected in Zotero's UI. Always confirm with the user before calling it. **Web API bypasses this** — include `"collections": ["KEY"]` in the POST body. Find collection keys with `?q=name` search on the collections endpoint.

### 3. Attach PDFs

`saveItems` attachments silently fail. Don't use them. Instead:

1. **Web API S3 upload (preferred):** Create attachment item → get upload auth → build S3 body (Python: prefix + file bytes + suffix) → POST to S3 → register with uploadKey. Works without Zotero running. See `/zotero-api` skill section 4.
2. **JS console fallback:** Download with `curl`, attach via `item_attach_pdf.js` in Zotero JS console.
3. Verify attachment exists via MCP: `zotero_get_item_children`

### 4. Verify

After manual adds, confirm via MCP:
- `zotero_search_items` — find by title
- `zotero_get_item_metadata` — check fields are complete
- `zotero_get_item_children` — confirm PDF attached

### 5. Clean up

If duplicates were created (common with `saveItems` retries):
- Run `collection_dedup.js` via Zotero JS console
- It keeps the copy with the most attachments, trashes the rest

## In Reports (bookdown)

### Bibliography generation

```yaml
# index.Rmd — dynamic bib from Zotero via Better BibTeX
bibliography: "`r rbbt::bbt_write_bib('references.bib', overwrite = TRUE)`"
```

`rbbt` pulls from BBT, which syncs with Zotero. Edit references in Zotero → rebuild report → bibliography updates.

**Library targeting:** rbbt must know which Zotero library to search. This is set globally in `~/.Rprofile`:

```r
# default library — NewGraphEnvironment group (libraryID 9, group 4733734)
options(rbbt.default.library_id = 9)
```

Without this option, rbbt searches only the personal library (libraryID 1) and won't find group library references. The library IDs map to Zotero's internal numbering — use `/zotero-lookup` with `SELECT DISTINCT libraryID FROM citationkey` against the BBT database to discover available libraries.

### Citation syntax

- `[@key2020]` — parenthetical: (Author 2020)
- `@key2020` — narrative: Author (2020)
- `[@key1; @key2]` — multiple
- `nocite:` in YAML — include uncited references

### Cite primary sources

When a review paper references an older study, trace back to the original and cite it. Don't attribute findings to the review when the original exists. (See LLM Agent Conventions in `newgraph.md`.)

**When the original is unavailable** (paywalled, out of print, can't locate): use secondary citation format in the prose and include bib entries for both sources:

> Smith et al. (2003; as cited in Doctor 2022) found that...

Both `@smith2003` and `@doctor2022` go in the `.bib` file. The reader can then track down the original themselves. Flag incomplete metadata on the primary entry — it's better to have a partial reference than none at all.

## PDF Fallback Chain

When you need a PDF and the obvious URL doesn't work:

1. DOI resolver → publisher site (often has OA link)
2. Europe PMC (`europepmc.org/backend/ptpmcrender.fcgi?accid=PMC{ID}&blobtype=pdf`) — ncbi blocks curl
3. SciELO — needs `User-Agent: Mozilla/5.0` header
4. ResearchGate — flag to user for manual download
5. Semantic Scholar — sometimes has OA links
6. Ask user for institutional access

Always verify downloads: `file paper.pdf` should say "PDF document", not HTML.

## Searching Paper Content (ragnar)

### Setup (per project)
- `scripts/rag_build.R` — maps citation keys to Zotero PDF attachment keys, builds DuckDB
- `data/rag/` gitignored — store is local, not committed
- Dependencies: ragnar, Ollama with nomic-embed-text model
- See `/lit-search` skill for full recipe

### Query
`ragnar_store_connect()` then `ragnar_retrieve()` — returns chunks with source file attribution.

### Anti-patterns
- NEVER write abstracts manually — if CrossRef has no abstract, leave blank
- NEVER cite specific numbers without verifying from the source PDF via ragnar search
- NEVER paraphrase equations — copy exact notation and cite page/section
