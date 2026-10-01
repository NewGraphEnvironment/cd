# Review round 1 — #100 `.Rbuildignore` diff

## Clean

No issues found.

Checked:
- Every new line is anchored `^...$`, dots escaped (`CLAUDE\.md`, `\.claude`, `\.lintr`, `CITATION\.cff`), no trailing whitespace or CR (`cat -et`). No comment lines.
- `inRbuildignore` matches against paths relative to the package root, so `^data$` / `^dev$` cannot hit `inst/extdata`, `inst/vignette-data` or any nested `data/`.
- Nothing in `R/`, `tests/`, `inst/` reads `scripts/`, `data-raw/`, `planning/`, `logs/`, `CITATION.cff` or `data/`; vignette mentions of `data-raw/` are comments/captions only. DESCRIPTION has no `LazyData`; `data/` holds only gitignored `backfill/` and `update/`, so excluding it removes local working data from local builds and breaks nothing.
- CI: `climate-update.yml` installs via `local::.` but runs `scripts/pipeline_update_edh.R` and writes `logs/` from the checkout, not from the tarball. `pkgdown.yaml` builds from the checkout (and already `rm -f CLAUDE.md` for the site surface). `update-citation-cff.yaml` reads/writes `CITATION.cff` in the checkout. `.lintr` is consumed by lintr from the source tree only.
