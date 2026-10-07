# Code-check round 2 — #37 scripts/ diff

Reviewer: subagent, 2026-10-06. Scope: `cc_diff.patch` (scripts/ only), full reads of
`_lib.py`, `test_lib.py`, `backfill_edh_all.py`, `backfill_edh_tmax_tmin.py`,
`backfill_edh_daily.py`, `pipeline_update_edh.R`, `pipeline_stage3_edh.R`,
`tmax_tmin_republish.R`, plus `R/cd_s3_push.R`, `R/cd_stac_catalog.R`, `R/cd_cache_fetch.R`
(consumers of what the republish changes). Focus: the four round-1 fixes, one axis over.

## Probes run (read-only, or in a scratch copy)

- `uv run scripts/test_lib.py` from a copy of `scripts/`: 35/35 pass (pandas 3.0.6,
  xarray 2026.9.0, numpy 2.5.3).
- Zarr round trip: a `datetime64[ns]` coordinate decoded from a zarr store, sliced to
  `local_year_window()`, through `local_daily()` and `monthly_from_daily()` -> 12 months.
  Also `[s]`, `[ms]`, `[us]` inputs -> 12 months. pandas 3's `date_range` is `[us]`;
  `DatetimeIndex.equals` does not false-refuse across units.
- Fix 1 (`s3_exists`): the real missing-key output on this bucket is
  `aws: [ERROR]: An error occurred (404) when calling the HeadObject operation: Not Found`,
  which the `"(404)"` fixed match catches; a 403 / throttle / credential error now `stop()`s.
  The caller has ListBucket (missing key answers 404, not 403), so the first run is not
  blocked.
- Fix 3 (units tag): `terra::metags()` (terra 1.9.50) on `data/backfill/monthly/tmax_2000.tif`
  returns a data.frame `name/value/domain` with `units = degC`, so
  `tags$value[tags$name == "units"]` reads as intended; a `units=K` file or a tagless file
  (NULL / 0-row) is not `identical()` to `"degC"` and stops.
- Fix 2 (stage 3): `expected_cogs` = 55 + 4 = 59 with `cd_seasons()` names
  winter/spring/summer/fall, matching what `cd_aggregate()` names and what Step 1/1b append to
  `written`. A variable with no inputs hits `next` before `written` is appended, so it fires.
- ETag==MD5 premises still hold: bucket default SSE-S3 (AES256); live `tmax_annual` /
  `tmin_summer` ETags equal the local backups' MD5; new COGs 5.3-5.8 MB (< 8 MiB); the only
  `~/.aws/config` multipart override is 64 MB (raises, does not lower, the threshold).
- `cd_stac_catalog()` records only start/end datetimes per item (no checksum, size or stats),
  so leaving `catalog.json` untouched after the republish is correct. `cd_cache_fetch()`
  invalidates on ETag, so consumer caches pick up the republished COGs.

## Findings

- **[fragile]** `scripts/pipeline_stage3_edh.R:165-184` — the round-1 fix closes the
  *variable* axis of "partial or stale" but not the *year* axis, and the guard's own message
  claims both. Every COG can be "written by this run" and still be shorter than what is live:
  - **Stale inputs vs live.** CI's `pipeline_update_edh.R` appends years to the live COGs
    from a runner that never writes into a developer's `data/backfill/monthly/`. After CI
    appends 2026 (about Feb 2027, now gated on the local year), a local stage 3 over a
    `monthly_dir` that ends at 2025 writes all 59 COGs, passes the guard, and
    `cd_s3_push()` (`--size-only`; every file differs in size) replaces each live 1950-2026
    COG with a 1950-2025 one. Versioning is suspended, so the appended year is gone from all
    15 variables. The re-run-stage-3-after-a-method-fix scenario is exactly #37's, had the
    republish script not been written.
  - **Holes.** A year missing for one variable (a deleted `tmean_1987.tif`) or a monthly file
    with `nlyr != 12` (Step 1 only `warning()`s and `next`s, :101-104) produces a COG with
    that year silently absent; it counts as written.

  `tmax_tmin_republish.R` already guards exactly this (contiguous years at :103-107, band
  names identical to live at :174-177); stage 3 does not. Minimal fix in the same place as
  the new guard: require every written COG's band names to be the same contiguous year run,
  and require that run to cover the live catalog's latest year (`cd_catalog()` +
  `names(rast("/vsicurl/<href>"))` for one COG, as `pipeline_update_edh.R` STEP 1 does)
  before building the catalog. Latent today: live COGs end at 2025, which equals the local
  monthly range.

## Checked and clean

- Fix 1 (`s3_exists`): only an explicit `(404)` reads as absent; any other failure stops, so
  both backup guards now fail closed. A missing *bucket* would also say 404, but every path
  that follows (`aws s3 cp` download, `s3_etag()` NA vs MD5) then stops, so it cannot reach a
  write.
- Fix 2 (`written`): appended only after a successful `cd_cog_write()` in both Step 1 and
  Step 1b; stale files in `cog_dir` no longer count.
- Fix 3: units check per input file plus the all-COGs < 0.05 degC stop. On a re-run after a
  partial publish the comparison is against the UTC-day backup (local `old_dir` or the S3
  backup), not the live object, so a half-published state still shows non-zero shifts and
  proceeds; step 4 then skips keys whose ETag already equals the new MD5.
- Fix 4: docstring now says UTC-day tmax read high, matching `diff_summary.csv`
  (tmax -0.51 to -0.77, tmin -0.15 to -0.42 degC).
- `backfill_edh_all.py`: local-year gate precedes compute; `t2m_local` sliced with
  `isoformat()` bounds equal to `local_year_window()`; `local_year_complete()` guarantees
  `local_daily()`'s 24-hour check passes; one `dask.compute` for both; transient errors are
  retried by the existing outer `with_retry(process_year)`, idempotent on re-entry.
- `backfill_edh_tmax_tmin.py` / `read_cog_days()`: same bbox constants as the cube script;
  partial or mislabelled cube years are refused by the band-count check and
  `monthly_from_daily()`; exit 1 when cube files are missing.
- `pipeline_update_edh.R`: probe failure -> `latest_local` NA -> `daily_step()` FALSE ->
  `daily_failed` -> the new `finish(0L)` exits 1 (live and dry-run); a probe returning a year
  below `latest_year` empties `candidate_years` and exits through `finish()`; `--check`'s log
  lines on stdout are filtered by the anchored `grep`.
- `tmax_tmin_republish.R` ordering: all S3 backups (each verified md5(local)==ETag(live)
  before upload and ETag after) precede any live overwrite; a CI append between runs is caught
  by the band-name check.

## Verdict

One fragile finding (stage 3 guard, year axis). Round-1 fixes hold.
</content>
</invoke>
