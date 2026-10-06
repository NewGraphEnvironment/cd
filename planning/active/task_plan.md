# Task: Daily air temperature at points from ERA5-Land hourly (#116)

## Problem

cd publishes monthly ERA5-Land layers. Stream-temperature models such as air2stream need a **daily or weekly air-temperature series at points**: one per water-temperature station, across many stations in BC, from about 2002 onward (and possibly from 1950). cd already reads hourly `t2m` from the DestinE Zarr in `scripts/backfill_edh_*.py`, but only to roll it up to monthly grids. The R side has no reader for that Zarr: `cd_fetch()` is CDS only.

## Approach (approved 2026-10-06)

Direct point reads from the EDH Zarr are too slow (201 s for one point × 20 years; chunks are [2880 h, 64, 64]) and reading through GDAL 3.13 (terra) is slower still — 39 s for 48 hours of one point, a whole chunk per read. (The plan first said GDAL could not decode the store's `bitround` filter; that was sf's GDAL 3.8.5, corrected in findings.md.) Build a daily BC cube (tmean/tmax/tmin, UTC−8 local days, 1950–2025) by script, publish per-year COGs to `s3://stac-era5-land/daily/`, sample it from R with `cd_extract_daily()`. The monthly climate-update extends the cube. NA (sea) cells fall back to the nearest land cell in the 3×3 ring, flagged `cell_moved`. `cd_extract()` is not renamed. Full rationale: `findings.md`.


## Phase 1: Producer, the daily cube script
- [x] `scripts/_lib.py`: `local_daily(hourly, offset_h=-8)` shifts `valid_time` by the offset, then resample `1D` → mean/max/min, minus 273.15. Also `local_year_complete(ds, year, offset_h)`, a coordinate-only check (no transfer, per #84) that the store holds `Y-01-01T08` → `Y+1-01-01T07` at 24 h/day.
- [x] `scripts/test_lib.py`: offline cases on synthetic hourly data. The peak at 23 UTC lands on the local day it belongs to; 365/366 bins per year; an incomplete next-Jan-1 → not complete; a day with a missing hour → not complete.
- [x] `scripts/backfill_edh_daily.py`: PEP 723 uv script modelled on `backfill_edh_tmax_tmin.py`. Uses `get_token`, `with_retry`, `preflight_single_instance`, `write_geotiff(band_names=dates)`, and is idempotent per output. Writes `data/backfill/daily/{var}_daily_{Y}.tif`; flags `--year` and `--from/--to`.
- [x] *(review #2, #4, #6)* `--check` prints the latest complete local year for R; `local_daily()` refuses input that is not whole 24-hour local days; `write_cog()` writes the published COG straight from Python

## Phase 2: Build, validate and publish the cube
- [x] One-year build (2002), then measure layout options (size and point-extract time over `/vsicurl/`); choose the COG creation options.
- [x] ~~Daily TIF → COG via an R helper in `scripts/_lib.R` + STEP 1c in `pipeline_stage3_edh.R`~~ — dropped after plan review #6 (`_lib.R` is pure-function only, and stage 3 would rebuild every monthly COG). The COG is written in Python by `write_cog()`; `data/backfill/daily/` is the publish directory.
- [x] **Independent check:** take the probe's raw hourly series at (54.0, −123.0) for 2002, resample in pandas with a −8 h shift, and compare it to the cube cell. Exact match is expected; record it in findings.
- [ ] Full backfill 1950–2025, run in the background. Spot-check counts: 228 files, 365/366 bands each, no all-NA band.
- [ ] Push `daily/` to S3; HEAD-check a sample of keys.

## Phase 3: Consumer, `cd_extract_daily()` (built in parallel with the Phase 2 backfill)
- [ ] Tests first, `tests/testthat/test-cd_extract_daily.R`, against a synthetic fixture built in a helper: a small terra grid with known values per (cell, day) and some NA "ocean" cells, written as `{var}_daily_{Y}.tif` in a temp dir. Cases:
  - columns and types
  - `from`/`to` crossing a year boundary
  - two points sharing a cell → same `cell`
  - sf input in EPSG:3005 transformed
  - data.frame lon/lat input
  - an NA cell moves to its nearest land neighbour with `cell_moved = TRUE`; an all-NA ring gives NA plus a warning
  - a year not published → clear abort naming it
  - a point off the grid → abort
  - zero-row result keeps every column
- [ ] `R/cd_extract_daily.R`: `cd_extract_daily(points, from, to, variables = c("tmean","tmax","tmin"), id = "id", source = cd_daily_source(), cache = <per Phase 2>)`.
  - Returns a tibble: `id`, `date` (Date), `variable`, `value` (°C), `cell`, `cell_x`, `cell_y`, `cell_moved`.
  - Cell choice is computed once from the land mask (band 1, first year); then one `terra::extract()` per variable-year over all cells.
  - Reuses `cd_remote_head()`/`cd_cache_fetch()` from `R/cd_cache_fetch.R`. Source URL comes from `getOption("cd.daily_url", …/daily)`.
- [ ] Example data: `data-raw/example_daily.R` crops two years of the real cube around the example AOI into `inst/extdata/example_daily/`, for a runnable `@examples`.
- [ ] Live test against S3, under `skip_on_ci()` + `skip_if_offline()`.
- [ ] `devtools::document()`, `lintr`, `devtools::test()`, `pkgdown::check_pkgdown()`.

## Phase 4: Monthly update wiring
- [ ] `pipeline_update_edh.R`: a daily check independent of the annual early exit.
  - Daily target = latest *Y* with `local_year_complete`.
  - Published = HEAD `daily/tmean_daily_{Y}.tif`, probing back from the target.
  - Build missing years via `backfill_edh_daily.py`, convert with the Phase 2 helper, and push `daily/`.
  - The annual path's early exit must not skip this.
- [ ] `--dry-run` reports the daily target and published year and builds nothing. Run it locally and once on CI (`gh workflow run`) after merge.

## Phase 5: Docs and record
- [ ] Update `CLAUDE.md`: architecture (the daily cube as a second product), the scripts list, the EDH gotchas (the cube uses UTC−8, while monthly tmax/tmin are still UTC per #37), and the consumer chain (`cd_extract_daily()` sits outside the long-format chain).
- [ ] `findings.md` gets the measurement table above plus the Phase 2 layout and validation numbers; that's the archive README's Measurement/Evidence.
- [x] ~~Draft an upstream GDAL issue for the `bitround` decode refusal~~ — not needed: the refusal was GDAL 3.8.5 (sf); GDAL 3.13 reads the filter (findings.md)

## Validation

- [ ] Tests pass
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
