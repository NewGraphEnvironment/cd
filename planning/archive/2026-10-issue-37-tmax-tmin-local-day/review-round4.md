# Code-check round 4 — #37 scripts/ diff (terminating re-walk)

Reviewer: subagent, 2026-10-06. Scope: `cc_diff.patch` (scripts/ only; confirmed identical to
`git diff main...HEAD -- scripts/` at `2a584f8`), full reads of `_lib.py`, `test_lib.py`,
`backfill_edh_all.py`, `backfill_edh_tmax_tmin.py`, `pipeline_update_edh.R`,
`pipeline_stage3_edh.R`, `tmax_tmin_republish.R`, and review rounds 1-3. Every verdict
below is re-derived from the current code, not copied from round 3.

## Probes run (all read-only, or in the scratchpad)

- **Live state (anonymous HEAD).** All 10 live tmax/tmin keys answer 200, ETag = MD5 (SSE-S3
  AES256), 5.0-5.5 MB, so every object is under the 8 MiB multipart threshold. All 10
  `_backup/tmax_tmin_utc_day/<key>` answer **403**, which means absent: there is no anonymous
  ListBucket, and the republish has not run live.
- **Bucket policy.** `s3:GetObject` on `arn:aws:s3:::stac-era5-land/*`; ownership is
  `BucketOwnerEnforced`; no public-access block. So once the backups are created they answer
  200 to the anonymous HEAD that `pipeline_update_edh.R` uses. The new CI check is therefore
  satisfiable, and does not block CI forever.
- **`tmaxmin_local_history()`, sourced from the script.** Against live it returns `FALSE`
  today, as intended before the republish. `curl::parse_headers_list()` yields `$etag`
  without quotes, in the same form as the backup's.
  Mutation table (the function body with `head_etag` swapped for a fake store):

  | state | result |
  |---|---|
  | all 10 live keys differ from their backups (republished) | TRUE |
  | backups absent (403) | FALSE |
  | live == backup on every key (a restore) | FALSE |
  | one key restored, nine republished | FALSE |
  | HEAD connection failure (code 0) | FALSE |
  | 200 with no ETag on both | FALSE |

  The guard passes only in the republished state. `keys` has length 10 (`cd_seasons()` =
  winter/spring/summer/fall), so `all()` never sees an empty vector.
- **Republish idempotency depends on byte-determinism of `cd_cog_write()`.** Ran
  `tmax_tmin_republish.R --dry-run` twice in a scratch working directory holding copies of
  `data/backfill/monthly` and `data/backfill/republish_37`. Both exited 0, and step 3's new
  `/vsicurl/` live-years check passed (live 1950-2025 = new = backup). All 10 rebuilt COGs had
  the same MD5 in run 1, run 2, and the repo's earlier `local_day/` build. So a same-machine
  re-run after a partial or complete step 4 sees `live ETag == md5(new)` and skips; it does not
  trip the new "neither the backed-up original nor this upload" stop.
- **Other degC producers.** `grep degC R/ scripts/` finds only `_lib.py`'s `local_daily()` and
  `monthly_from_daily()`. No R-side producer writes a `units=degC` tmax/tmin file, so the tag
  has exactly one (local-day) origin.

## Enumeration (every row re-derived against the current code)

