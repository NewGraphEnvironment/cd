# Code-check round 3 — #37 scripts/ diff (mechanism + enumeration)

Reviewer: subagent, 2026-10-06. Scope: `cc_diff.patch` (scripts/ only), full reads of
`_lib.py`, `backfill_edh_all.py`, `backfill_edh_tmax_tmin.py`, `pipeline_update_edh.R`,
`pipeline_stage3_edh.R`, `tmax_tmin_republish.R`, the `--check` path of
`backfill_edh_daily.py`, and review rounds 1-2. Checklist: `code-check.md` "A guard that
fails toward pass", "A proxy is not the property", "A guard's scope, escape hatches, and
remedies".

## Probes run (all read-only, or in the scratchpad)

- Live catalog: 59 COGs, **every one spans 1950-2025 (n=76)**, read over `/vsicurl/`. So
  stage 3's "one shared span" rule matches live, and reading only `tmean_annual` for the
  live end year is equivalent today.
- `data/backfill/monthly/` on this machine: 152 files, tmax/tmin 1950-2025 only;
  `tmax_2000.tif` tags `units=degC`. `data/backfill/cogs/` absent.
- S3 backup `_backup/tmax_tmin_utc_day/tmax_annual.tif`: **404** (republish not yet run
  live). Live `tmax_annual.tif` ETag `81c7045e…` equals the MD5 of the local
  `utc_day_backup/tmax_annual.tif`.
- Stage 3 year guard replayed in R with all 59 COGs written as 1960-2025 against live
  latest 2025: **passes** ("publishes 1960-2025 over live 1950-2025").

## Mechanism

**Every guard reads evidence about the artifact in hand and treats it as a statement about
the thing the write is about to replace.** The property a replacing write needs is a
*relation* between the new content and the current target: the target is what we think it
is, the new content covers every year the target holds, and both use the intended method.
Each defect so far checked one side of that relation against a local stand-in for the
other:

| round | stand-in | property it stood in for |
|---|---|---|
| R1a | "HEAD failed" | "the backup object is absent" |
| R1b | "COG present in cog_dir" | "COG built from current inputs this run" |
| R1c | "monthly file exists" (backfill skip) | "monthly file is local-day" |
| R2 | "every variable written" | "every live year written" |

This round finds the same substitution four more times: one end of the year span for the
span, a snapshot taken on the first run for the live object, the grid for the method, and a
comment for the publication order. The common shape is that nothing reads the **target**
(the live S3 object) at the moment of the write; guards compare against what was local,
remembered, or assumed.

## Enumeration

Every decision in the diff that leads to a replacing write (local file, S3 object, catalog)
or to a skip a later step reads as success.

