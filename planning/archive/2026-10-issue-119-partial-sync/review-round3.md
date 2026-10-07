# Code-check round 3: #119 (scripts/_lib.R, scripts/pipeline_update_edh.R, scripts/test_lib.R, climate-update.yml)

Verdict: **Clean.** I found no bug, security issue or data-loss path. The mechanism and every place it reaches are below, each checked against CI's GDAL 3.8 and against GitHub Actions. Three comments describe external behaviour inexactly, but none of them changes what the code does; they are listed at the end.

## Mechanism

The shared assumption is that **one R call is one request, made against the object as it is now, and that GDAL behaves on CI the way it behaves here.** Neither half holds:

- **GDAL keeps per-process state.** It caches file properties and byte regions for each `/vsicurl/` URL, failures included. Config options are global and have their own parsing; `CPL_VSIL_CURL_NON_CACHED` splits its value on `:`.
- **Network behaviour depends on the GDAL version.** It was probed on terra's GDAL 3.13 and shipped to CI's 3.8.4.

All three earlier defects come from this:

| earlier defect | what was assumed |
|---|---|
| no retry | the read is a single, reliable call |
| a retry that retried nothing | `rast()` sends a request |
| 236 s uncached reads | the config value is a prefix |

The concurrency comment is the same error aimed at GitHub instead of GDAL: a claim about an external scheduler's behaviour, written from belief rather than checked.

What makes the current remedy work on 3.8 is not what its comment says. I read `port/cpl_vsil_curl.cpp` at v3.8.4.

- **What NON_CACHED does on 3.8.** It does not bypass the cache:
  - The `VSICurlHandle` constructor still loads the cached FileProp.
  - `Read()` still consults the region cache.
  - `!m_bCached` only makes the handle's destructor call `InvalidateCachedData(url)`, which clears the props and every cached region for that URL.
- **Why the remedy works anyway.** It works because of an internal detail: `GDALOpenInfo` (gcore/gdalopeninfo.cpp, v3.8.4, L238-258) calls `VSIStatExL()` on any `/vsicurl/` path *before* `VSIFOpenExL()`.
  1. The stat's handle sees the stale or failed entry and is deleted, which invalidates it.
  2. The open that follows therefore goes to the network.
- **Status of that detail.** It is the same in 3.9, 3.10 and 3.11, and under it both uses behave as intended (probes below). It is still an implementation detail, not a documented contract.

## Probes on GDAL 3.8.5 (through sf, which links it here)

Scripts are in the scratchpad, `r3/`.

| probe | result |
|---|---|
| `retry38.R`: server answers 503 to the first 4 requests; read, then retry as `read_live_years()` does | **Without** NON_CACHED, attempts 2 and 3 fail with no request (server log: 4 HEADs, all from attempt 1). **With** NON_CACHED set after attempt 1, attempt 2 succeeds (HEAD 5, GET 6-7). The STEP 1 retry holds on 3.8. |
| `rb38.R`: read 3 COGs (1950-1955), rewrite them server-side as 1950-1956, re-read | Cached re-read returns **1955** (stale). With NON_CACHED set, the first read of each returns **1956**. The STEP 5 read-back holds on 3.8 and does not compare against what STEP 1 cached. |
| `scripts/test_lib.R` from a temp copy | 72/72 passed, exit 0 |
| `parse()` of both changed R scripts | OK |

## Enumeration (table)

Every network read, remote call, cache interaction, retry, timeout and external-behaviour claim in the changed code. Line numbers are from the current working tree.

