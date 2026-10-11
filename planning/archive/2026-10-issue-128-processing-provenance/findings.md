# Findings — Move run provenance to the STAC processing extension (#128)

## Issue context

**If we do it:** the provenance on every published file uses the STAC [processing extension](https://github.com/stac-extensions/processing) (v1.2.0), a standard any STAC reader understands and validates, instead of four `cd:` fields only cd knows. **If we never do:** the fields stay custom, and under NewGraphEnvironment/crate#23's rule (a field with a standard STAC home uses it; a custom prefix names what it describes, not who built the catalogue) they would need a `cd` schema registered in crate as an exception.

The timing matters. The `cd:` provenance keys shipped in v0.6.3 (#124) and nothing reads them yet. #126 is the first reader, so renaming now is nearly free. Renaming after #126 means a migration.

## What

| now (v0.6.3) | becomes |
|---|---|
| `cd:version` | `processing:version` |
| `cd:sha` | `processing:software` = `{"cd": "<sha>"}` (the extension allows commit hashes as values) |
| `cd:run_time` | `processing:datetime`, copied **byte for byte** from the `CD_RUN_TIME` tag: #126 compares the two as exact strings to tell whether the file read is the build the entry describes, so any reformat (`.000Z`, `+00:00`) would drop every checksum |
| `cd:run_id` | a link with `rel: "processing-execution"` to `https://github.com/NewGraphEnvironment/cd/actions/runs/<id>` when `CD_RUN_ID` is a numeric GitHub run id; no link for `local` |

- `cd_stac_item()` (`R/cd_stac_catalog.R`): write the new keys and add `https://stac-extensions.github.io/processing/v1.2.0/schema.json` to `stac_extensions` beside the file extension.
- `manifest_entries()` (`scripts/_lib.R`): use the same keys per file in `daily/manifest.json`. The manifest is not STAC, but it should not use a second vocabulary.
- Readers of the old keys: `scripts/_publish.R` (`daily_publish()` reads `cd:sha`), and the tests in `tests/testthat/test-cd_stac_catalog.R` and `scripts/test_lib.R`. `provenance_problems()` checks the GDAL tags, which stay, so it does not change.
- **The manifest republish must rewrite every entry.** `daily_publish()` lays local entries over the live ones (`manifest_merge()`), so a run holding only some years would leave `cd:*` keys on the rest, and `manifest_problems()` (checksum and size only) would pass the mixed file. Publish from a directory holding the whole cube, or migrate the live entries' keys in one pass, and make `manifest_problems()` refuse an entry without `processing:software`.
- The GDAL tags in the COGs (`CD_VERSION` etc.) are unchanged. They are file-level tags, not STAC fields.
- Republish `catalog.json` and `daily/manifest.json`. The COG bytes do not change, so their checksums stay the same and no consumer cache re-downloads. Only the metadata documents are rewritten. Afterwards, spot-check one catalog item and one manifest entry for the new keys.

## Not in scope

`cd:variable` and `cd:period` stay as they are. No STAC extension covers them, and every installed `cd_catalog()` reads them, so renaming them would break existing installs. Registering them in crate is not worth it for now: cd is their only reader, and cd's own publish checks enforce their shape.

## Blocks

#126, which reads only the new keys and merges after this issue's republish.

## Exploration (2026-10-11)

- **Schema (fetched v1.2.0 `schema.json`):** declaring the extension on an Item
  *requires* at least one `processing:*` field in `properties`, and any unknown
  `processing:` key fails. So an untagged COG must not declare the extension.
  `processing:datetime` must end `Z` or `+00:00`; `CD_RUN_TIME` is written as
  `%Y-%m-%dT%H:%M:%SZ` (`run_provenance()`, `scripts/_lib.R`), so a verbatim copy
  passes. `processing:software` is a string map. `processing-execution` is a
  documented link rel.
- **Readers of the old keys on main:** `cd_stac_item()` (`R/cd_stac_catalog.R:128-134`),
  `manifest_entries()` (`scripts/_lib.R:597-614`), `daily_publish()`
  (`scripts/_publish.R:221`, reads `cd:sha` for `publish_sha_problems()`),
  `tests/testthat/test-cd_stac_catalog.R:98-104`, `scripts/test_lib.R:478-495`.
  `test-cd_cog_write.R:72` and `test_lib.py:414` use `cd:sha` only as an invalid GDAL
  tag name; they stay. `provenance_problems()` checks GDAL tags; unchanged.
- **Local data:** `data/backfill/daily/` holds the full cube (228 files = 3 × 76
  years), so `scripts/daily_publish.R` can rewrite every manifest entry in one pass.
  The catalog is rebuilt from the live COGs (the `catalog_repair_hint()` recipe), so
  its checksums describe the live bytes by construction.
- **Timing hazard:** once `manifest_problems()` refuses entries without
  `processing:software`, STEP D's `daily_manifest_problems()` fails on every path,
  dry run included, until the live manifest is republished. The weekly dry run is
  Mondays 06:00 UTC. So the manifest republish follows the merge promptly.

## Errors Encountered

| Error | Resolution |
|-------|------------|
| Restore-the-bug backup to `$TMPDIR/new.R` failed (`TMPDIR` unset), leaving the mutation in place | Reverted by hand; later mutations back up to the scratchpad |
| Fixture `CD_RUN_TIME = "t"` failed the new UTC datetime guard | Fixture uses `2026-01-01T00:00:00Z` |

## Schema facts (processing v1.2.0, fetched 2026-10-11)

- Declaring the extension on an Item requires >= 1 `processing:*` field in properties; unknown `processing:` keys fail.
- `processing:datetime`: date-time ending `Z` or `+00:00`. `processing:software`: string map. `processing-execution`: documented link rel.
- STAC core item validation fails every cd item (`geometry: null` with `bbox`); pre-existing, not #128's.
