# Code-check round 4 (enumeration) — #126, HEAD 98d70b1

Run in a copy (`scratchpad/cdcopy4`). `devtools::document()` there left `man/` unchanged, so the Rd is current.
test-cd_catalog / test-cd_extract / test-cd_extract_daily all pass (`NOT_CRAN=true`). The stale-manifest
scenario in Finding 1 was reproduced against a local `python3 -m http.server`, with `cd_cache_path` mocked to a
scratch directory (script: `scratchpad/scripts/sim.R`).

## Case table

### Where the bytes and the entry come from (requests)

| caller / mode | file read | entry (catalog row / manifest) | requests | can error? |
|---|---|---|---|---|
| cd_extract, local href | the file | the `catalog` the user passed | none | pre-existing only |
| cd_extract, cache=TRUE, revalidate on, online | fresh cached copy | user's catalog object (never cached) | HEAD per file, GET if changed | pre-existing only |
| cd_extract, cache=TRUE, revalidate off, cached | cached copy, possibly stale | user's catalog | none | no |
| cd_extract, cache=TRUE, revalidate off, not cached | fresh download | user's catalog | HEAD + GET | pre-existing only |
| cd_extract, cache=TRUE, offline, cached | cached copy + `inform` message | user's catalog | failed HEAD | no |
| cd_extract, cache=TRUE, offline, not cached | — | — | failed HEAD | **yes**, cd_cache_fetch stops (pre-existing) |
| cd_extract, cache=FALSE | /vsicurl/, opened twice (cd_crop, build_tags) | user's catalog | range GETs | pre-existing only |
| daily, local source, no manifest | file | NULL, silent | none | no |
| daily, local, manifest not parseable (`{ not json`) | file | NULL + **warn** | none | no |
| daily, local, malformed top (JSON scalar `3`, top array, no `files` object) | file | NULL + **warn** | none | no |
| daily, local, `files` is a JSON array | file | unnamed list, so every file is unlisted: NA, silent | none | no |
| daily, remote, cache=FALSE | /vsicurl/ | `daily_manifest_fetch` GET, 60 s timeout; 4xx, offline, unparseable or malformed gives NULL + **warn** | HEAD per file, GET manifest | no (manifest); file reads pre-existing |
| daily, remote, cache=TRUE, revalidate on, online | fresh cached | manifest revalidated: fresh | HEAD per file + manifest, GET if changed | no |
| daily, remote, cache=TRUE, revalidate on, manifest gone (403/404) but cached | fresh | **stale cached manifest + `inform`, no warning** | HEADs | no |
| daily, remote, cache=TRUE, revalidate on, manifest gone, no cached copy | fresh | NULL + **warn** | HEADs | no |
| daily, remote, cache=TRUE, revalidate off, manifest cached | cached **or fresh** (a year not cached before is downloaded now) | **cached manifest, possibly older than the file** | none for cached; HEAD+GET for uncached files | no |
| daily, remote, cache=TRUE, revalidate off, manifest not cached | as above | fresh download | HEAD + GET | no |
| daily, remote, cache=TRUE, offline, manifest cached | cached files | cached manifest + `inform` | failed HEADs | no (if files cached) |
| daily, remote, cache=TRUE, offline, manifest not cached | cached files | NULL + **warn** | failed HEADs | no (if files cached) |

### Entry state to result (same predicates for both callers; daily entries go through `scalar_chr` first)

| entry state | checksum | cd_sha | warning |
|---|---|---|---|
| catalog lacks `checksum`/`run_time` columns (cd_extract) | NA | file's tag | none |
| entry missing (daily: unlisted file, or manifest NULL) | NA | tag | none |
| entry not an object (scalar, array) | NA | tag | none |
| checksum absent / null / array | NA | tag | none, **even when the file differs** (build_stale needs a checksum) |
| run time absent / null / array | NA | tag | none |
| both present, file has no CD_RUN_TIME tag | NA | tag (usually NA too) | build_warn |
| both present, tag equal (exact string) | entry's checksum | tag | none |
| both present, tag differs (incl. a format difference) | NA | tag | build_warn |

cd_sha is always the file's own `CD_SHA` tag (domain ""), and NA when the tag is absent or empty. It never comes from the
entry.

Errors: no new error path. `daily_manifest()` wraps every read in tryCatch. `build_tags`, `build_checksum`,
`build_stale` and `build_warn` cannot raise on these inputs. `catalog_field` swallows lookup errors. The only errors are
the existing file-read ones.

## Statements (location — claim — y/n)

