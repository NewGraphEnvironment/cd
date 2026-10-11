## Outcome

`cd_catalog()` now returns `checksum`, `size`, `cd_version`, `cd_sha`, `run_time` and `run_url`, and `cd_extract()` / `cd_extract_daily()` return `checksum` and `cd_sha` on every row, so an analysis can cite the build it read. Two design turns came out of the work.

- **The key names.** At the plan gate the user asked whether cd's `cd:` fields should be registered with crate (crate#23). That rule sends a field with a standard STAC home to it, so the provenance moves to the STAC processing extension in a separate prerequisite issue, #128. That issue also republishes. This branch reads only the `processing:` keys and merges after #128. `cd:variable` / `cd:period` stay unregistered: cd is their only reader, and renaming them would break installed copies of `cd_catalog()`.
- **Where the checksum comes from.** The plan review found that `cd_cache_fetch()` serves a stale copy when revalidation is off or the HEAD fails. A checksum copied from the catalog or manifest could then name a build nobody read. So `cd_sha` is read from the file's own `CD_SHA` tag, and the checksum is kept only when the file's `CD_RUN_TIME` tag equals the entry's `processing:datetime` exactly.

The four code-check rounds then found one defect class, over and over: the prose (roxygen, CLAUDE.md, warning advice) stated the NA and warning contract from one scenario, a stale cache, instead of from the predicates' case table. Round 4 built the full table, and the loop ended when every statement matched it. Along the way it moved the daily manifest read through the cache, because a live GET broke `cd.cache_revalidate = FALSE`'s no-request contract.

## Measurement

- Full suite: 628 pass, 0 fail, live tests run. The 6 warnings are pre-existing, in `test-cd_plot_comparison.R`. One skip: the canary waits on #128.
- A live run caught a wrong warning contract the offline tests could not reach. The 60° N test (`expect_no_warning`) failed because today's manifest carries `file:checksum` without `processing:datetime`, so every live call warned. Since then an entry with no run time gives NA silently.
- Each guard was shown to fire by restoring its bug:
  - unverified checksum: 6 red in `cd_extract`, 2 in daily;
  - warn-on-unprovable condition: 1 red in each test file;
  - `$cd` partial match: 1 red;
  - manifest fetch bypassing the cache: 2 red;
  - unnamed `files` array: 1 red.
- Review spend: 1 plan review plus 4 code-check rounds, with 2, 3, 4 and 2 findings. Rounds 2-4 each found a defect inside the previous round's fix, and the loop ended by enumeration in round 4.

## Evidence

`planning/archive/2026-10-issue-126-build-provenance-in-consumers/review-*.md`

Closed by: PR #129 (merge `ea88ddb`), released as v0.6.5 after #128's republish
