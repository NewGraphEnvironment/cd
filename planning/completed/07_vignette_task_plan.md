# Vignette + Plot Functions

## Context
Vignette using KOTL (Kootenay Lake) watershed against live S3 data. Tells the climate departure story. Plot functions added to package for reusability.

## Issues
- #27 Vignette with real S3 data
- TBD cd_plot_timeseries() 
- TBD cd_plot_comparison()

## Tasks
- [ ] `data-raw/example_aoi_kotl.R` — fetch KOTL via bcdata, ship gpkg
- [ ] File issues for plot functions
- [ ] `R/cd_plot_timeseries.R` + tests
- [ ] `R/cd_plot_comparison.R` + tests
- [ ] `vignettes/climate-departure.Rmd`
- [ ] Build vignette locally
- [ ] `devtools::test()` — all pass
- [ ] `lintr::lint_package()` — clean
- [ ] `/code-check` before each commit
