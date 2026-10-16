# Task: swe_max anomaly type: registry says absolute, CLAUDE.md says pct_normal (#139)

## Problem

Two descriptions of how `swe_max` departs from normal disagree:

- `cd_variables()` gives `swe_max` the anomaly type `absolute` (`R/cd_variables.R`, the snow-derived block: `swe_max`, `snowfall_fraction`, `snowmelt_doy_50`, `snowmelt_rate_peak` → `absolute`, `pct_point_diff`, `absolute`, `absolute`).
- `CLAUDE.md`'s "Snow annual derived" table says `pct_normal`.

`cd_anomaly()` reads the registry, so anything built on it reports peak snowpack as mm departures. The plain-language vignette (#137) reports it as a percent of normal and chose that in its own lookup rather than reading the registry, which is a sign the registry may be the wrong one. `swe`, the monthly native, is `pct_normal`.

Decide which is right, then make the registry and `CLAUDE.md` agree. If the registry changes, the bundled vignette data that carries an `anomaly_type` column needs a regen (`tests/testthat/test-cd_variables.R` checks it against the registry).

## Decisions (plan gate, 2026-10-15)

- `swe_max` becomes `pct_normal` (unit `%`), matching `swe`, BC snow-bulletin practice and the northern-bc vignette.
- `cd_compare()` keeps `window_a = 2015:2025`; only its docs change ("the recent 11 years").

## Phase 1: Registry and tests
- [ ] `R/cd_variables.R`: swe_max `anomaly_type` → `"pct_normal"`, `unit` → `"%"`. Update the roxygen `pct_change` note: "`vpd` and `swe_max` are `absolute`" becomes `vpd` and `snowmelt_rate_peak`
- [ ] `tests/testthat/test-cd_variables.R`: pct_normal count 5 → 6, add `swe_max` to the pct_normal list
- [ ] Tighten the bundled-data test so a registry variable carried with a different `anomaly_type` fails. Exempt only rows the registry does not list, or rows a carrier deliberately overrides (check whether any bundled table does). Restore the old rds and confirm the test goes red
- [ ] grep R/ and tests/ for anything else keyed on swe_max being absolute or mm (e.g. `test-cd_compare.R:271` pct series), and fix it
- [ ] `devtools::document()`, then run the tests

## Phase 2: Patch the bundled vignette data
- [ ] `data-raw/vignette_data_swe_max_type_patch.R`, modelled on the vpd patch. For every `ts`/`ano`/`trn` group in `peace_fwcp.rds` and `kootenay_lake.rds`: rebuild the swe_max baseline from `ts` using the reference the data-raw script used, then recompute `ano` with `cd_anomaly()` and `trn` with `cd_trend(trend_start = c(1951, 1981))`
- [ ] Guard before writing: recomputing with type `absolute` reproduces the stored swe_max rows exactly, which proves the inputs match. Every non-swe_max row, every other list element and every attribute must be unchanged. Re-running must be a no-op
- [ ] Run the patch, commit both rds files, and confirm the bundled-data test passes on the patched data

## Phase 3: Vignettes, docs, CLAUDE.md
- [ ] `peace-fwcp.Rmd` and `kootenay-lake.Rmd`: change the facet-swe-max caption ("Bars are mm…") and y label to percent of normal; change the snow-annual panel label "Peak SWE (mm)" to %. grep the prose for swe_max anomaly or trend figures stated in mm. The `cd_compare` mm values (135 → 122 mm) come from `value`, so they stay
- [ ] `data-raw/northern_bc_vignette_data.R`: fix the lookup comment (only the comment; the lookup and the rds stay as they are)
- [ ] Also check whether `peace_fwcp_vignette_data.R` and `kootenay_lake_vignette_data.R` need a note, so a future full regen picks up pct_normal from the registry with no extra step
- [ ] `R/cd_compare.R`: change "a recent decade (`2015:2025`)" to "the recent 11 years (`2015:2025`)", including the "recent decade" in the cumulative-impact sentence; `document()`
- [ ] `CLAUDE.md`: the swe_max row already says `pct_normal`. Change its unit column to match the registry's view if needed. Fix the #138 paragraph ("`vpd`, `swe_max` and `snowmelt_rate_peak` are `absolute`") to name only vpd and snowmelt_rate_peak
- [ ] NEWS entry is left to `/gh-pr-merge`

## Validation
- [ ] Tests pass (`devtools::test()`, grep FAIL/ERROR)
- [ ] Render both regional vignettes (`pkgdown::build_article()` or `rmarkdown::render`) and look at the swe_max facet and snow-annual panels
- [ ] `lintr::lint_package()` clean on touched files
- [ ] `/code-check` clean (each commit, or once over the branch with `/code-check branch`)
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion

