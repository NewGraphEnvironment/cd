# The DestinE EDH ERA5-Land hourly store

**Verified:** 2026-10-06; *Coordinates are not exact* 2026-10-08 · **Issues:** #116 (spawned it), #36 (EDH migration), #84, #123 · **Produced by:** plan-mode probes and the daily-cube build for #116 — method and raw numbers in `planning/archive/2026-10-issue-116-daily-air-temperature-cube/` (README `Measurement`, `findings.md`); coordinate probe for #123 in `planning/archive/*issue-123*/findings.md`

What we know about reading `https://data.earthdatahub.destine.eu/era5/reanalysis-era5-land-no-antartica-v0.zarr`, so the next point-or-grid question does not re-measure it.

## Layout

- Zarr v2, consolidated (`.zmetadata`), HTTP Basic auth with user `edh` and the `EDH_TOKEN`.
- Every variable (`t2m`, `d2m`, `tp`, snow, soil, …) is `float32`, shape `[669840, 1472, 3600]`, **chunks `[2880, 64, 64]`**: 120 days × 6.4° × 6.4° per chunk, ~47 MB uncompressed, blosc/zstd, with a `bitround` (keepbits 10) filter.
- Grid 0.1°, longitude 0–359.9, latitude 90 → −57.1. Time hourly from 1950-01-01T00; last stamp 2026-05-31T23 as of 2026-10-06 (the store advances by whole UTC months, two to three months behind).
- The companion `era5-land-daily-utc-v1.zarr` aggregates on **UTC days** — unusable where a local day matters (#37).

## Coordinates are not exact multiples of 0.1

Measured 2026-10-08 (#123), the same in the hourly store and in `era5-land-daily-utc-v1.zarr`:

| edge of the BC box | stored value |
|---|---|
| 60.0 N | `60.00000000000142` |
| 48.0 N | `48.00000000000125` |
| 140.0 W | `219.9999999999918` |
| 114.0 W | `245.9999999999903` |

A label slice that ends exactly on an edge, `sel(latitude=slice(60, 48), longitude=slice(220, 246))`, therefore keeps 48.0 and 246.0 but drops 60.0 and 220.0. That is how the published grid came out 120 × 260, stopping at 59.95 N and 139.95 W, for every product from the EDH migration (#36) to #123. `bc_slice()` in `scripts/_lib.py` pads each edge by half a cell. `bc_grid_check()` then refuses any cut that is not 121 × 261 before anything is fetched. Treat any label slice on this store the same way: pad by half a cell, then check the count.

## Cost of reading it

| read | route | time |
|---|---|---|
| one point × 1 year (`t2m`) | xarray + zarr 3 + fsspec | 30.6 s |
| one point × 20 years | xarray | 200.9 s |
| one point × 48 hours | GDAL 3.13 `gdalmdimtranslate` (terra links the same) | 39 s |
| BC bbox × 1 year, hourly | xarray | 80–207 s (afternoon slower) |
| store open (metadata only) | xarray | 3–6 s |

A point costs its whole 64 × 64 tile, so point-by-point reading for many stations is the wrong shape; read a region once and derive (that is why cd builds the daily cube). xarray beats GDAL by parallelising chunk fetches.

**GDAL version matters:** GDAL 3.8.5 (the one `sf` links on this machine) refuses the store outright — `Filter bitround not handled`. GDAL 3.13 decodes it. An R reader that goes through `sf::gdal_utils()` will fail where `terra` succeeds.

## Failure modes seen

- `aiohttp.ClientPayloadError: Response payload is not completed` (a chunk cut short) — twice in one 76-year run; and `502 Bad Gateway` on individual chunks — twice in a row on one year. Both transient; aiohttp errors do not subclass `OSError`, so `with_retry()` names `aiohttp.ClientError` explicitly (75883b8).
- A single HTTP 403 at the auth probe has been transient too (CLAUDE.md, CI considerations).
- Quota: 500,000 requests per month. A BC year is ~72 chunk requests, so even a full 76-year rebuild (~5,500) is about 1 %.