| location | claim | y/n |
|---|---|---|
| cd_catalog.Rd checksum…run_url items | sources: `file:checksum`, `file:size`, `processing:version`, `processing:software$cd`, `processing:datetime`, `processing-execution` link | y |
| cd_catalog.Rd | "Each of the last six is NA where the catalog does not carry it" | y (also NA for null, array, malformed) |
| cd_catalog.Rd Provenance | a checksum identifies a build, not values | y |
| cd_catalog.R catalog_field doc | a lookup error counts as absence | y |
| cd_catalog.R scalar_chr doc | NA for NULL, NA, an object or an array | y |
| cd_catalog.R build_tags doc | read from the file opened, so a stale copy reports its own build | y |
| cd_catalog.R build_checksum doc | kept only on an exact run-time match; writers must copy verbatim | y |
| cd_catalog.R build_checksum doc | "two builds never share one [run time]" | y (one run time per run, by run_start) |
| cd_catalog.R build_stale doc | stale only with a checksum and a run time, and a tag that differs or is missing | y |
| cd_extract.Rd checksum item | the catalog's checksum, kept only when the file is shown to be that build | y |
| cd_extract.Rd cd_sha item | from the file's own tags; NA when untagged | y |
| cd_extract.Rd Provenance | a stale cached copy or an out-of-date catalog gives NA and a warning | y where the row has a checksum; a row with a run_time and no checksum gives NA silently (borderline, not flagged) |
| cd_extract.Rd Provenance | a row with no run_time gives NA without a warning | y |
| cd_extract.R comment | the cache is resolved once, so the raster cropped and the tags read are the same file | y |
| cd_extract warning advice | catalog re-read; the cache sentence only when cache=TRUE; publish in progress | y (the "If a cached copy…" sentence also shows for local hrefs, but it is conditional, so true) |
| cd_extract_daily.Rd checksum/cd_sha items | as for cd_extract | y |
| cd_extract_daily.Rd Provenance | manifest read once per call | y |
| cd_extract_daily.Rd Provenance | through the cache when cache=TRUE, so it follows cd.cache_revalidate like the files | y as mechanism. But it does not say the cached manifest can be older than a file read in the same call (Finding 1) |
| cd_extract_daily.Rd Provenance | "a stale cached copy gives NA and a warning" | **n** when the stale copy is the manifest: unlisted gives silent NA, and a republished year gives a warning whose remedy does not clear it (Finding 1) |
| cd_extract_daily.Rd Provenance | no processing:datetime, or an unlisted file, gives NA silently | y |
| cd_extract_daily.Rd Provenance | a local source with no manifest gives NA silently | y |
| cd_extract_daily.Rd Provenance | "a manifest that cannot be read (a remote one missing or unreachable, or one that is not JSON) gives NA and a warning" | **n**: with cache=TRUE and a cached copy, a missing or unreachable remote manifest gives the cached copy with an `inform` and no warning; "not JSON" omits valid JSON of the wrong shape (the test's own `3`), which also warns (Finding 2) |
| cd_extract_daily.R daily_manifest doc | revalidate=FALSE makes no request, "as it does for the files" | y (no request only with a cached copy, as for the files) |
| cd_extract_daily warning advice | "If a cached copy is stale, `cd_cache_fetch(href, refresh = TRUE)` replaces it." | **n** when the stale copy is the manifest: reproduced, the warning persists after following it (Finding 1) |
| CLAUDE.md "Every extract row…" | catalog columns and their sources | y (#128 dependency accepted) |
| CLAUDE.md | cd_sha from the file's CD_SHA tag | y |
| CLAUDE.md | checksum only on an exact string match of CD_RUN_TIME and processing:datetime | y |
| CLAUDE.md | otherwise NA, because cd_cache_fetch serves stale copies | y |
| CLAUDE.md | "Two things warn … a daily manifest that cannot be read: remote and missing or unreachable, or not JSON" | **n**: same two gaps as the roxygen (Finding 2) |
| CLAUDE.md | no run time, a local source with no manifest, or an unlisted file gives NA silently | y |
| CLAUDE.md | with cache=TRUE, revalidate=FALSE stays request-free | y (given a cached copy) |
| CLAUDE.md | "The chain's later functions drop both columns" | y: run, cd_baseline/cd_anomaly/cd_trend/cd_compare outputs carry neither |
| test-cd_catalog: "surfaces checksums and processing provenance" | assertions | y |
| test-cd_catalog: "NA provenance for an untagged catalog" | y | y |
| test-cd_catalog: "JSON null field as NA, not an error" (+ the `cdo` partial-match comment) | y | y |
| test-cd_catalog: empty catalog keeps columns and types | y | y |
| test-cd_extract: "reports the checksum and the file's own cd_sha" | y | y |
| test-cd_extract: "NA checksum for a file that is another build" (comment: stale cached copy) | the scenario is simulated with a local file: same predicates | y |
| test-cd_extract: "NA checksum for an untagged file" | y | y |
| test-cd_extract: "NA checksum, silently, for a catalog without run times" | y | y |
| test-cd_extract: "NA provenance for a catalog without those columns" | y | y |
| test-cd_extract: "nothing to extract keeps its columns" | y | y |
| test-cd_extract_daily: "each row carries the checksum and cd_sha of the file it came from" | y | y |
| test-cd_extract_daily: "a file that is not the manifest's build…" | y | y |
| test-cd_extract_daily: "no manifest, or a file it does not list, gives NA without a warning" | y | y |
| test-cd_extract_daily: "a manifest still on the cd: keys gives NA checksum, silently" | y | y |
| test-cd_extract_daily: "a malformed manifest gives NA rather than stopping the read" | y | y |
| test-cd_extract_daily: "an unreadable remote manifest warns and gives NULL" (cache=FALSE) | y | y |
| test-cd_extract_daily: "a readable remote manifest returns its files" | y | y |
| test-cd_extract_daily: "with cache = TRUE a remote manifest is read through the cache, not fetched" | y | y |
| test-cd_extract_daily: "an offline cache with no manifest copy warns and gives NULL" | y | y |
| test-cd_extract_daily: "an unparseable local manifest warns and gives NA" | y | y |
| test-cd_extract_daily_live: checksum per file (#126) | the expected values come from a revalidated cached manifest and the actual from cache=FALSE, so they agree when the cache is current | y |
| helper-daily.R comments (`daily_manifest_write`, `daily_entry`, `tags =`) | y | y |

## Findings

### 1. (medium, introduced by R3's fix) A stale cached manifest is a new stale source that the docs and the warning's advice do not cover

`R/cd_extract_daily.R:148` (`daily_manifest(source, cache)`) and the advice at `:205-210`.

Since R3 the manifest is cached like the files, so under `cd.cache_revalidate = FALSE` (or when a HEAD fails) the
**manifest** can be older than a file read in the same call. That happens whenever a file that was not cached before is
downloaded fresh:

- **The year was republished** (a `--rewrite`, or #128's republish) after the manifest was cached. The fresh file's
  run-time tag differs from the old entry, so the checksum is NA and a warning fires. The warning names the **data
  file** and says "If a cached copy is stale, `cd_cache_fetch(href, refresh = TRUE)` replaces it." Following that
  refreshes a file that is already current and leaves the warning in place. Reproduced: phase 1 cached the manifest
  and 2003 at R1; the server then moved to R2; with revalidate off, an extract over 2003-2004 warned for
  `tmean_daily_2004.tif`; `cd_cache_fetch(<2004 href>, refresh = TRUE)`; the same extract warned again, with an
  identical NA. Only refreshing `<source>/manifest.json` clears it, and nothing tells the user that.
- **The year was published after the manifest was cached.** The file is "unlisted", so the checksum is NA and there is
  no warning, permanently under revalidate off. The roxygen tells the user a stale cached copy gives NA *and a
  warning*, and here it gives NA silently.

The run-time match still keeps a wrong checksum out (no data-correctness issue). What breaks is the contract that the
warning names a remedy that clears it, and the claim that a stale copy warns. Fixes, any one of: name the manifest URL
in the daily advice (`cd_cache_fetch("<source>/manifest.json", refresh = TRUE)`) and say in the Provenance section that
the cached manifest can be older than a file first downloaded later; or, when the manifest came from the cache and a
file is unlisted or stale, refresh it once (this costs one request, so it breaks revalidate=FALSE's no-request
contract only on a mismatch).

### 2. (low, docs) The "manifest that cannot be read" warning trigger is stated wrongly in two places

`R/cd_extract_daily.R` roxygen Provenance ("a remote one missing or unreachable, or one that is not JSON") and
CLAUDE.md ("remote and missing or unreachable, or not JSON").

- With `cache = TRUE` and a cached copy, a remote manifest that is missing (S3 403/404) or unreachable does **not**
  warn. `cd_cache_fetch()` serves the cached copy with an `inform` message, or makes no request at all when revalidate
  is off. The checksums then come from that copy. This is the R3 mechanism again: the prose was written from the
  cache=FALSE and no-cached-copy rows.
- "Not JSON" misses valid JSON of the wrong shape (a top-level scalar, a top-level array, or no `files` object), which
  also warns. The test "a malformed manifest gives NA…" uses `3`, which is valid JSON.

Suggested wording: "a manifest that cannot be read or has no `files` object warns; with `cache = TRUE` a cached copy
stands in for an unreachable remote one."

### Notes (not findings)

- cd_extract rows where the catalog has a `run_time` and no `checksum` give NA silently, even when the file differs.
  This follows build_stale's design. The roxygen sentence "a stale cached copy … gives NA and a warning" is read as
  applying only when a checksum exists.
- Unmeasured: with `cache = FALSE`, GDAL's in-process `/vsicurl/` cache could keep a pre-republish header for the life
  of the session. The advice ("a publish still in progress … until it completes") would then never clear without a
  restart. This was not reproduced, so it is not a finding.
