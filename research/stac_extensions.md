# STAC extensions in the published catalog

**Verified:** 2026-10-11 · **Issues:** #124 (file), #128 (processing) · **Produced by:** the v1.2.0 and v2.1.0 `schema.json` files fetched from stac-extensions.github.io, and `planning/archive/2026-10-issue-128-processing-provenance/compare_128.py` run against the built catalog

What the schemas require of a cd catalog item, so a writer change does not have to re-read them.

## Processing extension v1.2.0 (`https://stac-extensions.github.io/processing/v1.2.0/schema.json`)

- **Declaring it obliges a field.** For an Item, the schema's `require_any_field` needs at least one `processing:*` key in `properties` once the URL is in `stac_extensions`. An item from an untagged COG must not declare it; `cd_stac_item()` declares it only when `stac_provenance()` returned a property.
- **No unknown keys.** `fields` is `additionalProperties: false` over `processing:` names, so a misspelt or invented `processing:` key fails validation.
- **`processing:datetime`** is a `date-time` that must end `Z` or `+00:00` (UTC). `CD_RUN_TIME` is written `%Y-%m-%dT%H:%M:%SZ` by `run_provenance()` / `run_start()` and `_lib.py`, and is copied verbatim, because readers match it as an exact string against the file's tag (#126).
- **`processing:software`** is a map of name to string. A commit hash is allowed as the value; cd writes `{"cd": "<sha>"}`.
- **`processing:version`** is a string.
- **Link rel `processing-execution`**: "URL to any resource representing the processing execution". cd links a GitHub Actions run, and only for a digit run id (a local build's `local` gets none).
- The schema puts no constraint on links.

## File extension v2.1.0

`file:checksum` is a multihash (`1220` + sha256 hex for cd), and the schema's `^[a-f0-9]+$` cannot tell a bare digest from a multihash, so `file_multihash()` asserts the shape itself (#124).

## STAC core: every cd item fails, before any extension

Items carry `geometry: null` together with a `bbox`. STAC 1.0.0 core `item.json` forbids a `bbox` when geometry is null, so a full validator (`stac-validator`) fails every item for that reason alone. This predates #124/#128 and is not fixed. Validate cd items against the extension schemas only, e.g. python `jsonschema.validate(item, schema)` per declared extension, which is what `compare_128.py` does.
