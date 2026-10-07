# Code review — round 1 (#116 staged diff)

Scope: `scripts/_lib.py`, `scripts/backfill_edh_daily.py`, `scripts/test_lib.py`, planning notes.
Offline suite run on a copy in scratch: `uv run test_lib.py` → 26/26 passed.
`write_cog()` probed on a synthetic cube in scratch, and the already-built
`data/backfill/daily/tmean_daily_2002.tif` read (read-only) with rasterio.

## Findings

- **[severity: bug]** scripts/_lib.py:218-222 (`local_daily`) → scripts/_lib.py:251 (`write_geotiff` via `write_cog`) — the published daily COGs say `units=K` on data in degrees C. xarray (2026.9.0 in the uv env) now keeps attrs through both `resample().max()` and `- 273.15` (verified: `(r.max() - 273.15).attrs == {'units': 'K', ...}`), and `rio.to_raster()` writes every attr as a dataset tag. The built `tmean_daily_2002.tif` carries `units: K`, `GRIB_units: K`, `long_name: 2 metre temperature`, plus GRIB grid tags describing the global 3600x1472 grid (`GRIB_latitudeOfFirstGridPointInDegrees: 90.0`, `GRIB_Nx: 3600`, ...), while band 180 has a mean of 11.4 (C). These files are published to S3 as they are. There is no R `cd_cog_write()` step to rewrite them, as there is for the monthly path. So anyone reading tags (gdalinfo, rioxarray `open_rasterio().attrs`, a STAC harvester) is told the values are Kelvin. Fix: drop the attrs before writing (`da.attrs = {}` in `local_daily` or `write_cog`, or set `units="degC"`). The three COGs already built (1950, 1951, 2002) and any written by the in-flight run need rebuilding or re-tagging (`gdal_edit -unsetmd` / rasterio `update_tags`). The per-output existence check will otherwise keep them as they are.

- **[severity: fragile]** scripts/_lib.py:279 (`write_cog` temp name) — the intermediate is named `<var>_daily_<Y>.src.tif`, inside `data/backfill/daily/`, which is also the publish directory (`cd_s3_push("data/backfill/daily", prefix = "daily")`). `finally` removes it on an exception or Ctrl-C. A SIGKILL, an OOM kill (the hourly block is ~1.1 GB float32 before the resample) or a default-handled SIGTERM skips `finally` and leaves a full ~45 MB uncompressed `.src.tif`, and possibly `.src.tif.tmp` / `.tif.tmp`. `cd_s3_push` runs `aws s3 sync` excluding only `.*` and `*.aux.json` (R/cd_s3_push.R:44), so the next push uploads the stray file to `s3://stac-era5-land/daily/`. A `*.tif` glob, such as the planned "228 files" spot-check or any listing reader, also counts it as a cube year. Fix: write the intermediates to a temp dir outside `DAILY_DIR` (e.g. `tempfile.mkdtemp()` on the same filesystem, so `os.replace` stays atomic), or give them a non-`.tif` dot-prefixed name that the sync excludes.

No other defects found. Checked and fine:
- the local-window arithmetic, including the 1950 store start and 366-day years;
- the `local_daily` input guard;
- the leap/365 band labels;
- the per-output idempotency and the completeness check before fetch (#84);
- the `--check` stdout line, which is the last line and flushed (log lines also go to stdout, so the R caller must match `^latest_complete=` rather than read the whole output);
- the COG layout: 16x16 tiles, pixel interleave, DEFLATE, band descriptions YYYY-MM-DD survive the COG copy, and no sidecar is produced.

Planning notes: no factual contradictions with the code.
