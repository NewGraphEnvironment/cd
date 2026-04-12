# Findings: EDH migration

## EDH API basics (from #35 research and tonight's benchmark)

**Zarr URL:** `https://data.earthdatahub.destine.eu/era5/reanalysis-era5-land-no-antartica-v0.zarr`

**Auth:** Personal access token, passed inline as URL password:
```
https://edh:<EDH_TOKEN>@data.earthdatahub.destine.eu/...
```
Alternative: `storage_options={"client_kwargs":{"trust_env":True}}` to read from `.netrc`.

**Quota:** 500,000 requests/month per user (confirmed in EDH getting-started docs).

**Coord conventions (from live Zarr inspection):**
- Dimensions: `valid_time`, `latitude`, `longitude`
- `latitude`: descending from ~90 to -60 (confirmed by working slice `slice(60, 48)`)
- `longitude`: **0 to 359.9** (0-360 convention, NOT -180 to 180)
- For BC bbox `c(60, -140, 48, -114)` → lon slice must be `220` to `246`
- `valid_time`: hourly, from 1950-01-01T00:00 to current month last day
- Variable names: CF-style short names (`t2m`, `tp`, `d2m`, `swvl1-4`, `u10`, `v10`, etc.)

**50 variables available in single Zarr store:**
`asn, d2m, e, es, evabs, evaow, evatc, evavt, fal, lai_hv, lai_lv, lblt, licd, lict, lmld, lmlt, lshf, ltlt, pev, ro, rsn, sd, sde, sf, skt, slhf, smlt, snowc, sp, src, sro, sshf, ssr, ssrd, ssro, stl1, stl2, stl3, stl4, str, strd, swvl1, swvl2, swvl3, swvl4, t2m, tp, tsn, u10, v10`

**Relevant variable mapping for cd package:**
| cd variable | EDH variable(s) | Units | Notes |
|---|---|---|---|
| tmean | `t2m` | K | Hourly; monthly mean computed client-side |
| tmax | `t2m` | K | Hourly; daily max → monthly mean of daily max |
| tmin | `t2m` | K | Hourly; daily min → monthly mean of daily min |
| prcp | `tp` | m | Hourly total precipitation; sum over month, × 1000 for mm |
| dewpoint | `d2m` | K | Hourly 2m dewpoint |
| soil_moisture | `swvl1`, `swvl2`, `swvl3`, `swvl4` | m³/m³ | 4 vertical layers |
| vpd | derived | hPa | From t2m + d2m (Tetens) |
| rh | derived | % | From t2m + d2m |

## Performance (single month BC bbox)

- Open Zarr store: 2.6-3.0s (metadata only)
- Subset + materialize 1 month × BC bbox × hourly t2m: 14.9-15.9s
- In-memory size: 92.9 MB for 744 hours × 120 lat × 260 lon float64

## Implications for pipeline

- No rate limits means we can pull **all months in parallel** via asyncio/dask if wanted
- Zarr chunking is independent of month boundaries, so small time-slice pulls are efficient
- Can pull all 7 cd variables from the **same dataset open** — no need for separate fetches per variable

## R/Zarr tooling options

- **Reticulate + Python xarray** — proven; what `test_edh_era5_land.py` uses. Simple, works.
- **stars::read_mdim()** — GDAL zarr driver. Requires GDAL built with zarr, auth via URL password likely works.
- **pizzarr** — young R-native zarr package, may not support remote HTTPS stores.

Decision deferred to Phase 3 after Phase 2 unblocks the data.

## Known limitation: UTC-day aggregation for tmax/tmin

Both the existing R pipeline (`pipeline_tmax_tmin_hourly.R`) and the new EDH
Python script compute daily max/min over UTC-day windows, not local-time days.
For BC (UTC-7/-8) the local-afternoon tmax peak straddles UTC day boundaries,
introducing a small systematic bias vs. a local-time daily aggregation.

- CDS's `derived-era5-land-daily-statistics` product accepts a `time_zone`
  parameter and would fix this — but we abandoned it in #33 due to its
  ~2-hour-per-job queue time.
- Fixing properly requires shifting hourly timestamps by the local UTC offset
  before `.resample("1D")`, or doing per-pixel local-time aggregation
  (computationally expensive and overkill for a regional dataset).
- For now: the EDH script replicates the R pipeline's existing behavior so
  outputs are directly comparable. Addressing this bias is a follow-up issue
  (cd package methodology).

## Out-of-scope confirmations

- GEE has ERA5-Land but commercial license blocks us
- AWS / ARCO / WeatherBench all serve ERA5 (31 km), not ERA5-Land
- CDS-beta is same backend, same rate limits
