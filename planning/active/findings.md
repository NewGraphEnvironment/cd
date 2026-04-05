# Findings

## CDS queue vs data size
CDS queue time is per-request, not per-byte. Small AOI downloads just as slowly.
Test with full BC bbox for 1 year — proves real pipeline. If 1 year works, 75 works.

## Period aggregation needed
Monthly means from CDS give 12 months per year. Must aggregate to:
- Annual: mean (or sum for precip)
- Seasons: configurable month groups

## tmax/tmin untested
`derived-era5-land-daily-statistics` product confirmed to exist but not yet
tested with `ecmwfr::wf_request()`. Different request structure from monthly means.

(more findings during implementation)