| # | location | decision | property needed | what is actually checked now | verdict |
|---|---|---|---|---|---|
| 1 | `backfill_edh_all.py:126` | skip tmax/tmin whose file exists | existing file is a complete local-day year | existence | accepted proxy. Fresh CI runner (exists == written by this code). Locally, both consumers now refuse a non-degC file (#15, #17) |
| 2 | `backfill_edh_all.py:161-167` | drop tmax/tmin before compute | every local-year hour is in the store | `local_year_complete()`: exact count, unique, both endpoints | pass |
| 3 | `backfill_edh_all.py:191-202` | write tmax/tmin | 12 local months, each over all its local days | `local_daily()` whole 24-h days + `monthly_from_daily()` exact day set; atomic `write_geotiff` | pass |
| 4 | `backfill_edh_all.py:177-185` | load `t2m` for tmean/vpd/rh only | those three still get t2m; tmax/tmin use their own slice | condition lists all three; `local_vars` slices `hourly_ds["t2m"]` itself | pass |
| 5 | `backfill_edh_tmax_tmin.py:69` | skip existing monthly file | existing file is local-day | existence | accepted proxy (as #1), backstopped in both consumers |
| 6 | `backfill_edh_tmax_tmin.py:76` | write monthly from cube | cube file is a whole local-day year | `read_cog_days()` description count == band count; `monthly_from_daily()` every day of the year once | pass |
| 7 | `backfill_edh_tmax_tmin.py:82-85` | missing cube file | run not read as success | returns 1 | pass |
| 8 | `pipeline_update_edh.R:434-438` | probe NA → `finish(0L)` | run reported failed | `daily_step()` returns FALSE on NA first → `daily_failed` → exit 1 | pass |
| 9 | `pipeline_update_edh.R:439-449` | cap candidates at latest local year | each candidate local-complete | same `local_year_complete()` via `--check` | pass |
| 10 | `pipeline_update_edh.R:528-543` | count a year as written | all 15 files written this run | existence on a fresh runner; tmax/tmin only exist if the local gate passed | pass |
| 11 | `pipeline_update_edh.R:564-611` STEP 4 | append local-day tmax/tmin year to live COG | live history is local-day | gated by #26 (all 10 live keys differ from their UTC-day backups) before STEP 3; grid by extent/res | pass (was F4) |
| 12 | `pipeline_stage3_edh.R:183-195` | refuse unless all 59 written this run | every pushed COG built this run | `names(written)`, filled only after a successful write | pass |
| 13 | `pipeline_stage3_edh.R:199-209` | one contiguous span | no year holes, no short COG | `unique()` of band names; contiguity | pass |
| 14 | `pipeline_stage3_edh.R:210-225` | refuse unless every live year is written | written ⊇ every live COG's years | `setdiff(live tmean_annual years, years_written)` empty; read failure stops; NA names stop | accepted proxy: one live COG stands for 59. That is equivalent while CI appends all COGs together, and all 59 are 1950-2025 today (round 3) (was F2) |
| 15 | `pipeline_stage3_edh.R:104-111` | build/push tmax/tmin from monthly_dir | inputs are local-day | per file, per period: `units == "degC"`, else stop | accepted proxy: degC has one producer (`monthly_from_daily`/`local_daily`); pre-#37 files are K/tagless (round 2) (was F1) |
| 16 | `pipeline_stage3_edh.R:241` push `--size-only` | upload rebuilt COGs | every rebuilt COG reaches S3 | byte size | pre-existing, out of scope |
| 17 | `tmax_tmin_republish.R:102-126` | accept monthly inputs | local-day, complete, contiguous | per-file degC, 12 layers, contiguous years | accepted proxy, backstopped by #20 |
| 18 | `tmax_tmin_republish.R:148-164` | source of the local backup | local backup is the UTC-day original | kept if present; else S3 backup (404-only absent); else live | pass. A non-original can only enter from live after an out-of-order stage 3, and #20 then stops; #22 cannot overwrite with it unless live still equals it |
| 19 | `tmax_tmin_republish.R:177-182` | years match | new holds exactly the years live holds now | `names(new)` identical to live band names over `/vsicurl/` **and** to the backup | pass (was fail) |
| 20 | `tmax_tmin_republish.R:210-213` | stop when nothing moved | new is local-day, old is UTC-day | all mean shifts < 0.05 degC | accepted backstop |
| 21 | `tmax_tmin_republish.R:222-240` | S3 backup upload | never overwritten; content is the live original | 404-only absence; md5(local) == ETag(live) before; ETag after | pass |
| 22 | `tmax_tmin_republish.R:251-272` | overwrite live key | live is the backed-up original (or already this upload) | skip if ETag == md5(new); else require ETag == md5(local backup); else stop. NA ETag stops | pass (was F3) |
| 23 | `tmax_tmin_republish.R:274-282` | read-back | upload readable as consumers read it | `CPL_VSIL_CURL_NON_CACHED` on the bucket prefix, then the last band of one COG. A stale cache could only fail loud (old ≠ new) | pass (post-hoc) |
| 24 | `tmax_tmin_republish.R:215-218` | dry run exits | no S3 write | quits before 2b. Steps 1-3 are reads plus local writes only (verified twice in the scratchpad) | pass |
| 25 | `_lib.py` `write_geotiff` / `write_cog` | local file replace | no truncated file under the final name | tmp + `os.replace` | pass |
| 26 | **new** `pipeline_update_edh.R:456-484` | stop (`finish(1L)`) before dry-run exit and STEP 3 unless history is local-day | every live tmax/tmin key holds the republish or a CI append on top of it | anonymous HEAD of 10 live keys + 10 backups: all 200, live ETag non-NA, live ≠ backup | pass. Fails closed on every non-200, NA, restore, partial restore (mutation table). "Differs from backup" is an accepted proxy for "local-day": the writers of those keys are the republish, CI (gated here), stage 3 (gated on degC, #15) and a manual restore (byte-identical, so it blocks) |
| 27 | **new**, same guard: can it block a legitimate run forever? | — | satisfiable after the republish, for every later year | the backup is publicly readable (`GetObject` on `/*`, `BucketOwnerEnforced`); each CI append keeps live ≠ backup; a stage-3 rebuild over degC inputs also differs | pass. Red between merge and republish, and blocked if `_backup/` is deleted: both accepted |
| 28 | **new**, same guard: transient HEAD failure | — | run not read as success, no write | code 0/5xx → FALSE → `finish(1L)`, nothing fetched; next run retries | pass. The message blames "not confirmed local-day" for a network blip. The remedy it names (re-run the republish) is safe in that state: deterministic bytes → all 10 skipped, or step 3 stops on years |
| 29 | **new**, same guard: placement | — | no write can precede it | after STEP 1-2 (reads), before the dry-run exit, STEP 3 fetch, STEP 4 write and STEP 5 push. STEP D's daily-cube push precedes it but is a separate product | pass |
| 30 | **new** `tmax_tmin_republish.R:254-264` × idempotent re-run | re-run after partial or complete step 4 | already-uploaded keys skipped, rest uploaded | same-machine rebuild is byte-identical (3 builds, same MD5), so uploaded keys hit the skip branch | pass. On a machine whose terra/GDAL writes different bytes, uploaded keys hit the stop: no write, and recovery is the original machine or a restore of the backup. Fails closed |
| 31 | **new** `tmax_tmin_republish.R:177` live read in step 3 | stop on unreadable live | no compare against a stand-in | a `/vsicurl/` error is uncaught → stop before 2b | pass |
| 32 | **new** `pipeline_stage3_edh.R:210-217` | live years read | stop rather than pass on a bad read | the `tryCatch` handler `stop()`s; NA years land in `dropped` → stop | pass |
| 33 | **new** interaction: stage 3 run after merge but before the republish | stage 3 overwrites UTC originals with local-day (no S3 backup) | the originals are recoverable; CI not silently wrong | CI stays blocked (#26: no backup). The republish then stops at #20, or at 2b's md5(local) ≠ live when an old local backup exists | pass (fails closed, loud). The originals survive only in a local `utc_day_backup/`. This is out-of-order operation of a manual full rebuild, and the documented order (republish at merge) avoids it |

## Clean

Every row passes or is an accepted proxy/backstop. The round-3 failures (rows 11, 14, 15, 19,
22) hold under the current code. The rows the fixes introduced (26-33) fail closed on every
input probed:
- The CI guard is satisfiable once the backups exist: they are public under the bucket
  policy.
- It passes only in the republished state (mutation table).
- The republish's live-ETag guard does not break its own idempotent re-run, because the
  rebuild is byte-deterministic (measured across three builds).

No findings. The loop terminates.
