# Findings — STEP 1 reads the latest year from tmean_annual alone (#119)

## Issue context

Found by the plan review for #89.

## What changes if we do it

A STEP 5 sync that dies partway through gets repaired by the next monthly run
instead of being frozen in place.

## What happens if we never do it

`aws s3 sync` is not atomic. If a run uploads `tmean_annual.tif` with the new
year and then dies before the other 58 COGs (or before `catalog.json`), the next
run reads `latest_year` from `tmean_annual` alone (`scripts/pipeline_update_edh.R`
STEP 1), sees the new year, reports "Nothing to do", and never re-appends it to
the other COGs. The bucket then holds COGs ending in different years, with nothing
to show it.

The #89 guard does not cover this: it checks what one run is about to publish, not
what an earlier run left half-published.

## Suggested fix

In STEP 1, read the band names of every live COG (59 HEADs plus header reads over
`/vsicurl/`), not just `tmean_annual`, and take the target from the *minimum* latest
year. Where they disagree, either re-run the append for the lagging COGs or exit 1
with the list, which a human then resolves with stage 3.


## State after #89 (read 2026-10-07)

- `cd_s3_push()` aborts (`rlang::abort`) on a non-zero `aws s3 sync`, so after a
  partial sync `catalog.json` is never uploaded: the live catalog still spans the
  years every COG held before the run.
- S3 PUTs are per-object atomic, so a partial sync leaves whole COGs, each either
  at the old span or the new one; no truncated objects.
- STEP 1 already checks the live catalog's per-item start/end against
  `tmean_annual`'s years (`catalog_problems()`), so the case where `tmean_annual`
  got N fails fast — but with a hint (rebuild the catalog from live COGs) that
  would produce a mixed catalog.
- The case where `tmean_annual` did not get N passes STEP 1 and fails only at
  STEP 5 after the full fetch: `append_to_cog()` appends N again to the COGs that
  hold it, and `publish_problems()` sees spans that differ / are not contiguous.

## live_spans() mutation table (2026-10-07)

Each branch broken in a scratch copy of `scripts/`; `Rscript scripts/test_lib.R`
must exit non-zero. Control (unmutated copy) exits 0, 67/67.

| mutation | exit | FAIL lines |
|---|---|---|
| M1 drop the `^[0-9]{4}$` band check | 1 | 0 (crash: `seq()` on NA) |
| M1b pattern accepts `2025.0` | 1 | 1 |
| M2 drop the contiguity check | 1 | 3 |
| M3 drop the start-year check | 1 | 1 |
| M4 floor = max end year | 1 | 3 |
| M5 drop the unreadable-COG check | 1 | 1 |
| M6 keep empty `ahead` entries | 1 | 4 |
| M7 no early return on problems | 1 | 3 |
| M8 drop the empty-input check | 1 | 0 (crash: `min()` of nothing) |

The first harness counted FAIL lines only and reported M1 as "0 failing" — a crash
prints none. Exit status is the signal; the FAIL count is detail.

## Live dry run, STEP 1 rewritten (2026-10-07)

`Rscript scripts/pipeline_update_edh.R --dry-run`, local, against the live bucket:
59 COG headers read over `/vsicurl/` in **41 s** (08:39:18-08:40:00 by the log,
~0.7 s each), all agreeing on 1950-2025, nothing ahead; catalog check passed; exit 0
("No year complete in local time beyond 2025 yet"). Before this change STEP 1 read
one COG. The cost is accepted: ~40 s a run against a weekly two-minute dry run.

## Interop: a partial sync, repaired (2026-10-07)

`planning/active/interop_119.R` (run from the repo root). 59 tiny COGs spanning
1950-1955, 20 of them also holding 1956 and `tmean_annual` not, served over a local
`python3 -m http.server` and read through `/vsicurl/` as STEP 1 and STEP 4 read S3.
`append_to_cog()` is lifted from the pipeline script by `parse()`, so the run
exercises the shipped code, not a copy.

| `append_to_cog()` from | STEP 1 | "already holds" skips | `publish_problems()` | catalog |
|---|---|---|---|---|
| this branch | common 1950-1955, 20 ahead | 20 | none | 59 items, 1950-1956, `catalog_problems()` none |
| `main` (control) | — | 0 | "do not share one span of years" | refused |

The control is the issue's second shape reproduced: the year appended twice to the
COGs that held it, refused at STEP 5 after the fetch.

## Reviews and what they changed (2026-10-07)

