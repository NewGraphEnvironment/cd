# Code-check round 1: branch 124 (3c19b71...HEAD)

## Findings

- **[severity: fragile]** scripts/_publish.R:25-29, 127, 172 (`etag_problems()` in `daily_publish()`); same shape at scripts/pipeline_update_edh.R:977 and scripts/pipeline_stage3_edh.R (STEP 3)
  The comment calls the ETag check "the one check that what went up is what was hashed". It does not check that. It compares each S3 object with the file on disk **at check time**. The manifest (or catalog) checksum was taken earlier: `manifest_entries(paths)` at line 127, or `cd_stac_catalog()` in the pipelines. A write to `daily_dir` between the hash and the sync gives a manifest checksum for bytes that are not live, and both checks still pass. The S3 ETag matches the new local file, and `checksum_problems()` ran before the sync. Two writers can do that: `backfill_edh_daily.py --rewrite` and the backfill itself. Both replace files in place with `os.replace`, and the next manual step after a rewrite is `daily_publish.R`. `preflight_single_instance()` guards only the Python side, so `daily_publish.R` can run while a rewrite is still going. For the 228 files the rewrite has not reached yet, `provenance_problems()` does not refuse: they are already tagged by an earlier rewrite. The monthly pipelines have no concurrent writer, so they are exposed only in principle.
  Fix: close the chain hash -> disk -> S3. After the ETag check passes, recompute `checksum_problems(merged, daily_dir, names(local))` before `s3_put()`. In both pipelines, recompute `checksum_problems(catalog_entries(built_json), cog_dir)` before the catalog `aws s3 cp`. Alternatively, have `daily_publish.R` refuse while `backfill_edh_daily` holds its single-instance lock.

- **[severity: fragile]** scripts/_publish.R:128 -> 180 (`daily_manifest_live()` ... `s3_put(manifest_path, ...)`)
  `daily/manifest.json` is a read-modify-write with no precondition. The workflow's `concurrency` group covers CI runs only, not a `daily_publish.R` run by hand. Two publishers each read the live manifest, merge, and upload, and the later upload silently drops what the earlier one added.
  Concrete case: a hand re-tag publishes 228 new checksums while a CI STEP D, which read the old manifest, adds next year. CI uploads last and puts back the old checksums for all 228 files. Its post-sync checks still pass: the name set is unchanged, and `etag_problems()` checks only CI's own new files.
  Nothing detects the result afterwards either. `daily_manifest_problems()` in STEP D compares only the manifest's last year with the newest published year, never entry contents with objects, so every later run reports the cube as described.
  Fix: make the upload conditional on the manifest that was read. Use `aws s3api put-object --if-match <ETag of the manifest read at start>`, or `--if-none-match '*'` when there was none. A lost race then fails loudly instead of overwriting.

- **[severity: fragile]** scripts/_lib.R:379-381 (`run_provenance()`, R side)
  `git status --porcelain` runs with `stderr = FALSE`, and its status attribute is never read. A failed status therefore yields `character(0)`, which is read as a clean tree. The result is a bare SHA, so `sha_problems()` passes it: a guard that fails toward pass. Proven with a fake `git` that answers `rev-parse` and exits 128 on `status`. It gave `CD_SHA = 0123...4567` and `sha_problems()` = `character(0)`.
  The Python twin (`_lib.py` `run_provenance()`) uses `check=True` and returns `"unknown"` in the same case. That is the safe direction, so the two halves of "one env contract" disagree.
  Fix: `if (!is.null(attr(dirty, "status"))) sha <- "unknown"`.

- **[severity: fragile]** scripts/backfill_edh_daily.py:163-173 (`rewrite()`), also `main()` at line 213
  Both stamp `run_provenance()` without refusing a `-dirty` or `unknown` SHA. A live `daily_publish()` refuses exactly those files (scripts/_publish.R:139-140). So a rewrite started from a tree with any change, including an untracked file, produces 228 files that cannot be published, and the whole rewrite has to be redone. The R pipelines check up front for this reason (stage 3: "Before hours of work, not after"). The Python entry points do not.
  Fix: refuse up front in `rewrite()`, unless the run is a dry run or an explicit `--allow-dirty` is given. Same for `main()` when it is not running under CI.

## Checked and found sound (no action)

- `cd_cog_write()` metags handling on terra 1.9.50. An untagged raster's `metags()` is `NULL`, and `length(old_name) > 0` guards the clear. The tags land in the TIFF itself: GDAL `-json` info shows them in the default domain, with no `.aux.json` for tags alone. A raster carrying `time`/`units` gets an `.aux.json` holding only time/unit, and its tags are still in the TIFF. `c()` of a COG read back keeps the old `CD_*` tags, and `cd_cog_write()` replaces them as intended.
- jsonlite file sizes. 5,784,842, 123,456,789 and 1.5e9 serialize as plain integers under both the default `digits` and `digits = NA`, so `checksum_problems()` and `as.numeric()` agree.
- `s3_etag_matches()` covers a 1-part multipart upload (a 9 MB file under a 128 MiB chunk), single-part MD5, and the 8 MiB default.
- A stale installed cd (pre-#124) fails loudly on the first `cd_cog_write(tags =)` call (`[write] unknown option(s): tags`). It does not publish untagged files.
- test-cd_s3_push.R: `local_mocked_bindings(.package = "base")` on `system` works under testthat 3.3.2 (6 passes, run with a fake `aws` that would have failed).

## Notes (not defects)

- scripts/pipeline_stage3_edh.R:197: the comment still names `scripts/tmax_tmin_republish.R` as "the tool for that case". That script now stops on start.
- This review file sits untracked in `planning/active/`, so it marks any run started before it is committed as `-dirty`. The two runs already in flight are unaffected, because both `run_provenance()` versions read the SHA once at start.
