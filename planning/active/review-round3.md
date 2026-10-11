# Code-check round 3 (#126)

## Mechanism

The NA and warning contract is decided in code in three places: `build_checksum()`
(keep or NA), `build_stale()` (warn), and a second warning path in
`daily_manifest()` (manifest unreadable). Every prose restatement (roxygen x3,
internal comments, CLAUDE.md, the two warning `advice` strings) was written from
the one scenario the author had in mind, a **stale cached copy read against a
fresh catalog or manifest**, not derived from the predicates' case table. So each
restatement is right for that scenario and wrong for whichever cases sit outside
it: `cache = FALSE` (nothing is cached), the live index lagging its own files
(#119 partial sync, a `daily_publish()` that stops before the manifest upload), a
remote source with no manifest, and the manifest-read warning, which is not a
`build_stale()` case at all. R2's findings (CLAUDE.md "every NA warns"; advice
wrong for an out-of-date catalog) are this shape, and the R2 fix patched the
instance named (a stale `catalog` object) rather than the scenario assumption.
R1's findings are the sibling: the input's shape assumed to be the shape the
writer produces.

## Case table, from the code

cd_extract / cd_catalog (per file; ck = entry checksum, rt = entry run time, tag = file CD_RUN_TIME):

| ck | rt | tag | checksum | warns |
|---|---|---|---|---|
| y | y | equal | ck | no |
| y | y | different | NA | yes |
| y | y | missing | NA | yes |
| y | n | any | NA | no |
| n | any | any | NA | no |

cd_extract_daily adds: no local manifest -> NA, silent; remote manifest 404 /
timeout / offline / non-JSON -> NA, **warns**; local manifest unparseable or wrong
shape -> NA, warns; entry not listed -> NA, silent; entry not an object -> NA,
silent; then the table above per entry.

## Enumeration (each statement: location — claim — matches code? y/n)

