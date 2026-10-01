# Progress — .Rbuildignore: planning/, CLAUDE.md, scripts/, data-raw/ ship in the package tarball (#100)

## Session 2026-10-01

- Plan-mode exploration — phases approved by user
- Baseline measured: `R CMD build` of `git archive HEAD` ships 248 internal files
- Created branch `100-rbuildignore-planning-claude-md-scripts` off main
- Scaffolded PWF baseline from issue #100 with approved phases
- Next: start Phase 1
- Phase 1: `.Rbuildignore` +11 patterns; `/code-check` 3 rounds, all Clean (`f42f30e`)
- Phase 2: tarball 307 → 92 files; R CMD check 5 → 2 NOTEs, tests pass; filed #111 (remaining NOTEs) and #112 (unused 4.9 MB gpkg)
- Next: archive, PR
