# Code-check round 3 — R side + pipeline STEP D (#116)

Reviewer scope: staged diff excluding planning/ and inst/; full reads of R/cd_extract_daily.R,
tests (helper, fixture, live), scripts/pipeline_update_edh.R (STEP D + finish()),
scripts/backfill_edh_daily.py, scripts/_lib.py, data-raw/example_daily.R, CLAUDE.md diff,
R/cd_cache_fetch.R. All probes ran in a scratchpad copy; nothing in the repo was modified
except this file. The fixture suite passes offline (50 expectations, 0 failures).

## Mechanism

Round 1's two findings share one mechanism: **a writer serialises ambient state it was
handed implicitly, and the publish step ships whatever the writer left behind** — xarray
attrs that survived `resample()`/arithmetic became file tags (`units=K`, GRIB tags), and a
staging file placed inside the synced directory would have become an S3 object. The
writer had no reason to look at either. I checked everywhere else that mechanism can
reach in this diff. Every case was clean:
- **Encoding, not just attrs.** rioxarray also honours `da.encoding` (`scale_factor`,
  `add_offset`, `_FillValue`, `dtype`). The local COGs show no Offset/Scale, Float32 values
  in plausible degC, and band 1 at Prince George -10.0 degC on 2002-01-01, so source
  encoding is not leaking.
- **Files built before the fix.** I read `tmax_daily_2002`, `tmean_daily_1950` and
  `tmin_daily_1953` in `data/backfill/daily/` without modifying them. All three carry
  `units=degC` and no GRIB tags, so they were built after the fix and are safe for
  `cd_s3_push`.
- **What `cd_s3_push(daily_dir)` would sync.** `data/backfill/daily/` holds only
  `*_daily_YYYY.tif`. `write_cog` stages in `data/backfill/.cog_stage_*`, which is outside
  the synced dir and would be matched by `--exclude '.*'` anyway. `write_geotiff`'s `.tmp`
  lands inside that stage dir. STEP D's `nlyr(rast(f))` writes no sidecar.
- **terra sidecars.** Running `cd_extract_daily()` over the fixture, and running the
  `data-raw/example_daily.R` crop + `writeRaster` sequence, left no `.aux.xml` or
  `.aux.json` next to the source or the output. The example TIFs carry only `units=degC` plus
  the accepted STATISTICS.
- **The cache** writes `<hash>.tif` and `.meta` under `rappdirs::user_cache_dir("cd")`,
  and nothing publishes from there. The live test's `R_USER_CACHE_DIR` override does reach
  rappdirs (probed: it returned `<tempdir>/cd`), so the test is isolated.

## Findings

- **[severity: bug]** tests/testthat/test-cd_extract_daily_live.R:23 and :30 — The test calls
  `tidyr_free_wide(a)` at line 23, inside `test_that()`, but the helper is only defined at
  line 30, after the block. testthat evaluates each `test_that()` while it sources the file,
  so the binding does not exist yet. I probed this with a two-line file: `could not find
  function "helper_later"`. The test is skipped today, which hides the problem. Once the cube
  is published, the test reaches that line on any local `devtools::test()` with a network and
  errors. This is exactly the run that exists to exercise the remote read paths. Fix: move
  `tidyr_free_wide` above the `test_that()` or into `helper-daily.R`.

- **[severity: fragile]** R/cd_extract_daily.R:260 — `land <- !is.na(terra::values(template[[1]], mat = FALSE))`
  reads band 1 of the whole grid. The cube is pixel-interleaved with 16x16 tiles, so every
  tile holds all 365 bands, and reading band 1 everywhere means fetching every tile. Under
  `cache = FALSE` that is the entire file over `/vsicurl/`. I measured this against a local
  Range-capable server serving a copy of `tmean_daily_2002.tif` (16.98 MB):
  `cd_extract_daily(1 point, 3 days, "tmean", cache = FALSE)` pulled **16,997,605 bytes in
  28 requests**. A plain point `extract()` on the same file pulled **245,760 bytes in 26
  requests**. As a result `cache = FALSE` always downloads the first variable-year in full
  and keeps no copy. For a one-variable, one-year call that is strictly worse than
  `cache = TRUE`. It also contradicts the roxygen at lines 47-48 ("only the 16 x 16-cell
  tiles holding the points are read") and the CLAUDE.md line ("a point read fetches one
  ~125 KB tile"). Fix: test land only where needed, e.g.
  `is_land <- function(cl) !is.na(terra::extract(template[[1]], cl)[, 1])`, applied to
  `cell` and then to each `nb`.

- **[severity: fragile]** scripts/pipeline_update_edh.R, `daily_step()` (STEP D) with the
  workflow's weekly dry run — STEP D runs on dry runs as well, through `--check` and the HEAD
  probes. When none of `target-3 .. target` is on S3, it sets `daily_failed` and `finish()`
  exits 1. Per the brief, the cube is not published yet. If this merges first, every Monday
  heartbeat goes red, and `climate-update.yml` files or comments on the
  `climate-update-failure` issue, until someone publishes it. The code does what CLAUDE.md
  says, so this is a deployment-order hazard rather than a logic error. Push at least the
  latest four complete years (or the whole cube) with `cd_s3_push("data/backfill/daily",
  prefix = "daily")` **before** merging. Otherwise, close the auto-filed issue once it is
  published (CLAUDE.md, "Close the auto-filed failure issue").

- **[severity: fragile]** scripts/pipeline_update_edh.R, `daily_published()` — The HEAD probe
  uses `curl::new_handle(nobody = TRUE)` with no `timeout`. The same file's STEP 0 comment
  explains why that matters: `new_handle()` bounds only the connect phase, so a server that
  completes the handshake and then stalls hangs until `timeout-minutes: 360` cancels the job.
  Because STEP D runs before STEP 1, a stall here also stops that month's annual update.
  Fix: add `timeout = 30L`, as STEP 0 does.

- **[severity: fragile]** R/cd_extract_daily.R:33 and :186-195 — The docs say `points` may
  be an `sfc`. An `sfc` carries no attributes, so `terra::vect(sfc)` has no `id` column and
  the call always aborts with "`points` has no `id` column; set `id`". No value of `id` can
  satisfy it. Either drop `sfc` from the `@param` or synthesise ids (`seq_along`) for
  attribute-less input.

## Checked and fine (no action)

- `finish()` covers every post-STEP-D `quit(status = 0)`. The remaining `quit(status = 1)`
  calls and any uncaught `stop()` exit non-zero on their own.
- `system2(stdout = TRUE)` status handling for `--check` is correct, including
  `latest_complete=0`, which fails the `[0-9]{4}` match and is reported as an error.
- `terra::extract(r, ucell)` returns no ID column, so positional `keep` is correct.
  `compareGeom(stopOnError = FALSE)` returns FALSE silently.
- `keep` cannot be zero-length, because every year in `years` overlaps `[from, to]`.
- `terra::distance(matrix, matrix, lonlat = TRUE)` gives a 1 x n matrix, and the tie-break
  by cell number works.
- The published COG declares no NoData, but its sea cells are float NaN, and terra reads
  NaN as NA. The land mask and the extract therefore behave the same as on the fixture.
- `rlang::arg_match(multiple = TRUE)` needs rlang >= 1.0.0 (2022), which is acceptable.
- The CLAUDE.md claims (`cd_stac_catalog()` is non-recursive, the four-year window,
  `--size-only`, local-day lag) match the code. The exception is the tile-read claim, which
  the second finding covers.
