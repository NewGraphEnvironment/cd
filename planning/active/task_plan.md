# Task: .Rbuildignore: planning/, CLAUDE.md, scripts/, data-raw/ ship in the package tarball (#100)

`.Rbuildignore` has held six lines since the scaffold commit (`3ca80a4`, plus `^\.git$` in `3088af7`).
Every tarball built from this repo — and every install from GitHub — carries `planning/`, `CLAUDE.md`,
`scripts/`, `data-raw/`, `dev/`, `logs/` and `.claude/` into the user's library. Measured 2026-10-01 on
`git archive HEAD` (v0.5.6): 201 planning, 20 scripts, 16 data-raw, 5 logs, 2 dev, 2 .claude, plus
`CLAUDE.md`, `CITATION.cff`, `.lintr`.

`data/` holds no tracked files (gitignored `backfill/`, `update/` working data only — no package
datasets), so `^data$` is safe. No test, vignette or R file reads any excluded directory at runtime.

## Phase 1: Exclude internal top-level entries
- [x] Append to `.Rbuildignore`, one live regex per line, no comments:
      `^CLAUDE\.md$`, `^planning$`, `^scripts$`, `^data-raw$`, `^dev$`, `^logs$`,
      `^\.claude$`, `^\.lintr$`, `^CITATION\.cff$`, `^data$`, `^research$`
      (`^research$` pre-emptively, per the planning convention; `^README\.Rmd$` omitted — no such file)
- [x] Check each pattern matches its target and nothing else with `tools:::inRbuildignore()`
      against `ls -A` + `git ls-files`

## Phase 2: Verify by building, not by reading
- [ ] `git archive` the branch into the scratchpad, `R CMD build --no-build-vignettes --no-manual`,
      `tar tzf | cut -d/ -f2 | sort | uniq -c` — expect only `DESCRIPTION NAMESPACE NEWS.md
      README.md LICENSE R man tests inst vignettes` (+ `build/` if produced)
- [ ] `R CMD check --no-manual --ignore-vignettes` on the before and after tarballs; record the
      "hidden files" / "portable file names" / "top-level files" NOTEs disappearing
- [ ] Record before/after counts and NOTE diff in `findings.md`

## Phase 3: Wrap up
- [ ] `/planning-archive` with archive README (Measurement + Evidence)
- [ ] `/gh-pr-push` — `Fixes #100`, SRED line in body. NEWS + version bump left to `/gh-pr-merge`

## Validation

- [ ] Tests pass
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
