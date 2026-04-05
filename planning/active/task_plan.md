# STAC Catalog + S3 Push

## Context
Final producer functions. Generate static STAC catalog JSON from COGs, push to `stac-era5-land` S3 bucket. Completes the producer pipeline: fetch → derive → cog_write → stac_catalog → s3_push.

## Issues
- #7 `cd_stac_catalog()` — STAC JSON generation
- #8 `cd_s3_push()` — S3 upload

## Tasks
- [ ] Fix `cd_catalog_default()` URL to real bucket
- [ ] Implement `cd_stac_catalog()` in `R/cd_stac_catalog.R`
- [ ] Implement `cd_s3_push()` in `R/cd_s3_push.R`
- [ ] Write tests for each function
- [ ] End-to-end: generate catalog → read with cd_catalog()
- [ ] `devtools::test()` — all pass
- [ ] `lintr::lint_package()` — clean
- [ ] `/code-check` before each commit
