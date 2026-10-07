# Findings — tmax/tmin daily aggregation uses UTC-day, not local-time day (#37)

## Issue context

## Problem

Daily max/min aggregation for tmax/tmin uses UTC-day windows instead of local-time days. For BC (UTC-7 to UTC-8) the local-afternoon tmax peak (~14-16h local, ~22-00h UTC) straddles UTC day boundaries, which produces a small systematic bias vs. a proper local-time aggregation:

- Monthly tmax biased low (afternoon peaks split across two UTC days)
- Monthly tmin biased high (overnight lows split across two UTC days)

The EDH-based Python pipeline (`scripts/backfill_edh_tmax_tmin.py`) flags this as a known limitation in its docstring (lines ~31-36) but has not yet been fixed.

## Context

- The cd package documentation states tmax/tmin as "monthly mean of daily max/min" without specifying the day boundary — the bias is real but probably smaller than other sources of ERA5-Land error for most use cases (valley/alpine contrasts, regional trends).
- Climate departure analysis compares anomalies against a baseline, so the bias partially cancels *if* the same method is used for baseline and the test period. But it does not cancel for absolute-threshold questions (fire weather, growing-degree days, frost dates).

## Proposed solution

Two options, in increasing fidelity and cost:

### Option A: Fixed UTC offset (simplest)
Shift `valid_time` by -8h before `.resample("1D")` to approximate Pacific time. One-line change. Ignores DST and the eastern-BC switch to MST. Captures ~90% of the improvement.

```python
hourly = hourly.assign_coords(
    valid_time=hourly.valid_time - np.timedelta64(8, "h")
)
daily_max = hourly.resample(valid_time="1D").max()
```

### Option B: Per-pixel local time
Compute a UTC-offset raster from longitude (or from a time-zone polygon overlay) and apply per-pixel. Correct for eastern BC but more complex and doesn't handle DST.

## Recommended path

**Option A** for the next backfill regeneration. It's cheap, captures most of the correctness, and matches how most Pacific-coast climate analysis handles the hourly to daily transition. Document the simplification in the cd package methodology section.

## Tracking

Separate follow-up after EDH migration. CDS-based path (#33) closed obsolete; this is the only remaining tmax/tmin correctness issue.

## Phase 1 (2026-10-06)

- `monthly_from_daily()` + `read_cog_days()` in `_lib.py`. The cube reader returns
  exactly the shape `local_daily()` produces, so history (from the cube) and new
  years (from hourly) go through the same monthly function.
- The cube on disk sits on the live COG grid: 0.1 deg, extent -139.95/-113.95/47.95/59.95,
  120 x 260, checked with terra against `/vsicurl/` of `tmax_annual.tif` (76 bands, 1950-2025).
- Mutations: `LOCAL_OFFSET_H = 0` turns 6 cases red (both new monthly cases among them);
  removing the whole-year guard turns 3 red. 35/35 otherwise.
- The test spike for "UTC month vs local month" has to sit at 00-07 UTC on the 1st. A
  23:00 UTC spike on the 31st is the same month either way, so it cannot tell the two apart.
  The plan's wording ("23:00 UTC on 31 Jan") was corrected to 02:00 UTC on 1 Feb.

## Phase 2 (2026-10-06)

- **Equivalence, measured.** `backfill_edh_all.py --year 2002` (new local-day path, live EDH,
  115 s for tmax+tmin in one `dask.compute`) vs `backfill_edh_tmax_tmin.py --year 2002`
  (cube -> monthly, 0.5 s): identical grid, identical NA mask (10,714 sea cells),
  max |diff| = 1.3e-5 degC for both tmax and tmin, i.e. float32 rounding. History rebuilt
  from the cube and new years computed in CI are the same numbers.
  Harness: the other five 2002 outputs were stubbed with empty files so `needed` held only
  tmax/tmin, then deleted.
- The STEP 2 cap lives at the top level: STEP D's `--check` probe was hoisted out of
  `daily_step()` into `latest_local`, read by both STEP D and STEP 2. When the probe fails
  (`NA`), STEP 2 does not cap; the Python `local_year_complete()` gate still refuses a short
  local year, so the worst case is the pre-#37 cost (a fetch that gets discarded).
- Consequence of the gate: the annual publish of all 15 variables now waits for 07:00 UTC
  on 1 Jan of the next year, about one month later than before. The daily cube and the
  annual COGs now advance together.

## Errors Encountered

| Error | Resolution |
|-------|------------|
| `Error in sys.excepthook` at interpreter exit after reading a COG | `read_cog_days()` loads inside `with open_rasterio(...)` so no handle survives to shutdown |
