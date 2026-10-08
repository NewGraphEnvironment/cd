# Task: Daily cube stops at 59.95 N, and one point outside it aborts cd_extract_daily() (#123)

`cd_extract_daily()` rejects a BC station inside the extent its own error message names (wet#40: 10DA001 at 59.98856 N). The cube stops at 59.95 N. A second, separate problem: one point outside the cube aborts the whole call.

## Context

wet#40 hit `Outside the daily cube's extent (BC, 48-60 N, 114-140 W): 10DA001` for a station at 59.98856 N. That latitude is inside the extent the message names.

**Root cause, measured in plan mode.** EDH's coordinates carry float drift:
- latitude: `60.00000000000142`, `48.00000000000125`
- longitude: `219.9999999999918`, `245.9999999999903`

So `sel(latitude=slice(60.0, 48.0), longitude=slice(220, 246))` excludes the 60.0 N row and the −140.0 W column, and keeps 48.0 and −114.0. The slice comes back 120 × 260 instead of 121 × 261.

The same exact-edge slice is copied into all three backfillers (`backfill_edh_daily.py` inline, plus `bc_slice()` in both `backfill_edh_all.py` and `backfill_edh_snow.py`). The live `catalog.json` bbox is `[-139.95, 47.95, -113.95, 59.95]`, so the monthly layers have the same cut.

**Decisions taken at the gate:**
- Rebuild the daily cube **and** all 59 monthly COGs, so both stay on one 121 × 261 grid.
- Publish in this run, with no backup. The values in the old block are unchanged, and the old grid can be rebuilt from EDH anyway.

**Consequences:**
- Every `cell` number changes, because a new top row and left column are added.
- The bundled AOIs (≤ 58.03 N, ≥ −127.74 W) and `inst/vignette-data` are unaffected and are not regenerated.
- Nothing on `main` will publish before 2027: the 2026 year needs EDH data through Jan 2027. If main's old code did write onto the new live grid, STEP 4's existing grid-mismatch check (`pipeline_update_edh.R:797`) would abort a monthly append. STEP D has no such check, so merge before local 2026 completes on EDH (~Feb–Mar 2027).

**Out of scope: hashing.** Content hashing follows stac_airphoto_bc#30: `file:checksum` and `file:size`, run-provenance tags, a validator, and a determinism check. Once plan mode ends I file it as a separate cd issue. That issue rewrites from the local TIFs and COGs, with no EDH fetch, and republishes once. #123 publishes unhashed.

## Phase 0: Bookkeeping
- [x] File the cd hashing issue (#124). Adapt stac_airphoto_bc#30's spec to cd: the catalog items, a manifest for the daily cube (which is not in catalog.json), and a re-hash on every STEP 4 / STEP D publish.

## Phase 1: One BC grid, defined once (`scripts/_lib.py`)
- [x] Write the tests first in `scripts/test_lib.py`:
  - On a synthetic dataset with drifted coordinates (lat +1.4e-12, lon −8e-12, in 0–360), `bc_slice()` returns 121 × 261 including both edges.
  - `bc_grid_check()` raises on a 120 × 260 slice and passes on 121 × 261.
  - Restore the exact-edge slice and confirm the test goes red.
- [x] `_lib.py`: add the BC bbox constants and `bc_slice(ds, start, end)`, padded by half a cell (0.05°), with the 0–360 handling moved in from the scripts.
- [x] `_lib.py`: add `bc_grid_check(da)`. It asserts 121 × 261 and that the edge centres are within 1e-6 of 60 / 48 / −140 / −114. It reads coordinates only, so it runs before any `.compute()`.
- [x] Replace the three local copies (`backfill_edh_daily.py`, `backfill_edh_all.py`, `backfill_edh_snow.py`) with the shared helpers. Each script calls `bc_grid_check()` on its slice before fetching anything.
- [x] `backfill_edh_daily.py`: after each `write_cog()`, re-open the file header with rasterio and check that its bounds are (−140.05, 47.95, −113.95, 60.05). This is the issue's "written extent" guard.
- [x] Update the "120x260" docstrings. `uv run scripts/test_lib.py` passes.
- [x] Plan review (`review-plan.md`): the backfillers' skip paths also check existing outputs (`bc_files_check()`), and stage 3 / STEP 5 refuse a COG set that is not all on the BC grid (`grid_problems()` in `scripts/_lib.R`)

## Phase 2: `cd_extract_daily()` — a point outside the cube gets NA, not an abort
- [ ] Tests in `tests/testthat/test-cd_extract_daily.R`. These replace the "a point off the grid aborts" test:
  - An off-grid point gets NA rows for every variable and day, NA `cell` / `cell_x` / `cell_y`, and `cell_moved = FALSE`, while the other points keep their values.
  - The warning names the point and states the extent read from the fixture template (53.8 / 54.3 / −124 / −123.4), not a hardcoded string.
  - All points off grid gives all-NA rows.
  - An off-grid point plus a stranded point raises both warnings. Collect them with `withCallingHandlers`, because `expect_warning` sees only the first.
- [ ] `R/cd_extract_daily.R`, `daily_cells()`: an outside cell becomes NA, and the warning formats `terra::ext(template)`. The neighbour search skips NA cells.
- [ ] `cd_extract_daily()`: drop NA from `ucell`, guard an empty `ucell`, and give unmatched rows NA values.
- [ ] Roxygen: update the Cell choice section and `@return` (cell columns can be NA), then `devtools::document()`. Run `devtools::test()` and `lintr`.

## Phase 3: Rebuild locally on the 121 × 261 grid
- [ ] Move the current `data/backfill/{daily,monthly,annual}` aside to `data/backfill/_grid_120x260/` (gitignored), to compare against later.
- [ ] Run `backfill_edh_daily.py` for 1950–2025. Then run `backfill_edh_tmax_tmin.py` (from the cube), `backfill_edh_all.py` and `backfill_edh_snow.py`. Each runs in the background and notifies on exit.
- [ ] Verify:
  - Every output is 121 × 261 with extent (−140.05, −113.95, 47.95, 60.05).
  - The inner 120 × 260 block of every rebuilt file is value-identical to its old counterpart: all 228 daily files and the old local tmax/tmin; other monthly variables against the live COGs.
  - 10DA001's cell has data.
- [ ] Record the measurements in `findings.md`: run times, quota, and the identity results.

## Phase 4: Publish
- [ ] Before any push: `grid_problems()` over all of `data/backfill/daily` (the push syncs the whole directory), and `pipeline_stage3_edh.R --dry-run` passes (O2).
- [ ] Daily: `cd_s3_push("data/backfill/daily", prefix = "daily")`. Read back the extent of all 228 over `/vsicurl/` in a fresh R process: `--size-only` could skip a same-size file, and GDAL's cache would serve an earlier header.
- [ ] Monthly: run `scripts/pipeline_stage3_edh.R` (all 59 COGs, `publish_problems()`, catalog, push, read-back).
- [ ] Live checks:
  - The catalog bbox is `[-140.05, 47.95, -113.95, 60.05]`.
  - `cd_extract_daily()` at 10DA001 returns non-NA values, with both `cache = TRUE` and `cache = FALSE`.
  - The live test file passes.
- [ ] Comment on wet#40: the abort is now a warning plus NA rows, so wet's message-parsing retry (`temp_fill_validate.R`) is dead code.
- [ ] Dispatch the dry-run of `climate-update.yml` on main and confirm it is green: STEP 1 / `catalog_problems()` on the live catalog, and STEP 2's tmax/tmin local-day check.

## Phase 5: Docs
- [ ] `research/edh_era5_land_store.md`: add the coordinate-drift fact, with the measured values, and why the slice is padded.
- [ ] `CLAUDE.md` EDH gotchas: one bullet on the padded slice / 121 × 261 grid and `bc_grid_check()`.

## Validation

- [ ] Tests pass (`devtools::test()`, `uv run scripts/test_lib.py`)
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
