# Task: Wire cd_cache into the COG read path so repeated builds read locally (#76)

## Problem

The consumer read path re-downloads every COG from S3 on every call.
`cd_extract()` loops each catalog row through `cd_crop()`, which does
`terra::rast(href)` directly on a `/vsicurl/` URL. GDAL's `/vsicurl/`
only keeps a small in-memory chunk cache per session with no on-disk
persistence across R sessions, so every report render, appendix knit,
or vignette build re-pulls the full COG for each AOI from scratch. This
is the likely dominant driver of S3 egress (~$17 / ~290 GB in May 2026,
NewGraphEnvironment/rtj#168). The fix is half-built: `R/cd_cache.R` ships
`cd_cache_path()` / `cd_cache_clear()` / `cd_cache_info()` but nothing in
`R/` calls them — the module is orphaned.

## Approved design (from plan-mode exploration)

- **Whole-COG caching** (dedupes across overlapping AOIs, simplest key).
- **Cache key:** `hash(url)` for the cached filename (keeps `.tif`
  extension so terra reads it), with a sidecar `.meta` JSON holding
  `{url, etag, size, downloaded_at}`. Keying the filename by url-hash
  (not etag) means a republish overwrites in place — self-cleaning.
- **Invalidation:** cheap HTTP HEAD per read (ETag + Content-Length via
  `curl`). HEAD is <1 KB vs GB-scale bodies. ETag match → serve local;
  else re-download. STAC items carry no `updated`/etag field, so HEAD is
  the only available freshness signal.
- **Revalidation cadence:** HEAD-always for correctness, with an opt-out
  `options(cd.cache_revalidate = FALSE)` for a fully-offline fast path.
- **Offline fallback:** HEAD fails + local copy present → serve cached.
- **Partial-download guard:** download to temp, validate byte size vs
  `Content-Length`, atomic rename — never serve a truncated file.
- **New dependency:** add `curl` to DESCRIPTION Imports.

## Phase 1: Fetch-through-cache core

- [x] New `R/cd_cache_fetch.R`: `cd_cache_fetch(href, refresh = FALSE, cache_dir = NULL)` returns a local path
- [x] Local (non-http/s3) hrefs pass through untouched
- [x] HEAD → ETag/size; serve local on ETag match (size fallback when ETag absent), else download-temp → size-validate → atomic rename → write `.meta`
- [x] `refresh = TRUE` forces re-download; `options(cd.cache_revalidate = FALSE)` skips HEAD; offline-with-local-copy serves cached + messages
- [x] Add `curl` to DESCRIPTION Imports (and `withr` to Suggests for tests)
- [x] `tests/testthat/test-cd_cache_fetch.R`: 20 tests via mocked fetcher (`local_mocked_bindings`), CI-safe — passthrough, key/meta creation, ETag + size revalidation, partial-download rejection, refresh, offline fallback, revalidate opt-out

## Phase 2: Wire into read path

- [ ] `cd_crop(href, aoi, cache = TRUE)` — route remote hrefs through `cd_cache_fetch`, local passthrough
- [ ] `cd_extract(..., cache = TRUE)` — thread `cache` through to `cd_crop`
- [ ] Update roxygen (`@param cache`, runnable examples stay local/passthrough)
- [ ] Extend `test-cd_crop.R` / `test-cd_extract.R`: `cache = TRUE` with local file still passes through correctly

## Phase 3: Docs, README stopgap, egress confirmation

- [ ] README + pkgdown note: caching behavior + GDAL `/vsicurl/` env-var stopgap (`VSI_CACHE`, `GDAL_HTTP_*`)
- [ ] Manually confirm a second knit does ~zero egress (document method + result in findings.md)
- [ ] `devtools::document()` + `devtools::check()` clean
- [ ] NEWS entry + version bump (minor — new `cache` args + `curl` dep) as final commit

## Validation

- [ ] Tests pass
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
