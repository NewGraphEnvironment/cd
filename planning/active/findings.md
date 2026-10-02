# Findings — inst/extdata/context_kotl.gpkg (4.9 MB) ships but nothing reads it (#112)

## Issue context

**If we do it:** the installed package loses 4.9 MB, about 40% of its 12.5 MB installed size. **If we never do:** every install carries a file nothing reads.

## Problem

`inst/extdata/context_kotl.gpkg` is 4.9 MB. Nothing in `R/`, `tests/`, `vignettes/` or `README.md` references it. The only mention is its producer, `data-raw/example_context_kotl.R`, plus a comment in `data-raw/example_context_fwcp_peace.R`. It dates from `3ece27c` (2026-04-07, before the Kootenay Lake vignette). The vignette added in #57 uses `context_kootenay_lake.gpkg`, which appears to supersede it. `example_aoi_kotl.gpkg` is still used by the README example, so keep it.

Found by a code-check reviewer while verifying #100's tarball contents, and confirmed with `git grep -n context_kotl`.

## Proposed Solution

- Confirm `context_kootenay_lake.gpkg` supersedes it. Then delete `inst/extdata/context_kotl.gpkg`, and either delete `data-raw/example_context_kotl.R` or mark it superseded.
- Rebuild and compare the tarball size before and after.
