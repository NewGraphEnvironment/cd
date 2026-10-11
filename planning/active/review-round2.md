# Code-check round 2 — branch 128-move-run-provenance-to-the-stac-process

Reviewer: subagent, read-only (no repo files modified besides this one).

## Clean

No issues found.

## Round 1 fixes, checked

- **`daily_publish()` now passes the checkout's SHA to `publish_sha_problems()`** (scripts/_publish.R:231). This is right on CI. `pipeline_update_edh.R` calls `run_start()` at line 119, before STEP D (line 291), so the `CD_SHA` env var is `GITHUB_SHA`. `run_provenance()` returns that value, and it is never `-dirty` or `unknown`. `publish_sha_problems()` then returns before the origin/main check because `GITHUB_ACTIONS == "true"`, so CI gets no new refusal. Off CI:
  - A live `pipeline_update_edh.R` run gives the same SHA as the files it just wrote.
  - `daily_publish.R` gets `git rev-parse HEAD`, with `-dirty` if `git status --porcelain` shows changes. Everything the publish writes is gitignored: `data/backfill/`, `logs/*.log` and `scripts/__pycache__/`. A clean checkout of main therefore passes, and any other checkout is refused, as intended.

  The check runs only when `!dry_run`, as it does in the sync path.
- **catalog_publish.R header.** It now correctly says that a STEP 5 failure is refused here and points at `catalog_repair_hint()`, which this branch left unchanged.

## Checked and not a problem

- **`stac_provenance()`**, which writes both documents:
  - `NULL` tags are dropped, so jsonlite writes no `{}`.
  - `list(cd = sha)` serialises as an object. A one-link `list(list(...))` stays an array under `auto_unbox`.
  - Only digit run ids link, and `""` and `"12a"` are rejected.
  - `processing:datetime` is the tag string verbatim.
- **Reader keys.** The reader on branch 126 reads exactly these keys:
  - `cd_catalog.R` reads `processing:version`, `processing:software[["cd"]]`, `processing:datetime` and the `processing-execution` link.
  - `cd_extract_daily.R` reads `processing:datetime`.
- **`manifest_entries()`.** `cd:::stac_provenance` resolves to the installed cd from `local::.` on CI (climate-update.yml:57). Off CI it resolves through `load_cd()` (pkgload), and test_lib.R:371 calls `pkgload::load_all`. The cd 0.6.3 installed on this machine lacks the function, but none of these callers reaches it.
- **Old keys.** No script outside the tests still reads `cd:sha`, `cd:run_*` or `cd:version` (grep over scripts/, R/, .github/).
- **`manifest_problems()` vocabulary guard.** It runs on `merged` on every path, the dry run included, so a partial local dir over an old-vocabulary live manifest is refused. `entry_sha()` and the `$` lookups have no sibling keys to partial-match.
- **`daily_publish(sync = FALSE)`.**
  - The pre-check (`after` against `merged`) admits a local file that is not on S3. The ETag check then refuses it, in both the dry run and the live run, before the conditional put.
  - The live path still re-hashes (`checksum_problems`) and compares the listing.
  - No `cd_s3_push` runs.
- **catalog_publish.R.**
  - `cd_stac_catalog()` arguments match both pipelines: the default id, title and description, `base_url = cog_base`, and a root link of `./catalog.json`.
  - The sync filters are in the right order. A stray top-level `.tif` on S3 is refused through the item-set comparison, and leftover temp files through `stray_problems()`. Both fail safe.
  - Unreadable COGs make `terra::rast()` raise before any publish.
  - A failed HEAD gives `--if-none-match '*'`, which is refused because the key exists.
  - Interleaving with a CI publish is covered as follows:
    - COGs ahead of the catalog are caught by the span check.
    - A same-span rebuild is caught by the checksum comparison.
    - A catalog that changes is caught by `--if-match`, which round 124 tested live on `_healthcheck/`.
    - CI's later unconditional `aws s3 cp` writes a correct, newer catalog.
  - `s3api put-object --content-type application/json` matches what `aws s3 cp` infers for `.json`.
- **Tests.**
  - The `metags<-` merge in test_lib.R:505 leaves the other tags in place, and `ck_r2` is not used after it.
  - The new expectations reach their failure modes: old-key entry, missing or offset datetime, `+00:00` accepted, CI link, untagged item with no extension, and the exact-string run time.
