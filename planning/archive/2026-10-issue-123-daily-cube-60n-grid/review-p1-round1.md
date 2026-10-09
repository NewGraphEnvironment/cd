# Code review — #123 Phase 1, round 1

Scope: staged diff (`scripts/_lib.py`, `test_lib.py`, `backfill_edh_{daily,all,snow,tmax_tmin}.py`).

Verified:
- `uv run scripts/test_lib.py` → 37/37.
- Mutation in a scratch copy (`_BC_PAD = 0.0`) → both new cases FAIL (120 x 260, edges 59.9 / -139.9), so the fixture reaches the defect.
- No other Python slicer of the store exists (`grep latitude --include=*.py`).
- `with_retry()` does not retry `ValueError`, so a grid-check failure costs no backoff.

## Findings

- **[severity: fragile]** `scripts/backfill_edh_snow.py:270-275` (`snowfall_fraction`). This is the only place where data from the two stores is combined: `annual_sf` comes from the hourly store and `annual_tp` from the daily store. `annual_sf / annual_tp` aligns them with xarray's default inner join on coordinate labels. `bc_grid_check()` checks each side to 1e-6, but it does not check that the two sides' coordinates are bitwise equal. If one edge coordinate differs by a single ulp between the stores, the join silently drops that row or column. The probe below shows both arrays passing the guard while the ratio comes out (120, 261). Nothing downstream catches it. The snow outputs get no `bc_file_check()`, and `pipeline_stage3_edh.R` has no check across variables or grids. Only STEP 4's per-COG extent check in an incremental run would see it, and a stage-3 full rebuild never runs that check. The brief says the edge values are the same in both stores. progress.md says "edges 60.0/48.0/220.0/246.0 (± drift)", which does not say the values are bitwise equal. The defect was in exactly these new edge values, and the old cut excluded them, so before this change the join never had to match them. Cheap fix, either one:
  - call `bc_grid_check(sf_pct, what=f"snowfall_fraction {year}")` before `write_annual_geotiff`, or
  - `annual_tp = annual_tp.assign_coords(latitude=annual_sf.latitude, longitude=annual_sf.longitude)` after both are grid-checked.

  Probe (scratchpad `join.py`): two 121 x 261 arrays, one with `lat[0]` moved by `np.nextafter`. Both pass `bc_grid_check`, and `(a / b).shape == (120, 261)`.

Nothing else found. Checked and clean:
- the pad arithmetic (centres at 60.1 and 47.9 stay excluded)
- the 0-360 normalisation in `bc_grid_check`
- `bc_file_check` bounds against rioxarray's transform (resolution taken from the end coordinates, drift about 1e-11)
- a store or file with an empty slice, or one oriented south to north, fails closed
- the per-output skip in the daily script unlinks a file that failed the check
- `backfill_edh_tmax_tmin.py` refuses old cube files before it writes anything
