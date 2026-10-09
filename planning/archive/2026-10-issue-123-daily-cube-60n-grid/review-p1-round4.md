# Code-check round 4: Phase 1 (#123): where each guard's verdict ends up

Scope: every raise or stop site the staged diff adds or relies on. For each one, this traces where the verdict goes:
- to the script's exit status;
- to the `climate-update.yml` run conclusion;
- to the failure issue filed by `if: failure() || cancelled()`.

It also asks whether the new exit-1 changes the outcome of a normal month.

## Findings

- **[fragile, pre-existing; now the one path where a guard verdict can fail toward green]** `scripts/pipeline_update_edh.R:655-717`. When STEP 3 has more than one candidate year, a failed year is dropped in silence if another year wrote.
  - **What happens.** `any_fetch_errored` is read in only one place, `if (length(new_years_written) == 0)` at line 708.
  - **The green case.** Year Y1 writes all 15 variables. Y2's `backfill_edh_all.py` or `backfill_edh_snow.py` exits 1. That exit can come from a grid guard or from a transient error that used up its retries. The run then goes through STEP 4/5, publishes Y1 and reaches `finish(0L)`. The run is green, no issue is filed, and Y2's failure is only a log line.
  - **The reverse order is safe.** If Y1 fails and Y2 writes, `publish_problems()` refuses the gap, and `finish(1L)` turns the run red.
  - **Severity is low:**
    - The grid guards are deterministic per store, so a grid failure on Y2 fails Y1 as well.
    - Next month's run retries Y2 alone. It then reaches `quit(status = 1)`.
    - So the cost is one month of delay in the alarm, not a lost alarm.
  - **Why it is reported.** It is the same mechanism round 3 fixed: the child's verdict reaches STEP 3 but not the run's exit. The round-3 comment in both scripts says STEP 3 "counts a failed fetch". It counts one only when no year wrote.
  - **Cheap close.** Fold `any_fetch_errored` into `finish()` the same way `daily_failed` is folded in. A run that published Y1 then still exits 1.

No other site fails toward pass. None of the new exit-1 paths fires in a normal month.

## Enumeration: site | what raises | caught where | exit status | CI outcome | OK?

