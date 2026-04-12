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

- [ ] Write `scripts/backfill_edh.py` — pull all variables for 1950-2025, BC bbox, monthly NetCDF
- [ ] Variable mapping: t2m → tmean/tmax/tmin inputs, tp → prcp, d2m → dewpoint, swvl1-4 → soil_moisture
- [ ] Output format matches existing `data/backfill/raw/` layout
- [ ] Idempotent — skip months already downloaded
- [ ] Test on one year (1950) end to end
- [ ] Run full backfill (~4 hours unattended)
- [ ] Confirm outputs feed cleanly into `cd_derive()` / `cd_aggregate()`

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
