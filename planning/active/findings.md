# Findings — swe_max anomaly type: registry says absolute, CLAUDE.md says pct_normal (#139)

## Issue context

## Problem

Two descriptions of how `swe_max` departs from normal disagree:

- `cd_variables()` gives `swe_max` the anomaly type `absolute` (`R/cd_variables.R`, the snow-derived block: `swe_max`, `snowfall_fraction`, `snowmelt_doy_50`, `snowmelt_rate_peak` → `absolute`, `pct_point_diff`, `absolute`, `absolute`).
- `CLAUDE.md`'s "Snow annual derived" table says `pct_normal`.

`cd_anomaly()` reads the registry, so anything built on it reports peak snowpack as mm departures. The plain-language vignette (#137) reports it as a percent of normal and chose that in its own lookup rather than reading the registry, which is a sign the registry may be the wrong one. `swe`, the monthly native, is `pct_normal`.

Decide which is right, then make the registry and `CLAUDE.md` agree. If the registry changes, the bundled vignette data that carries an `anomaly_type` column needs a regen (`tests/testthat/test-cd_variables.R` checks it against the registry).

## Also

`cd_compare()`'s docs call its default `window_a = 2015:2025` "a recent decade", but it is 11 years. Either say "the recent 11 years" or move the default to `2016:2025`. The two regional vignettes use the default, so the second option changes their numbers.

Found during #137.


## Exploration (plan mode, 2026-10-15)

The registry (`R/cd_variables.R`) gives `swe_max` the type `absolute` (mm). `CLAUDE.md` says `pct_normal`. #48 chose `absolute` on purpose (81d96bf); `CLAUDE.md` drifted in a docs pass (8f88660). **Decided at the gate: `pct_normal`**, because `swe` (monthly) is `pct_normal`, BC snow bulletins report peak snowpack as % of normal, the northern-bc vignette already reports it that way, and percent puts ecoregions with very different snowpacks on one scale. **The window fix is wording only**: `cd_compare()` keeps `2015:2025`, and its docs stop calling that 11-year span a decade.

What the exploration found and the plan depends on:
- The registry's `unit` is the anomaly's unit (swe, soil_moisture are `"%"`), so `swe_max` moves `"mm"` → `"%"`.
- `peace_fwcp.rds` and `kootenay_lake.rds` carry `anomaly_type = "absolute"` and `unit = "mm"` on the swe_max rows of each `ano` and `trn` (regional, every ecoregion, every kootenay wsg). `meta_resolve()` prefers a carried type, so these would stay in mm. The bundled-data test in `test-cd_variables.R` compares units only where the types match, so it would pass on them silently.
- Only `regional` stores `bl`. The ecoregion and wsg entries hold `ts`/`ano`/`trn`/`cmp_pct`, so the patch has to rebuild the baseline from `ts`.
- `northern_bc.rds` has its own lookup and no `anomaly_type` tables, so it needs no regen. Its data-raw comment ("the registry calls swe_max absolute") becomes false.
- Precedent for a targeted patch is `data-raw/vignette_data_vpd_unit_patch.R` (#96). A full regen would pull newer catalog years and move every published number.

## Errors Encountered

| Error | Resolution |
|-------|------------|
| `test-cd_fetch.R:9` failed after the registry change: a second hardcoded pct_normal list that never names swe_max, so the swe_max grep missed it | Added swe_max; grep for the list's literal, not the variable |

## Patch check (2026-10-16 UTC)

- `data-raw/vignette_data_swe_max_type_patch.R` rebuilt 6 peace and 9 kootenay groups. The guard (re-run as absolute == stored rows) passed on all; a mutant with `baseline_years = 1952:1980` was refused before writing.
- Mann-Kendall p-values are identical for every group and slopes equal old × 100 / baseline (pct of normal is a positive linear rescale), so every significance statement in the vignettes still holds. Regional 1951 slopes: peace −0.0216 %/yr (p 0.77), kootenay −0.2928 %/yr (p 0.0042).
- Plan review: `review-plan.md`.
