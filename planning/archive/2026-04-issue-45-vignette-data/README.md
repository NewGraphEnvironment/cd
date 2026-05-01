# Archive: peace-fwcp vignette pre-compute (#45)

## Outcome

Stopped the `peace-fwcp` vignette from hitting the public S3 STAC
catalog ~144 times per CI render. Pre-compute now happens once via
`data-raw/peace_fwcp_vignette_data.R`; the vignette loads bundled
`.rds` + `.tif` from `inst/vignette-data/` and renders in 10 s
(was ~6 min). Released as **v0.1.3** (patch).

Pattern follows the `r-packages` convention in CLAUDE.md: separate
data generation from presentation, and document the equivalent live
calls in chunk comments.

## Key findings worth remembering

- `terra::mean()` on multi-band SpatRaster requires `library(terra)`
  loaded explicitly in `data-raw/` scripts — base `mean()` returns
  NA with a warning. The vignette doesn't hit this because its
  setup chunk loads terra; data-raw scripts need the same.
- `system.file("vignette-data", "...", package = "cd")` works because
  `inst/vignette-data/` is not in `.Rbuildignore` — gets installed
  alongside the package.
- The post-merge `pkgdown.yaml` flake on v0.1.2 was a transient
  /vsicurl/ failure on `prcp_annual.tif`. Same code passed on the
  release-tag re-run minutes later.

## Closing ref

- Issue: NewGraphEnvironment/cd#45
- PR: NewGraphEnvironment/cd#46 (merged 2026-05-01)
