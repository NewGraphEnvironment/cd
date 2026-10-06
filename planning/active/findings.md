# Findings — Daily air temperature at points from ERA5-Land hourly (#116)

## Issue context

**If we do it:** a stream-temperature model can be driven by daily air temperature at any set of stations or points, read from the same ERA5-Land source cd already uses. **If we never do:** each consumer writes its own ERA5-Land download and point extraction, with its own day boundary and cell choice.

## Problem

cd publishes monthly ERA5-Land layers. Stream-temperature models such as air2stream need a **daily or weekly air-temperature series at points**: one per water-temperature station, across many stations in BC, from about 2002 onward (and possibly from 1950). cd already reads hourly `t2m` from the DestinE Zarr in `scripts/backfill_edh_*.py`, but only to roll it up to monthly grids. The R side has no reader for that Zarr: `cd_fetch()` is CDS only.

## Proposed solution

A function along the lines of `cd_point_daily(points, from, to)`, named to fit cd's conventions. It takes points (sf or lon/lat with an id) and returns a long table: `id`, `date`, `variable` (`tmean`, `tmax`, `tmin`), `value` (°C), and the ERA5-Land cell used.

Decisions to make while building it:

- **Day boundary.** Use a local day, not a UTC day. #37 explains why a UTC day biases daily max/min, and why that bias does not cancel for absolute thresholds such as degree-days, which is this use. Its Option A (a fixed −8 h offset) is enough.
- **Cell choice.** Default to the nearest 9 km cell, and return the cell id so that stations sharing a cell are visible.
- **Read path: measure first.** Before choosing between them, time one point × 20 years read directly from the Zarr.
  - The direct read may be slow if the store is chunked by time step rather than by location.
  - If it is slow, the alternative is a daily BC cube built once by script and published to S3, which the R function then samples.
- **Out of scope:** elevation correction between cell and station. The station's own model parameters absorb a constant offset.

Consumer: stream temperature work in NewGraphEnvironment/wet (wet#36 and the gap-fill that follows it).

Relates to #37


## Read-path measurement (2026-10-06, plan-mode probe)


The issue said to measure the read path before choosing one. These measurements settled it.

| fact | value |
|---|---|
| EDH hourly store chunking (`t2m` and every other var) | `[2880 h, 64, 64]`, so one chunk is 120 days × 6.4° × 6.4° |
| one point × 1 year, direct xarray read | **30.6 s** |
| one point × 20 years (2002–2021), direct | **200.9 s** (175,320 hours) |
| ~300 stations point-by-point | about 17 h, so not viable |
| R / GDAL 3.13 Zarr driver on the store | opens it, then refuses: `Filter bitround not handled` |
| EDH `era5-land-daily-utc-v1` store | UTC days, which is the bias #37 describes, so unusable here |
| whole-BC hourly year fetch (EDH migration, #36 archive) | ~90 s/year |
| store time range | 1950-01-01 → 2026-05-31T23:00 |

Probe: xarray + zarr 3 via uv, point (54.0 N, −123.0 E → 237.0 on the store's 0–360 grid), `.sel(method="nearest")`, `.compute()`, wall time. Open of the consolidated store: 5.9 s.

GDAL probe: `sf::gdal_utils("mdimtranslate", 'ZARR:"/vsicurl/https://data.earthdatahub.destine.eu/era5/reanalysis-era5-land-no-antartica-v0.zarr"', ...)` with `GDAL_HTTP_AUTH=BASIC` → `GDAL Error 1: Filter bitround not handled`. A bare `/vsicurl/` path (no `ZARR:` prefix) 404s instead (driver not identified).

## Decisions taken at the plan gate


- **Span:** 1950–2025, about 2–3 h for the one-off build.
- **The monthly climate-update extends the cube** (this issue, not a follow-up).
- **Day boundary:** fixed UTC−8 (#37 Option A). The 27 MST stations in eastern BC that wet puts at UTC−7 get a day boundary one hour off. This is documented, not fixed. The monthly tmax/tmin COGs are untouched; #37 stays open.
- **Ocean or lake cell (NA):** fall back to the nearest non-NA cell within the 3×3 ring, flagged `cell_moved`. If the whole ring is NA, return NA and warn.
- **Name: `cd_extract_daily()`.** It sorts beside `cd_extract()` and reads as its daily point counterpart. **`cd_extract()` keeps its name.** It doesn't return monthly values: it returns annual and seasonal zonal means per year, so `cd_extract_monthly` would mislabel it. A rename would also break the two vignette data scripts and every downstream caller for no behaviour change. If you want the pair to read as `_zonal`/`_daily`, that's a separate issue with a deprecation shim.

## Errors Encountered

| Error | Resolution |
|-------|------------|
| `TypeError: open_group() got an unexpected keyword argument 'zarr_format'` | Probe pinned `zarr<3`; current xarray needs zarr 3. uv also reused the cached env for the same script name — copy to a new filename to force a fresh env. |
