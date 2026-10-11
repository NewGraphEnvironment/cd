# Code-check round 3: branch 128-move-run-provenance-to-the-stac-process

Reviewer: subagent, read-only. The only repo file written is this one.

## Mechanism

Each entry point lists its own publish guards and its own operator text inline. The
guards and the text belong to that caller, not to a shared publish routine. The guard
set was designed for #124's only mode, where one run from one checkout writes the bytes
and the metadata together. Two facts stood in for "the code writing the metadata is
current":

1. **The files' `CD_SHA`.** It names the checkout, because the same run made the files.
2. **"The catalog is always rebuilt wholesale by the current code."** So the manifest
   needed a vocabulary guard and the catalog did not.

#128 adds metadata-only paths, and there those stand-ins stop holding. Each caller then
has to re-list the guard by hand. Text written for one caller (a header, a remedy, a
helper's error message) also reaches another caller unchanged. Round 1 found one
instance of each: the SHA guard was in one caller only, and a header promised a use
the guard list refuses. Two more are below.

## Findings

- **[severity: fragile, operator guidance]** scripts/_publish.R:118-138 (`s3_put_if()`), reached newly from scripts/catalog_publish.R:160 and from `daily_publish(sync = FALSE)`.
  - **The text.** On `PreconditionFailed`, `s3_put_if()` appends text written for STEP D's sync path: *"The files are up; the next STEP D reports the manifest's gap and names the repair."*
  - **Catalog case.** catalog_publish.R now uses the same helper for `catalog.json`, so a lost race with a pipeline's STEP 5 prints that text. Every part of it is wrong there:
    - No file went up. refuse() prints "nothing was published" on the line above.
    - STEP D checks the daily manifest, not the catalog.
    - No "gap" will be reported.
    - The right action is to re-run catalog_publish.R once the pipeline has finished, or nothing at all if that pipeline ran post-merge code.
  - **Manifest-only case.** It is misleading the same way: nothing was uploaded, and there is no gap. The race means another publisher replaced the manifest, so the remedy is to re-run `--manifest-only`.
  - **Fix.** Let the caller supply the precondition text, or make the helper's text generic ("Another publish changed <key> since this run read it; nothing was overwritten. Re-run once it has finished.").

- **[severity: fragile]** scripts/_lib.R:338-349 (`catalog_repair_hint()`), printed by pipeline_update_edh.R STEP 5's failure paths (lines ~978, 993, 1000) and in STEP 1.
  - **Not a re-flag of B1.** Leaving the hint's recipe as it was, rather than pointing it at catalog_publish.R, is right. The new problem is what that recipe runs once #128 merges.
  - **The recipe uses an installed cd.** It says `cd::cd_stac_catalog(...)` and then a plain `aws s3 cp`, so it runs whatever cd is installed, not the checkout. That contradicts CLAUDE.md's "never an installed cd".
  - **Measured here:** the installed cd is 0.6.3, and its `cd_stac_item` still writes `` `cd:sha` = tag("CD_SHA"), `cd:run_time` = ... ``.
  - **What following it publishes.** A whole `catalog.json` in the old vocabulary, with no `publish_sha_problems()`, no `checksum_problems()` and no conditional put.
  - **Nothing catches it afterwards.** This diff gave the manifest a vocabulary guard that runs on the live document every run (`manifest_problems()` via `daily_manifest_problems()` in STEP D). The catalog has no counterpart: STEP 1's `catalog_problems()` checks only keys and spans. So the regressed catalog stays live until the next STEP 5 rebuild, about a year away.
  - **What readers see.** The #126 reader reads only `processing:*`, so throughout that time:
    - `cd_catalog()` and `cd_extract()` give `NA` for `cd_version`, `run_time` and `run_url`.
    - `build_checksum()` cannot match a `processing:datetime`, so every extract row's `checksum` is `NA` too.
    - None of this warns, by design: it is the shape of a pre-#128 catalog.
  - **Pre-existing in kind.** An installed cd from before #124 had the same hole for `file:checksum`. #128 adds a new version boundary that the operator's installed cd is on the wrong side of until a release is installed.
  - **Fix, either of:**
    - Have the hint load the checkout (`Rscript -e 'pkgload::load_all(); cd_stac_catalog(...)'` from the repo root).
    - Add a vocabulary check, such as every item carrying `processing:software`'s `cd`, to `catalog_problems()` or to STEP 1's live check, as the manifest now has.

## Where the mechanism reaches, each place checked

- **`daily_publish(sync = FALSE)` / `--manifest-only`.**
  - The checkout SHA is now guarded (round 1 fix).
  - `manifest_problems(merged)` forces every entry into the new vocabulary, so a partial local cube over the old live manifest is refused.
  - The ETag checks run on both the dry and the live path.
  - The upload is conditional. The only defect left is the inherited `s3_put_if()` text (finding 1).
- **scripts/catalog_publish.R.**
  - Checkout SHA guarded, with `load_cd()` loading the checkout.
  - The header now matches the guard list: it refuses the STEP 5 case and points at the hint.
  - Live checksums must survive; ETag-checked downloads; item set and span; grid; provenance; conditional put; read-back.
  - Only defect: finding 1.
- **pipeline_update_edh.R STEP D (CI).**
  - `run_start()` sets `CD_SHA = GITHUB_SHA`, so the files' SHA and the checkout's are the same.
  - `publish_sha_problems()` returns early on CI.
  - `manifest_entries()` resolves `cd:::stac_provenance` to the cd installed from `local::.`.
- **pipeline_update_edh.R STEP 5 and pipeline_stage3_edh.R tails.**
  - Both build with `cd_stac_catalog()` from the checkout: `load_cd()` off CI, `local::.` on CI.
  - The checkout SHA is checked at start (update:121, stage3:70).
  - COGs that STEP 4 copied unchanged keep their own tags, which describe their bytes.
  - Their repair text is finding 2.
- **The two writers of provenance.**
  - `cd_stac_item()` and `manifest_entries()` both go through `stac_provenance()`: one vocabulary, `NULL` dropped, digit run ids only.
  - The R and Python `run_provenance()` both emit `%Y-%m-%dT%H:%M:%SZ`, which the UTC regex accepts.
  - The tag-domain difference is accepted.
- **Docs.**
  - The CLAUDE.md #124 paragraph and its script list, the daily_publish.R header, the catalog_publish.R header and the roxygen of `cd_stac_catalog` all match the code.
  - NEWS.md still describes the `cd:*` keys of 0.6.3. That is correct for the released version, and `/gh-pr-merge` writes the #128 entry.
- **Remedy text (`manifest_problems()`, _lib.R:684), not a defect.**
  - The remedy names plain `Rscript scripts/daily_publish.R` (a sync publish) rather than `--manifest-only`, the path #128 built for this case.
  - It still works. `aws s3 sync` without `--size-only` uploads nothing whose local mtime is older than its object, and the ETag and checksum checks then pass.
  - `--manifest-only` is the narrower remedy if the text is touched again.

## Clean otherwise

Nothing else found. Specifically:

- The `entry_sha()` and `$` lookups have no sibling keys to partial-match.
- `manifest_merge()` keeps the `links` arrays as written.
- `jsonlite` writes `list(cd = sha)` as an object and a one-link list as an array.
- test_lib.R's new fixtures reach their failure modes. The `metags<-` merge on `mf_ci_r` keeps the other three tags, so the entry still passes `provenance_problems()`.
