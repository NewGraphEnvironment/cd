# Findings — Wire cd_cache into the COG read path (#76)

## Plan-mode exploration (2026-06-23)

### Read path
- `cd_extract()` (`R/cd_extract.R:43`) loops catalog rows through
  `cd_crop()`. `cd_crop()` (`R/cd_crop.R:23`) calls `terra::rast(href)`
  directly on the remote URL — no caching.
- Only `cd_extract` calls `cd_crop` internally. `cd_crop` is also
  exported and called directly (e.g. vignette spatial-tmean live
  equivalent). Routing `cd_crop` through the cache covers both.

### Orphaned cache module
- `R/cd_cache.R` ships `cd_cache_path()`, `cd_cache_clear()`,
  `cd_cache_info()` backed by `rappdirs::user_cache_dir("cd")`. No
  fetch-through layer; nothing in `R/` calls them.

### Invalidation signal
- STAC items (`inst/extdata/example_catalog.json`, writer in
  `R/cd_stac_catalog.R:118`) carry only `cd:variable`, `cd:period`,
  `datetime`, `start_datetime`, `end_datetime`. **No `updated` field,
  no etag.** So the only freshness signal is an HTTP HEAD on the COG
  URL (S3 ETag / Last-Modified). Confirmed: invalidation must be
  HEAD-based, per the issue's own suggestion.

### Dependencies
- `curl` and `httr` both available transitively, but neither in
  DESCRIPTION Imports. Plan adds `curl` (lighter) to Imports.

### CI safety
- Exported-function examples use local `system.file()` paths →
  cache passthrough, no network in `R CMD check` examples.
- Vignettes load pre-computed `.rds` (`inst/vignette-data/`), not live
  S3, so pkgdown CI never exercises the live fetch path. Cache wiring
  won't break CI.

## Decisions captured
- Whole-COG cache (not AOI-cropped subsets).
- Filename = hash(url); sidecar `.meta` holds etag/size/timestamp.
- HEAD-always revalidation + `options(cd.cache_revalidate = FALSE)`
  opt-out (user-approved).
- Atomic temp→rename with Content-Length size validation.

## Egress confirmation (live S3 smoke test, 2026-06-24)

Ran `cd_cache_fetch()` against the real catalog
(`https://stac-era5-land.s3.us-west-2.amazonaws.com/prcp_annual.tif`,
5.26 MB) in a throwaway cache dir. Not a committed test (needs network);
documented here as the issue's "second knit does ~zero egress" check.

| Call | Time | Network |
|------|------|---------|
| 1st fetch | 0.8 s | full 5.26 MB download |
| 2nd fetch (HEAD revalidate) | 0.04 s | ~1 KB HEAD only, file mtime unchanged → no re-download |
| 3rd fetch (`cd.cache_revalidate = FALSE`) | 0.000 s | zero network |

Sidecar `.meta` captured the real S3 ETag (`bb297f3a…`) and
Content-Length (5518610). So a repeat report/vignette build drops from
N × full-COG egress to N × ~1 KB HEAD (or zero with revalidate off).
Confirms the fix kills the recurring egress driver in rtj#168.

## Issue context

(full body)

The consumer read path re-downloads every COG from S3 on every call.
`cd_extract()` loops each catalog row through `cd_crop()`, which does
`terra::rast(href)` directly on a `/vsicurl/` URL. GDAL's `/vsicurl/`
only keeps a small in-memory chunk cache per session (~16 MB default)
with no on-disk persistence across R sessions. So every separate report
render, appendix knit, or vignette build re-pulls the full overviews +
tiles for each AOI from scratch. Multiple dev iterations × multiple AOIs
× all variables/periods → hundreds of GB of repeated downloads. This is
the likely dominant driver of S3 egress (~$17 / ~290 GB May 2026,
rtj#168). Self-inflicted, recurring, avoidable.

`R/cd_cache.R` ships the cache helpers but nothing in `R/` calls them.
Wiring it into the read path turns repeated builds from network pulls
into local reads.

References:
- NewGraphEnvironment/rtj#168 — account-wide S3 cost guardrails (this is
  the source-side fix for the egress that issue alarms on).