| # | where | what | GDAL 3.8 (CI) | GitHub Actions | holds? |
|---|---|---|---|---|---|
| 1 | pipeline L442 `GDAL_HTTP_TIMEOUT=60` | per-request total timeout (CURLOPT_TIMEOUT through `CPLHTTPSetOptions`); process-wide, so it also covers STEP 4 and STEP 5 reads | Honoured. 3.8 also *retries* "Operation timed out", so a stalled request costs up to 4×60 s plus backoff per attempt, about 13 min per COG over 3 R attempts. A total S3 stall across all 59 would outlast `timeout-minutes: 360`. | The job is cancelled and the alarm fires (`cancelled()`). STEP 4 range reads are at most 2 MB (128 × 16 KB), far inside 60 s on a hosted runner. | yes: bounds each request, not the whole step; fails red |
| 2 | L443-444 `GDAL_HTTP_MAX_RETRY=3`, `RETRY_DELAY=2` | GDAL's in-process retry | 3.8 retries 429, 500, 502-504, a 400 carrying RequestTimeout, and curl errors "Connection timed out", "Operation timed out" and "Connection was reset". The retry is applied to the vsicurl HEAD (probe: 4 HEADs for 1 + 3). | n/a | yes (the comment's list is inexact, see note 2) |
| 3 | L445 `GDAL_DISABLE_READDIR_ON_OPEN=EMPTY_DIR` | skips the listing on open and makes the sibling list empty; process-wide, so it also hits local reads (monthly/annual TIFs, `rast(cog_path)`, `cd_stac_catalog()`) | Same option in 3.8 (`Open()`/`Stat()` both test `EQUAL(..., "EMPTY_DIR")`). Locally it would hide `.aux.xml` sidecars, but no `.aux.xml` or `.aux.json` exists under `data/`. Band names are internal (GDAL_METADATA). `cd_s3_push` excludes `*.aux.json`. | runner starts empty | yes |
| 4 | L453-455 `uncache()`: `CPL_VSIL_CURL_NON_CACHED=/vsicurl/https://...` | split on `:` gives the prefix `/vsicurl/https`, which covers every https vsicurl read for the rest of the process | Invalidate-on-close plus `GDALOpenInfo`'s stat-before-open, as described under Mechanism. Probed: recovers a cached 5xx failure and a stale header. | n/a | yes (the comment's word "bypasses" is inexact, see note 1) |
| 5 | L458-469 `read_live_years()`: 3 attempts, `uncache()` after each failure, sleeps of 5 s and 10 s | R-level retry over GDAL's; NULL means unreadable, which takes the re-run hint, not stage 3 | Probed (`retry38.R`): attempt 2 sends requests and succeeds. Round 2 showed the same for connection-refused (`sf38b.R`). A GDAL retry emits a CE_Warning, which terra surfaces as an R warning; the call is wrapped in `tryCatch(error=)` only, so the value is kept. | n/a | yes |
| 6 | L472 STEP 1, first remote GDAL read in the process | nothing earlier populates the vsicurl cache (STEP D uses curl HEADs and local files) | n/a | n/a | yes |
| 7 | L732-737 STEP 4 `rast(/vsicurl/cog_url)`, `values(existing_rast[[y]])`, full read in `cd_cog_write` | read hours after STEP 1, from STEP 1's cached props and header regions unless `uncache()` fired | A cached header is correct only if the object has not changed since STEP 1. The workflow `concurrency` group rules out another run of this workflow. A human running stage 3 or `tmax_tmin_republish.R` in that window is not covered (out of scope, and nothing claims otherwise). The extra values read for a held year fails toward `stop()`. | the concurrency group serializes runs | yes |
| 8 | L766-778 byte copy with `curl_download(timeout = 600)`, 3 attempts | not GDAL. curl uses FAILONERROR, so 4xx/5xx raise (round 2 probed curl 8.0.0). `on.exit(unlink(tmp))` removes `*.curltmp` on failure (read in curl 8.0.0's body), so no stray file reaches the sync. `names(rast(cog_path))` is checked against STEP 1's names. | n/a | a fresh runner installs current curl, same behaviour | yes |
| 9 | L762 comment: the copy has the same size, so `--size-only` skips it | byte-identical to the live object, so equal size | n/a | n/a | yes |
| 10 | L913-933 catalog cp and `read_json(catalog_url)` read-back (unchanged) | R url connection, not GDAL. S3 has had strong read-after-write consistency since 2020, and nothing fronts the bucket with a CDN. | n/a | n/a | yes |
| 11 | L940-955 STEP 5 COG read-back: `uncache()`, then `read_live_years()` | must see the post-sync objects, not STEP 1's or STEP 4's cache | Probed (`rb38.R`): fresh on the first read. Its retries also work, since NON_CACHED is already set. | n/a | yes |
| 12 | L446-448 comment: 3.8 "answers a URL whose first open failed with that failure again, sending no request" | `Exists()` returns the cached `EXIST_NO` without fetching | matches the source and the probe | n/a | yes |
| 13 | L449-451 comment: "GDAL splits its value on ':'" and "disables caching for every https read" | `CSLTokenizeString2(..., ":")` with a STARTS_WITH match | matches the v3.8.4 source | n/a | yes |
| 14 | L936-939 comment: "uncached, or GDAL answers with the headers STEP 1 cached (probed)" | the original probe ran on 3.13 (`nc_probe.R`, terra) | now probed on 3.8.5: the cached re-read is stale and the NON_CACHED re-read is fresh | n/a | yes |
| 15 | L437-441 comment: "GDAL puts no total timeout on a /vsicurl/ read by default" | no default for `GDAL_HTTP_TIMEOUT` in 3.8 `CPLHTTPSetOptions` | true | n/a | yes |
| 16 | L440-441 comment: EMPTY_DIR "stops the per-file sidecar probes" | `bSkipReadDir` short-circuits the listing, and the empty sibling list stops sidecar opens | true | n/a | yes |
| 17 | yml L18-25 `concurrency: group climate-update, cancel-in-progress: false` | workflow-level and repo-wide, so `workflow_dispatch` on any ref joins it. The pkgdown group has a different name. | n/a | GitHub allows one in-progress and one pending run per group, and a newly queued run cancels the pending one. Pending time does not count against `timeout-minutes`. | yes |
| 18 | yml L18-22 comment: a Monday 1st fires both crons at 06:00 and one waits | two schedule entries produce two runs, each with its own `github.event.schedule` | n/a | yes. Cron start times can drift under load, which changes nothing here. | yes |
| 19 | yml L125-129 comment: a cancelled pending run has no step run and files nothing; the next month's cron picks it up | a pending run never starts its job, so the alarm step (in the same job) never runs. Publication is per year, so the next live cron retries the same target. | n/a | matches GitHub's documented behaviour | yes |

## Findings

No bug, security issue or data-loss path.

### Notes: comment accuracy only, no behavioural effect (not findings)

1. **pipeline L449, "CPL_VSIL_CURL_NON_CACHED bypasses the cache".** On 3.8 (and 3.9-3.11) it does not bypass anything; it invalidates on handle close.
   - It is effective only because `GDALOpenInfo` stats a `/vsicurl/` path before opening it, and the stat's close clears the entry.
   - It works, and both uses were probed on 3.8.5, but it depends on that internal order.
   - If someone later reads remote bytes through `VSIFOpenL` without a preceding stat (for example `sf::gdal_utils` on an already-open handle, or a reused dataset object), the first read would still be stale.
   - One sentence naming the real mechanism would stop that misuse.
2. **pipeline L457, "GDAL's retry covers 429 and 5xx; this one covers a dropped connection".**
   - 3.8 also retries timeouts and "Connection was reset", which is Windows/schannel wording.
   - It does not retry 501, 505 or above, or Linux libcurl's "Recv failure: Connection reset by peer".
   - The R loop covers the gaps for STEP 1 and STEP 5. STEP 4's reads have only GDAL's retry, which is unchanged from main.
3. **pipeline L437-441, "bound them".** The bound is per request, not per step.
   - With 3.8 retrying timeouts, a persistent stall costs about 13 min per COG.
   - Across 59 COGs that exceeds the 6 h job limit.
   - It still ends cancelled, with the alarm, so nothing hangs silently.