- **Plan review** (`review-plan.md`, triaged there): no Blockers. Folded in G1 (read
  timeouts and retries), G2 (re-read the COGs after publishing, not just the catalog),
  G3 (stop when an ahead year was not written), G5 (repair-hint caveat), O1 (move the
  unfetched check before the empty-candidates exit), A1 (a held year must equal this
  run's), A2 (byte-copy an unchanged COG), A3 (STEP 4 reads the same URL as STEP 1),
  A4, S1 (workflow `concurrency`), AC2, AC3 and the docs. G4 (stage 3 reads
  `tmean_annual` alone) went to [cd#121](https://github.com/NewGraphEnvironment/cd/issues/121).
  AC1 was partly wrong: the interop already lifts the shipped `append_to_cog()` by
  `parse()`.
- **code-check round 1** (`review-round1.md`): one finding, rated fragile, the same as G1.
  Nothing was published wrongly; a transient 503 on any of the 59 reads gave a red
  run and a stage-3 hint.

## `CPL_VSIL_CURL_NON_CACHED` works with a URL containing a colon (2026-10-07)

GDAL documents the value as colon-separated, and the base is `https://...`. Probed
against a local `http.server`: read a COG, overwrite it with 2 more bands, re-read.
Without the setting the re-read returned the stale last band (1955). With
`/vsicurl/http://127.0.0.1:<port>` set, it returned 1957 on both files. So G2's
post-publish re-read needs it, and it works. (#37's republish used it, but there a
stale cache could only fail loud, so that pass did not show it.)

## STEP 1 read time with `GDAL_DISABLE_READDIR_ON_OPEN=EMPTY_DIR`

Live dry run, the same 59 COGs: **20 s**, down from 41 s. The sidecar probes were
half the cost.

## Fixture dry runs (`fixture_dryrun_119.sh`, review AC3)

A copy of the script with `catalog_url` and `cog_base` pointed at a local
`http.server`. STEP 0, STEP D and the tmax/tmin check run against the real bucket.

| state | outcome |
|---|---|
| `partial`: common 1950-2024, 20 COGs also hold 2025 | WARNING naming them; target 2025; dry-run note; **exit 0** |
| `beyond`: common 1950-2025, 20 also hold 2026 (past the local-time cap) | "cannot fetch 2026" before any "nothing to do"; **exit 1** |
| `missing`: `rh_fall.tif` absent | "could not read 1 live COG(s)" + re-run hint, not stage 3; **exit 1** after 3 attempts (16 s) |

## Interop after the fixes

Same script, the updated `append_to_cog()`: 20 "Copied unchanged" (md5-identical to
the live object), 20 "matching this run's", 39 appends; `publish_problems()` and
`catalog_problems()` none; a held 1956 that differs from this run's stops the run.
The `main` control above was run before `append_to_cog()`'s signature changed, so
the current harness no longer runs against `main`.

## code-check round 2: a defect inside round 1's fix (2026-10-07)

`review-round2.md`. **GDAL 3.8 caches a failed `/vsicurl/` open per process**, so
round 1's R retry loop sent no request on attempts 2 and 3. Reproduced here through
sf, which links 3.8.5 (terra links 3.13 on this machine, which is why the fixture
runs never showed it):

```
server down, a: FALSE
server up, a again (same URL): FALSE      <- cached failure
server up, b (fresh URL): TRUE
with NON_CACHED env, a again: TRUE
```

Three remedies, in order:

| remedy | result |
|---|---|
| `CPL_VSIL_CURL_NON_CACHED` set before STEP 1 | correct, but the 59 reads went from **20 s to 236 s**. GDAL splits the value on `:`, so `/vsicurl/https://...` uncaches every https read |
| a query string per retry (`?attempt=2`) to get a fresh cache key | S3 serves the same object (same ETag), but GDAL then tries the other drivers: 76 `.shx file is unreadable` warnings per read |
| **`NON_CACHED` switched on only after a read fails, and left on** (plus before STEP 5's read-back) | healthy run back to **21 s**; a failure makes the rest of the run uncached, which is slow and correct, and STEP 4 never meets the cached failure |

The 3.8 behaviour of the third remedy rests on the sf probe (the setting clears a
cached failure), not on an end-to-end terra run on 3.8.

Also from round 2: a pending run cancelled by the `concurrency` group runs no steps,
so it files no alarm (the comment said it did). And a timeout cancel does fire the
alarm, which is `failure() || cancelled()`.

## Mechanism and enumeration (round 3 prompt)

Round 1's finding and round 2's finding inside its fix share one assumption: how a
remote read behaves (caching, retry, timeout) was taken from this machine's GDAL
3.13, not CI's 3.8. Every network operation the branch adds or changes:

| operation | timeout | retry | cache on 3.8 |
|---|---|---|---|
| STEP 1 `read_live_years()` `rast()` | `GDAL_HTTP_TIMEOUT` 60 | GDAL 429/5xx ×3, then R ×3 | uncached after the first failure |
| STEP 4 `rast(cog_url)` + `values()` of a held band | 60 | GDAL 429/5xx ×3 | cached success from STEP 1, or uncached |
| STEP 4 `curl::curl_download()` byte copy | 600 s | R ×3 (added in round 3's prep) | curl, no GDAL cache; leaves no file on failure (probed: 403) |
| STEP 5 read-back `read_live_years()` | 60 | as STEP 1 | uncached (probed necessary) |

## code-check summary (2026-10-07)

| round | findings | fixed | accepted | inside a previous fix? |
|---|---|---|---|---|
| plan review | 21 (no Blockers) | 17 | AC4 noted; G4 to cd#121; AC1 partly wrong | — |
| 1 | 1 (fragile: reads unbounded, unreadable gets the stage-3 hint) | 1 | 0 | — |
| 2 | 2 fragile + 1 comment | 3 | 0 | **yes**: the retry retried nothing on GDAL 3.8 |
| 3 | Clean + 3 comment notes | 3 (comments) | 0 | no |

Ended by enumeration, not a quiet round: round 3 was asked for the mechanism (how
remote reads behave was assumed from the local GDAL 3.13, not CI's 3.8; GitHub's
scheduler was assumed, not checked) and listed every place it reaches (19 rows in
`review-round3.md`). Each row was checked against GDAL 3.8.4's source or a 3.8.5 probe,
and against GitHub's concurrency documentation. All 19 hold.

## Errors Encountered

| Error | Resolution |
|-------|------------|
| Retry loop retried nothing on GDAL 3.8 (cached failure) | `NON_CACHED` on after the first failure |
| `NON_CACHED` up front: 59 reads 20 s to 236 s | Only after a failure; GDAL splits the value on `:` |
| GDAL re-read after an upload returned the cached header | `CPL_VSIL_CURL_NON_CACHED` on `/vsicurl/<base>` (probed) |
| Mutation harness reported M1 as surviving | It crashed instead; count exit status, not FAIL lines |
| "start in different years" message listed the first 5 COGs, hiding the odd one | Name only COGs whose start differs from the majority |
