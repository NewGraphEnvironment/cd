## Outcome

Wired the orphaned `cd_cache` module into the consumer COG read path so
repeated extractions, report renders, and vignette rebuilds read each COG
from a local on-disk cache instead of re-pulling from S3 every call —
killing the dominant recurring S3 egress driver (rtj#168). New exported
`cd_cache_fetch()` downloads a remote http(s) COG once (filename =
`hash(url)` + ext, sidecar `.meta` JSON with the S3 ETag/size/timestamp),
revalidates freshness with a cheap HTTP HEAD (ETag, falling back to
Content-Length size when a host returns no ETag), and serves the local
copy on a hit. Downloads go to a temp file in the cache dir, are
size-validated against Content-Length, then atomically renamed (guarded
against `file.rename` failure) so a truncated file is never served. A
failed HEAD with a cached copy present serves the cache; `options(
cd.cache_revalidate = FALSE)` skips the HEAD entirely for offline work.
`cd_crop()` and `cd_extract()` gained `cache = TRUE` (default), threading
remote reads through the cache while local paths pass through unchanged.

Built in three phases (core / read-path wiring / docs+release). Phase 1
got a 3-round `/code-check` that caught two real issues — perpetual
re-download for ETag-less hosts (fixed with a Content-Length size
fallback in `cd_cache_valid()`) and an unchecked `file.rename` return
(now `stop()`s on failure). Tests use testthat3e `local_mocked_bindings`
to mock `cd_remote_head`/`cd_remote_download`, keeping the 20 cache tests
CI-safe with no real network. Egress kill was confirmed against the live
S3 catalog: first read of `prcp_annual.tif` pulled 5.26 MB; the second
read was a ~1 KB HEAD with no re-download (0.04 s), and fully offline
(0 s) with revalidation disabled. Released as v0.4.0 (minor — new
exported function, new `cache` args, new `curl` dependency). Known
follow-up surfaced but left out of scope: `planning/` is not in
`.Rbuildignore`, which is the source of several pre-existing `--as-cran`
NOTEs.

Closed by: PR #76 (commits 39c7833 → f53ba3d on branch
`76-wire-cd-cache-read-path`)
