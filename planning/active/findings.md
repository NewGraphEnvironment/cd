# Findings — inst/extdata/context_kotl.gpkg (4.9 MB) ships but nothing reads it (#112)

## Issue context

**If we do it:** the installed package loses 4.9 MB, about 40% of its 12.5 MB installed size. **If we never do:** every install carries a file nothing reads.

## Problem

`inst/extdata/context_kotl.gpkg` is 4.9 MB. Nothing in `R/`, `tests/`, `vignettes/` or `README.md` references it. The only mention is its producer, `data-raw/example_context_kotl.R`, plus a comment in `data-raw/example_context_fwcp_peace.R`. It dates from `3ece27c` (2026-04-07, before the Kootenay Lake vignette). The vignette added in #57 uses `context_kootenay_lake.gpkg`, which appears to supersede it. `example_aoi_kotl.gpkg` is still used by the README example, so keep it.

Found by a code-check reviewer while verifying #100's tarball contents, and confirmed with `git grep -n context_kotl`.

## Proposed Solution

- Confirm `context_kootenay_lake.gpkg` supersedes it. Then delete `inst/extdata/context_kotl.gpkg`, and either delete `data-raw/example_context_kotl.R` or mark it superseded.
- Rebuild and compare the tarball size before and after.

## Supersession (plan-mode exploration, 2026-10-02)

- `git grep context_kotl` outside `planning/` hit only the producer and one comment in `data-raw/example_context_fwcp_peace.R`.
- The file's consumer, the KOTL vignette, was removed in #50 (NEWS.md, v0.2.x entry). That entry's "KOTL polygon assets stay" refers to `example_aoi_kotl.gpkg`, used at README.md:23 and kept.
- `context_kootenay_lake.gpkg` (#57) layers: lakes, rivers, streams, highways, wsgs, ecoregions, towns over KOTL+LARL+DUNC+SLOC. `context_kotl.gpkg` layers: towns, lakes, rivers, streams, highways over KOTL only. Superset.
- Code-check round 1 widened this: no `list.files()` over `inst/extdata`, no pattern-built filenames, and an org-wide `gh` code search found no other repo reading the file.

## Measurement

R 4.5.2, `R CMD build --no-build-vignettes --no-manual` on `git archive` of HEAD (`048f93a`) vs the staged tree (`git write-tree`), then `R CMD INSTALL -l` into a scratch library:

| | before | after | change |
|---|---|---|---|
| tarball | 7,146,394 B | 3,830,880 B | −3.3 MB (−46%) |
| tarball files | 101 | 100 | only `inst/extdata/context_kotl.gpkg` gone |
| installed `cd/` | 12,776 KB | 7,948 KB | −4.7 MB (−38%) |
| installed `extdata/` | 11,796 KB | 6,968 KB | −4.7 MB |

The gpkg compresses in the tarball (4.9 MB raw → ~3.3 MB of tarball), so the issue's "loses 4.9 MB" holds for the installed size, not the download.

After-tarball `_R_CHECK_FORCE_SUGGESTS_=false R CMD check --no-manual --ignore-vignettes`: **Status: OK** (0 NOTEs; #111 had already cleared the last two). `devtools::test()`: FAIL 0 | WARN 6 | SKIP 0 | PASS 436. `system.file("extdata", "example_aoi_kotl.gpkg", package = "cd")` resolves in the installed after-library and reads 1 feature.

Reproduce (per side; `<tree>` is `HEAD` or `$(git write-tree)`):

```bash
git archive <tree> | tar -x -C src && R CMD build --no-build-vignettes --no-manual src
wc -c < cd_0.5.8.tar.gz; tar -tzf cd_0.5.8.tar.gz | wc -l
R CMD INSTALL -l lib cd_0.5.8.tar.gz && du -sk lib/cd lib/cd/extdata
```
