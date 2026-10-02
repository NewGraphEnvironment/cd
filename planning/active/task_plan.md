# Task: inst/extdata/context_kotl.gpkg (4.9 MB) ships but nothing reads it (#112)

`inst/extdata/context_kotl.gpkg` is 4.9 MB. Nothing in `R/`, `tests/`, `vignettes/` or `README.md` references it. The only mention is its producer, `data-raw/example_context_kotl.R`, plus a comment in `data-raw/example_context_fwcp_peace.R`. It dates from `3ece27c` (2026-04-07, before the Kootenay Lake vignette). The vignette added in #57 uses `context_kootenay_lake.gpkg`, which appears to supersede it. `example_aoi_kotl.gpkg` is still used by the README example, so keep it.

Found by a code-check reviewer while verifying #100's tarball contents, and confirmed with `git grep -n context_kotl`.

## Context (from plan-mode exploration)

`inst/extdata/context_kotl.gpkg` ships in every install and nothing reads it. Exploration confirmed the issue's claim and the supersession it asked about:

- `git grep context_kotl` outside `planning/` hits only its producer `data-raw/example_context_kotl.R` and a "Same recipe as example_context_kotl.R" comment at `data-raw/example_context_fwcp_peace.R:3`. Nothing in `R/`, `tests/`, `vignettes/`, `README.md`.
- Its consumer, the KOTL vignette, was removed in v0.2.x (#50, NEWS.md:169). That NEWS line says the KOTL *polygon* assets stay for the README — that is `example_aoi_kotl.gpkg` (README.md:23), which this work keeps.
- `context_kootenay_lake.gpkg` (2.2 MB, #57) covers the KOTL+LARL+DUNC+SLOC superset with the same layer kinds (towns, lakes, rivers, streams, highways) plus wsgs and ecoregions. Superseded.
- The only test touching `extdata` as a directory (`test-cd_stac_catalog.R`) lists `*.tif` only, so removing a gpkg cannot affect it.

**Decision taken in this plan (recommended): delete the producer script too**, rather than mark it superseded. A kept script for a deleted output is a trap — running it recreates the 4.9 MB file under `inst/extdata/` — and git history keeps the recipe. `example_aoi_kotl.R` stays (README asset).

## Phase 1: Baseline measurement
- [x] Build tarball from `git archive HEAD` (`R CMD build --no-build-vignettes --no-manual`), record tarball size and installed `inst/extdata` size — same method as #100's archive README

## Phase 2: Remove the asset and its producer
- [x] `git rm inst/extdata/context_kotl.gpkg data-raw/example_context_kotl.R`
- [x] `data-raw/example_context_fwcp_peace.R:3`: repoint "Same recipe as example_context_kotl.R" at `example_context_kootenay_lake.R` (the live sibling)
- [x] `git grep -n context_kotl -- ':(exclude)planning'` returns nothing

## Phase 3: Verify
- [x] Rebuild tarball, compare size before/after; record both in `findings.md`
- [x] `devtools::test()` passes
- [x] `R CMD check --no-manual --ignore-vignettes` on the tarball (`_R_CHECK_FORCE_SUGGESTS_=false`) — no new NOTEs vs v0.5.8
- [x] README example still resolves `example_aoi_kotl.gpkg` via `system.file()`

## Validation
- [x] Tests pass
- [x] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion (README carries the before/after measurement)

NEWS line and version bump are left to `/gh-pr-merge` (patch release).
