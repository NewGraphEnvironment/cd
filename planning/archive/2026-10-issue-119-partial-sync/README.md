## Outcome

`pipeline_update_edh.R` STEP 1 took the published years from `tmean_annual` alone. A STEP 5 `aws s3 sync` that died partway therefore left some COGs a year ahead of the rest, and the catalog stayed behind, because `cd_s3_push()` aborts first. After #89 that state was never silent, but it was never repaired. It either failed STEP 1 with a wrong repair hint, or fetched for hours and appended the year a second time.

STEP 1 now reads all 59 COGs' band names. `live_spans()` in `scripts/_lib.R` reconciles them, and the run targets the years every COG holds. STEP 4 appends to each COG only the years it lacks, after checking that a held year equals this run's computed layer, and byte-copies a COG with nothing left to append. A live run exits 1 until a post-publish re-read of the 59 shows them in step; the dry run warns. The workflow gained a `concurrency` group, so a run cannot read another's sync as a dead one.

The plan gate chose repair over refusal. The plan review, run concurrently, found no Blockers and produced 17 fixes; stage 3's own tmean-only read went to #121. Code-check round 2 found a defect inside round 1's fix. GDAL 3.8, which CI's terra links, caches a failed `/vsicurl/` open, so the new retry loop sent no request. The first remedy, uncaching up front, made the reads 12× slower (20 s to 236 s), because GDAL splits the setting on `:`. The shipped remedy uncaches only after a failure. Round 3 was Clean, ended by an enumeration of 19 network, cache and claim sites, each checked against GDAL 3.8.

## Measurement

The same 59 live COGs on every row:

| reads | time | why |
|---|---|---|
| default GDAL settings | 41 s | first live dry run |
| with `GDAL_DISABLE_READDIR_ON_OPEN=EMPTY_DIR` | 20-21 s | no 403'd sidecar probes |
| `CPL_VSIL_CURL_NON_CACHED` up front | 236 s | rejected |

- **The GDAL 3.8 failed-open cache was reproduced through sf (3.8.5):** the same URL kept failing after the server came up, and opened once the setting was on. Round 3 repeated the check with a 503 and with an object rewritten on the server.
- **Interop**, run on a local HTTP server against the shipped `append_to_cog()`:
  - Partial sync, 20 COGs ahead: 20 copied byte-identical, 39 appended, both guards report no problems.
  - The same state through `main`'s code is refused at STEP 5 with "do not share one span".
  - A held year that differs from this run's stops the run.
- **Fixture dry runs:** `partial` warns and exits 0; `beyond` (ahead past the local-time cap) exits 1 before any "nothing to do"; `missing` (one COG absent) gives a re-run hint and exits 1.
- **Tests and live run:**
  - Offline `test_lib.R`: 72/72, with every `live_spans()` branch shown to fire by mutation (9 mutations, all red).
  - `devtools::test()`: 491 pass.
  - Live dry run: exit 0.
- **Not run:** STEP 3-5 end to end. They cannot run until 2026 lands on EDH (~Feb 2027).

Durable facts about GDAL `/vsicurl/` went to [`research/gdal_vsicurl_reads.md`](../../../research/gdal_vsicurl_reads.md).

## Evidence

`planning/archive/2026-10-issue-119-partial-sync/` holds:

- `interop_119.R` and `fixture_dryrun_119.sh`, both run from the repo root;
- `findings.md`, with the mutation table, the probes and the remedies tried;
- `review-*.md`, the plan review and the three code-check rounds.

Closed by: PR for branch `119-step-1-reads-the-latest-year-from-tmean-`
