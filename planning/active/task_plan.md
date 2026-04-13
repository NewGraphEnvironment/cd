# Task Plan: Migrate cd_fetch() to DestinE Earth Data Hub Zarr

Issue: NewGraphEnvironment/cd#36
Branch: `36-edh-migration`

## Context

CDS (`ecmwfr`) rate limiting makes the tmax/tmin backfill take ~3 days of babysitting. Benchmark in #35 showed EDH Zarr delivers the same ERA5-Land data at ~15s/month (5× faster, no rate limits, 500K requests/month quota). Pivot the producer pipeline to EDH.

## Phase 1: Scaffold and benchmark (mostly done from #35)

- [x] Confirm EDH carries ERA5-Land at 9 km native (validated #35)
- [x] Confirm temporal coverage 1950 to present (validated #35)
- [x] Confirm commercial license (CC-BY 4.0, validated #35)
- [x] Write portable PEP 723 test script (`scripts/test_edh_era5_land.py`)
- [x] Bench one month BC t2m — 15.9s vs CDS 80s
- [x] Commit test script on the branch

## Phase 2: Pragmatic Python backfill (unblock #33)

The quickest path to finishing the tmax/tmin data: a Python script that uses EDH directly.
Runs outside R, produces monthly GRIB or NetCDF that downstream R stages already consume.

- [x] Write `scripts/backfill_edh_tmax_tmin.py` — tmax/tmin only for now (unblocks #33)
- [x] Output matches existing R pipeline's Stage 2 format (yearly `.tif` × 12 month bands, °C, EPSG:4326)
- [x] Band descriptions Jan..Dec so `cd_aggregate()` seasonal grouping works
- [x] Idempotent — skip years where both output files exist
- [x] Test on one year (1950) — 114s, realistic values, terra reads correctly
- [x] Run full backfill 1950-2025 — completed in ~1h 53min (76 years × tmax + tmin)
- [x] Regenerate 2024 from EDH (was a CDS leftover) for homogeneous methodology
- [x] QA — discovered CDS-era vars on a different grid (ext shifted 0.1°, CRS missing, 121×261 vs EDH 120×260)
- [x] Probe EDH products — confirmed two-Zarr approach: hourly for state vars, daily for prcp

## Phase 2b: Unified backfill (all variables on EDH grid)

Grid mismatch between CDS-era vars and EDH-era tmax/tmin blocks release.
Regenerating everything from EDH gives one internally-consistent dataset.

- [x] Extend backfill to all 7 cd variables (scripts/backfill_edh_all.py)
- [x] Regenerate all `data/backfill/monthly/*_YYYY.tif` with consistent grid + CRS
- [x] Re-run QA — all grids aligned, all CRS tagged, tmin<=tmean<=tmax sanity passes
- [x] VPD/RH derived in Python (Tetens), no R cd_derive re-run needed

**QA summary 2026-04-12:**
- 7 variables × 76 years = 532 monthly TIFs
- All on 120×260 EPSG:4326 grid, extent [-139.95, -113.95, 47.95, 59.95]
- Zero tmin>tmax or tmean inversion violations (163,888 cell-checks)
- (tmax+tmin)/2 vs tmean mean diff = 0.57°C (classical climatology shortcut bias, normal)
- 2008 had a ClientPayloadError that my retry didn't catch (wrong exception class);
  re-ran --year 2008 to fill the gap. Filed as future improvement in #38.

## Phase 2c: R Stage 3

- [x] Run R stage 3 (COG + STAC + S3) against the unified EDH-generated TIFs
  (scripts/pipeline_stage3_edh.R; 35 COGs live on s3://stac-era5-land,
  verified via /vsicurl read)

## Phase 3: R integration for cd_fetch()

- [ ] Decide: reticulate + Python xarray, OR stars::read_mdim() via GDAL zarr driver
- [ ] Prototype both on one month, compare simplicity and performance
- [ ] Refactor `cd_fetch()` with `source = c("edh", "cds")` parameter, default `"edh"`
- [ ] Keep `cd_fetch()` CDS path for fallback
- [ ] Update tests to exercise both paths
- [ ] Update examples and docs

## Phase 4: Pipeline and docs

- [ ] Update `scripts/pipeline_backfill.R` to use EDH source
- [ ] Update monthly GitHub Action to use EDH
- [ ] Add `EDH_TOKEN` to repo secrets (rotate current token first)
- [ ] Update CLAUDE.md — CDS section → EDH primary, CDS fallback
- [ ] Update README / pkgdown auth setup instructions

## Phase 5: Close out

- [ ] Run full backfill from scratch via integrated R path — validate output matches phase 2
- [ ] Close #33 (tmax/tmin saga resolved by EDH)
- [ ] Close #35 (evaluation → migration done)
- [ ] Merge PR closing #36
- [ ] Archive planning to `planning/completed/`

## Success criteria

- `cd_fetch()` default path uses EDH; CDS path works as fallback
- Full 1950-2025 backfill completes in under 8 hours (single session, unattended)
- Vignette and tests pass with EDH as source
- CDS API knowledge preserved in CLAUDE.md but marked as fallback
