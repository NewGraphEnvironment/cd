# Code-check review round 1 — #112 (staged diff)

## Clean
No issues found.

### What was verified
- `git grep -i kotl` outside `planning/archive/`: no reader of `context_kotl` in `R/`, `tests/`, `vignettes/`, `scripts/`, `.github/`, `README.md`, `_pkgdown.yml`, `DESCRIPTION`, `.Rbuildignore`, or other `inst/` files. Remaining `kotl` hits are `example_aoi_kotl.gpkg` (README.md:23, kept), its kept producer `data-raw/example_aoi_kotl.R`, WSG code strings, and NEWS history.
- Indirect readers: every `list.files()` in `R/` and `scripts/` targets cache / grib / cog / monthly dirs, never `inst/extdata`; all `system.file("extdata", ...)` calls use literal names of files that still exist; no `paste0("context_", ...)` style construction anywhere.
- Ecosystem: local grep over `~/Projects/repo` and `gh` code search (`org:NewGraphEnvironment context_kotl`, default branches) find only cd's own producer, the edited comment, and planning/archive + sred evidence dumps (history). No external package reads `system.file(..., "context_kotl.gpkg", package = "cd")`.
- Edited comment (`data-raw/example_context_fwcp_peace.R:3`): `example_context_kootenay_lake.R` exists, uses the same recipe (frs_db_query towns/lakes/rivers/streams/highways/wsgs/ecoregions, same st_write layering), and its thresholds (lakes > 200 ha, stream order >= 5) are lower than Peace's (> 1000 ha, >= 7), so "bigger lake threshold, higher minimum stream order" remains accurate. That file's header reciprocally says "Same recipe as example_context_fwcp_peace.R".
- Deleting the producer removes the only writer of `inst/extdata/context_kotl.gpkg`; nothing left can regenerate the deleted file.

### Pre-existing, not introduced by this diff (FYI only)
- `data-raw/example_context_fwcp_peace.R:8` lists output layers as "towns, lakes, streams, highways" but the script also writes rivers, wsgs, ecoregions. Untouched line; not a failure.
