# Plan review — #124 (Plan agent, returned 2026-10-09 after Phases 1-3 had landed)

Bottom line: no blocker on the normal path — nothing writes COG bytes after they are hashed. Holes: nothing checks the live objects are the hashed bytes; the daily manifest can go stale while CI stays green; the republish must not publish a branch or `-dirty` SHA.

| # | Cat | Finding | Disposition |
|---|-----|---------|-------------|
| G1 | Gap | No check after upload that live bytes match the checksum. Sync without `--size-only` still skips a same-size file whose local mtime is older than S3's. ETag = MD5 for single-part (all 59 monthly COGs < 8 MiB); daily files are multipart (> 8 MiB) — compute the multipart ETag offline. | Adopt: `s3_etag()` + per-object HEAD check in both pipelines and the daily publish |
| G2 | Gap | STEP D decides "published" by HEAD alone; a manifest that missed a year (cp failed after the sync) is never noticed or repaired. | Adopt: STEP D checks the live manifest covers every year it sees published, dry run included |
| G3 | Gap | Bootstrap/key set checked only against itself. | Adopt: after the sync, manifest key set must equal the live `daily/` listing — no CI detection needed |
| G4 | Gap | A stray non-.tif file in a publish dir reaches S3 with no entry. | Adopt: `stray_problems()` on both publish dirs |
| G5 | Gap | `tmax_tmin_republish.R` replaces 10 COGs without tags and leaves the catalog: would make the catalog lie. | Adopt: retire with a `stop()` naming stage 3 |
| G6 | Gap | `--rewrite` overwrites 228 files that EDH cannot reproduce (a3b5c24); byte identity shown only on synthetic data. | Adopt: read back and compare values after each write |
| G7 | Gap | Comments made false by dropping `--size-only`. | Adopt (list in review) |
| G8 | Gap | No test for `size_only`. | Already added (test-cd_s3_push.R) |
| G9 | Gap | `metags()` is NULL for a raster with no tags, so `provenance_problems()` calls it "could not be opened". | Adopt; probed: in-memory untagged raster → NULL |
| G10 | Gap | Sort manifest keys locale-independently. | Adopt: `sort(method = "radix")` |
| O1 | Ordering | Republish must be re-run from clean main after merge; live publish must refuse `-dirty`/`unknown`. | `sha_problems()` added; sequence goes in the PR body |
| O2 | Ordering | Version bump lands after merge, so a republish from the merge commit stamps 0.6.2. | Republish from the release commit; PR body |
| O3 | Ordering | Between merge and republish, a live run with a year to publish would refuse (first such run ~Feb 2027). | PR body states the deadline; STEP 1 warns when the live catalog has no checksums |
| O4 | Ordering | CD_RUN_TIME must be set before STEP D. | Already so (`run_start()` right after the mode log) |
| A1 | Assumption | `scripts/__pycache__/` is ignored only by this machine's global gitignore, so other checkouts stamp `-dirty`. | Adopt: add to repo `.gitignore` |
| A2 | Assumption | ETag = MD5 for single part on this bucket (SSE-S3). | Relied on, as `tmax_tmin_republish.R` did |
| A3 | Assumption | Local and CI manifest writes could race. | Not adopted; noted |
| A4 | Verified | metags merge/copy semantics; cd_cog_write keeps non-CD tags (stale GRIB_* on swe_max_annual ride along). | Leave GRIB tags; noted |
| S1 | Scope | `daily_publish()` (network) does not belong in `_lib.R`. | Adopt: `scripts/daily_publish.R`, sourced by the pipeline |
| S2 | Scope | Flip `size_only` default to FALSE. | Adopt |
| S3 | Scope | `research/` note unnecessary. | Adopt: dropped |
| S4 | Scope | `cd_catalog()` exposes no checksum/provenance; consumer caches re-download after republish. | Follow-up issue; PR notes the re-download |
| AC1 | Acceptance | The checksum identifies a build, not values. | Adopt in docs |
| AC2 | Acceptance | Compare catalog read-back as raw bytes. | Adopt |
| AC3 | Acceptance | PR "Relates to #124"; close after the republish. | Adopt |
| AC4 | Acceptance | Failing-on-purpose tests for G1-G4, O1. | Adopt |
