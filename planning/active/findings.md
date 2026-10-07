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
