# Review round 2 — #112 (build/publish side)

## Clean
No issues found.

Checked:
- `.github/workflows/pkgdown.yaml`: no step copies, size-checks, globs or uploads `inst/extdata`. The allowed-pages gate looks at root markdown pages, not extdata.
- `.github/workflows/climate-update.yml`, `update-citation-cff.yaml`: no extdata references.
- Vignettes: `kootenay-lake.Rmd` loads `example_aoi_kootenay_lake.gpkg` and `context_kootenay_lake.gpkg`, and `peace-fwcp.Rmd` loads the fwcp_peace files and the commentary CSV. Both are still present. Neither vignette uses `kotl`.
- `R/cd_stac_catalog.R:37` lists only `\.tif$` in `cog_dir`. The `tests/testthat/test-cd_stac_catalog.R` expectations are `>= 1` row/item checks over `example_climate.tif`, so removing a gpkg cannot change them.
- `list.files` / `dir_ls` across R/, tests/, vignettes/, data-raw/ and scripts/: none of them point at extdata as a directory, apart from the tif-filtered STAC call above.
- No reference to `context_kotl` or `example_context_kotl` is left outside planning/ and .git. README still uses `example_aoi_kotl.gpkg`, which is kept.
- The new referent `data-raw/example_context_kootenay_lake.R` exists and describes the same fwapg recipe.

Note (not a defect): `example_context_kootenay_lake.R:3` and `example_context_fwcp_peace.R:3` now each say "same recipe as" the other. The pointer is circular but both files exist, so it is harmless.
