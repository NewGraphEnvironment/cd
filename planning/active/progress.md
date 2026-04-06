# Progress

## Status: In Progress

### Period aggregation
- [x] Flexible season definitions (cd_seasons() configurable)
- [x] Annual/seasonal/monthly aggregation from monthly data
- [x] Tests (mean + sum + custom seasons)
- [x] `/code-check` — added 12-band validation guard
- [x] Committed

### Daily statistics (tmax/tmin)
- [x] Test CDS product — works, returns .nc not .zip
- [x] Needs `day` and `time_zone` params
- [x] Rate limiting solved: `retry = 120` (poll every 2 min)
- [ ] `/code-check`
- [ ] Committed

### Backfill script
- [x] `scripts/pipeline_backfill.R`
- [ ] Tested for 1 year (full BC bbox)
- [ ] `/code-check`
- [ ] Committed

### Update script
- [ ] `scripts/pipeline_update.R`
- [ ] `/code-check`
- [ ] Committed

### GitHub Action
- [ ] `.github/workflows/climate-update.yml`
- [ ] `/code-check`
- [ ] Committed

### Final
- [ ] Full backfill run
- [ ] S3 data verified
- [ ] PR created
