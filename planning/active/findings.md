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
| R / GDAL Zarr driver on the store | GDAL 3.8.5 (sf) refuses `bitround`; GDAL 3.13 (terra, CLI) reads it — 39 s for 48 h of one point |
| EDH `era5-land-daily-utc-v1` store | UTC days, which is the bias #37 describes, so unusable here |
| whole-BC hourly year fetch (EDH migration, #36 archive) | ~90 s/year |
| store time range | 1950-01-01 → 2026-05-31T23:00 |

Probe: xarray + zarr 3 via uv, point (54.0 N, −123.0 E → 237.0 on the store's 0–360 grid), `.sel(method="nearest")`, `.compute()`, wall time. Open of the consolidated store: 5.9 s.

GDAL probe, **corrected 2026-10-06 the same afternoon.** The first probe ran `sf::gdal_utils("mdimtranslate", 'ZARR:"/vsicurl/…zarr"', …)` and got `GDAL Error 1: Filter bitround not handled`. That was **sf's GDAL 3.8.5**, not the 3.13 the plan named. Re-run with GDAL 3.13.0 (Homebrew CLI, the same version terra links): `gdalmdiminfo` lists `t2m` with `FILTERS: [{"id": "bitround", "keepbits": 10}]` and `gdalmdimtranslate -array "name=t2m,view=[0:48,360,2370]"` **succeeds — 48 hours of one point in 39 s** (one 2880 h × 64 × 64 chunk pulled whole). So R *can* read the store through terra/GDAL 3.13; it is just far slower than xarray, which parallelises chunk fetches (~40 min per point for 20 years by this route vs 201 s). The cube decision stands on speed alone. No upstream GDAL issue to draft: newer GDAL already handles the filter.

## Decisions taken at the plan gate


- **Span:** 1950–2025, about 2–3 h for the one-off build.
- **The monthly climate-update extends the cube** (this issue, not a follow-up).
- **Day boundary:** fixed UTC−8 (#37 Option A). The 27 MST stations in eastern BC that wet puts at UTC−7 get a day boundary one hour off. This is documented, not fixed. The monthly tmax/tmin COGs are untouched; #37 stays open.
- **Ocean or lake cell (NA):** fall back to the nearest non-NA cell within the 3×3 ring, flagged `cell_moved`. If the whole ring is NA, return NA and warn.
- **Name: `cd_extract_daily()`.** It sorts beside `cd_extract()` and reads as its daily point counterpart. **`cd_extract()` keeps its name.** It doesn't return monthly values: it returns annual and seasonal zonal means per year, so `cd_extract_monthly` would mislabel it. A rename would also break the two vignette data scripts and every downstream caller for no behaviour change. If you want the pair to read as `_zonal`/`_daily`, that's a separate issue with a deprecation shim.

## Cube layout (measured 2026-10-06, 2002 tmean, 365 bands, 261×121 cells)

| layout | size | 1 point remote | 300 points remote |
|---|---|---|---|
| COG BLOCKSIZE=16, pixel interleave, DEFLATE + float predictor, no overviews | 17.0 MB | 0.66 s | 3.18 s |
| COG BLOCKSIZE=128 (3 tiles over the grid) | 15.6 MB | 1.67 s | 0.79 s |
| COG BLOCKSIZE=16, band interleave | 21.7 MB | — | — |
| download whole file + local extract (either layout) | — | — | 1.7–2.1 s |

Remote timings: `terra::extract()` over `/vsicurl/` from a scratch S3 prefix (`_scratch_116/`, deleted after), one run each; a windowed read was noisy (2.1–4.5 s). sf's GDAL 3.8.5 COG driver refuses BLOCKSIZE < 128; rasterio's GDAL 3.12.2 accepts 16.

**Chosen:** 16 px pixel-interleaved — one point's 365 days in one ~125 KB tile. `cd_extract_daily(cache = TRUE)` downloads whole files (fast for many points, reused across calls); `cache = FALSE` reads only the tiles needed. Full year, all three variables: 36 MB (tmean 17.0, tmax 9.2, tmin 10.2 MB) → ~2.8 GB for 1950–2025.

## Independent validation (2026-10-06)

Raw hourly `t2m` at the cell (54.0 N, −123.0) for UTC 2002-01-01T08:00 – 2003-01-01T07:00, pulled straight from the Zarr, index shifted −8 h, pandas `resample("D").agg(mean, max, min) − 273.15` — no `_lib.py` code involved. Against the published 2002 cube cell: **max |diff| = 0 for tmean, tmax and tmin, all 365 days, exact at float32.** (Review #10 expected tmean to differ by summation order; at float32 it does not.)

## EDH quota

500,000 requests/month (#36 findings). One BC local year ≈ 4 time × 3 lat × 6 lon ≈ 72 chunk requests; the 1950–2025 backfill ≈ 5,500. Not a constraint.

## Errors Encountered

| Error | Resolution |
|-------|------------|
| `ABORT: another backfill_edh_daily is running` with the reported pid already gone | `preflight_single_instance()` matches the agent's wrapping shell, whose command line contains the script name (pre-existing behaviour, all backfillers). Launch through a runner script whose own argv lacks the name. |
| `TypeError: open_group() got an unexpected keyword argument 'zarr_format'` | Probe pinned `zarr<3`; current xarray needs zarr 3. uv also reused the cached env for the same script name — copy to a new filename to force a fresh env. |
