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
- [x] Implement `cd_baseline()` in `R/cd_baseline.R`
- [x] Implement `cd_anomaly()` in `R/cd_anomaly.R`
- [x] Implement `cd_compare()` in `R/cd_compare.R`
- [x] Implement `cd_trend()` in `R/cd_trend.R`
- [x] Implement `cd_summary()` in `R/cd_summary.R`
- [x] Write tests for each function
- [x] `devtools::test()` — all pass (111/111)
- [x] `lintr::lint_package()` — clean
- [x] `/code-check` before each commit

## Additional work on this branch
- [x] Research departure framing for cd_compare() defaults (issue #20)
- [x] Build ragnar store from 6 papers
- [x] Write auditable findings with verbatim quotes
- [x] Review agent verified 5/7 claims, fixed 2 issues
