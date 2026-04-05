# Backfill Pipeline + GitHub Action

## Context
Populate stac-era5-land S3 bucket with all 7 variables x 5 periods x 75 years (1950-2025). Then set up GitHub Action for monthly incremental updates. Two CDS products needed: monthly means and daily statistics (tmax/tmin).

## Tasks
- [ ] Add period aggregation helpers (flexible season definitions)
- [ ] Test daily statistics CDS product (tmax/tmin) for 1 year
- [ ] Write `scripts/pipeline_backfill.R` (idempotent, resumable)
- [ ] Write `scripts/pipeline_update.R` (incremental monthly)
- [ ] Test full pipeline for 1 year (BC bbox)
- [ ] Write `.github/workflows/climate-update.yml`
- [ ] Run full backfill overnight
- [ ] Verify S3 data + STAC catalog
- [ ] `/code-check` before each commit