| # | Site | What raises | Caught where | Script exit | CI outcome (pipeline_update_edh.R → workflow) | OK? |
|---|---|---|---|---|---|---|
| 1 | `backfill_edh_all.py` `process_year` entry, `bc_files_check(out.values())` | `ValueError`: a file is off the grid, or is unreadable, since `RasterioIOError` is converted | `with_retry` does not retry `ValueError`. `main()` catches it with its per-year `except Exception`, adds the year to `failed` and returns 1 | 1 (probed: patched `process_year` to raise, `main([2026])`, exit=1) | STEP 3 line 660: `any_fetch_errored`, `next`. If no year was written: `quit(1)` at line 712, or `finish(1)` at line 705 when `spans$ahead` is non-empty. Red, and an issue is filed. In CI it never fires on a fresh runner: `data/` is gitignored and there is no cache | OK, except the multi-year case in the finding above |
| 2 | all.py `bc_grid_check(hourly_sub)` (a Dataset; `.latitude`/`.longitude` work on it) | `ValueError` | same as row 1 | 1 | same as row 1 | OK, same caveat |
| 3 | all.py `bc_grid_check(t2m_local)` | `ValueError` | same | 1 | same | OK, same caveat |
| 4 | all.py `bc_grid_check(tp_daily)` (raises after the hourly variables have been written) | `ValueError` | same | 1 | same. The files written for that year are not used, because STEP 3 takes `next` before it checks for files | OK, same caveat |
| 5 | all.py exit check, `bc_files_check(out.values())` | `ValueError` (the files stay on disk: an accepted tradeoff) | same | 1 | same | OK, same caveat |
| 6 | `backfill_edh_snow.py` entry, `bc_files_check` | `ValueError` | same pattern in snow's `main()` | 1 (probed, exit=1, log line `DONE with 1 failed year(s): [2026]`) | STEP 3 line 669: same as row 1 | OK, same caveat |
| 7 | snow `bc_grid_check` on sde/rsn/snowc, then on sf/smlt | `ValueError` | same | 1 | same | OK, same caveat |
| 8 | snow `bc_grid_check(tp_daily)` and `bc_grid_check(sf_pct)` | `ValueError`. The exact-join `ValueError` from `.where(..., 0)` takes the same route | same | 1 | same | OK, same caveat |
| 9 | snow exit check, `bc_files_check` | `ValueError` | same | 1 | same | OK, same caveat |
| 10 | `backfill_edh_daily.py` top of the loop, `bc_files_check(outs.values())` | `ValueError` | Nothing catches it: `main()` has no per-year try | 1 (traceback) | STEP D line 398: `ok` is FALSE, `daily_step()` returns FALSE, and `daily_failed` becomes TRUE. The annual path still runs; every later exit goes through `finish()`, which forces 1. Red, and an issue is filed | OK |
| 11 | daily `bc_grid_check(hourly)` | `ValueError` | uncaught | 1 | same as row 10 | OK |
| 12 | daily post-write `bc_file_check(outs[var])` | `ValueError`. The file is unlinked, then the error is re-raised | uncaught | 1 | same as row 10. Earlier variables of that year stay on disk, but CI publishes nothing, because `daily_step` returns before `cd_s3_push` | OK |
| 13 | daily `--check` | does not call a `bc_*` helper | n/a | n/a | n/a | n/a |
| 14 | `backfill_edh_tmax_tmin.py`, `bc_files_check([out])` and `bc_file_check(src)` | `ValueError` | uncaught | 1 (traceback) | Not run by CI. Nothing in `scripts/`, `.github/` or `R/` calls it, so the operator sees the traceback locally | OK |
| 15 | `pipeline_stage3_edh.R`, `grid_problems()` added into `problems` | non-empty character vector | `if (length(problems) > 0) stop(...)` at top level | Rscript 1 | Local only, so there is no CI run. Nothing is pushed | OK |
| 16 | `pipeline_update_edh.R` STEP 5, `grid_problems()` | non-empty character vector | logs the problem, then `finish(1L)` before `cd_stac_catalog`/push | 1 | Red, and an issue is filed. Nothing is published | OK |
| 17 | STEP 4 `append_to_cog` grid-mismatch `stop()` (relied on; it fires while the live COGs are still 120 x 260) | R error at top level | uncaught | Rscript 1 | Red, and an issue is filed. Not reached before local 2026 completes (~Feb 2027); Phase 4 republishes first | OK |
| 18 | `sys.exit(main(years))` in all.py and snow.py | `main` returns 0 or 1 on every path. A crash before the loop (token, open zarr, preflight `sys.exit(str)`) still exits non-zero, as it did before | n/a | 0 or 1 | — | OK |

## Normal month: does any new exit-1 fire where the run used to return quietly?

No. The paths are:

- **About 11 runs a year never reach STEP 3.** STEP 2 drops every candidate year that is greater than `latest_local`, then calls `finish(0)` (lines 573-593). None of the `bc_*` sites runs.
- **The year-boundary run.** Here the hourly store is complete in local time, because STEP 2 capped the years at the `--check` probe, which uses the same `local_year_complete`.
  - The daily store may still be short. In that case all.py's `months_available(daily_ds)` takes the `SKIP prcp` path and returns normally.
  - snow.py does the same for `snowfall_fraction` (`del needed[...]`, return).
  - Both scripts exit 0. STEP 3 logs "partial or unavailable on EDH yet" and calls `finish(0)`, exactly as before.
- **None of the other raises in `process_year` fires on a complete local year:**
  - `monthly_from_daily` is gated by `local_year_complete`.
  - `local_daily` receives a slice cut to `local_year_window`.
  - The `.where` exact join in snow does not fire. Both stores have identical drifted coordinates, measured in `research/edh_era5_land_store.md`, and `bc_slice` pads both the same way.
- **The entry `bc_files_check` cannot fire in CI.** There is no `actions/cache` and `data/` is gitignored, so the directory is empty.

## Does any caller rely on all.py or snow.py always exiting 0?

No. The only callers in `scripts/`, `.github/` and `R/` are `pipeline_update_edh.R:657` and `:666`. Both already branch on `status != 0`, and that branch was the intended handling. No `.sh` wrapper calls either script. Running locally without `--year` now ends with exit 1 if any year failed. That is the intent, and Phase 3's background runs will report it.

## Checked

- `uv run scripts/test_lib.py`: 37/37 passed. `Rscript scripts/test_lib.R`: 75/75 passed.
- Exit-status probe, run in a scratch copy (`scratchpad/r4/scripts/probe.py`). It patched `process_year` to raise `ValueError` and stubbed the token and the zarr open. Both `backfill_edh_all` and `backfill_edh_snow` exited 1.
