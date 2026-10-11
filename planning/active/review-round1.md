# Code-check round 1 — branch 126-surface-checksums-and-run-provenance-in

Scope: `review-branch.diff` (branch vs merge-base with origin/main, planning/ excluded).
Changed test files (test-cd_catalog, test-cd_extract, test-cd_extract_daily) plus
test-cd_stac_catalog and test-cd_crop run green in a copy of the repo
(`NOT_CRAN=true`, terra 1.9.50).

## Findings

- **[severity: fragile]** R/cd_extract_daily.R:173-174 and :231 — a malformed manifest stops the
  whole read, though the design (and the roxygen at :216-219) says provenance must never stop a
  read. The catalog side wraps every lookup in `tryCatch` (`catalog_field()`); the daily side does
  not:
  - an entry that is a scalar rather than an object (`{"files": {"tmean_daily_2002.tif": "1220aa"}}`)
    makes `entry[["file:checksum"]]` raise `subscript out of bounds`;
  - a manifest whose top level is a JSON scalar (`"x"`, from a local file or a 200 body) makes
    `m$files` raise `$ operator is invalid for atomic vectors` before the `is.list()` check runs.

  Both reproduced against the bundled `example_daily` copied to a temp dir with a hand-written
  `manifest.json`: `cd_extract_daily()` errors instead of returning values with `NA` checksum. The
  published manifest is shape-checked by `daily_publish()`, so the live risk is low. But
  `daily_manifest()` reads any `<source>/manifest.json` a user's local cube happens to hold, and
  the values the user asked for are lost for a provenance field. Fix: guard with
  `is.list(m) && is.list(m$files)` (or `m[["files"]]`), and read the entry fields only when
  `is.list(entry)` (or wrap the lookup the way `catalog_field()` does).

- **[severity: fragile]** R/cd_catalog.R:64 — `%||%` is neither imported (NAMESPACE imports only
  `rlang::.data`/`.env`) nor defined in the package. DESCRIPTION declares `R (>= 4.1)`, and base R
  gained `%||%` only in 4.4.0. On R 4.1–4.3 the call raises "could not find function", and
  `catalog_field()`'s `tryCatch` swallows it, so `run_url` is silently `NA` for every item. It
  then reads as "local build" rather than as an error. Pre-existing use at R/cd_cache.R:16 already
  breaks remote caching on R < 4.4, so the package is de facto 4.4+, but this new use fails silently
  rather than loudly. Fix: `importFrom(rlang, "%||%")`, or an explicit `if (is.null(l$rel))`.

## Checked and not defects

- Fails toward pass: `build_checksum()` keeps the entry's checksum only when the entry's run time
  and the read file's `CD_RUN_TIME` are both non-NA and equal. `NA` in any input gives
  `FALSE & …` = `FALSE`, never `NA`, so `ifelse()` cannot leak the claimed value. In `cd_extract()`
  the tags are read from the same resolved `src` path that is cropped (cache resolved once). In
  `cd_extract_daily()` they come from the same `r` the values are extracted from. `CD_RUN_TIME` is
  fixed per run at second resolution (`run_start()`), and `--rewrite` stamps fresh provenance, so
  two different builds of one file do not share a run time.
- Column types in every return path: empty catalog (`items <- list()`, so every `vapply` gives
  `character(0)` and `size` is `numeric(0)`); zero matching catalog rows (the typed template in
  `bind_rows`); zero points (`out_empty`); all points off-grid (`ck` of length 1 recycles over the
  `.pt` rows); `ifelse()` returns character in every branch.
- JSON shapes: JSON `null` gives NULL, then NA. An object or array gives `is.list`, then NA. A
  `processing:software` that is a string raises `[[` out of bounds, which is caught, then NA.
  `links` missing or with no `processing-execution` rel: `list()[[NA_integer_]]` is NULL, then NA.
  A `file:size` above 2^31 (3000000001) round-trips exactly through `as.character()` and
  `as.numeric()`.
- Partial matching: `processing:software` is indexed with `[["cd"]]` (exact), and the test with
  `cdo` reaches the defect it names. The manifest is indexed with `[[file]]` and
  `[["file:checksum"]]` (exact). No STAC processing key is a prefix of another.
- `terra::metags()` domain column: added in terra 1.8-42, below the `terra (>= 1.8-54)` floor.
- Remote manifest fetch: curl follows redirects, a status of 400 or more gives NULL and a warning,
  and the 60 s timeout bounds an offline call. The body is ASCII JSON, so `rawToChar()` encoding
  is not a concern.
- Downstream chain: `cd_anomaly()` and `cd_compare()` join by explicit `by =` and select explicit
  columns, so the two new extract columns are dropped, as CLAUDE.md states.
- Tests reach their failure modes: the stale-build, untagged-file, catalog-without-run-time and
  `cd:`-keys-only manifest tests all fail if `build_checksum()` returned the claimed checksum
  unconditionally.
