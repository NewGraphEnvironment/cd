## Outcome

cd now publishes a **daily air-temperature cube** for BC and a reader for it. `scripts/backfill_edh_daily.py` turns EDH's hourly ERA5-Land `t2m` into local-day (fixed UTC−8) tmean/tmax/tmin and writes one COG per variable-year to `s3://stac-era5-land/daily/` (1950–2025, 228 files, 2.7 GB, outside `catalog.json`). `cd_extract_daily()` samples it at sf / SpatVector / lon-lat points, returning the ERA5-Land cell used and moving sea cells to the nearest land neighbour (flagged). `pipeline_update_edh.R` STEP D extends the cube monthly on its own clock, before the annual path's early exits. The issue's own instruction — measure the direct read before choosing — decided the design: a point costs its whole 120-day × 64 × 64 chunk, so reading stations straight from the Zarr was ~17 h for 300 stations. Wrong turns, kept: plan mode claimed GDAL could not read the store (that was sf's GDAL 3.8.5; GDAL 3.13 reads it, slowly); the first build wrote `units=K` tags on °C data (xarray carries attrs into file tags) and was killed and rebuilt; the second died at 1975 on an aiohttp payload truncation that `with_retry()` did not treat as transient, which is now fixed for every backfiller. The durable facts about the store are in [`research/edh_era5_land_store.md`](../../../research/edh_era5_land_store.md).

## Measurement

- **Direct Zarr read:** one point × 20 years 201 s (xarray); 48 hours of one point 39 s through GDAL 3.13. → build a cube.
- **Cube layout:** 16 px pixel-interleaved COG, 17.0 MB per tmean-year; one point read over `/vsicurl/` = 262 KB (was the whole file before code-check round 3's fix). 128 px tiles were faster for 300 points remote (0.8 vs 3.2 s per file) but a whole-file download beats both for many points, which is what `cache = TRUE` does.
- **Correctness:** 2002 cube cell = independent pandas resample of the raw hourly series, exact at float32, all 365 days × 3 variables. Whole cube: 0 tmax ≥ tmean ≥ tmin violations at Prince George 1950–2025; constant land mask (20,486 cells). STEP D's live rebuild of 2025 was byte-identical to the backfill's.
- **Consumer:** 1 point × 2002–2025 in 80 s (`cache = FALSE`); 300 points × 2002–2025 in 130 s cold (885 MB cached), 12 s warm.
- **Build:** 80–207 s per year; four transient EDH failures in 76 years, all recovered by the retry. Quota use ~5,500 of 500,000 requests.

## Evidence

`logs/backfill_daily_20261006.log` (local, gitignored — the two interrupted runs and the resumed one); CI dry run `37552913968`; review files in this directory (`review-*.md`).

Closed by: PR (see `/gh-pr-push`)
