# Task: cd_variables(): vpd unit is Pa but the data is hPa (#96)

`cd_variables()` gives `vpd` the unit `"Pa"` (`R/cd_variables.R:46`, and the `unit` doc line at `:13`). The data is hPa:

- `R/cd_derive.R:93` — `@return SpatRaster of VPD in hPa.`
- `scripts/backfill_edh_all.py:26` — `vpd_YYYY.tif  hPa (Tetens from tmean + dewpoint)`
- both vignettes label trends `hPa/dec` by hand
- annual values in the bundled vignette data are ~1.5–4.2, which is hPa-scale (Pa would be ~100× larger)

`vpd` is `absolute`, so the anomaly unit is the value unit, and "Pa" reaches `cd_summary()`'s `Unit` column, `cd_plot_timeseries()` labels, and (since #93) raw-value plots.

## Phase 1: Registry fix (test first)

- [x] `tests/testthat/test-cd_variables.R`: new test that the `vpd` unit is `"hPa"`; it fails against current code
- [x] `R/cd_variables.R`: `"Pa"` → `"hPa"` in `unit`, and the `@return` doc line (`degree C, percent, hPa, mm, day, mm/wk`)
- [x] `devtools::document()` regenerates `man/cd_variables.Rd`; `devtools::test()` passes

## Phase 2: Vignette data carries the unit it is in

- [ ] `tests/testthat/test-cd_variables.R`: new test walking both bundled `vignette-data` .rds (`system.file()`). Every table with `variable`/`unit`/`anomaly_type` must carry the registry's unit wherever its `anomaly_type` matches the registry's. Show it fails on the current .rds.
- [ ] `data-raw/vignette_data_vpd_unit_patch.R`: a one-off local script that loads the source tree (`pkgload::load_all()`). For each .rds it sets `unit` from `"Pa"` to `"hPa"` on vpd rows only, then asserts the result equals the original except that column (values, rows, every other column identical), and writes it back with `saveRDS(compress = "xz")`, as the generators do. Run a second time, it finds nothing to change and writes nothing.
- [ ] Run it and commit both .rds; the Phase 2 test passes
- [ ] The header comment of each `data-raw/*_vignette_data.R` is left alone: the generators already take units from `cd_variables()`, so a future regen writes hPa on its own

## Phase 3: NEWS + docs

- [ ] NEWS.md entry under a dev heading (`/gh-pr-merge` sets the version). It is a behaviour change: the `Unit` for vpd in `cd_anomaly()`, `cd_summary()` and the plot labels is now hPa, and the values are unchanged. A series saved earlier keeps its `"Pa"`, because a carried `unit` wins, so re-label or re-run `cd_anomaly()`.
- [ ] Grep `CLAUDE.md` and `research/` for a vpd unit claim (CLAUDE.md:75 already says hPa: no change expected)

## Validation

- [ ] Tests pass (`devtools::test()`); `lintr::lint_package()` clean on touched files
- [ ] Build the peace-fwcp vignette's trend table locally and confirm the vpd rows read hPa
- [ ] `/code-check` clean (each commit, or once over the branch with `/code-check branch`)
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
