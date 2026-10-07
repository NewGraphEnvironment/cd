# Task: STEP 5 can publish a catalog listing only the variables that run rewrote (#89)

## What happens if we never do it

One skipped variable in one monthly run silently removes it from the catalog for
every consumer, and the run reports `=== UPDATE COMPLETE ===` and exits 0.

## Decision (the gate: approve or redirect)

**Recommended: strict. Abort before any push unless all 59 COGs were rewritten with the
new year(s).** The rejected alternative is merging the new items into the live catalog.
That keeps every variable listed, but a skipped variable then lags a year behind the
others with nothing to show it. STEP 1 reads `latest_year` from `tmean_annual` only, so
the next run would never retry the skipped variable. Strict matches stage 3. STEP 3
already requires all 15 variables per year before a year counts, so on a healthy run
every skip path in STEP 4 is an anomaly, and refusing to publish is the right response.
Nothing is pushed on abort (the push comes after the catalog), so the live bucket is untouched.

## Phase 1: Shared publish guard in `scripts/_lib.R` (pure, offline-testable)
- [x] `cog_expected(agg_methods, seasons, annual_vars)` returns the 59 `{var}_{period}.tif` names (the list stage 3 builds inline at :183)
- [x] `publish_problems(written, expected, live_keys, required_years)` returns a character vector of reasons not to publish, empty when clean. `written` is a named list of band names (years) per COG written this run. Checks: expected COG not written; written COG not expected (stale/extra); spans differ across COGs; span not contiguous; span missing any required year; a live catalog `{var}_{period}` key absent from what would be published
- [x] `scripts/test_lib.R`: one case per reason (each must produce exactly that problem), a clean case returning `character(0)`, and the issue's scenario: 58 of 59 written means a non-empty result naming the missing one
- [x] Restore-the-bug check: neuter each branch in a copy and confirm its test goes red (mutation table in findings.md)

## Phase 2: Wire the guard into `pipeline_update_edh.R`
- [x] `append_to_cog()` records `written[[cog_name]] <- names(combined)` (same shape as stage 3)
- [x] The silent `next`s in STEP 4 (missing file, wrong `nlyr`, period absent from `cd_aggregate()`) log their reason, so the abort message has a cause above it
- [x] Guard between STEP 4 and STEP 5: `publish_problems(written, cog_expected(...), paste(catalog$variable, catalog$period, sep = "_"), union(current_years, new_years_written))`, plus the `.tif` set actually in `cog_dir` must equal `names(written)` (a stale file from an earlier local run would otherwise be catalogued and pushed). On any problem: log each one, say nothing was published, `finish(1L)`
- [x] After `cd_stac_catalog()`, read the local catalog back with `cd_catalog()` and assert it covers every live `(variable, period)` and has at least as many items as the live catalog, before `cd_s3_push()`. This checks the artifact itself, not the inputs it was built from
- [x] Update the header comment (step 5) to say it refuses a partial catalog
- [x] (plan review B1) `append_to_cog()` returns the band names; the call sites assign `written`, rather than the function writing a global
- [x] (plan review O1) STEP 1 checks the live catalog's keys against the expected 59 before any fetch, and before the dry-run exit
- [x] (plan review G1) `catalog.json` is written outside `cog_dir` and uploaded with `aws s3 cp` after the COG sync, then read back from the live URL. `--size-only` would otherwise skip it on a healthy update
- [x] (plan review O2) a built catalog that fails readback is deleted
- [x] (code-check round 3) STEP 1 also checks the live catalog's item years against the live COGs, so a failed catalog upload cannot leave it a year behind on green runs; failures name a catalog-only repair

## Phase 3: Stage 3 uses the same guard
- [x] Replace stage 3's inline `expected_cogs` and span/live-year checks (:183-225) with `cog_expected()` + `publish_problems()`. Behaviour is unchanged (required_years = live years) and the 59-COG rule now lives in one place
- [x] Add the same built-catalog-covers-live readback before its push
- [x] Same explicit catalog upload + live readback (dry-run passes `--dryrun`). Stage 3 is now stricter: a stale `.tif` in `data/backfill/cogs` is refused, not published

## Phase 4: Docs
- [ ] CLAUDE.md: the `pipeline_update_edh.R` Scripts line and the Architecture paragraph say the update path refuses a partial catalog, as stage 3's line does
- [ ] `findings.md`: the skip-path inventory and why strict was chosen over merge

## Verification
- `Rscript scripts/test_lib.R`: all checks ok, including the 58-of-59 case; mutation table shows each guard branch fires
- `Rscript -e 'invisible(parse("scripts/pipeline_update_edh.R")); invisible(parse("scripts/pipeline_stage3_edh.R"))'`
- `Rscript scripts/pipeline_update_edh.R --dry-run` still exits 0 (proves STEP 0-2 and package load; the dry run stops before STEP 4, so the guard itself is proven by the offline tests, not by this)
- `devtools::test()` and `lintr::lint_package()` clean (no R/ changes expected)
- STEP 4/5 cannot run end to end before 2026 lands on EDH. Phase 1's offline cases are the evidence that the guard works; the PR will say so

## Validation
- [ ] Tests pass
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion

