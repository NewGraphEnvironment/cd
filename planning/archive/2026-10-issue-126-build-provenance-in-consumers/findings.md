# Findings — Surface checksums and run provenance in cd_catalog() and the extract functions (#126)

## Issue context

**If we do it:** an analysis built with `cd_catalog()` / `cd_extract()` / `cd_extract_daily()` can record which build of the layers it read (checksum and `cd:sha`), so a consumer such as wet can cite it and notice when a republish changes it. **If we never do:** #124's checksums and provenance are on S3 but only reachable by reading `catalog.json` or `daily/manifest.json` by hand.

## What

#124 puts `file:checksum` / `file:size` and `cd:version` / `cd:sha` / `cd:run_time` / `cd:run_id` on every catalog item, and the same per file in `s3://stac-era5-land/daily/manifest.json`. The consumer functions do not surface them:

- `cd_catalog()` returns only `variable`, `period`, `href` (`R/cd_catalog.R`).
- `cd_extract_daily()` returns values with no record of which file build they came from.

Options: add `checksum` and `cd_sha` columns to `cd_catalog()`; attach the build to `cd_extract()` / `cd_extract_daily()` output as an attribute or columns. A checksum identifies a build, not values (the run time is in the bytes), so a changed checksum means "rebuilt", not "different data".

Also note for consumers: the #124 republish changes every published file's bytes, so `cd_cache_fetch()` caches (ETag-validated) re-download once.

Relates to #124


## Plan-gate exploration (2026-10-10)

- Live `catalog.json` items carry `cd:version`/`cd:sha`/`cd:run_time`/`cd:run_id` in
  `properties` and `file:checksum`/`file:size` on `assets$data`; `daily/manifest.json`
  carries the same keys per file (v0.6.3, sha 349f9d7, run_id `local`).
- Bundled `example_catalog.json`, `example_climate.tif` and `example_daily/*.tif` carry
  no provenance tags, so examples will show `NA`.
- `cd_baseline()` / `cd_anomaly()` / `cd_trend()` drop extra input columns without error
  (probed with `checksum`/`cd_sha` added to `cd_extract()` output). A custom attribute
  survives `dplyr::filter()` and `[` but not `bind_rows()`, which the vignette loops use;
  hence columns.

## crate#23 assessment

crate#23 (NewGraphEnvironment/crate) rules: a field with a standard STAC home uses it;
otherwise its prefix names what it describes, not who built the catalogue.

- Provenance has a standard home: STAC processing extension v1.2.0
  (`processing:version`, `processing:software` — values may be commit hashes —
  `processing:datetime`, link rel `processing-execution`). Decided: move to it in a
  separate cd issue landing before #126, while nothing reads the `cd:` keys yet.
- `cd:variable` / `cd:period` have no standard home and break the naming rule, but only
  cd reads them and renaming breaks every installed `cd_catalog()`. Decided: leave them,
  not registered in crate.
- `daily/manifest.json` is not STAC, so crate does not apply; it follows the catalog's keys.

## Errors Encountered

| Error | Resolution |
|-------|------------|
| Live 60 N test (`test-cd_extract_daily_live.R:46`, `expect_no_warning`) failed: today's manifest has `file:checksum` but no `processing:datetime`, so `build_warn()` fired on every live call | Warn only when the entry states a run time and the file's tag differs or is missing (the stale-copy case); an entry with no run time gives NA silently. Found by `NOT_CRAN=true test_file()` of the live tests, 2026-10-10 |
