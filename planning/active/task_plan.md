# Task: STEP 1 reads the latest year from tmean_annual alone, so a partial sync is never repaired (#119)

`aws s3 sync` is not atomic. If a STEP 5 run uploads some COGs with the new year
and dies before the rest (and before `catalog.json`, which `cd_s3_push()`'s abort
keeps back), the next run reads `latest_year` from `tmean_annual` alone. Since
#89 that is no longer silent in every case, but it is never repaired:

| partial state | after #89 |
|---|---|
| `tmean_annual` uploaded (N), others not | STEP 1 `catalog_problems()` exits 1; its repair hint (rebuild the catalog from live COGs) would produce a mixed catalog |
| `tmean_annual` not uploaded, some others at N | STEP 1 passes, STEP 3 fetches for hours, STEP 4 appends N twice to the COGs holding it, STEP 5 refuses "do not share one span" |

**Decision (plan gate, 2026-10-07):** repair, not refuse. The target comes from the
years every COG holds; STEP 4 appends to each COG only the years it lacks. The
weekly dry run reports a partial state as a WARNING and exits 0; a live run exits 1
until the repair is published.

## Phase 1: `live_spans()` helper + offline tests
- [x] `live_spans(cog_years)` in `scripts/_lib.R` (pure, no I/O), documented like its neighbours
- [x] Cases in `scripts/test_lib.R`: healthy 59 → no ahead/problems; one COG ahead by N; `tmean_annual` lagging (others ahead); two COGs ahead by different amounts; different start year; gap; duplicate year (the double-append shape); NA/non-year band; empty input
- [x] Mutation check: break each branch and confirm a test goes red (table in findings.md)

## Phase 2: STEP 1–2 in `pipeline_update_edh.R`
- [ ] Replace the `tmean_row` / `r_current` read with a read of all 59 COGs' band names; unreadable COG → named problem
- [ ] `current_years` / `latest_year` from `common`; exit 1 on `problems` with a stage-3 hint
- [ ] Catalog check against `common`; WARNING listing `ahead` COGs
- [ ] `partial_live` flag + `finish()` exits non-zero while it is set; dry-run branch reports and exits 0
- [ ] Header flow comment updated

## Phase 3: STEP 4–5
- [ ] `append_to_cog()` drops already-held years and rewrites an unchanged COG; `NULL` only when nothing was handed in
- [ ] `required_years` from every live COG's years; clear `partial_live` after the read-back succeeds
- [ ] Interop check: tiny COGs with mixed spans in a temp dir, through `rast()` band names → `live_spans()` → append-filter → `publish_problems()` → `cd_stac_catalog()` → `catalog_problems()`; 0 problems after repair

## Phase 4: Verify + docs
- [ ] `Rscript scripts/test_lib.R` all pass; `devtools::test()` unaffected
- [ ] Live dry run: `Rscript scripts/pipeline_update_edh.R --dry-run` logs 59 COGs 1950-2025, no ahead, exit 0; record the time the 59 reads take
- [ ] CLAUDE.md Architecture paragraph: STEP 1 reads all 59 and repairs a partial sync
- [ ] Edit the #119 issue body: the "Nothing to do" outcome is stale after #89; describe the two current shapes and that the fix chosen is repair

## Validation

- [ ] Tests pass
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
