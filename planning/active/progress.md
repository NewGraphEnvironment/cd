# Progress: EDH migration

## Session 2026-04-12 (evening)

**Context from prior day:** Got rate-limited twice by CDS. Researched alternatives (#35), benchmarked EDH Zarr at 5× faster with no rate limits and same data. Filed #36 for migration. Pivoting now.

**Completed:**
- Branched off main: `36-edh-migration`
- Stashed and restored `scripts/test_edh_era5_land.py` on new branch
- Set up PWF files (this document, task_plan.md, findings.md)

**Next:**
- Run R stage 3 (COG/STAC/S3) against EDH-generated TIFs
- Validate COGs structurally match what the pipeline previously produced
- S3 push (requires user confirmation)
- Land the PR

## Session 2026-04-12 (unified backfill run)

**Completed:**
- Full 1950-2025 unified backfill of 5 non-tmax/tmin variables via EDH in ~4 hours
  (10:19 - 14:20 wall time)
- 532 monthly TIFs total (7 vars × 76 years), all on matching EPSG:4326 120×260 grid
- CDS-era files safely preserved in `data/backfill/monthly/_cds_backup/` (375 files)
- Two transient errors handled well:
  - 1989: TimeoutError → retry-with-backoff caught it, completed on attempt 2
  - 2008: ClientPayloadError → retry catch didn't include aiohttp class; outer handler
    skipped the year and continued. Filled later via `--year 2008` rerun.
- QA confirmed: all grids aligned, tmin<=tmean<=tmax with zero violations,
  physically plausible values, soil_moisture composite correct.

## Session 2026-04-12 (overnight run)

**Completed:**
- Full 1950-2025 backfill via EDH, ~1h 53min unattended (02:16 - 04:09)
  - 75 year-files written (1951-2025) plus 1950 from earlier test = 76 years
  - Avg ~90s per year, no failures
- Regenerated 2024 from EDH (was a CDS leftover from April 7 with different methodology)
- Filed #37 for the UTC-day aggregation bias (not blocking #36)
- All 76 years × 2 variables × 12 months × BC bbox GeoTIFFs in data/backfill/monthly/

**Validation (R/terra spot check):**
- 1950 Jul tmax up to 29.7 °C — historically realistic
- 2000 Jul tmax up to 28.9 °C
- 2024 Jul tmax up to 34.6 °C — matches heat dome era
- 2025 Jul tmax up to 31.9 °C
- All years: 12 layers, Jan..Dec names, EPSG:4326, BC bbox extent

## Session 2026-04-12 (morning QA)

**Completed:**
- Wrote `scripts/qa_monthly.R` — checks grid alignment, time coverage,
  physical sanity across all variables
- Wrote `scripts/probe_edh_vars.py` — pulls one month of each EDH
  variable, compares to CDS, validates aggregation semantics
- **Discovered grid mismatch:** CDS-era vars on 121×261 grid with no CRS
  tag, vs EDH-era tmax/tmin on 120×260 EPSG:4326. Blocks release.
- **Validated EDH semantics:**
  - tmean (hourly t2m mean): 0.99 correlation with CDS, 0.43 °C mean abs diff
  - dewpoint: plausible BC winter values
  - soil_moisture: all 4 depths match CDS composite closely
  - prcp: hourly `tp` is accumulation (`GRIB_stepType=accum`) — need
    EDH daily product for correct monthly precip
- **Decision:** two-Zarr approach, extend backfill to all variables so
  the whole dataset is internally grid-aligned

**Next:**
- Commit QA + probe scripts on the branch (durable tooling)
- Extend backfill script to all 7 cd variables
- Regenerate `data/backfill/monthly/` entirely
- Re-run QA → R Stage 3 → PR

**Commits this session:**
- `0014bf2` — Add planning docs for EDH migration
- `7ef03cb` — Add EDH Zarr benchmark test script
- _pending_ — Add EDH-based tmax/tmin backfill script

**Verified 2026-04-12 02:11:**
- EDH Zarr benchmark: 15.9s / month BC t2m (5× faster than CDS)
- EDH full-year backfill: 114.3s / year BC tmax/tmin as GeoTIFF
- Output drop-in replacement for existing R Stage 2: 12 layers Jan..Dec,
  EPSG:4326, °C, BC bbox — `terra::rast()` reads cleanly with expected names
- Realistic BC values for 1950: Jan tmax -30.5 to 0.7°C, Jul tmax -1.2 to 29.7°C
