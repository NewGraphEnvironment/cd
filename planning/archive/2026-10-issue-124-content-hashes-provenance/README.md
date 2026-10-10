## Outcome

Every COG cd publishes now carries a sha256 multihash and the run that made it (#124). `cd_cog_write(tags =)` and `write_cog(tags =)` write `CD_VERSION`/`CD_SHA`/`CD_RUN_TIME`/`CD_RUN_ID` into the file before the bytes are final; `cd_stac_catalog()` puts `file:checksum`/`file:size` (STAC file extension v2.1.0) and the provenance on every item; the daily cube gets `daily/manifest.json`, published by `daily_publish()` (`scripts/_publish.R`) as the live manifest with the run's entries laid over it. Before a publish the hashes are recomputed, untagged or stray files refused, and a live publish needs a SHA on origin/main; after the sync each object's ETag (single or multipart) is checked against its file and the file re-hashed, the catalog/manifest goes up last (the manifest conditionally, `--if-match`), and is read back byte for byte. Syncs dropped `--size-only`, which would have left a same-size rebuild behind under a checksum not its own; `tmax_tmin_republish.R` is retired for the same reason. What was learned: a checksum here identifies a build, not values (the run time is in the bytes); GDAL adds no churn of its own; and the review rounds kept finding one mechanism, a fact set in one place and relied on elsewhere by intent only (hash vs upload, R vs Python SHA, installed cd vs checkout, terra floor vs the calls used), which ended by enumerating its reach (findings.md). The live republish waits for the merge and release, from clean main: the local files built on the branch carry a branch SHA and `publish_sha_problems()` refuses them.

## Measurement

- Determinism: same input + same tags → identical bytes, on terra 1.9.50 / GDAL 3.13 (R) and rasterio (Python); one tag changed → bytes differ. A `read_cog_days()` → `write_cog()` rewrite reproduces the original bytes exactly.
- Tags cost +208 bytes per daily file. `--rewrite` of 228 daily files: 18 min; stage 3 dry run with tags and checksums: 8 min 43 s; `daily_publish.R --dry-run` over 228 files: 7.7 s.
- terra `metags()` returns a data.frame from 1.8-42, but its setter is a no-op there and `<- NULL` clears nothing until 1.8-54 (round 3, archived setter code run against current C++) — floor set to 1.8-54, after a first floor of 1.8-42 that would have let stale provenance pass.
- S3 ETags: monthly COGs single-part (MD5); daily files 2-part at 8 MiB, though this machine's config now says 128 MB — so the part size is inferred from the part count. Conditional `put-object` (`--if-match`/`--if-none-match`) live-tested on `_healthcheck/`.

## Evidence

`findings.md` (all measurements and the enumeration table); `review-plan.md`, `review-round*.md` (four reviews and their dispositions).

Closed by: PR for branch `124-content-hashes-and-run-provenance-on-eve` (Relates to #124; the issue closes after the post-merge republish)
