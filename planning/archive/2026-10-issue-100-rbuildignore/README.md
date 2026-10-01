## Outcome

`.Rbuildignore` had held its six scaffold lines since the first commit, so every tarball and
every GitHub install shipped `planning/`, `scripts/`, `data-raw/`, `dev/`, `logs/`, `.claude/`,
`CLAUDE.md`, `CITATION.cff` and `.lintr`. Added an anchored pattern for each, plus `data/`
(gitignored working data, no package datasets) and `research/` (pre-emptive). Verified by
building and listing the tarball rather than by reading the file, and by checking each
pattern against the tree with `tools:::inRbuildignore()`. The `/gh-pr-merge` shipped-change
gate, which derives its pathspec from `.Rbuildignore`, now reads a planning-only or
CLAUDE.md-only merge as non-shipped. Three code-check rounds were all Clean.

## Measurement

R 4.5.2, `R CMD build --no-build-vignettes --no-manual` on clean copies of the tree:
tarball **307 → 92 files, 7.90 → 7.15 MB**; only `DESCRIPTION NAMESPACE NEWS.md README.md
LICENSE R man tests inst vignettes` remain. A build from the real working tree, with untracked
and ignored files included, gives the identical listing, so local builds no longer sweep
up `logs/*.log` (~2.3 MB) or `data/backfill`. `R CMD check --no-manual --ignore-vignettes`:
**5 NOTEs → 2**, tests passing in both. The first check attempt stopped at "package
dependencies" on both tarballs because Suggests `aws.s3` and `ecmwfr` are not installed
locally; rerun with `_R_CHECK_FORCE_SUGGESTS_=false`. The two remaining NOTEs predate this
work (#111). A reviewer's side finding, an unread 4.9 MB `inst/extdata/context_kotl.gpkg`,
was confirmed and filed as #112. Details in `findings.md`.

Closed by: commit f42f30e
