# Task: Move run provenance to the STAC processing extension (processing:*) before anything reads cd:sha (#128)

**If we do it:** the provenance on every published file uses the STAC [processing extension](https://github.com/stac-extensions/processing) (v1.2.0), a standard any STAC reader understands and validates, instead of four `cd:` fields only cd knows. **If we never do:** the fields stay custom, and under NewGraphEnvironment/crate#23's rule (a field with a standard STAC home uses it; a custom prefix names what it describes, not who built the catalogue) they would need a `cd` schema registered in crate as an exception.

Branch off main; #126 (PR #129) already reads the new keys and merges after the republish.
Decisions taken at the plan gate: one internal helper `stac_provenance()` feeds both
writers; manifest entries carry the run link as STAC-shaped `links`; the catalog
republish gets `scripts/catalog_publish.R`; the live republish runs post-merge from main.

## Phase 1: STAC item writer
- [x] `stac_provenance(tags)` in `R/cd_stac_catalog.R`: `processing:version` ←
      `CD_VERSION`, `processing:software` ← `list(cd = CD_SHA)`, `processing:datetime`
      ← `CD_RUN_TIME` byte for byte, a `processing-execution` link to
      `https://github.com/NewGraphEnvironment/cd/actions/runs/<id>` only when
      `CD_RUN_ID` matches `^[0-9]+$`; absent tags omitted (jsonlite writes NULL as `{}`)
- [x] `cd_stac_item()` uses it; declares
      `https://stac-extensions.github.io/processing/v1.2.0/schema.json` beside the file
      extension only when the item carries a `processing:*` field; roxygen updated,
      `devtools::document()`
- [x] Tests (`test-cd_stac_catalog.R`): new keys and values; `processing:datetime`
      identical to the tag string; link for a numeric id, none for `"local"`; an
      untagged COG has no `processing:*`, no link, no processing extension; no `cd:`
      key other than `cd:variable`/`cd:period` on any item; `cd_catalog()` still reads
      the catalog. Restore the old writer once and confirm the new tests go red

## Phase 2: daily manifest writer and guard
- [x] `manifest_entries()` (`scripts/_lib.R`) uses `cd:::stac_provenance()`
- [x] `daily_publish()` (`scripts/_publish.R`) reads the SHA from
      `processing:software$cd`
- [x] `manifest_problems()` refuses, by name, any entry without a
      `processing:software` holding a one-string `cd` (so a partial publish can never
      leave a mixed `cd:*`/`processing:*` manifest)
- [x] `scripts/test_lib.R`: update the entry/merge checks to the new keys; add a check
      that a manifest with one `cd:*`-only entry is refused; restore-the-bug once;
      `Rscript scripts/test_lib.R` green

## Phase 3: catalog republish tooling and dry runs
- [x] `scripts/catalog_publish.R` (`--dry-run`): sync live COGs (excluding `daily/`,
      `_backup/`, `_healthcheck/`) to a temp dir; refuse unless all 59 are present and
      end in the same year (`cog_expected()`, `live_spans()`), `stray_problems()` is
      clean; build with `cd_stac_catalog()`; `catalog_problems()` and
      `checksum_problems()` on the result; live: `aws s3 cp` to `catalog.json` then
      `readback_problems()`; dry run writes locally and prints what would go up
- [x] ~~`catalog_repair_hint()` names the script~~ — dropped on review B1: the hint fires when the COGs are ahead of the catalog, which a metadata republish refuses. Hint unchanged; `scripts/test_lib.R` green (104/104)
- [x] Dry runs from the branch: `Rscript scripts/catalog_publish.R --dry-run` and
      `Rscript scripts/daily_publish.R --dry-run` — expect `aws --dryrun` to list **no**
      COG uploads (local cube = live bytes), 228 manifest entries all `processing:*`;
      compare local checksums with the live manifest's
- [x] Validate one built item and the item shape against the official processing
      v1.2.0 and file v2.1.0 schemas (`uvx stac-validator` or python `jsonschema`);
      verification only, not a test
- [x] Review fixes folded in (`review-plan.md`): item set and span from the live catalog;
      conditional upload (`s3_put_if()`), `publish_sha_problems()` on the checkout,
      checksums refused if changed; `daily_publish(sync = FALSE)` / `--manifest-only` so the
      manifest republish cannot upload a COG; `manifest_problems()` also requires a UTC
      `processing:datetime`; `planning/active/compare_128.py` checks old vs new documents
      differ only by the rename and validates items against the processing + file schemas
      (STAC core is skipped: `geometry: null` with `bbox` predates #128)

## Phase 4: docs
- [x] `CLAUDE.md` #124 paragraph: `cd:version`/… → the processing keys and link;
      `scripts/catalog_publish.R` in the Scripts list; `daily_publish.R` header comment
- [x] `devtools::test()` + `lintr::lint_package()` clean; `/code-check branch`
      (three-round floor)

## Phase 5: republish (after merge, on your go) — done 2026-10-11; see README
- [x] From a clean `main`: `Rscript scripts/daily_publish.R --manifest-only`, then
      `Rscript scripts/catalog_publish.R` — before the next Monday 06:00 UTC dry run
- [x] `uv run planning/archive/2026-10-issue-128-processing-provenance/compare_128.py` on `data/backfill/pre_128/*` vs the live
      documents: only the rename, every checksum unchanged
- [x] Tell #126 / PR #129 it can merge

## Validation

- [x] Tests pass
- [x] `/code-check` clean (each commit, or once over the branch with `/code-check branch`)
- [x] PWF checkboxes match landed work
- [x] `/planning-archive` on completion
