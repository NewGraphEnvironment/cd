# Task: Surface checksums and run provenance in cd_catalog() and the extract functions (#126)

**If we do it:** an analysis built with `cd_catalog()` / `cd_extract()` / `cd_extract_daily()` can record which build of the layers it read (checksum and `cd:sha`), so a consumer such as wet can cite it and notice when a republish changes it. **If we never do:** #124's checksums and provenance are on S3 but only reachable by reading `catalog.json` or `daily/manifest.json` by hand.

Decisions from the plan gate:
- **Provenance moves to the STAC processing extension, in a separate cd issue that lands
  first.** `cd:version` becomes `processing:version`, `cd:sha` becomes
  `processing:software$cd`, `cd:run_time` becomes `processing:datetime`, and `cd:run_id`
  becomes a `processing-execution` link. The new issue renames the keys in the writers
  and republishes the catalog and manifest. #126 reads only the new keys.
  `cd:variable`/`cd:period` stay as they are and are not registered in crate (only cd
  reads them; renaming them would break installed copies of `cd_catalog()`).
- **Extract outputs get columns**, `checksum` and `cd_sha`, one value per file read.
  Probed: `cd_baseline()`, `cd_anomaly()` and `cd_trend()` drop extra columns without
  error, and columns survive `bind_rows()` and CSV.

Live state, checked 2026-10-10: the catalog items and the manifest entries carry
`cd:*` keys (v0.6.3, sha 349f9d7). The bundled example COGs and `example_catalog.json`
carry no provenance, so the examples show `NA`.


## Phase 0: Prerequisite issue
- [x] File a cd issue (#128): rename the provenance keys to `processing:*` (v1.2.0 schema in
      `stac_extensions`) in `cd_stac_item()` (`R/cd_stac_catalog.R`),
      `manifest_entries()` (`scripts/_lib.R`), the publish checks
      (`provenance_problems()`, tests in `test-cd_stac_catalog.R`, `scripts/test_lib.R`),
      then republish `catalog.json` and `daily/manifest.json`. Note in that issue that
      #126 depends on it, and add the dependency to #126's body.

## Phase 1: cd_catalog() columns
- [ ] Tests first (`tests/testthat/test-cd_catalog.R`):
  - The example catalog gets the new columns, typed, all `NA`.
  - A synthetic catalog with `file:*` and `processing:*` fields parses to the right values.
  - An item missing some fields gets `NA` in those columns only.
  - An empty catalog keeps every column with its type.
- [ ] `R/cd_catalog.R`: add `checksum` (from `assets$data$file:checksum`), `size`
      (double), `cd_version`, `cd_sha` (`processing:software$cd`), `run_time`
      (character), and `run_url` (the href of the `processing-execution` link), each
      `NA` when absent. Write one small helper so a missing field never errors.
- [ ] Update the roxygen `@return` (a checksum identifies a build, not values).
      Run `devtools::document()`.

## Phase 2: cd_extract() columns
- [ ] Tests (`test-cd_extract.R`): `checksum`/`cd_sha` are copied from the catalog row
      onto every row of that variable/period, and a catalog without those columns
      (hand-built, or saved before this release) gives `NA`, using the existing
      `col_or_na()` helper.
- [ ] `R/cd_extract.R`: carry `rows$checksum[i]` and `rows$cd_sha[i]` through
      `col_or_na()`. Update `@return`.

## Phase 3: cd_extract_daily() columns
- [ ] Tests (`test-cd_extract_daily.R`):
  - A temp source made of `example_daily` plus a `manifest.json` with a distinct
    checksum per file: each row carries its own file's checksum and SHA.
  - A source with no manifest gives `NA` and no warning.
  - A remote source whose manifest can't be read (mocked) gives a warning and `NA`.
  - A file missing from the manifest gives `NA` on its rows.
  - The zero-point output keeps both columns.
- [ ] `R/cd_extract_daily.R`: add a `daily_manifest(source)` helper that reads
      `<source>/manifest.json` once per call (local: absent means `NULL`; remote: a
      failed read warns and returns `NULL`). Look up `<v>_daily_<yr>.tif` per piece
      and add `checksum` and `cd_sha` to `out_empty` and the final tibble. Update
      `@return`. Document that the manifest is read live while `cache = TRUE` files
      are ETag-validated at fetch, so the two agree unless a publish lands mid-call.
- [ ] Live canary (`test-cd_extract_daily_live.R`, `skip_on_ci`): the published cube
      returns a non-`NA` checksum. It can only pass after the prerequisite republish.

## Phase 4: Docs
- [ ] NEWS entry, including the issue's note that the #124 republish changes every
      file's bytes, so `cd_cache_fetch()` caches re-download once.
- [ ] CLAUDE.md consumer section: one line saying the extract outputs carry
      `checksum`/`cd_sha` and where they come from.
- [ ] `lintr::lint_package()`, `devtools::test()`, `pkgdown::check_pkgdown()`.

## Validation

- [ ] Tests pass
- [ ] `/code-check` clean (each commit, or once over the branch with `/code-check branch`)
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
