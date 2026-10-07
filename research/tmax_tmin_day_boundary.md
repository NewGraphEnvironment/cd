# Day boundary for tmax/tmin: UTC days vs local days in BC

**Verified:** 2026-10-06 · **Issues:** #37 (spawned it), #116 (the local-day cube) · **Produced by:** `scripts/tmax_tmin_republish.R --dry-run` (per-COG table in `data/backfill/republish_37/diff_summary.csv`, reproduced below) and an EDH hourly probe at two cells — method and wrong turns in `planning/archive/2026-10-issue-37-tmax-tmin-local-day/`

Daily maximum and minimum 2 m temperature depend on where the day starts. ERA5-Land is hourly in UTC; BC is UTC−8 (UTC−7 in summer, and UTC−7 all year in the MST corner of the east).

## Where the extremes fall

EDH hourly `t2m`, July 2002, mean by UTC hour: the maximum is at **23–00 UTC** (Prince George 23, Kamloops 00), i.e. about 15–16 PST, and the minimum is at **13 UTC**, about 05 PST.

## What each window does

| window | runs (PST) | tmax | tmin |
|---|---|---|---|
| UTC day | 16:00 → 16:00 | boundary sits **on** the afternoon peak: a hot afternoon counts toward two days, so tmax reads **high** | holds exactly one night, so tmin is clean |
| local day (fixed UTC−8) | 00:00 → 00:00 | boundary far from the peak, so tmax is clean | holds the end of one night and the start of the next: two chances at a low, so tmin reads **low** (the time-of-observation effect a midnight station day also has) |

## Measured: local minus UTC, BC mean, 1950–2025

Mean over years of each year's BC-mean difference; range across years in brackets.

| | annual | winter (DJF, same year) | spring | summer | fall |
|---|---|---|---|---|---|
| tmax | −0.64 (−0.73..−0.57) | −0.51 (−0.68..−0.37) | −0.63 (−0.80..−0.41) | −0.77 (−0.91..−0.67) | −0.65 (−0.84..−0.49) |
| tmin | −0.31 (−0.39..−0.24) | −0.42 (−0.59..−0.27) | −0.27 (−0.39..−0.16) | −0.15 (−0.20..−0.10) | −0.40 (−0.58..−0.30) |

Largest single cell: 1.75 °C (tmax, spring). The diurnal range narrows by about 0.33 °C on the annual mean. The difference drifts over the record, so trends move, not only levels: at (−125, 52) the plan review measured 0.49 °C in 1960 and 0.61 °C in 2020.

The UTC values reproduce exactly from EDH hourly through `resample("1D")` in UTC (Prince George 2002 annual tmax 9.182 °C, Kamloops 11.846 °C, matching the published COGs to 1e-3), so the whole difference is the day boundary.

## What cd uses

Local days at a fixed UTC−8 for both tmax and tmin, since #37: the same days as the daily cube (`cd_extract_daily()`), and the convention station records use. #37's original premise had the direction backwards (it expected tmax low, tmin high under UTC).
