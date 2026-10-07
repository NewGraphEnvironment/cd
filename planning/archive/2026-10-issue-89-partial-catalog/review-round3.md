# Review round 3 (#89)

Reviewer: subagent, 2026-10-07. Diff: branch vs main (`diff_r3.patch`). Ran `Rscript scripts/test_lib.R`
(53/53 pass). Read the live catalog over https: 59 items, all with years 1950-2025. Probed terra
1.9.50 in a scratch dir. Nothing in the repo was modified and nothing was written to S3.

## Mechanism

Both earlier defects come from one mistake: the guard checked the step **before** publication when
it should have checked the artifact that publication produces.

- Round 1: `written` records that the run *intended* a file. What gets catalogued and pushed is the
  directory listing. The guard checked the record, not the directory (`absent` fixes it).
- Plan review: a sync exiting 0 was read as "catalog.json reached S3". `--size-only` uses byte size
  as its test for "changed", and a healthy update keeps the size the same. The guard trusted the
  wrapper's exit code over the bytes in the bucket (fixed by an explicit `cp` plus a readback).

In both cases a name, a record or an exit status was standing in for the bytes a consumer reads. The
right question for each remaining guard is the same: what does it read, and would that differ from
what is live on S3 or what a consumer gets?

## Remaining proxies in the diff

| # | Guard (where) | Reads | Stands in for | Verdict |
|---|---|---|---|---|
| 1 | `publish_problems` `on_disk` (both pipelines) | `list.files(cog_dir, "\\.tif$")` | what `cd_stac_catalog()` lists | **The property itself**: the same call with the same pattern that `cd_stac_catalog()` makes. The sync also carries non-`.tif` files (`*.aux.xml`), but those cannot enter the catalog. |
| 2 | `written` band names (update STEP 4, stage 3) | `names()` of the in-memory raster, not the file | the band names in the file on S3 | **Sound.** The built-catalog check then reads the files themselves, through `cd_stac_item` → `rast()`. Probed: the names live in the TIFF and survive without the `.aux.json` sidecar that `cd_s3_push` excludes (terra 1.9.50; the sidecar holds only time and units). |
| 3 | Built-catalog `catalog_problems` | the JSON `cd_stac_catalog` wrote, min/max year per item | the catalog's content | **Sound.** Its reference (`expected_cogs`, `required_years`) does not come from `cd_stac_catalog`, so it is not reading its own output. It cannot see a gap or a duplicate inside a span, but `publish_problems` has already refused those. |
| 4 | Live readback `identical(live_after, built)` | keys, start and end from the live URL | "the catalog we built is the live one" | **Sound for its purpose.** It reads S3 directly, with no CDN, and S3 is read-after-write consistent. It compares a projection that leaves out hrefs, but the uploaded bytes are the same local file. It verifies the catalog only, never the COGs: see 5. |
| 5 | `cd_s3_push` exit 0 → "the COGs are up" (both pipelines) | sync exit status, `--size-only` | each rebuilt COG reached S3 | **Update path: sound.** An appended year adds one sample to every tile, one entry to BitsPerSample and SampleFormat in every IFD, and one band description, so the new file cannot plausibly have the old file's byte count. The only equal-size case is an S3 object that is *already* the appended version, left by an earlier partial run. That is #119, and the duplicate `2026` band then fails the contiguity check, so the run fails closed. **Stage 3: a pre-existing hole, not widened here.** A rebuild with the same years and changed values (a derivation fix) can in principle compress to the same size and be skipped. The new readback then reports success, which is still true of everything the catalog states, because years are all it records. This was recorded as out of scope in the #37 reviews, and it is why `tmax_tmin_republish.R` uses `cp` and checks ETags. |
| 6 | Ordering: COGs synced, then catalog uploaded | — | the live catalog never names a missing object | **Sound.** Every catalog key is required to be in `expected`. STEP 1 requires live == expected, so every href already exists on S3. Stage 3 can add keys, but the sync uploads a new key before the catalog names it. A failed sync aborts before the catalog upload. A consumer reading mid-sync can see mixed year spans across variables; that is transient and pre-existing. |
| 7 | STEP 1 `catalog_problems(live_keys, expected)` (update) | keys only, **no years** | "the live catalog is a state this run can extend" | **Hole: Finding 1.** |
| 8 | `required_years` / `live_years` | tmean_annual's live band names only | every live COG's years | **Sound for this diff.** A COG with more or fewer live years than tmean comes back from STEP 4 with a different span or a duplicate band, and the guard refuses. The repair side is #119. |
| 9 | Live state read in STEP 1, published in STEP 5 (hours later) | a snapshot | live state at push time | **A stand-in that assumes a single writer.** A local stage 3 or republish landing inside an update run's window would be overwritten by COGs built from the pre-republish S3 copies plus the new year. They are larger, so the sync uploads them, and nothing re-checks. Acceptable while CI is the only scheduled writer; noted only. |

## Findings

- **[severity: fragile]** `scripts/pipeline_update_edh.R:424` and `:731-736`. If `aws s3 cp` of
  catalog.json fails after a successful sync, the result stays green and stale for about a year.
  - What follows: the run exits 1 and tells the operator to "Re-upload data/update/catalog.json".
    On CI that file dies with the runner: the workflow's only artifact is `logs/update_*.log`.
  - The next monthly run reads `latest_year` from tmean_annual's band names, which now include the
    new year. It then exits 0 with "Already at or past current year" or "No year complete in local
    time". Every later run is green until the following year's STEP 5 rebuilds the catalog.
  - Throughout that time the live catalog's `end_datetime` is a year behind the COGs. No reader in
    `R/` uses `end_datetime` (`cd_catalog()` reads only variable, period and href), so the cd
    consumer chain is unaffected. External STAC clients filtering on datetime would see the year as
    missing.
  - Cause: STEP 1 takes the published state from the COGs (a proxy), not from the catalog, which is
    the artifact that went stale. The fix proposed in #119 (the minimum latest year across all 59
    COGs) does not catch this either, because all 59 COGs agree.
  - Cheapest guard: in STEP 1, read the live JSON with `catalog_item_years()` and pass `start`,
    `end` and `current_years` to the `catalog_problems()` call that already exists there. A catalog
    whose items do not span the tmean COG's years then exits 1 on every run until a human repairs
    it, instead of exiting 0.
  - Separately, the remedy text at `:734` should name a repair that works from CI, such as stage 3,
    or rebuilding catalog.json from the 59 live COGs.

No other real issues. Items 1-6 and 8 are sound stand-ins. Item 5's stage 3 case and item 9 are
pre-existing or assume a single writer; this diff does not widen either.
