# Code-check round 2 — #119 (scripts/_lib.R, scripts/pipeline_update_edh.R, scripts/test_lib.R, climate-update.yml)

## Findings

- **[severity: fragile]** scripts/pipeline_update_edh.R:446-457 (`read_live_years()`) — on CI's GDAL, the round-1 retry loop never retries. GDAL 3.8 caches a failed `/vsicurl/` open for the life of the process, so attempts 2 and 3 fail from that cache without sending a request.
  - **Probe** (scratchpad, local `http.server`, GDAL 3.8.5 through sf, the same configs as STEP 1). The first open ran with the server down. The server was then started and the same URL reopened in the same process: it was still **ERR**. With `CPL_VSIL_CURL_NON_CACHED` set for the prefix, the same reopen was **OK**. A control on a fresh URL with the server up was OK.
  - **Why it passed locally:** under terra's GDAL 3.13, a connection-refused failure is *not* cached and the retry does recover.
  - **5xx, both GDAL versions:** a 5xx that outlasts GDAL's own retries is cached under 3.8 and 3.13 alike. With a server returning 503 for the first 4 requests, the server log shows exactly 4 HEADs, all from attempt 1. Attempts 2-4 made no request and failed.
  - **Which GDAL CI uses:** `ubuntu-latest` is 24.04, and its system GDAL is 3.8.4, which the P3M terra binary links. The case the comment says this loop covers ("a dropped connection") therefore gets no retry in CI. One blip on any of the 59 reads still turns the weekly heartbeat or the monthly run red, which is what round 1 asked to stop.
  - **Fix:** set `CPL_VSIL_CURL_NON_CACHED` to `paste0("/vsicurl/", cog_base)` before the STEP 1 reads rather than only before the STEP 5 read-back. STEP 5 needs it anyway. It also stops STEP 4 reusing headers STEP 1 cached hours earlier. The STEP 5 read-back's retries do work today, because the setting precedes them.

- **[severity: fragile]** .github/workflows/climate-update.yml:125-128 — the new comment says a pending run cancelled by the concurrency group "comments here too". It does not. With workflow-level `concurrency`, a run that is pending and then superseded is cancelled before its job starts, so no step runs, the alarm step included.
  - **Effect:** a pending *live* monthly run (for example, one queued behind a dry run on a Monday the 1st) that gets displaced by a manual `workflow_dispatch` disappears with no failure comment. That month's live run is lost silently.
  - **Impact is low:** the catalog advances about once a year, and the next monthly cron catches up. The comment still documents an alarm that does not exist.
  - **Fix:** correct the comment, or move `concurrency` to the job level (a job-level pending job is also cancelled without running, so the comment needs correcting either way).

## Minor (comment accuracy, no behavioural effect)

- scripts/pipeline_update_edh.R:438-440 — "a stalled one would hang until the job's timeout-minutes cancels it, which skips the failure alarm". The alarm step is `if: failure() || cancelled()`, precisely so that a timeout cancel does fire it. The real argument for the timeout is a six-hour hang, not a skipped alarm.

## Checked and not flagged

- **`CPL_VSIL_CURL_NON_CACHED` with a value containing `http(s):`.** GDAL splits the value on `:`, so the effective prefix is `/vsicurl/https`, which matches every https `/vsicurl/` file. That is broader than intended, harmless, and confirmed working under 3.8.5 and 3.13.
- **`GDAL_DISABLE_READDIR_ON_OPEN=EMPTY_DIR` stays set for the rest of the process,** covering STEP 4's local reads and `cd_stac_catalog()`. Band names on a terra-written COG are internal: a local COG read under EMPTY_DIR returned its names (GDAL 3.13). The monthly and annual TIFs are read for `nlyr` and values only.
- **`curl::curl_download()` raises on 403/404** (curl 8.0.0, probed) and leaves no file. The `names(rast(cog_path))` comparison covers a truncated body.
- **`append_to_cog()` held-band check.** `cd_cog_write()` writes FLT4S (the terra default), so float32 rounding (~6e-8 relative) is far inside `tolerance = 1e-5`. `all.equal` treats NaN and NA alike via `is.na`. A grid mismatch on a held year stops with the "differs" message rather than the grid message. That is misleading but fails safe.
- **`required_years`.** `as.integer()` drops names, and `after$common` comes from `seq(int, int)`, so it is integer. `identical()` holds.
- **The `unfetched` / `unrepaired` guards** compare integer with double through `setdiff`/`match`, which matches by value.
- **Byte-copy plus `--size-only`.** The copied COG has the live size, so it is skipped. Lagging COGs gain a band, so they change size and upload.
- **`finish()` paths.** The `partial_live` live run exits 1 on every early exit after STEP 1. `partial_live` is cleared only after the read-back. Exits that bypass `finish()` are non-zero.
- **Evidence scripts.**
  - `fixture_dryrun_119.sh` points both URLs at the fixture (grep count asserted) and reads the R exit through `PIPESTATUS[0]`.
  - `interop_119.R` exercises the lagging shape (tmean_annual not ahead, 20 ahead, 38 behind).
  - Neither sets the GDAL configs, which is why the finding above was not visible to them.
