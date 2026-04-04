# Progress

## Status: In Progress

### Open questions
- [x] Precipitation units — m/day rate, convert × 1000 × days_in_month → mm/month
- [x] Soil moisture weighting — simple mean of 4 layers (close to upstream)
- [x] VPD units — hPa, Tetens formula natively produces hPa

### cd_fetch() — Issue #4
- [x] Implementation
- [x] Tests (mocked)
- [x] Docs
- [x] `/code-check` — fixed empty zip crash + temp dir collision
- [x] Committed

### cd_derive() — Issue #5
- [ ] Implementation
- [ ] Tests (synthetic)
- [ ] Docs
- [ ] `/code-check`
- [ ] Committed

### Validation
- [ ] `scripts/validate_against_upstream.R`
- [ ] Values compared to bc_climate_anomaly NCs

### Final
- [ ] `devtools::test()` all pass
- [ ] `lintr::lint_package()` clean
- [ ] PR created
