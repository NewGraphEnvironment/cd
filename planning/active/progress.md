# Progress — Wire cd_cache into the COG read path (#76)

## Session 2026-06-23

- Plan-mode exploration of read path, orphaned cache module, STAC
  invalidation signal, HTTP deps, CI safety — phases approved by user
- User chose HEAD-always revalidation + `cd.cache_revalidate` opt-out
- Created branch `76-wire-cd-cache-read-path` off main
- Scaffolded PWF baseline from issue #76 with approved phases
- Phase 1 complete: `cd_cache_fetch()` + helpers (`cd_is_remote`,
  `cd_cache_valid`, `cd_remote_head`, `cd_remote_download`), `curl`
  Imports + `withr` Suggests, 20 CI-safe tests. Full suite FAIL 0 /
  219 PASS, lint clean. `/code-check` 3 rounds: 2 fixes (etag→size
  fallback for header-poor hosts, `file.rename` failure guard), round
  3 clean.
- Phase 2 complete: `cd_crop(..., cache = TRUE)` routes remote hrefs
  through `cd_cache_fetch` (local passthrough), `cd_extract(..., cache
  = TRUE)` threads it through. Backward-compatible (default TRUE);
  `cache=TRUE`/`FALSE` output identical for local COGs (asserted).
  Full suite FAIL 0 / 206 PASS. Trivial param-threading over the
  3-round-reviewed core — judgment-reviewed, not re-looped.
- Next: Phase 3 — README/pkgdown caching + GDAL stopgap note, second-
  knit egress confirmation, check() clean, NEWS + minor version bump
