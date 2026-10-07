# Task: tmax/tmin daily aggregation uses UTC-day, not local-time day (#37)

Daily max/min aggregation for tmax/tmin uses UTC-day windows instead of local-time days. For BC (UTC-7 to UTC-8) the local-afternoon tmax peak (~14-16h local, ~22-00h UTC) straddles UTC day boundaries, which produces a small systematic bias vs. a proper local-time aggregation:

- Monthly tmax biased low (afternoon peaks split across two UTC days)
- Monthly tmin biased high (overnight lows split across two UTC days)

The EDH-based Python pipeline (`scripts/backfill_edh_tmax_tmin.py`) flags this as a known limitation in its docstring (lines ~31-36) but has not yet been fixed.

## Context

The published monthly-derived `tmax`/`tmin` COGs (`s3://stac-era5-land/{tmax,tmin}_{annual,winter,spring,summer,fall}.tif`, 1950-2025, written 2026-04-12) take daily max/min over UTC days. BC's afternoon peak falls 22-00 UTC, so it splits across two days: tmax reads low, tmin high. The bias does not cancel for absolute thresholds.

What exploration found, which shapes the plan:

- **The fix already exists.** #116 added `LOCAL_OFFSET_H = -8`, `local_year_window()`, `local_year_complete()` and `local_daily()` to `scripts/_lib.py`, with offline tests in `scripts/test_lib.py` (#37 Option A, verbatim).
- **The full local-day cube is on disk**: `data/backfill/daily/{tmax,tmin}_daily_{1950..2025}.tif` (228 files, same grid as the monthly path). Monthly mean of daily max = mean of the cube's bands by month. The regen therefore needs **no EDH fetch** (minutes, not hours), and the monthly and daily products agree by construction.
- **Two code paths compute tmax/tmin today**: `backfill_edh_all.py` (what CI runs, lines 164-182) and `backfill_edh_tmax_tmin.py` (standalone full backfill). Both use `resample("1D")` on UTC.
- **A local year is not complete until 08:00 UTC on 1 Jan of the next year.** So in CI, tmax/tmin for year Y cannot be written until January Y+1 data lands, about a month after the other variables are ready. `pipeline_update_edh.R` STEP 3 requires all 15 variables before it appends a year.
- **Publishing hazards:** bucket versioning is `Suspended`, so an overwrite is unrecoverable without a backup. `cd_s3_push()` syncs `--size-only`, and `pipeline_stage3_edh.R` rebuilds `catalog.json` from whatever is in the local `cogs/` dir. Running it with only tmax/tmin present would publish a 10-item catalog. Neither tool is safe for this republish.
- Consumer caches revalidate by ETag (`cd_cache_fetch()`), so a republish reaches users by default. Only users who set `options(cd.cache_revalidate = FALSE)` need `cd_cache_clear()`.
- Both vignettes quote tmax/tmin trend numbers (`peace-fwcp.Rmd` ~L328-336, `kootenay-lake.Rmd` ~L337+) from `inst/vignette-data/*.rds`, which will go stale.

## Decisions (recommended defaults; change any before approving)

1. **Regenerate history from the local cube**, not by re-fetching EDH. Phase 2 checks it against the EDH-hourly path on one year.
2. **The annual publish slips about a month for all 15 variables.** STEP 3 is capped at the latest local-complete year, so every variable still publishes together. The alternatives are a truncated last local day, or tmax/tmin trailing the other variables, which the append logic does not support.
3. **Republish to S3 before opening the PR, with a backup first.** The vignette numbers can only be refreshed once the corrected COGs are live. The 10 current COGs are copied to `s3://stac-era5-land/_backup/tmax_tmin_utc_day/` and kept locally. `catalog.json` is not rebuilt: the years and extents do not change, and the script asserts that.

## Phase 1: Local-month helper + offline tests
- [x] `_lib.py`: add `monthly_from_daily(daily)`. It takes local-dated daily values, returns the monthly mean labelled by local month, and refuses anything but a whole local year (365/366 days, 12 months)
- [x] `test_lib.py`: a 23:00 UTC peak on 31 Jan is credited to January; 00-07 UTC on 1 Jan Y belong to Y-1; a cube-shaped input and an hourly→`local_daily`→monthly input give identical monthly values; a short year is refused
- [x] Mutation check: switching back to UTC days turns a case red

## Phase 2: Producer code on local days
- [x] `backfill_edh_all.py`: compute tmax/tmin from the `local_year_window()` slice via `local_daily()` + `monthly_from_daily()`, gated on `local_year_complete()` before any compute (#84). tmean/vpd/rh/soil stay on UTC months; that is out of scope, and the shift is negligible for means
- [x] `backfill_edh_tmax_tmin.py`: rewrite as the cube→monthly backfill: read `data/backfill/daily/{tmax,tmin}_daily_YYYY.tif`, write `data/backfill/monthly/{tmax,tmin}_YYYY.tif`; no EDH, idempotent, `--year`
- [x] `pipeline_update_edh.R` STEP 3: cap `candidate_years` at STEP D's `latest_complete` when it is known, so an unready local year costs no fetch from either backfiller; when STEP D failed, fall back to current behaviour
- [x] Equivalence check: one year (2002) through the new `backfill_edh_all.py` path vs. the cube-derived file, max abs diff ≈ 0

## Phase 3: Regenerate and republish tmax/tmin COGs
- [ ] Run `backfill_edh_tmax_tmin.py` for 1950-2025 (152 monthly TIFs)
- [ ] `scripts/tmax_tmin_republish.R` (with `--dry-run`): build the 10 COGs with `cd_aggregate()` + `cd_cog_write()` and assert that band names, extent and resolution match the live COGs. It reports the old→new difference per COG (mean, by season), backs up the live 10 (local + `_backup/` prefix), uploads with `aws s3 cp` (not `--size-only` sync), then verifies each upload by ETag/size and reads one back over `/vsicurl/`
- [ ] Record the measured bias (expected: tmax up, tmin down, largest in summer) in findings, then in `research/` if it is durable

## Phase 4: Docs, vignettes, release notes
- [ ] Re-run `data-raw/{peace_fwcp,kootenay_lake}_vignette_data.R`; update the quoted tmax/tmin numbers and any day-night asymmetry claims in both vignettes
- [ ] Document the day boundary (local, fixed UTC−8, no DST, MST corner an hour off) in `cd_variables()` roxygen
- [ ] Update `README.md` (drop the roadmap item), `CLAUDE.md` (EDH gotcha, scripts list), the `backfill_edh_daily.py` and `_lib.py` docstrings, `research/edh_era5_land_store.md`, and NEWS (values changed; one-month publish slip; `cd_cache_clear()` if revalidation is off)

## Validation
- [ ] `uv run scripts/test_lib.py` passes; `devtools::test()` passes; `pkgdown::check_pkgdown()` passes
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion (README carries the Measurement + Evidence sections)

## Verification (end-to-end)
- `uv run scripts/test_lib.py` (offline)
- One-year EDH vs. cube equivalence (Phase 2)
- `Rscript scripts/tmax_tmin_republish.R --dry-run`, then the live run; then `cd_catalog()` → `cd_extract()` of tmax for one AOI reads the new values (diff vs. backup ≠ 0, same years)
- Vignettes render locally with the refreshed data
