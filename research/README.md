# Research

What is known and outlives the issue that found it. One topic file per subject, revised in place; `git log --follow` is its history.

| file | covers |
|---|---|
| [edh_era5_land_store.md](edh_era5_land_store.md) | The EDH ERA5-Land hourly Zarr: layout, chunking, read cost by route, GDAL version support, transient failures, quota |
| [gdal_vsicurl_reads.md](gdal_vsicurl_reads.md) | Re-reading the published COGs over GDAL `/vsicurl/`: the per-process cache (failed opens on 3.8), what `CPL_VSIL_CURL_NON_CACHED` really does, timeouts, retries, read cost |
| [tmax_tmin_day_boundary.md](tmax_tmin_day_boundary.md) | UTC days vs local days for daily max/min in BC: where the extremes fall, which way each window biases, the measured difference per season |

Naming: `<topic>.md`, revised in place, from 2026-10-06.
