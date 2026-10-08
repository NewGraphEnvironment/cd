# Findings — Daily cube stops at 59.95 N, and one point outside it aborts cd_extract_daily() (#123)

## Issue context

**If we do it:** `cd_extract_daily()` covers all of BC up to 60 °N, and one point it cannot place no longer stops the call for every other point. **If we never do:** stations in BC's northern strip get no air temperature, and any call that includes one fails with a message whose stated extent says it should have worked.

## Problem

`cd_extract_daily()` rejects a BC station inside the extent its own error message names. Seen in NewGraphEnvironment/wet#40, extracting air temperature at the ~300 water-temperature stations:

```
Error in `daily_cells()`:
! Outside the daily cube's extent (BC, 48-60 N, 114-140 W): 10DA001.
```

10DA001 is the Petitot River below Highway 77, a BC station (`tidyhydat::allstations`) at **59.98856 °N, −122.9609 °W**.

Measured on the cached `tmean_daily_2002.tif` (cd 0.6.1, 2026-10-08):

```
SpatExtent : -139.95, -113.95, 47.95, 59.95 (xmin, xmax, ymin, ymax)
res 0.1 x 0.1, EPSG:4326
top row centre 59.9, left column centre -139.9
terra::cellFromXY(r, cbind(-122.9609, 59.98856))  # NA
```

The cube therefore stops at 59.95 °N. Cells from 59.95 to 60 °N of BC are missing. That strip holds the BC–Yukon/NWT border stations, 10DA001 among them.

`scripts/backfill_edh_daily.py` sets `LAT_N, LAT_S = 60.0, 48.0` and `LON_W, LON_E = -140.0, -114.0`, so 121 × 261 cell centres. The cube holds 120 × 260: 48.0–59.9 °N and −139.9 to −114.0 °W. The 60.0 °N row and the −140.0 °W column are dropped somewhere between the slice and the written COG. Where was not traced. The −140.0 column lies west of BC and does not matter. `backfill_edh_all.py`'s docstring describes the monthly grid as "120x260", so the monthly layers likely share the cut; that was not checked.

A second, separate behaviour made it worse: **one point outside the cube aborts the whole call.** With 301 points, one border station meant no air temperature for any of them. wet's scripts work around it by parsing the station numbers out of the message, dropping them and retrying.

## Proposed solution

1. Keep the 60.0 °N row in the daily cube (and the monthly grid, if it has the same cut). Rebuild, and add a guard in the build script that the written extent's `ymax` reaches 60.05.
2. Make the error message state the extent from the template (`terra::ext()`), not a hardcoded string, so it cannot drift from the data again.
3. For a point outside the cube, return `NA` rows for that point with a warning that names it, the same as a point whose ring of neighbours has no data, instead of aborting the call.

(1) is the fix for BC. (2) and (3) stand on their own.

Relates to #116


## Root cause (plan mode, 2026-10-08)

The EDH hourly store's coordinates carry float drift (`scratchpad probe_coords.py`, xarray on `reanalysis-era5-land-no-antartica-v0.zarr`):

| edge | store value | slice bound | result |
|---|---|---|---|
| north | `60.00000000000142` | 60.0 | excluded |
| south | `48.00000000000125` | 48.0 | kept |
| west | `219.9999999999918` | 220.0 | excluded |
| east | `245.9999999999903` | 246.0 | kept |

`sel(latitude=slice(60, 48), longitude=slice(220, 246))` → 120 × 260, first centre 59.900000000001 / 220.0999999999. The live `catalog.json` bbox is `[-139.95, 47.95, -113.95, 59.95]`, so the monthly layers have the same cut. All three backfillers copy the slice.

- The bundled AOIs reach at most 58.03 N and −127.74 W, so the vignette data is unaffected.
- `pipeline_update_edh.R:797` STEP 4 aborts if the grid of a live COG and a new year differ (tolerance 1e-6), which fails safe if a mixed grid is ever attempted.
- `cd_cache_fetch()` revalidates by ETag by default, so consumers refetch the rebuilt files.

## Gate decisions

- Rebuild daily + all 59 monthly on 121 × 261; publish in-run, no backup.
- Hashing (stac_airphoto_bc#30 pattern) is a separate issue, done later from the local files with no EDH fetch.

## Errors Encountered

| Error | Resolution |
|-------|------------|
