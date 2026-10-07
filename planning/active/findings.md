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

## Errors Encountered

| Error | Resolution |
|-------|------------|
| Mutation harness reported M1 as surviving | It crashed instead; count exit status, not FAIL lines |
| "start in different years" message listed the first 5 COGs, hiding the odd one | Name only COGs whose start differs from the majority |
