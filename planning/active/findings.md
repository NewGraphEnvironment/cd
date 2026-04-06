# Findings

## CDS queue vs data size
CDS queue time is per-request, not per-byte. Small AOI downloads just as slowly.
Test with full BC bbox for 1 year — proves real pipeline. If 1 year works, 75 works.

## Period aggregation needed
Monthly means from CDS give 12 months per year. Must aggregate to:
- Annual: mean (or sum for precip)
- Seasons: configurable month groups

## tmax/tmin tested (2026-04-05)

`derived-era5-land-daily-statistics` works. Key differences from monthly means:
- Requires `day` parameter (list of days, e.g., `sprintf("%02d", 1:31)`)
- Requires `time_zone` parameter (e.g., `"utc+00:00"`)
- Returns **NetCDF** (not GRIB in zip like monthly means)
- One layer per day requested
- Longer processing time — CDS computes daily stats on the fly from hourly
- **Rate limiting risk** — hit 429 during polling when requesting full month
- To get monthly mean of daily max/min: request all days, `terra::mean()` the layers

## Backfill batching strategy

- Monthly means: 1 request per year (multi-variable), ~2 min queue each
- Daily stats: need all days per month per year × 2 (tmax + tmin)
  - Option A: 1 request per month = 12 × 76 years × 2 = 1824 requests (too many)
  - Option B: 1 request per year (all 12 months × all days) = 76 × 2 = 152 requests
  - Option C: request all days for a full year in one go
  - **Need to test if CDS accepts all 12 months × 31 days in one request**
- Add sleep between requests to avoid rate limiting
