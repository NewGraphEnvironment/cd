# Review round 2 — #100 `.Rbuildignore` (consumers of the built package)

## Clean

No issues found.

Angle: consumers of the built or installed package, not the source tree.

- **Installed-path lookups.** I grepped `R/`, `tests/`, `vignettes/`, `inst/`, `scripts/`, `data-raw/` and `.github/` for `system.file`, `find.package`, `path.package`, `here::here`, `../../` and `source(`. Every `system.file()` call targets `inst/extdata` or `inst/vignette-data`, and both ship in the tarball. Nothing resolves `scripts/`, `logs/`, `data/`, `dev/`, `research/`, `planning/` or `CITATION.cff` through the installed package. The `here::here()` calls are in `scripts/rag_*.R`, which run from the checkout. In `R/`, the only `system()` call (`cd_s3_push.R:51`) shells out to the aws CLI, not to a repo script.
- **`^data$`.** This is the one exclusion that could have bitten, because `data/` is R's reserved dataset directory. Here it is safe. `data/` holds nothing tracked (only the local `backfill/` and `update/` working dirs), DESCRIPTION has no `LazyData`, and `R/` documents no datasets. Excluding it also keeps multi-GB local backfill data out of a locally built tarball.
- **`local::.` installs** (climate-update.yml, pkgdown.yaml). pak builds through `.Rbuildignore`, so the installed `cd` lacks `scripts/`, but the workflow runs `Rscript scripts/pipeline_update_edh.R` from the checkout. Both pipeline scripts only `library(cd)` or fall back to `load_all()`, and neither reads anything from the installed package's directory.
- **pkgdown.** It runs `build_site_github_pages(install = FALSE)`, which renders from the source checkout against the `local::.` install. `_pkgdown.yml` references none of the excluded paths. CITATION.cff is not read by pkgdown, which uses `inst/CITATION`.
- **R CMD check on the tarball.** It contains all 22 test files plus `tests/testthat.R`, the two vignette Rmds and `vignettes/references.bib`. In the vignettes, `data-raw/` appears only in an HTML comment, code comments and a caption string, never as a path that gets read. `example_catalog.json` hrefs are relative to `inst/extdata`.
