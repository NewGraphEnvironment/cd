# Consumer Analysis Functions

## Context
Final consumer-side group. Pure dataframe math on `cd_extract()` output — no raster I/O. Completes the consumer pipeline: extract → baseline → anomaly → compare → trend → summary.

## Issues
- #12 `cd_baseline()` — flexible reference period
- #13 `cd_anomaly()` — departure from baseline
- #14 `cd_compare()` — arbitrary time window comparison
- #15 `cd_trend()` — Mann-Kendall + Theil-Sen
- #16 `cd_summary()` — reporting table output

## Tasks
- [ ] Implement `cd_baseline()` in `R/cd_baseline.R`
- [ ] Implement `cd_anomaly()` in `R/cd_anomaly.R`
- [ ] Implement `cd_compare()` in `R/cd_compare.R`
- [ ] Implement `cd_trend()` in `R/cd_trend.R`
- [ ] Implement `cd_summary()` in `R/cd_summary.R`
- [ ] Write tests for each function
- [ ] `devtools::test()` — all pass
- [ ] `lintr::lint_package()` — clean
- [ ] `/code-check` before each commit
