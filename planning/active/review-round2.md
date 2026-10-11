# Code-check round 2 (#126): branch diff vs origin/main

Reviewer: subagent, 2026-10-10. Probes ran in a scratchpad copy of the repo. Nothing in the repo was edited except this file.

## Round-1 fixes, checked one axis over

All of these were run end to end through `cd_extract_daily()` or `cd_catalog()` in the copy. None errored:

- Manifest `{"files":{}}`, `{"files":[]}`, `{"files":[{"a":1}]}`: NA, silent. `[[name]]` on an empty or unnamed list is NULL, not an error, on this R.
- Manifest top level `null` or `[]`: warns, NA.
- An entry that is an array (`[1,2]`): NA. An entry whose `file:checksum` is a number: kept as `"5"`.
- Catalog `links` given as an object, as `["x"]`, as `null`, or with a link that has no `rel`; `processing:software` as a string or as `{"cd": [..]}`; `file:size` as a string or as 3e9: each gives NA, or the value where one exists, and nothing errors. The `[[ ]]` lookups are exact, so `cdo` does not answer for `cd`.
- `build_stale()` / `build_checksum()`: `ok` is never NA (`&` is not short-circuit, and FALSE & NA is FALSE). The `if()` always gets length 1.
- `build_tags()`: terra has had the `domain` column since 1.8-42, below the 1.8-54 floor. `NULL` metags is guarded. A tagged COG from `cd_cog_write()` reads back `sha`/`run_time` correctly.
- The extract output went through `cd_baseline` -> `cd_anomaly` -> `cd_trend` -> `cd_summary`, and also `cd_compare`, with no error, and the extra columns are dropped as CLAUDE.md says. A zero-row extract keeps its typed columns.
- `cd_extract()` now resolves the cache itself and calls `cd_crop(cache = FALSE)`. That keeps the old `isTRUE(cache)` semantics. No test or script mocks `cd_crop`, so nothing is bypassed.

## Findings

- **[severity: fragile]** CLAUDE.md:38 (the "Every extract row names the build" paragraph). It says "Anything else gives `NA` and a warning". The code deliberately gives NA **silently** in three cases:
  - an entry or catalog row with no run time (`build_stale()` returns FALSE);
  - a source with no manifest;
  - a file the manifest does not list.

  The roxygen for both functions says this correctly, and so do the tests (`expect_no_warning`). CLAUDE.md is the instruction file every session loads, so a later session could read the silence as a bug and "fix" it, which would make every pre-#128 catalog warn on every read. Fix: reword to say that a stated run time that differs from the file's tag, or a missing tag, gives NA and a warning, and that an entry with no run time gives NA silently.

- **[severity: fragile]** R/cd_catalog.R `build_checksum()` / `build_stale()`. These compare `processing:datetime` with the file's `CD_RUN_TIME` tag as **exact strings**. That holds today only because the writer copies the tag verbatim (`cd:run_time = tag("CD_RUN_TIME")` in `R/cd_stac_catalog.R:132` and `scripts/_lib.R:609`). The #128 issue body maps `cd:run_time` to `processing:datetime` but never says the value must stay byte-for-byte the tag. A reformat to another valid RFC 3339 spelling (`.000Z`, `+00:00`) would make every file read warn "not the build" and return NA checksums everywhere. Nothing on CI would catch it: the only test against live data is `skip_on_ci()`. Fix: state the verbatim-copy contract in #128 (or in a comment at the writer). Normalising both sides before comparing would also work, but it is not needed if the contract is written down.

- **[severity: fragile, low]** R/cd_catalog.R `build_warn()`. The remedy text is always "A stale cached copy is the usual cause; `cd_cache_fetch(href, refresh = TRUE)` replaces it." For `cd_extract()`, the mismatch can just as well come from a **stale catalog**: a `cd_catalog()` result saved or held across a republish, while revalidation fetched the new file. In that case refreshing the cache changes nothing and the warning repeats on every call. The roxygen even names "an out-of-date catalog" as a cause, but the warning text does not. For `cd_extract_daily()` the advice is right, because the manifest is always fetched live. However, that warning lists bare file names, not hrefs, so the `href` the remedy asks for has to be rebuilt by hand. This is not a data defect, since checksums are correctly NA. Only the remedy misdirects.

No bugs or security issues found. Everything else in the checklist that applies, checked:

- `%||%` and other R >= 4.2 features: none in the diff.
- `$` partial matching: exact `[[` where it matters.
- `expect_no_warning` returns the value (testthat 3.3.2: `invisible(act$val)`), so `ts <- expect_no_warning(...)` is sound.
- `expect_identical(info =)` is a valid argument.
- The typed `bind_rows` template takes its types from the source.
- `tryCatch` error handlers have nothing to discard.
- The curl fetch has a timeout.
- `curl`, `jsonlite`, `rlang` and `terra (>= 1.8-54)` are all in Imports, and `withr` is in Suggests.

Pre-existing and outside this diff: `testthat (>= 3.0.0)` in Suggests while tests use `local_mocked_bindings` (needs 3.2.0) and `expect_no_warning` (3.1.5). The branch adds more uses but did not create the gap.
