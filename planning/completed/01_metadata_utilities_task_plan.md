# Metadata & Utility Functions

## Context
First function group for the cd package. These are the foundational metadata and cache utilities that all other functions depend on. No external data or network calls — pure R.

## Issues
- #1 `cd_variables()` — variable metadata lookup
- #2 `cd_periods()` — temporal period lookup  
- #3 `cd_cache_*()` — cache management

## Tasks
- [x] Implement `cd_variables()` in `R/cd_variables.R`
- [x] Implement `cd_periods()` in `R/cd_periods.R`
- [x] Implement `cd_cache_path()`, `cd_cache_clear()`, `cd_cache_info()` in `R/cd_cache.R`
- [x] Write tests: `tests/testthat/test-cd_variables.R`
- [x] Write tests: `tests/testthat/test-cd_periods.R`
- [x] Write tests: `tests/testthat/test-cd_cache.R`
- [x] `devtools::document()` — generate man pages
- [x] `devtools::test()` — all pass (25/25)
- [x] `lintr::lint_package()` — clean
- [x] Commit each function with `Fixes #N`

## Findings

(populated during implementation)

## Progress

(updated as tasks complete)