- R/cd_catalog.R `@return` checksum/size/cd_version/cd_sha/run_time/run_url — sources named (`file:*`, `processing:*`, `processing-execution` link) — y
- R/cd_catalog.R "Each of the last six is NA where the catalog does not carry it" — y (malformed fields also NA via `catalog_field()` tryCatch)
- R/cd_catalog.R `@section Provenance` — checksum identifies a build, not values — y
- R/cd_catalog.R `build_tags()` comment — read from the file opened, NA where untagged — y
- R/cd_catalog.R `build_checksum()` comment — kept only when tag == entry run time, exact string, else NA — y
- R/cd_catalog.R `build_stale()` comment — entry states checksum and run time, tag differs or missing; no run time is NA without warning — y
- R/cd_catalog.R `build_warn()` text "Not the build ... (its run-time tag differs or is missing), so `checksum` is NA" — y
- R/cd_extract.R `@return checksum` — kept only when shown to be that build, else NA — y
- R/cd_extract.R `@return cd_sha` — from the file's tags, NA if untagged — y
- R/cd_extract.R Provenance "a stale cached copy or an out-of-date catalog gives NA and a warning" — y when the row has a checksum (no checksum: NA silently; not realistic post-#124)
- R/cd_extract.R Provenance "A catalog row with no run_time ... NA without a warning" — y
- R/cd_extract.R warning advice "If `catalog` was read before a republish, read it again ...; otherwise a cached copy is stale" — **n** for `cache = FALSE` (no cached copy) and for a live catalog behind its COGs (#119): neither remedy clears it
- R/cd_extract_daily.R `@return checksum` / `cd_sha` — y
- R/cd_extract_daily.R Provenance "kept only when ... matches the manifest's processing:datetime ... a stale cached copy gives NA and a warning" — y
- R/cd_extract_daily.R Provenance "An entry with no processing:datetime ... NA silently" — y
- R/cd_extract_daily.R Provenance "A `source` with no manifest (such as the bundled example) gives NA silently" — **n** for a remote source: a 404 goes through `daily_manifest_fetch()` -> NULL -> warning. True only for a local source
- R/cd_extract_daily.R Provenance "a remote manifest that cannot be read gives NA and a warning" — y (a local unparseable one also warns; omitted, not contradicted)
- R/cd_extract_daily.R `daily_manifest()` comment — no manifest NULL silently, unreadable warns — y (404 counts as unreadable)
- R/cd_extract_daily.R warning advice "A cached copy is the usual cause: ... refresh = TRUE" — **n** for `cache = FALSE`, and for a manifest behind its files (`daily_publish()` stopping between sync and manifest upload, which `_publish.R` names as a real state)
- CLAUDE.md "cd_catalog() carries checksum ... read from file:* and the STAC processing extension's keys" — y
- CLAUDE.md "cd_sha comes from the file actually read" — y
- CLAUDE.md "kept only when the file's CD_RUN_TIME tag equals the entry's processing:datetime as an exact string" — y
- CLAUDE.md "Otherwise NA, because cd_cache_fetch() serves a stale copy ..." — y as a reason (incomplete: also cache = FALSE vs a lagging index)
- CLAUDE.md "**Only** a provable mismatch warns (build_stale(): the entry states a run time and the file's tag differs or is missing)" — **n** twice: `daily_manifest()` warns on an unreadable/404/offline manifest, which is no mismatch; and `build_stale()` also requires the entry to state a checksum
- CLAUDE.md "a source with no manifest ... give NA silently, on purpose" — **n** for a remote source (warns)
- CLAUDE.md "a catalog from before #128 is exactly that shape" — y (a pre-#128 manifest on `cd:*` keys is also silent; tested)
- CLAUDE.md "The chain's later functions drop both columns" — y (`cd_anomaly()` selects `cols_out`; `cd_baseline()`/`cd_trend()`/`cd_compare()` summarise)
- tests: "cd_extract gives NA checksum for a file that is another build" (warns) — y; "for an untagged file" (warns) — y; "silently, for a catalog without run times" — y; "for a catalog without those columns" — y; "no manifest, or a file it does not list, gives NA without a warning" — y (local source only); "a manifest still on the cd: keys gives NA checksum, silently" — y; "a malformed manifest gives NA rather than stopping the read" (scalar top level warns, scalar entry silent) — y; "an unreadable remote manifest warns and gives NULL" — y; "an unparseable local manifest warns and gives NA" — y; live test "reports each file's manifest checksum" — y (skips until #128 keys are live)

man/*.Rd regenerated in a copy: no diff. Changed test files pass (`NOT_CRAN=true`).

## Findings

- **[fragile]** CLAUDE.md "Every extract row names the build" paragraph — "Only a provable mismatch warns (build_stale(): ...)" and "a source with no manifest ... NA silently" are both false for `cd_extract_daily()` on a remote source: `daily_manifest()` (R/cd_extract_daily.R ~238) warns on a 404, a timeout, offline, or non-JSON, and the default `source` is remote. The build_stale() gloss also omits its checksum condition. Same drift R2 fixed once; the paragraph should name the manifest-read warning as the second warning path.
- **[fragile]** R/cd_extract_daily.R Provenance roxygen — "A `source` with no manifest (such as the bundled example) gives `NA` silently" holds only for a local source; a remote source with no manifest warns.
- **[fragile]** R/cd_extract.R:87-91 and R/cd_extract_daily.R:202-205 — warning advice still assumes the stale-cache scenario. With `cache = FALSE` nothing is cached, yet the text names a stale cached copy and `cd_cache_fetch(refresh = TRUE)`. When the live index lags its files (#119 partial sync for the catalog; `daily_publish()` stopping after the sync and before the manifest upload, both named in the producer code), re-reading the catalog and refreshing the cache both leave the warning in place, so a user who follows the advice gets the same warning on every read. The NA is correct in all three cases; only the remedy is wrong.
- **[fragile]** R/cd_extract_daily.R:143 `daily_manifest(source)` / :250 `daily_manifest_fetch()` — the manifest is fetched over the network on every call, whatever `cache` and `cd.cache_revalidate` say. `?cd_cache_fetch` documents `options(cd.cache_revalidate = FALSE)` as a "fully-offline fast path" with no HTTP request. That path now makes one GET per call (up to the 60 s timeout when packets are dropped rather than refused) and warns "Could not read the daily cube's manifest" on every offline call. Before this branch an offline cached read made no request and raised nothing.
