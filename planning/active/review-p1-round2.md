# Code-check round 2: Phase 1 (#123), staged diff

## Clean

No real issues found in the staged diff.

## What was checked

**The round-1 fix (snowfall_fraction, `backfill_edh_snow.py:277-281`) is correct, but the case it targets was already loud.**
- Probe (xarray 2026.9.0, scratchpad `probe_where.py`): two (lat, lon) arrays whose 60 N label differs by 1 ulp.
  - `100 * a / b` inner-joins to 120 x 261, with no warning.
  - The next call, `.where(b > 0, 0)`, raises `AlignmentError: cannot align objects with join='exact'`. xarray's `where` uses `join="exact"` whenever `other` is given, and here `other` is 0.
- So in the current code a dropped edge row from a store mismatch raises before the new `bc_grid_check(sf_pct)` is reached.
- The new check still does no harm. It would also catch a mismatch if the `.where()` were ever removed or changed to the NA form, which inner-joins.
- One inaccuracy, in a comment only: "would drop that row here without a word" is not what happens with the code as written. The `.where()` raises.

**Other places where arrays are combined by label alignment.** Each one combines data from a single source and a single slice, so the coordinates are identical objects:
- `backfill_edh_all.py`:
  - vpd/rh: `es - ea` both come from `hourly_sub`, one Dataset cut by one `sel()`.
  - soil_moisture: `xr.concat` of `swvl1..4` from the same `hourly_sub`.
  - prcp: one variable, daily store only.
  - tmax/tmin: one `t2m_local` slice through `local_daily` and `monthly_from_daily`; nothing is combined.
- `backfill_edh_snow.py`:
  - swe and swe_max: `sde * rsn` both come from `hourly_ds[...].sel(**state_box)`.
  - snowfall, snowmelt, doy_50, rate_peak: each uses one variable.
  - snowfall_fraction is the only place that mixes stores (above).
- `backfill_edh_daily.py`: one slice, three reductions; nothing is combined.
- `backfill_edh_tmax_tmin.py`: reads the cube with `read_cog_days`, then `monthly_from_daily` and `write_geotiff`; nothing is combined.
- No other Python script slices the store: `grep latitude=slice` matches only `_lib.py` and `test_lib.py`.

**The guards themselves.**
- `uv run scripts/test_lib.py`: 37/37 passed.
- Mutation proof in a temp copy: setting `_BC_PAD = 0.0` turns both new cases red (35/37). The slice comes back 120 x 260 and `bc_file_check` rejects the "good" COG. The guards fire.
- `bc_grid_check` fails closed. An empty slice gives `edges=None`, which raises. A store stored south to north, or with mismatched longitude conventions, gives an empty or wrong-sized slice, which also raises.
- `bc_grid_check` raises `ValueError`. `with_retry` does not treat that as transient, so the error propagates right away. In all/snow, the per-year handler logs FAILED and the run continues. In the daily script it is uncaught, so the run exits non-zero.
- `bc_file_check` bounds: rioxarray derives the transform from the first and last coordinates. Drift of about 1e-11 is far inside the 1e-6 tolerance (confirmed by the passing test, which writes a COG from drifted coordinates).
- `backfill_edh_tmax_tmin.py` declares `rasterio` in its PEP 723 deps, so the `bc_file_check` import resolves.
- Nothing in `scripts/`, `R/` or `tests/` hardcodes 120 or 260 as a grid size. STEP 4's extent comparison in `pipeline_update_edh.R:797` would abort an append across grids.

**Noted, not a finding.** In `backfill_edh_daily.py`, `bc_file_check` runs after `write_cog`'s `os.replace` has already put the file in `DAILY_DIR`. A SIGKILL in that window would leave a file nobody checked. It would only be off-grid if the pre-fetch `bc_grid_check` had passed and the writer had then shifted the grid. Also, a `RasterioIOError` raised while reading the header is not a `ValueError`, so it would not trigger the unlink. Neither is reachable in practice.
