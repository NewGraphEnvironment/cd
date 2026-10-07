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

## Errors Encountered

| Error | Resolution |
|-------|------------|
