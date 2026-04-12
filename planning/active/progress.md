# Progress: EDH migration

## Session 2026-04-12 (evening)

**Context from prior day:** Got rate-limited twice by CDS. Researched alternatives (#35), benchmarked EDH Zarr at 5× faster with no rate limits and same data. Filed #36 for migration. Pivoting now.

**Completed:**
- Branched off main: `36-edh-migration`
- Stashed and restored `scripts/test_edh_era5_land.py` on new branch
- Set up PWF files (this document, task_plan.md, findings.md)

**Next:**
- Commit backfill script
- Run full 1950-2025 backfill in background (~2.5h)
- Run R stage 3 (COG/STAC/S3) against EDH-generated TIFs

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
