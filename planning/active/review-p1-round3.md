# Code-check round 3: Phase 1 (#123), staged diff (new code since round 2)

## Findings

- **[bug]** `scripts/backfill_edh_all.py:272-281`, `scripts/backfill_edh_snow.py:330-338`, read by `scripts/pipeline_update_edh.R:655-712`. In CI, a grid-guard failure now ends in a green run that blames EDH latency.
  - **What happens.** `bc_grid_check()` / `bc_files_check()` raise `ValueError` inside `process_year()`. `with_retry` passes it straight through, as intended. The per-year `except Exception` in `main()` then logs `FAILED year ...` and the script prints `ALL DONE` and exits **0**.
  - **Proof.** In a scratch copy (`scratchpad/r3/repo/scripts/probe.py`), `process_year` was patched to raise the guard's `ValueError`. `main([2026])` returned normally, with exit status 0.
  - **What STEP 3 does with that.** It sees status 0, so `any_fetch_errored` stays FALSE. It then checks the 15 files exist. The guard raises before the write, so files are missing. STEP 3 logs `partial or unavailable on EDH yet, skipping`, and `finish(0L)` reports "No new complete years available on EDH yet (latency is normal)". The run is green.
  - **Most plausible trigger.** The hourly-derived files for the year get written, then `bc_grid_check(tp_daily)` raises on the daily store. prcp is missing, so the year is skipped. The same happens when all.py succeeds and snow.py's guard raises.
  - **Why it matters.** The catalog advances about once a year, and the other ~11 runs are correctly green no-ops (CLAUDE.md, Architecture). A guard failure therefore looks exactly like normal latency, and the new year never publishes, with no failure issue filed.
  - **This diff made it worse, not just left it alone.** Before it, the same store change wrote off-grid files, and STEP 4's grid-mismatch `stop()` (`pipeline_update_edh.R:797`) made the run red. Catching the cut earlier converts a loud failure into a quiet one. That is the "guard that fails toward pass" mechanism at the run level.
  - **Fix.** Have `main()` in both scripts return non-zero (`sys.exit(1)`) when any year FAILED, or re-raise non-transient errors. STEP 3 then sets `any_fetch_errored`, and `quit(status = 1)` fires when nothing was written.
  - **Same path, related case.** `rasterio`'s `RasterioIOError` subclasses `OSError` (checked: its MRO contains `OSError`). A truncated or unreadable existing output therefore makes `bc_files_check()` at the top of `process_year` count as *transient*. `with_retry` sleeps 10 + 20 + 40 s, then the error is swallowed by the same per-year handler with exit 0. In CI the dir is fresh, so this only bites local runs.

- **[fragile]** The daily cube has no set-level grid gate before it is published. Locations: `scripts/backfill_edh_daily.py:143-149`, and Phase 4's `cd_s3_push("data/backfill/daily", prefix = "daily")`.
  - **How the mechanism reaches it.** The monthly path now checks the published artifact (`grid_problems()` over all of `cog_dir`). The daily path checks only the inputs it touches. The top-of-loop `bc_files_check()` covers only years in the run's `--from/--to` range, while `cd_s3_push` syncs every file in the directory.
  - **Consequence.** A file outside the run's range (a stray test year, or one the move to `_grid_120x260/` missed) is pushed unchecked. Phase 4 then reads back only "the extent of a sample".
  - **CI is safe.** In CI, STEP D's `daily_dir` holds only files built and checked by this run.
  - **Cheap close.** `grid_problems(list.files("data/backfill/daily", "\\.tif$", full.names = TRUE))` before the Phase 4 push. The function is grid-generic, and the cube shares the extent.

## Checked and clean

- **`grid_problems()` placement and inputs.**
  - Both pipelines call `library(terra)` before `source("scripts/_lib.R")`, and `grid_problems` namespaces every call (`terra::`). `test_lib.R` uses `terra::` only, so terra loads by namespace. Nothing else sources `_lib.R`.
  - `as.vector(terra::ext())` is ordered (xmin, xmax, ymin, ymax), which matches `bc_grid$ext`.
- **STEP 5 in CI.** `cog_dir` (`data/update/cogs`) is fresh on the runner: there is no `actions/cache` in `climate-update.yml`, and `data/` is gitignored. It holds only STEP 4's outputs: byte copies of the live COGs, and `c(existing, new)` rewrites, which take the live extent. So `grid_problems` sees exactly the set about to be published.
- **First CI run after the republish.**
  - The live COGs and the new year are both 121 x 261, with drift of about 1e-11. That passes STEP 4's `all.equal(..., 1e-6)`, `grid_problems`' 1e-6 absolute check, and Python's `bc_file_check`.
  - STEP 2's tmax/tmin ETag-twin check still passes, because the live keys differ from the UTC-day backups.
  - **Before the republish.** A live append of a 121 x 261 year onto 120 x 260 COGs aborts loudly at STEP 4. STEP 4 is not reached before 2026 completes (~Feb 2027), as the task plan states.
- **Stage 3.** A stale or mixed year in `monthly_dir` is stopped in one of two ways: `rast(year_layers)` errors on mismatched extents, or `grid_problems` / `publish_problems` refuses. Either way, nothing is pushed.
- **`backfill_edh_daily.py` and `backfill_edh_tmax_tmin.py`.** In both scripts the `ValueError` from `bc_files_check` / `bc_file_check` is uncaught, so the script exits non-zero. In CI's STEP D, a non-zero daily exit makes `daily_failed` true, and `finish()` then exits 1.
- **Tests.** `uv run scripts/test_lib.py`: 37/37 passed. `Rscript scripts/test_lib.R`: 75/75 passed.
