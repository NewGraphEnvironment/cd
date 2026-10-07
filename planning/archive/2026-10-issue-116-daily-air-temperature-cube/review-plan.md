# Plan review — #116 (Plan agent, 2026-10-06)

Reviewer read task_plan.md, findings.md and the uncommitted Phase 1 diff fresh. 16 findings; disposition below.

| # | Class | Finding | Disposition |
|---|---|---|---|
| 1 | Blocker | `pipeline_update_edh.R` exits early at 4 points before the only push (STEP 5); a daily year built on a run where the annual path exits is never pushed (fresh runner) | **Accept.** Self-contained daily step right after STEP 0, with its own dry-run report and its own push of `daily/`; failure recorded, annual path still runs, non-zero exit at the end |
| 2 | Blocker | `local_year_complete` is Python; R cannot call it | **Accept.** `backfill_edh_daily.py --check` prints the latest complete local year (metadata only) |
| 3 | Gap | three lazy arrays → three fetches per year | Already handled: the script `.compute()`s the hourly block once before `local_daily()` |
| 4 | Gap | `local_daily` silently mis-bins unsliced/gappy input | **Accept.** Assert shifted first stamp is 00:00 and length == 24 × n_days |
| 5 | Gap | grid fits one default 512 block → a point read pulls the whole file | **Accept.** Measure BLOCKSIZE / interleave / PREDICTOR in Phase 2 |
| 6 | Gap | COG helper in `_lib.R` breaks its "pure, no I/O" rule; STEP 1c in stage3 rebuilds every monthly COG | **Accept, simpler variant:** write the COG straight from Python (`rasterio.shutil.copy(driver="COG")`); no R conversion step at all |
| 7 | Gap | ring fallback: E-W neighbour nearer than N-S at 54°N; edge-of-grid ring; grid stability across years | **Accept.** Geodesic distance point→cell centre, lowest cell id breaks ties; edge test; assert ext/res identical across years |
| 8 | Gap | no way to name lon/lat columns for data.frame input | **Accept.** `coords = c("lon", "lat")` |
| 9 | Assumption | EDH quota for a 76-year backfill | **Checked, not a risk.** Quota is 500,000 requests/month (#36 findings); one BC year ≈ 4 time × 3 lat × 6 lon ≈ 72 chunk requests, so ~5,500 for 1950–2025 |
| 10 | Assumption | tmean will not match pandas bit-for-bit (summation order) | **Accept.** Exact for max/min, |Δ| < 1e-4 °C for mean |
| 11 | Assumption | catalog non-recursive, sync recursive, `--size-only` skips a same-size rebuilt year | Confirmed; note `--size-only` in CLAUDE.md |
| 12 | Ordering | CI dry-run can run on the branch before merge (`gh workflow run --ref`) | **Accept** |
| 13 | Ordering | example data depends on the built cube | Accept; example after the 2002 build |
| 14 | Scope | `cd_extract_daily` vs `noun_verb` | **Keep** — the user proposed `cd_extract_daily` at the gate and approved it; precedent `cd_plot_timeseries`; state the exception in CLAUDE.md |
| 15 | Scope | example data too big | **Accept.** One year, ~5×5 cells |
| 16 | Acceptance | `devtools::check()`, no `sf::` in R/, NEWS/version, perf target, test_lib.py not in CI | check() added; terra-only in R/ with sf tests skip_if_not_installed; NEWS/version at `/gh-pr-merge`; perf measured; test_lib.py stays local-only, said in CLAUDE.md |
