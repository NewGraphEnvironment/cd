# Consumer Extract Functions

## Context
Core consumer pipeline: query catalog, crop to AOI, extract zonal means. Replaces `extract_aoi_anomaly.R`. Depends on metadata functions (#1-#3, merged). All downstream analysis (#12-#16) depends on these.

## Issues
- #9 `cd_catalog()` — STAC catalog reader
- #10 `cd_crop()` — AOI crop and mask
- #11 `cd_extract()` — zonal mean time series

## Tasks
- [x] Create `data-raw/example_climate_tmean.R`
- [x] Ship example data in `inst/extdata/`
- [x] Implement `cd_catalog()` in `R/cd_catalog.R`
- [ ] Implement `cd_crop()` in `R/cd_crop.R`
- [ ] Implement `cd_extract()` in `R/cd_extract.R`
- [x] Write tests: `tests/testthat/test-cd_catalog.R`
- [ ] Write tests: `tests/testthat/test-cd_crop.R`
- [ ] Write tests: `tests/testthat/test-cd_extract.R`
- [ ] `devtools::test()` — all pass
- [ ] `lintr::lint_package()` — clean
- [ ] `/code-check` before each commit
