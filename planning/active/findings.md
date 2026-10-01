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
