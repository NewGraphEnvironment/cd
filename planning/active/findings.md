# Findings — .Rbuildignore: planning/, CLAUDE.md, scripts/, data-raw/ ship in the package tarball (#100)

## Issue context

**If we do it:** `R CMD build` ships the package and nothing else. **If we never do:** every tarball built from this repo — and every install from GitHub — carries `planning/` (review files, PWF logs), `CLAUDE.md`, `scripts/` (producer pipeline, incl. `_lib.py`), `data-raw/`, `dev/`, `logs/` and `.claude/` into the user's library.

## Problem

`.Rbuildignore` has held six lines since the scaffold commit (`3ca80a4`, plus `^\.git$` in `3088af7`):

```
^LICENSE\.md$  ^_pkgdown\.yml$  ^docs$  ^pkgdown$  ^\.github$  ^\.git$
```

Checked with `tools:::inRbuildignore()` on 2026-09-29: `CLAUDE.md`, `planning`, `scripts`, `data-raw`, `logs` all return `FALSE`. Surfaced by `/gh-pr-merge`'s shipped-change gate while releasing v0.5.1 — the gate reported `planning/archive/…` as shipped, so it cannot currently tell a docs-only merge from a code merge either.

Measured 2026-09-30 (from #107, closed as a duplicate of this issue): `R CMD build --no-build-vignettes --no-manual` on `git archive HEAD` (v0.5.3 plus the #98 branch) produced a tarball with these top-level entries, about 230 internal files in all:

```
184 planning
 20 scripts
 16 data-raw
  5 logs
  2 dev
  2 .claude
  1 CLAUDE.md
  1 CITATION.cff
  1 .lintr
```

`devtools::check()` on v0.5.6 reports this as the "hidden files", "portable file names" and "top-level files" NOTEs. Add `^research$` too if a `research/` directory is ever created.

## Proposed Solution

- Add `^CLAUDE\.md$`, `^planning$`, `^scripts$`, `^data-raw$`, `^dev$`, `^logs$`, `^\.claude$`, `^\.lintr$`, `^CITATION\.cff$`, `^README\.Rmd$` if present, and `^data$` (gitignored working data), checking each against `ls -A`.
- Verify with `R CMD build` and `tar tzf` on the result, not by reading the file (`.Rbuildignore` has no comment syntax — every line is a live regex).
- `R CMD check` for NOTEs about non-standard top-level files, before and after.

## Errors Encountered

| Error | Resolution |
|-------|------------|

## Phase 1 — pattern check (2026-10-01)

`tools:::inRbuildignore()` against `ls -A`: each new pattern matches exactly its one top-level
entry (`^research$` matches nothing — no such directory yet). Kept top-level after the change:
`.gitignore DESCRIPTION inst LICENSE man NAMESPACE NEWS.md R README.md tests vignettes`
(`.gitignore` is dropped later by R's built-in excludes). Over every tracked file outside the
excluded directories, the only matches are `.Rbuildignore .lintr CITATION.cff CLAUDE.md
LICENSE.md _pkgdown.yml` — all intended; nothing under `R/ man/ tests/ inst/ vignettes/`.

## Phase 2 — build and check, before vs after (2026-10-01, R 4.5.2)

Both tarballs built with `R CMD build --no-build-vignettes --no-manual` from clean copies:
before = `git archive` of `1e5b450` (v0.5.6 + CLAUDE.md sync), after = `git checkout-index`
of the staged tree (`.Rbuildignore` byte-identical to `f42f30e`, checked with `cmp`).

| | files | size | top-level entries |
|---|---|---|---|
| before | 307 | 7.90 MB | + planning 201, scripts 20, data-raw 16, logs 5, dev 2, .claude 2, CLAUDE.md, CITATION.cff, .lintr |
| after | 92 | 7.15 MB | DESCRIPTION NAMESPACE NEWS.md README.md LICENSE R man tests inst vignettes |

`R CMD check --no-manual --ignore-vignettes` (`_R_CHECK_FORCE_SUGGESTS_=false` — Suggests
`aws.s3`, `ecmwfr` not installed here; the first attempt without it stopped at "package
dependencies" on both tarballs): **5 NOTEs → 2**, tests pass in both. Gone: "hidden files
and directories" (`.lintr`, `.claude`, `.gitkeep`s), "portable file names" (three
`planning/archive/` paths over 100 bytes), "CITATION file in a non-standard place"
(`CITATION.cff`). Remaining, pre-existing and unrelated — unused `sf` import and
`.data`/`.env` globals — filed as #111.

Code-check round 3 also built from the real working tree (untracked + ignored files
included): identical listing, so `logs/*.log` (~2.3 MB), `data/backfill`, `data/update` and
`scripts/__pycache__` no longer reach a local build. It ran `/gh-pr-merge`'s shipped-change
pathspec loop against the new `.Rbuildignore`: `v0.5.6..HEAD` (CLAUDE.md sync, CITATION.cff
bot commit, PWF baseline) now reports nothing shipped; with the old file it listed all three.
Side finding, verified with `git grep`: `inst/extdata/context_kotl.gpkg` (4.9 MB) is read by
nothing — filed as #112.
