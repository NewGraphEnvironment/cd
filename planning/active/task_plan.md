# Task: Content hashes and run provenance on every published COG (catalog items and daily cube) (#124)

**If we do it:** every COG cd publishes carries a hash and the run that made it. A changed hash then means changed bytes, and a consumer such as wet can tell which build of the monthly layers or the daily cube an analysis read. **If we never do:** a republish like #123's replaces every published file in place, and nothing outside git history records what was there before or what replaced it.

## Phase 1: Provenance tags on the R write
- [x] `cd_cog_write(tags = NULL)`: a named character vector written as dataset `metags`, replacing any the input carries (stale `CD_*` from a `/vsicurl/` source); refuses a key containing `:`; never mutates the caller's raster
- [x] Tests (`test-cd_cog_write.R`): tags read back from the file; a stale input tag is replaced; same input + same tags written twice → identical bytes (sred#39); no `.aux.json` beside the COG
- [x] `run_provenance()` in `scripts/_lib.R`: `CD_VERSION` (DESCRIPTION), `CD_SHA` (`GITHUB_SHA`, else `git rev-parse HEAD`, `-dirty` suffix on an unclean tree), `CD_RUN_TIME` (env `CD_RUN_TIME`, else now, ISO UTC), `CD_RUN_ID` (`GITHUB_RUN_ID`, else `local`); offline cases in `scripts/test_lib.R`

## Phase 2: Provenance tags on the Python write (daily cube)
- [ ] `run_provenance()` in `scripts/_lib.py`, same keys and same env contract, so one `pipeline_update_edh.R` run stamps both products with one run time
- [ ] `write_geotiff(tags=)` applies them in its existing `r+` block on the staging GeoTIFF (before the COG copy, so the COG write is the last thing to touch the bytes); `write_cog(tags=)` passes through; `backfill_edh_daily.py` passes `run_provenance()`
- [ ] `backfill_edh_daily.py --rewrite`: re-tags existing local cube years via `read_cog_days()` → `write_cog()`, no EDH (the republish path)
- [ ] `scripts/test_lib.py`: tags survive the COG copy; two writes, same tags → identical bytes; `--rewrite` preserves values and band names

## Phase 3: Checksums in the STAC catalog
- [ ] `openssl` to Imports; internal `file_multihash()` (`"1220"` + lowercase sha256 hex, shape asserted)
- [ ] `cd_stac_item()`: `file:checksum` + `file:size` on the `data` asset, `stac_extensions` = file v2.1.0, and `cd:version` / `cd:sha` / `cd:run_time` / `cd:run_id` properties read from the COG's own tags (omitted when absent)
- [ ] Tests (`test-cd_stac_catalog.R`): checksum equals an independent hash of the file; shape `^1220[0-9a-f]{64}$`; size matches; provenance properties match the tags; `cd_catalog()` round-trip unchanged

## Phase 4: Validators and monthly publish wiring
- [ ] `scripts/_lib.R`: `checksum_problems(catalog_json, cog_dir)` (recompute every item's size + multihash from the local file, check shape) and `provenance_problems(paths)` (every COG carries all four tags, non-empty); restore-the-bug cases in `test_lib.R` (one flipped byte, a bare digest without `1220`, a missing tag each go red)
- [ ] `cd_s3_push(size_only = TRUE)` argument; both pipelines pass `FALSE`
- [ ] `pipeline_stage3_edh.R` and `pipeline_update_edh.R`: `Sys.setenv(CD_RUN_TIME=…)` once at start, `tags = prov` on every `cd_cog_write()`, both validators after the catalog build and before any push
- [ ] Read-back compares the whole live `catalog.json` to the built one (checksums included), not only keys and years

## Phase 5: Daily cube manifest
- [ ] `scripts/_lib.R` pure helpers: `manifest_entries(paths)` (size, multihash, provenance from tags), `manifest_merge(live, local)`, `manifest_problems(manifest, dir, vars, years)` (key set = 3 vars × one contiguous span of years; every local file matches its entry; shapes)
- [ ] `daily_publish(daily_dir, bucket, dry_run)` in `scripts/_lib.R`: read live `daily/manifest.json` (absent → refuse in CI, naming the local bootstrap), merge, validate, sync (`size_only = FALSE`), then `aws s3 cp` the manifest last (written outside `daily_dir`), read back identical
- [ ] STEP D calls `daily_publish()` instead of `cd_s3_push()`; `scripts/daily_publish.R` is the thin local entry point; STEP D's "build it locally" hint names it
- [ ] Offline tests for the three pure helpers in `test_lib.R`

## Phase 6: Real-data dry run and docs
- [ ] `uv run scripts/backfill_edh_daily.py --rewrite` over the 228 local daily files; `Rscript scripts/daily_publish.R --dry-run` with no live manifest's bootstrap path
- [ ] `Rscript scripts/pipeline_stage3_edh.R --dry-run`: all 59 COGs tagged, catalog carries checksums, validators pass; record timings and the determinism result in `findings.md`
- [ ] CLAUDE.md architecture: checksums, provenance tags, daily manifest; correct the `--size-only` sentences
- [ ] `research/` note if the determinism / tag measurements are worth keeping beyond the archive

## Validation

- [ ] Tests pass (`devtools::test()`, `Rscript scripts/test_lib.R`, `uv run scripts/test_lib.py`); lintr; `devtools::document()`
- [ ] `/code-check` clean (each commit, or once over the branch with `/code-check branch`)
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion

## Not in this run

The live republish (stage 3 push + `scripts/daily_publish.R` without `--dry-run`) waits for the merge, so the published `CD_SHA` is a commit on main.
