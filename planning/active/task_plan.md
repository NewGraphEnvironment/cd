# Producer Fetch & Derive Functions

## Context
Producer-side pipeline: download raw ERA5-Land from CDS, transform to processed climate variables. First R implementation of the external pipeline upstream uses. Two CDS products needed (monthly means + daily statistics for tmax/tmin).

## Issues
- #4 `cd_fetch()` — CDS API download (two products)
- #5 `cd_derive()` — VPD, RH, soil moisture, unit conversion, tmax/tmin aggregation

## Tasks
- [x] Resolve open questions (precip units, soil moisture weighting, VPD units)
- [x] Implement `cd_fetch()` in `R/cd_fetch.R`
- [ ] Implement `cd_derive()` in `R/cd_derive.R`
- [x] Write tests: `tests/testthat/test-cd_fetch.R` (mocked)
- [ ] Write tests: `tests/testthat/test-cd_derive.R` (synthetic rasters)
- [ ] Create `scripts/validate_against_upstream.R`
- [ ] `devtools::test()` — all pass
- [ ] `lintr::lint_package()` — clean
- [ ] `/code-check` before each commit
