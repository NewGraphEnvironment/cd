# Findings — Content hashes and run provenance on every published COG (catalog items and daily cube) (#124)

## Issue context

**If we do it:** every COG cd publishes carries a hash and the run that made it. A changed hash then means changed bytes, and a consumer such as wet can tell which build of the monthly layers or the daily cube an analysis read. **If we never do:** a republish like #123's replaces every published file in place, and nothing outside git history records what was there before or what replaced it.

## What

Follow NewGraphEnvironment/stac_airphoto_bc#30 and `stac_floodplains_bc` (`item_create.py` `file_meta()`, `item_validate.py` `check_checksums()` / `check_provenance()`), adapted to cd's two products:

- **`file:checksum` + `file:size` on every catalog item's `data` asset.** Use STAC file extension v2.1.0. The checksum is a sha256 **multihash** (`1220` + hex digest). `cd_stac_catalog()` computes them from the local COGs it lists.
- **The daily cube is not in `catalog.json`** (`cd_stac_catalog()` lists non-recursively). It needs its own manifest, e.g. `daily/manifest.json` with key, size and multihash per file, written by STEP D and by any local backfill push.
- **Run provenance written as GDAL tags before the COG write**, not with `r+` afterwards: cd version and SHA, run time. For the monthly COGs that is `cd_cog_write()`; for the daily cube it is `write_cog()` in `scripts/_lib.py`. Take the hash after tagging, because the tags are part of the bytes.
- **Re-hash on every publish.** STEP 4 appends a year to every monthly COG each year, and STEP D adds a daily year, so `pipeline_update_edh.R` and `pipeline_stage3_edh.R` both regenerate checksums. Before the sync, a validator in `scripts/_lib.R` (beside `publish_problems()` / `catalog_problems()`) recomputes them from the local files and refuses a mismatch.
- **Determinism check.** Write one unchanged input twice through `cd_cog_write()` and through `write_cog()`, and compare the bytes. If GDAL embeds anything that varies by run, a checksum churns on every rebuild and carries no information (NewGraphEnvironment/sred#39).

## Sequencing

#123 rebuilds both products on the 121 × 261 grid and publishes them unhashed. Hashing does not need EDH: it rewrites from the local files (`data/backfill/monthly` → stage 3, and the daily COGs from themselves) and republishes once.

Relates to #123


## Plan-mode exploration: what exploration settled

- **terra writes `metags()` into the COG bytes** (`<GDALMetadata>` in the TIFF, no `.aux.json`), and two `writeRaster(filetype = "COG")` writes of the same raster + same tags are **byte-identical** (terra 1.9.50 / GDAL 3.13, probed today). So determinism holds on the R side once the tags are pinned; the run-time tag is the only intended variation.
- Tag keys must not contain `:` (GDAL reads it as a namespace — floodplains `02_raster_tag.py`). Use `CD_VERSION`, `CD_SHA`, `CD_RUN_TIME`, `CD_RUN_ID`.
- **A hole the issue does not name:** `cd_s3_push()` syncs `--size-only`. A rebuild whose size does not change (a re-tag, a stage-3 rebuild of the same years) is skipped, so the catalog would publish a checksum the live object does not have. Hashing is only truthful if the publishes drop `--size-only` (sync then uploads anything newer by mtime).
- **STEP D's runner holds only the new year's daily files**, so the daily manifest cannot be built from the local dir alone: it must be the live manifest merged with this run's entries. The first manifest has to come from a full local push.
- STEP 4 builds `c(existing /vsicurl/ COG, new)`: the old COG's tags ride along, so the writer must **replace** tags, not merge them.
- `tools::sha256sum()` is R ≥ 4.5 only (DESCRIPTION says ≥ 4.1). Use `openssl::sha256(file(path))` (streams; add `openssl` to Imports) rather than raising the R floor.
- STEP 4's "copied unchanged" COGs keep the provenance of the run that made their bytes — correct, and the validator accepts it as long as all four tags are present.

## Decisions taken at the plan gate
1. Provenance also goes into each catalog item's properties and manifest entry, read from the file's tags — so a consumer sees the build without opening the COG.
2. `openssl` in Imports rather than `R (>= 4.5)`.
3. The daily manifest lives at `s3://stac-era5-land/daily/manifest.json`, keyed by file name.

## terra metags semantics (measured 2026-10-09, terra 1.9.50 / GDAL 3.13)

- `metags(x) <- c(...)` MERGES with existing tags and copies (the caller's raster is unchanged).
- `metags(x) <- NULL` clears, but ERRORS on a raster with no tags (`value[, 3] <- ""`: incorrect number of subscripts).
- An untagged raster's `metags()` is a zero-row frame whose columns are not character, so `startsWith()` on it errors.
- `c(a, b)` keeps `a`'s tags, so STEP 4's `c(existing /vsicurl/ COG, new)` carries the old run's provenance unless stripped.
- Dataset tags land in the TIFF's `<GDALMetadata>`; no `.aux.json`. Two COG writes of one raster with the same tags are byte-identical; changing one tag changes the bytes.
- Published COGs today carry only `AREA_OR_POINT=Area`; the monthly inputs' `units=degC` does not survive `cd_aggregate()`.

## rasterio COG copy (measured 2026-10-09, uv env, scripts/test_lib.py)

- Dataset tags set with `update_tags()` on the staging GeoTIFF survive `rasterio.shutil.copy(driver="COG")`.
- Two `write_cog()` calls on one array with the same tags, 1.1 s apart, give identical bytes.
- `read_cog_days()` -> `write_cog()` with the same tags reproduces the original bytes exactly, once `attrs = {"units": "degC"}` is restored (read_cog_days clears attrs). So `--rewrite` changes nothing but the tags.
- Mutation check: with `update_tags` removed, the tag case goes red.

## S3 ETags (measured 2026-10-09)

- `tmean_annual.tif` (5,608,749 B): ETag `47a67dfd…` = local MD5, single part.
- `daily/tmax_daily_2000.tif` (9,263,371 B): ETag `5701ffe3…-2`, multipart at 8 MiB, matches the local file. This machine's `~/.aws/config` now says `multipart_chunksize = 128MB`, so the part size is not fixed: `s3_etag_matches()` tries every common size giving the ETag's part count.
- `openssl::md5()` / `sha256()` results keep a `hash` class through `as.character()`, so `identical()` against a plain string is FALSE. `as.vector()` or `paste0()` strips it.

## `--rewrite` on real data (2026-10-09)

Copy of 2001 (3 files): 7.0 s, each file +208 bytes (the four tags), values / band names / layout unchanged, no stage directory left. 76 years ≈ 9 min.

## Errors Encountered

| Error | Resolution |
|-------|------------|

## Real-data dry run, stage 3 (2026-10-09)

`pipeline_stage3_edh.R --dry-run` from a frozen copy, branch cd installed: 8 min 43 s; 59 COGs tagged, 59/59 catalog items carry a valid multihash and one run time; every validator passed; `aws --dryrun` lists all 59 COGs then catalog.json (no `--size-only`).

## S3 conditional writes (2026-10-09, aws-cli 2.34.34)

`s3_put_if()` against `_healthcheck/`: `--if-none-match '*'` writes when absent and is refused (PreconditionFailed, exit 254) when present; `--if-match` with a stale ETag is refused, with the current one writes. Test key deleted.
