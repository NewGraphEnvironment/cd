# Findings — STEP 5 can publish a catalog listing only the variables that run rewrote (#89)

## Issue context

Found by an independent review of `v0.4.0..v0.4.2`. **The most serious of the
three filed** — it is a silent-success-on-partial-work path that ends with the
published catalog losing variables.

## What changes if we do it

A monthly run stops being able to overwrite the bucket-root `catalog.json` with a
catalog listing only the subset of variables it happened to rewrite.

## What happens if we never do it

One skipped variable in one monthly run silently removes it from the catalog for
every consumer, and the run reports `=== UPDATE COMPLETE ===` and exits 0.

## The mechanism

`cog_dir` is `data/update/cogs` — a working directory populated only by
`append_to_cog()` for variables that got new layers this run.
`cd_stac_catalog()` (`R/cd_stac_catalog.R:37`) builds the catalog purely from
`list.files(cog_dir, pattern = "\\.tif$")`, and STEP 5 pushes it to the bucket
root.

There are at least nine paths that leave a variable absent from `cog_dir`:

- `scripts/pipeline_update_edh.R:368` — `new_layers` empty
- lines 315, 324, 399, 422 — variable/period not present in the existing catalog
- lines 404, 427 — expected monthly/annual TIF missing on disk
- lines 406, 429 — `nlyr()` not 12 (monthly) or 1 (annual)

`cd_s3_push()` has no `--delete`, so the orphaned `.tif` objects survive in the
bucket; only the catalog entry pointing at them is lost. That is arguably worse
than deletion, because the data is present and unreachable.

## Why it has not bitten yet

It needs a run that successfully appends a year while skipping at least one
variable. The catalog has not advanced since 2025, and 2026 will not complete on
the hourly store until roughly March 2027 — so there is time, but the first real
run is exactly when it would fire.

## Suggested fix

Build the catalog from the full published set, not from the run's scratch
directory: enumerate the bucket (or merge the new items into the existing
catalog read in STEP 1) rather than from `cog_dir`. Whichever way, assert the
item count before pushing — a catalog with fewer items than the one it replaces
should abort, not publish.

## Skip paths in STEP 4 (pipeline_update_edh.R at 1af5db1)

Every one leaves a COG out of `cog_dir`, so out of the catalog STEP 5 builds:

| line | path | logged? |
|---|---|---|
| 565 | `append_to_cog()` with empty `new_layers` | no |
| 595 | monthly var/period not in live catalog | yes |
| 601 | monthly TIF for a new year missing | no |
| 603 | monthly TIF not 12 bands | no |
| 605 | period absent from `cd_aggregate()` output | no |
| 618 | annual-derived var not in live catalog | yes |
| 624 | annual TIF missing | no |
| 626 | annual TIF not 1 band | no |

601/603/624/626 also have a quieter failure: with two new years, one missing file
gives that COG one year fewer than the rest, so it is *written* but short. The span
check catches that; a written-set check alone would not.

## Strict over merge

Chosen at the plan gate. Merging new items into the live catalog keeps every variable
listed, but a skipped variable then lags the others by a year with nothing to show it,
and STEP 1 reads `latest_year` from `tmean_annual` alone, so no later run retries it.

## DJF carries the same band names as annual

`cd_aggregate()` works on one year's 12 bands, so DJF is Jan+Feb+Dec of the same
calendar year and its band is named for that year. One span across all 59 COGs is
therefore the right invariant for both pipelines.

## Mutation table: publish_problems() and catalog_problems() (scripts/_lib.R)

Each branch neutered in a copy (`if (FALSE)`), then `Rscript scripts/test_lib.R` run there:

| branch neutered | tests red |
|---|---|
| publish: expected COG not written | 2 (58-of-59, nothing written) |
| publish: unexpected COG written | 1 |
| publish: stale .tif on disk | 1 |
| publish: expected COG absent from disk (code-check round 1) | 3 |
| publish: live key outside expected | 1 |
| publish: spans differ | 1 |
| publish: not contiguous | 3 (gap, descending, non-year band) |
| publish: required year missing | 2 (start after live, missing appended year) |
| catalog: duplicate item | 1 |
| catalog: expected item absent | 1 |
| catalog: item outside expected | 1 |
| catalog: years misaligned | 1 |
| catalog: item does not span the years | 2 (stale end year, missing start) |
| `anyNA()` / `is.na()` dropped alone | the guard errors (`seq(NA, NA)`, `if (NA)`): exit 1, no FAIL line |

The last row fails toward refusal: an error inside a guard stops the pipeline
before anything is published.

## The catalog would not have been uploaded (plan review G1)

`cd_s3_push()` syncs `--size-only`. A healthy update rewrites `catalog.json` with the
same 59 items in the same order, and the only change is `end_datetime`
`2025-12-31` -> `2026-12-31`, which is the same length. The sync would skip it, and the
live catalog would keep reporting 2025. Both pipelines now upload `catalog.json`
explicitly, after the COG sync, so a catalog never points at COGs that are not
up yet.