| # | location | decision | property needed | what is actually checked | verdict |
|---|---|---|---|---|---|
| 1 | `backfill_edh_all.py:126` | skip tmax/tmin whose file exists | existing file is a complete local-day year | file existence | proxy. Safe in CI (fresh runner: exists == written by this code). Locally it is backstopped only in the republish (#17), not in stage 3 (#15) |
| 2 | `backfill_edh_all.py:161-167` | drop tmax/tmin before any compute | every hour of the local year is in the store | `local_year_complete()`: exact count, unique, both endpoints | equivalent: pass |
| 3 | `backfill_edh_all.py:191-202` | write tmax/tmin | 12 local months, each over every local day | `local_daily()` whole 24-h days + `monthly_from_daily()` exact day set | equivalent: pass |
| 4 | `backfill_edh_all.py:177-185` | load `t2m` only for tmean/vpd/rh | tmean/vpd/rh still get t2m | condition still lists all three | pass |
| 5 | `backfill_edh_tmax_tmin.py:69` | skip existing monthly file | existing file is local-day | existence | proxy (same as #1); same backstop gap |
| 6 | `backfill_edh_tmax_tmin.py:76` | write monthly from cube | cube file is a whole local-day year | band descriptions == band count, dates == every day of the year; cube has one (local-day) producer | pass |
| 7 | `backfill_edh_tmax_tmin.py:82-85` | missing cube file | run not read as success | returns 1 | pass |
| 8 | `pipeline_update_edh.R:434-438` | probe NA → `finish(0L)` | run reported failed | `daily_step()` returns FALSE on NA before anything else, so `daily_failed` is TRUE and `finish()` exits 1 (live and dry-run) | pass |
| 9 | `pipeline_update_edh.R:439-449` | cap candidates at latest local year | each candidate local-complete | same `local_year_complete()` via `--check`; empty set is a genuine resting state | pass |
| 10 | `pipeline_update_edh.R:494-509` | count a year as written | 15 files written this run | existence; fresh CI runner, and a not-yet-complete year cannot pre-exist | pass (pre-existing) |
| 11 | `pipeline_update_edh.R:530-551` (STEP 4, reached by new local-day tmax/tmin) | append new tmax/tmin year to live COG | appended year uses the live history's day convention | extent and resolution only; the order "republish before CI appends" is a comment in the republish header | **fail** (F4) |
| 12 | `pipeline_stage3_edh.R:176-184` | refuse unless all 59 written this run | every pushed COG built this run | `names(written)` | pass |
| 13 | `pipeline_stage3_edh.R:188-198` | refuse unless one contiguous span | no year holes, no per-variable short span | `unique()` of band names, contiguity | pass |
| 14 | `pipeline_stage3_edh.R:199-211` | refuse unless run reaches live | run's years ⊇ every live COG's years | `max(written) >= max(live tmean_annual)`; the start year is never compared | **fail** (F2). Reading one COG is equivalent today (all 59 share 1950-2025) |
| 15 | `pipeline_stage3_edh.R` Step 1 → catalog + push | build and push tmax/tmin from monthly_dir | tmax/tmin inputs are local-day (what live is after #37) | nothing | **fail** (F1) |
| 16 | `pipeline_stage3_edh.R:227` push `--size-only` | upload rebuilt COGs | every rebuilt COG reaches S3 | byte size | pre-existing, out of scope |
| 17 | `tmax_tmin_republish.R:100-111` | accept monthly inputs | inputs local-day, complete, contiguous | `units=degC` per file, 12 layers, contiguous years | accepted proxy; backstopped by #20 |
| 18 | `tmax_tmin_republish.R:137-154` | source of the local backup | local backup is the UTC-day original | local copy kept unexamined if present; else S3 backup (404-only absent); else live | pass with backstop: live can only be non-original via #15, and #20 then stops |
| 19 | `tmax_tmin_republish.R:163-177` | band names / grid "match live" | new COG holds exactly the years live holds **now** | compared against the backup in `old_dir`, a snapshot from the first run | **fail** as a check of live (feeds F3) |
| 20 | `tmax_tmin_republish.R:195-199` | stop when nothing moved | new is local-day and old is UTC-day | all mean shifts < 0.05 degC | accepted backstop: pass |
| 21 | `tmax_tmin_republish.R:209-227` | S3 backup upload | backup never overwritten; content is live original | 404-only absence; md5(local) == ETag(live) before; ETag after | pass |
| 22 | `tmax_tmin_republish.R:239-252` | overwrite live key | live is still the backed-up original or this script's own upload; new covers live's years | only `ETag(live) == md5(new)` → skip; anything else is uploaded | **fail** (F3) |
| 23 | `tmax_tmin_republish.R:255-260` | read-back | upload readable as consumers read it | one band of one COG, after all uploads | pass (post-hoc only) |
| 24 | `tmax_tmin_republish.R:201-204` | dry run exits | no S3 write | quits before 2b | pass |
| 25 | `_lib.py` `write_geotiff` / `write_cog` | local file replace | no truncated file under the final name | tmp + `os.replace` | pass |

## Findings

- **[fragile]** `scripts/pipeline_stage3_edh.R:98-118` (row 15) — stage 3 builds and
  publishes tmax/tmin from whatever `monthly_dir` holds and never checks the day convention.
  It is the second consumer of the same monthly files the republish guards with
  `units=degC` (`tmax_tmin_republish.R:100-111`), whose own comment gives the reason: "The
  backfills skip files that exist, so a stale one would otherwise be republished." After
  #37 is live, any machine that still has a pre-#37 full monthly set (tmax/tmin tagged
  `units=K`) passes all three new stage-3 guards: 59 written this run, one contiguous span,
  reaching 2025. It then pushes UTC-day tmax/tmin over the local-day live COGs with no
  backup (versioning suspended). Nothing reports it, and `diff_summary`'s near-zero-shift
  backstop exists only in the republish. Recoverable by re-running the republish, but only
  if someone notices. This is the R1c fix landing in one of two callers that share an input.
  Fix: apply the same per-file `units == "degC"` stop to tmax/tmin inputs in stage 3
  Step 1.

- **[fragile]** `scripts/pipeline_stage3_edh.R:199-211` (row 14) — the "reaches live"
  guard compares only the end year. A `monthly_dir` whose years are contiguous but start
  late (1960-2025) passes against live 1950-2025 (replayed in R: passes) and the push
  replaces every live COG with one missing 1950-1959. The guard's comment says it prevents
  replacing "live years with nothing". This is R2's year axis again, at the other end. Fix:
  read the live band names (already fetched) and require
  `all(live_years %in% years_written)`, not `max >= max`.

- **[fragile]** `scripts/tmax_tmin_republish.R:137-140, 163-177, 209-213, 239-252`
  (rows 19 and 22) — once the S3 backup exists, nothing on a re-run compares the live object
  with anything:
  - Step 2 keeps an existing local backup unexamined.
  - Step 3's "band names differ (… live …)" check compares the new COG with that backup,
    not with live.
  - 2b logs "exists, kept" and skips its md5(local) == ETag(live) check.
  - Step 4 uploads whenever `ETag(live) != md5(new)`.

  The concrete case: CI appends 2026 to all 59 live COGs (~spring 2027, once the local year
  completes). Someone then re-runs the republish to rebuild after any later fix.
  `backfill_edh_tmax_tmin.py`'s default `range(1950, 2026)` yields inputs ending in 2025,
  which match the 1950-2025 backup. The shift against the UTC-day backup is non-zero, so the
  script proceeds and overwrites all 10 live tmax/tmin COGs with 1950-2025. That silently
  drops 2026, while `catalog.json` (rebuilt by CI) still advertises it. The header's
  restore instruction ("copy … `_backup/tmax_tmin_utc_day/*` back over the 10 keys") has the
  same hole after any CI append. Fix: before each upload in step 4, require
  `s3_etag(key) %in% c(md5(file.path(old_dir, key)), md5(path))`, and compare `names(new)`
  with the live COG's band names over `/vsicurl/`. Stop otherwise.

- **[fragile]** `scripts/pipeline_update_edh.R:530-577` (row 11; the diff changes what
  reaches it) — from merge on, CI appends **local-day** tmax/tmin years. The live history
  stays **UTC-day** until someone runs the one-off republish. The only thing enforcing that
  order is the republish header ("Run the live publish when the code … is on main"), and
  `append_to_cog()` checks extent and resolution only. If the republish is not run before
  2026 completes in local time, every tmax/tmin COG gains a final year about 0.5-0.8 degC
  colder in tmax for no physical reason, which is a trend artefact. Nothing detects it. A
  later republish attempt then stops on band names, failing safe but leaving the mixed series
  live. This is "regeneration status, never by equality": the republish leaves a record that
  it ran (`_backup/tmax_tmin_utc_day/<key>`). Fix: STEP 4 should refuse to append tmax/tmin
  (stop, or skip with a non-zero exit) unless that key exists.

## Checked and clean

Rows 2-10, 12-13, 17-18, 20-21, 23-25. The round-1 and round-2 fixes hold:
- `s3_exists()` treats only `(404)` as absent.
- `written` is filled only after a successful `cd_cog_write()`.
- The units check is per file.
- The span check matches live, which is 1950-2025 on all 59 COGs.
