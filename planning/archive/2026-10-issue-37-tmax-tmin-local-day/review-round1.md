# Code-check round 1 — #37 scripts/ diff

Reviewer: subagent, 2026-10-06. Scope: `cc_diff.patch` (scripts/ only) plus full reads of
`_lib.py`, `test_lib.py`, `backfill_edh_all.py`, `backfill_edh_tmax_tmin.py`,
`pipeline_update_edh.R`, `pipeline_stage3_edh.R`, `tmax_tmin_republish.R`, and
`backfill_edh_daily.py` (the `--check` the new STEP 2 cap depends on).

## Probes run (all read-only or in a scratch copy)

- `uv run scripts/test_lib.py` from a copy of `scripts/`: 35/35 pass (pandas 3.0.6, xarray 2026.9.0, dask 2026.8.0).
- `dask.compute(*[monthly_from_daily(...)])` on chunked xarray returns DataArrays with
  `attrs == {"units": "degC"}`, float32, 12 months.
- `monthly_from_daily()` on a `datetime64[ns]` coordinate (as EDH gives) against pandas 3's
  `datetime64[us]` `date_range`: `DatetimeIndex.equals` is True, so the guard does not
  false-refuse real input.
- Live tmax/tmin COGs are 5.0-5.5 MB (under the 8 MiB multipart threshold), bucket default
  encryption is SSE-S3 (AES256), and the local backup's MD5 equals the live ETag for
  `tmax_annual` / `tmax_summer`, so the ETag==MD5 verification in the republish holds.
- Bucket versioning: `Suspended` (confirmed).

## Findings

- **[fragile]** `scripts/tmax_tmin_republish.R:73-75` (used at :137 and :196) — `s3_exists()`
  returns FALSE for *any* non-zero `aws s3api head-object` exit: a 404, but also a 403, a
  throttle, an expired session token or a network blip. Both "never overwrite the backup"
  guards rest on it, and both fail toward the destructive branch:
  - :137 — if the S3 backup exists but the HEAD fails and there is no local backup (fresh
    machine, or `data/backfill/republish_37/` cleared), the local "backup" is downloaded from
    the **live** key, which after a publish holds the local-day COG — exactly the case the
    comment says must never happen.
  - :196 — on that same re-run the HEAD of `bkey` fails again, the md5(local)==ETag(live)
    check then *passes* (both are the republished file), and `aws s3 cp` writes the
    local-day file **over the only copy of the UTC-day original**. Versioning is suspended,
    so that is unrecoverable (it would need a full UTC-day rebuild from EDH).
  Unlikely (needs the HEAD to fail on a key that exists, on a re-run after publish), but the
  cost is the one thing the backup exists to prevent. Fix: treat only an explicit `(404)` in
  the head-object output as absent and `stop()` on any other failure (the
  `code-check-shell.md` rule "`aws s3 cp` cannot tell a missing key from a missing bucket":
  only a 404 means absent). Optionally make the backup PUT conditional
  (`aws s3api put-object --if-none-match '*'`) so the server enforces "never overwritten".

- **[fragile]** `scripts/pipeline_stage3_edh.R:163-175` — the new catalog guard checks that the
  59 expected COG *names exist* in `cog_dir`, not that this run built them. `cog_dir`
  (`data/backfill/cogs`) persists between runs and Step 1 only rewrites variables that have
  monthly files. So the exact scenario the comment names — a partial `monthly_dir` after a
  single-variable regen — passes the guard whenever an earlier full stage-3 run left COGs
  behind: tmax/tmin are rebuilt, the other 49 are stale copies, the catalog is built over
  them, and `cd_s3_push()` (`--size-only`, no versioning) uploads every stale COG whose size
  differs from live — which is all of them once CI has appended a year since that build. That
  overwrites live COGs with older, shorter ones. (`data/backfill/cogs` does not exist on this
  machine today, so it is latent, and the push behaviour predates the branch; the guard is new
  and claims to cover this case.) Fix: record the paths Step 1/1b actually wrote this run and
  compare `expected_cogs` against that set, or clear `cog_dir` at the start of Step 1.

- **[fragile]** `scripts/tmax_tmin_republish.R:89-116` and `scripts/backfill_edh_tmax_tmin.py:393`
  — nothing checks that the monthly inputs are local-day files. Both
  `backfill_edh_tmax_tmin.py` (`if out.exists(): continue`) and `backfill_edh_all.py` skip an
  existing `tmax_YYYY.tif`, so on any machine still holding pre-#37 UTC-day monthly files the
  regen writes nothing ("nothing to write", exit 0) and the republish rebuilds and publishes
  the **UTC-day** values while logging "10 COGs republished on local days". The only defence is
  a human noticing ~0 shifts in `diff_summary.csv`. On this machine the inputs are correct
  (regenerated 21:00 today; tagged `units=degC`; dry-run shifts are -0.15 to -0.77 degC). A
  discriminating marker already exists: new files carry exactly the `units=degC` tag from
  `monthly_from_daily()`, old ones carried t2m's attrs (`units=K`, GRIB tags). A one-line
  check of that tag per input in the republish, or a `stop()` when every
  `|mean_shift_c| < 0.05`, makes it a control rather than a reading.

- **[stale claim]** `scripts/backfill_edh_tmax_tmin.py:26-28` — the docstring still says UTC days
  were "biasing tmax low and tmin high". The branch's own measurement
  (`data/backfill/republish_37/diff_summary.csv`, `research/tmax_tmin_day_boundary.md`,
  CLAUDE.md) shows the opposite for tmax: UTC-day tmax reads **high** by 0.5-0.8 degC, and the
  local-day correction lowers tmin too. Not a failure, but it is the one copy of the sentence
  the research file says was wrong, left in the script that produces the numbers.

## Checked and clean

- `backfill_edh_all.py`: local-year gate precedes any compute (#84 holds); `t2m` dropped from
  `needed_hourly_vars` only for tmax/tmin, still fetched for tmean/vpd/rh; single
  `dask.compute` for both; retry re-entry recomputes `needed` so it is idempotent.
- `pipeline_update_edh.R`: probe failure sets `daily_failed` via `daily_step()` returning FALSE,
  so the new `finish(0L)` on NA still exits 1; the cap uses the same `local_year_complete()` as
  the Python gate, so the two cannot disagree; dry-run path unchanged in shape.
- `read_cog_days()` / `monthly_from_daily()`: band-name round trip, leap day, NaN cells,
  float32 and lon -180..180 all pinned by the cube-vs-hourly test, which passes.
- Republish ordering: all S3 backups precede any live overwrite; a CI append between dry-run and
  live run is caught by the band-name check (stop) and by md5(local backup)!=ETag(live) (stop).
</content>
</invoke>
