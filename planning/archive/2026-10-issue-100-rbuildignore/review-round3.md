# Review round 3: completeness (is anything internal still shipping?)

## Clean

No issues found in the diff.

### What was checked (2026-10-01)

1. **Working-tree build, not the clean copy.** I rsynced the real working tree (untracked and
   gitignored files included, `.git` left out since `^\.git$` already covers it) to a temp dir and
   ran `R CMD build --no-build-vignettes --no-manual` on it. `tar tzf` of the result matches the
   clean `checkout-index` tarball in `scratchpad/after/` exactly (`diff` reports nothing). The
   working tree's untracked and ignored contents all sit under directories that are now excluded:
   - `scripts/__pycache__/*.pyc` → `^scripts$`
   - `planning/active/review-round1.md` (untracked) → `^planning$`
   - `logs/*.log` (~2.3 MB) → `^logs$`
   - `data/backfill/`, `data/update/` → `^data$`
   - `.claude/visibility` → `^\.claude$`

   `find` turned up no `.DS_Store`, `.Rhistory`, `.RData`, `.Rproj.user`, `*.Rproj`, `*_cache/`,
   `*_files/` or stray `*.html` anywhere, and no `inst/doc`. A `devtools::build()` that builds
   vignettes adds `inst/doc`, which is intended.
2. **Kept directories.** The tarball's non-`R/`, non-`man/*.Rd`, non-`tests/testthat/*` entries
   are `DESCRIPTION LICENSE NAMESPACE NEWS.md README.md`, `man/figures/logo*.png`,
   `tests/testthat.R`, the two vignette Rmds plus `references.bib`, and `inst/extdata/*` plus
   `inst/vignette-data/*`. None of them is a note, a review file or scratch. `tests/testthat/`
   holds only `test-*.R`, with no `_problems/` and no `testthat-problems.rds`.
3. **The `/gh-pr-merge` shipped-change gate.** I ran the gate's own loop
   (`soul/skills/gh-pr-merge/SKILL.md` lines 309-330) against the staged `.Rbuildignore`. Each new
   pattern turns into a working `:(exclude)` pathspec (`CLAUDE.md`, `planning`, `.claude`, `.lintr`,
   `CITATION.cff`, `data`, `research`, …). Results:
   - `v0.5.6..HEAD` (the CLAUDE.md sync, the CITATION.cff auto-update and the PWF baseline): empty
     output with rc 0, so `SHIPPED_CHANGED=0`. With the old six-line `.Rbuildignore`, the same range
     listed `CITATION.cff CLAUDE.md planning/...`, i.e. it counted as shipped.
   - The index against `v0.5.6` (this PR) lists `.Rbuildignore`, so it counts as shipped. That is
     correct, because it does change the tarball.

   The issue's use case holds: after this change, a docs-only merge that touches only `planning/`
   or `CLAUDE.md` (or the post-release CITATION.cff bot commit) counts as non-shipped.

### Out-of-scope observations (pre-existing, not introduced by this diff)

- `inst/extdata/context_kotl.gpkg` (4.8 MB, about a third of the 12.5 MB installed size) ships,
  but nothing in `R/`, `tests/`, `vignettes/` or `README.md` reads it. Only
  `data-raw/example_context_kotl.R` and `data-raw/example_context_fwcp_peace.R` mention it. The
  vignette uses `context_kootenay_lake.gpkg`. It looks like a superseded artifact, but it is not
  internal and it breaks nothing. Worth a separate issue if package size matters.
  (`example_aoi_kotl.gpkg` *is* used, by the README example.)
- The gate does not exclude `.gitignore`, which R drops by default, so a merge touching only
  `.gitignore` would still count as shipped. It fails in the conservative direction (it releases),
  so nothing is lost.
