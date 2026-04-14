# Archive: EDH migration (#36)

## Outcome

Migrated the cd producer pipeline from Copernicus CDS (`ecmwfr`) to
DestinE Earth Data Hub (Zarr). Full 1950-2025 backfill regenerated for
all 7 cd variables on a single internally-consistent EPSG:4326 BC grid,
live on `s3://stac-era5-land`. Monthly GitHub Action rewired to use EDH
and validated via `workflow_dispatch`. Consumer API unchanged.

Released as **v0.1.0** (2026-04-14).

## Key findings worth remembering

- EDH hourly `tp` has `GRIB_stepType=accum` — naive sum gives 8× wrong
  precip. Use the EDH daily product for prcp; hourly is correct for
  state variables (t2m, d2m, swvl1-4).
- Both R and Python EDH paths need atomic writes — a killed process
  that leaves a truncated `.tif` fools the idempotency check.
- ERA5-Land has ~3 month latency, so the monthly GHA will no-op most
  of the year and only do real work once per year when a complete
  new year becomes available on EDH.

## Closing ref

- Issue: NewGraphEnvironment/cd#36
- PR: NewGraphEnvironment/cd#40 (merged 2026-04-14)
- Follow-ups: #37 (tz bias), #38 (soul convention), #39 (vignette)
