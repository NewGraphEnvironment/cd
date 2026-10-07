# Code-check round 1 — #119 (scripts/_lib.R, scripts/pipeline_update_edh.R, scripts/test_lib.R)

## Findings

- **[severity: fragile]** scripts/pipeline_update_edh.R:437-449 (with scripts/_lib.R:236-241) — an unreadable COG is a different state from a broken one, but both get the same verdict and the same fix. STEP 1 now makes 59 `/vsicurl/` reads with no retry. The `tryCatch(..., error = function(e) NULL)` turns any read error into `NULL`, including a transient one: a dropped connection, an S3 503/SlowDown, or a DNS blip on the runner. `live_spans()` then reports "could not read N live COG(s)", and the script prints `Repair: rebuild all 59 COGs with scripts/pipeline_stage3_edh.R.` and runs `finish(1L)`.
  - **Before:** one read of tmean_annual. A failure surfaced as an R error naming that href.
  - **Now:** the exposure is 59 times larger, and it runs on every weekly dry run as well as the monthly live run. One blip on any of the 59 turns the run red, files or comments on the `climate-update-failure` issue, and tells the operator to do a multi-hour stage 3 rebuild. Stage 3 needs the full local backfill. A re-run would have fixed it.
  - **CLAUDE.md conflicts:** the CI notes say one transient blip should not cost a red run plus an auto-filed issue (the reason the EDH probe retries). The checklist says the same twice: in "A guard that fails toward pass", treat unreadable as a third state, and on the abort side, retry in-process before an error reaches the exit code.
  - **No retry anywhere:** neither the script nor `.github/workflows/climate-update.yml` sets `GDAL_HTTP_MAX_RETRY` or `GDAL_HTTP_RETRY_DELAY`.
  - **Fix shape:** retry the per-COG read a couple of times. Report "could not read" with its own remedy (re-run, or check the object exists) rather than the stage 3 rebuild, which only fits the contiguity/start-year shapes.
  - **It fails safe:** nothing is published wrong. The cost is a false alarm and a misleading, heavy remedy.

## Checked and not flagged (for the record)

- **Double-append:** STEP 1 refuses a duplicated year as non-contiguous. `append_to_cog()` drops held years through `intersect(names(new_layers), names(existing_rast))`. Names are `as.character(yr)` against the band names, so both sides are "2026"-style strings.
- **Dropped year:**
  - `required_years` is the union of every live year and the new years.
  - Suppose one ahead year fails to fetch while a later one succeeds (fetch error, `next`). The COGs then disagree in span or have a gap, and `publish_problems()` refuses through "do not share one span" or "not contiguous".
  - The `unfetched` guard runs ahead of the dry-run exit.
- **Mixed set published:** STEP 5 still requires all 59 written this run. `catalog_problems()` on the built catalog checks the span against `required_years`, and the read-back is unchanged.
- **Green while broken:**
  - Every `finish()` after STEP 1 exits 1 on a live run while `partial_live` is set: the nothing-to-do paths, `latest_local` NA, and "no new complete years" all qualify.
  - Every exit that bypasses `finish()` is `quit(status = 1)` or an R error, so none is green.
  - `partial_live` is cleared only after the read-back matches.
  - The dry run exits 0, which is the accepted tradeoff.
- **STEP 1 catalog check in the partial state:** after a sync dies partway, the catalog spans `common` and passes. "All COGs synced, catalog cp failed" still lands in `catalog_problems()` with `partial_live` FALSE and the catalog-only hint, which is correct. The refusal can also fire with `partial_live` TRUE, when the catalog ends before `common`'s end. That takes two partial syncs in a row plus a further year appended in the second, which needs the repair to be delayed by about a year. It still fails toward refusal, so I did not flag it.
- **`--size-only` sync:**
  - Lagging COGs change size, so they upload.
  - An ahead COG rewritten unchanged has the same content as the remote, so skipping it or re-uploading it are both harmless.
- **vsicurl process cache:** nothing writes to S3 between the STEP 1 reads and the STEP 4 reads of the same URLs.
- **Type mixing:** `setdiff(unlist(spans$ahead), candidate_years)` compares integer with double, and `match` handles that. `seq()` over integer endpoints returns integer, so `identical()` in `live_spans()` holds. `vapply(years, min, integer(1))` on an empty list is safe, because problems return first.
- **Tests:** `scripts/test_lib.R` ran from a temp copy: 67/67 passed.
