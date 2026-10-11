# Code-check round 1 — branch 128-move-run-provenance-to-the-stac-process

Reviewer: subagent, read-only (no repo files modified besides this one).

## Findings

- **[severity: fragile]** scripts/_publish.R:224-231 (`daily_publish()`, used with `sync = FALSE` by `scripts/daily_publish.R --manifest-only`) — the live manifest-only republish never checks the checkout that writes the manifest. `publish_sha_problems()` is given only the files' own `CD_SHA`s (`entry_sha()` of each local entry). In the sync path that is close enough, because the files were built by this checkout. In manifest-only mode the files are old builds whose SHAs are already on origin/main, so they always pass. Meanwhile the manifest's content comes from the checkout: `manifest_entries()` calls `cd:::stac_provenance()` loaded by `load_cd()` (pkgload off CI), and `manifest_problems()` comes from the checkout's `_lib.R`. A run from an unmerged branch (this one, for example) or a dirty tree would therefore publish `daily/manifest.json` in whatever vocabulary that code writes, with nothing refusing it. `scripts/catalog_publish.R:455` closes exactly this gap for the catalog (`publish_sha_problems(run_provenance()[["CD_SHA"]])`), so the guard landed in one of the two metadata-republish callers and not the other. "The live republish runs post-merge from main" is enforced for the catalog and only by convention for the manifest. Fix: when `!sync && !dry_run`, add `publish_sha_problems(run_provenance()[["CD_SHA"]])` to `problems`, the same as catalog_publish.R.

- **[severity: fragile, operator guidance]** scripts/catalog_publish.R:8-9 — the header says the script is for "a catalog a failed STEP 5 left behind its COGs (catalog_repair_hint() in _lib.R points here)". Both halves are wrong:
  - `catalog_repair_hint()` was deliberately left unchanged (task_plan Phase 3, review B1) and does not name this script.
  - A failed STEP 5 leaves COGs ahead of the catalog, which is the case this script refuses: either `spans$ahead` is non-empty, or `spans$common` is not equal to the live catalog's `years` (lines 403-411).

  An operator who follows the header after a failed STEP 5 gets a refusal, and the header names no other remedy. Fix: drop that clause, or replace it with "for a failed STEP 5, use catalog_repair_hint() / stage 3".

## Checked and not a problem

- `stac_provenance()`: absent tags are left out, so no `{}` is written. Only digit run ids link. The extension is declared only when a `processing:` property exists. A link with no properties, and so no declared extension, is still schema-valid.
- `processing:datetime` is copied verbatim. Both writers (`run_provenance()` in R, `_lib.py`) emit `...Z`, which `manifest_problems()`'s `(Z|\+00:00)$` accepts. This matches what reader branch 126 (`build_checksum`, `cd_extract_daily`) compares against.
- `manifest_problems()` vocabulary guard: a partial local dir over an old live manifest is refused, so mixed vocabularies cannot be published. `daily_manifest_problems()` applies it to the live manifest in STEP D, so CI STEP D fails between the merge and the manifest republish. task_plan Phase 5 already schedules the republish before the next Monday dry run.
- `daily_publish(sync = FALSE)`:
  - dry run: runs the ETag check before reporting.
  - live: runs ETag, checksum and listing checks before `s3_put_if`, with no `cd_s3_push`.
  - error text distinguishes the two modes.
- catalog_publish.R:
  - `aws s3 sync` filter order: `*/*` excluded last, so later filters win.
  - `--exact-timestamps`: needed on download. Without it a same-size object rebuilt on S3 is skipped when the local copy is older. The ETag check backstops it anyway.
  - The `--delete` scope is right, and a leftover partial download is caught by `stray_problems()`, which fails safe.
  - Item set, span, grid and provenance checks run, then the comparison with the live checksums.
  - Conditional put on the live ETag, then byte read-back.
  - A HEAD failure gives `--if-none-match '*'`, which is refused because the key exists, so it fails safe.
  - The HEAD taken after the GET leaves a small window, but any COG change in that window is caught by the span and checksum comparisons.
- `cd:::stac_provenance` in `_lib.R`: on CI it resolves to cd installed from the checkout (`local::.`). Off CI it resolves through `load_cd()`, and `test_lib.R` uses `pkgload::load_all`.
- Tests: the new expectations reach their failure modes. They cover the old-key entry, a missing datetime, a non-UTC offset, `+00:00` accepted, the CI link, an untagged item with no extension, and the exact-string run time.
