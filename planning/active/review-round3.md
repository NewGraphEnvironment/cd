# Code-check round 3 — #139 (swe_max absolute/mm -> pct_normal/%)

Scope: the mechanism "a value carried on stored data outlives a registry fix".
Boundary: every tracked file in the cd repo (planning/ excluded), plus a local
grep of sibling checkouts under ~/Projects/repo for consumers of `swe_max`
(local disk only; not an org-wide code search).

## Findings

- **[severity: fragile]** downstream, outside this diff — `fish_passage_peace_2025_reporting/scripts/cd_inputs_snapshot.R:72-74`
  copies `cd`'s `inst/vignette-data/peace_fwcp.rds` into `data/gis/cd_peace.rds`
  as is. The patched file now carries swe_max anomalies in percent. That repo's
  appendix still hard-codes mm for those same rows:
  `0720-appendix-climate-departure.Rmd:352` (fig.cap "ERA5-Land mm snow water
  equivalent"), the `cd-facet-swe-max` chunk (~line 556: fig.cap "Bars are mm of
  water-equivalent snowpack departure", `labs(y = "Peak snow water equivalent
  anomaly (mm)")`). It is broken from the next snapshot refresh on (the script's
  own refresh procedure runs after a cd upgrade). From then on the bars and
  trend lines are % while the captions and axis say mm. Nothing errors.
  `cd_plot_timeseries()`'s own axis label will say "%", so the figure contradicts
  its caption. The repo is PUBLIC.
  The same applies, latent until regen, to `fish_passage_fraser_2025_reporting`
  and `fish_passage_skeena_2025_reporting`. Their `scripts/gis/climate_departure.R`
  (:301/:322 and :307/:328) rebuilds `ano` through `cd::cd_anomaly()` from the
  registry, so a regen under cd >= this release gives percent. Their appendices
  keep `labs(y = "Peak SWE anomaly (mm)")` (:650 / :712) and the fig.cap
  "ERA5-Land mm SWE" (:392). The currently committed rds in those repos still
  carry absolute/mm. `meta_resolve()` keeps the carried mm, so they render
  correctly today. Not fixable in this diff. It needs an issue in each of the
  three repos, or a line in the release note naming them, alongside the
  meta_check note already planned.

## In-repo inventory (every store holding something derived from cd_variables() for swe_max)

| store | carries swe_max type/unit? | state after this branch | matters? |
|---|---|---|---|
| `inst/vignette-data/peace_fwcp.rds` `$regional`/`$ecoregion$*` `ano`, `trn` | yes (`anomaly_type`, `unit`) | `pct_normal` / `%` everywhere (measured: all 6 groups, trn rows `trend_on = "anomaly"`) | consistent with registry |
| `inst/vignette-data/kootenay_lake.rds` `$regional`/`$ecoregion$*`/`$wsg$*` `ano`, `trn` | yes | `pct_normal` / `%` everywhere (all 9 groups) | consistent |
| same files, `ts`, `bl`, `cmp`, `cmp_pct` | no type/unit columns (`cmp` has `method` only; `cmp_pct` holds no swe_max) | raw mm values / mm window difference | correct: data unit; `cd_compare()` passes only `long_name` |
| `inst/vignette-data/northern_bc.rds` `lookup`, `scorecard` | `unit = "pct"`, `method`, no `anomaly_type` | own vocabulary, swe_max `pct_change` from `cd_compare()` (registry `pct_change` unchanged, TRUE) | independent of the change; skipped by the bundled-data test on purpose |
| `northern_bc.rds` `bulkley_parts` (`swe_max_normal_mm`, `swe_max_pct_last10`) | column names encode units | mm normal, percent change | correct |
| `inst/vignette-data/northern_bc_bulkley.tif` band `swe_max_normal` | no unit tag (gdalinfo) | raw mm | correct |
| `inst/vignette-data/*_departure_tmean.tif`, `inst/extdata/example_climate.tif`, `example_daily/*` | no swe_max | — | n/a |
| `inst/extdata/example_catalog.json` | one tmean item; STAC props are `cd:variable`/`cd:period` only | — | n/a |
| STAC writer `R/cd_stac_catalog.R` | reads `cd_variables()$variable` only (filename parsing); writes no unit/anomaly type | — | live catalog unaffected |
| producer `scripts/backfill_edh_snow.py` | writes values in mm; no registry read, no unit tag for swe_max | — | correct (COG holds data, mm) |
| `scripts/pipeline_*_edh.R`, `scripts/_lib.R`, `scripts/test_lib.R` | name lists only | — | n/a |
| `inst/extdata/peace_wsg_ecoregion_commentary.csv` | no snow content | — | n/a |
| `tests/testthat/_snaps/` | empty, nothing tracked | — | n/a |
| test fixtures | only `test-cd_fetch.R` / `test-cd_variables.R` name swe_max, both updated; `test-cd_compare.R` moved to `snowmelt_rate_peak` | — | n/a |
| no `R/sysdata.rda`, no `data/`, no committed `docs/` | — | — | n/a |
| vignette prose | Kootenay "peak SWE dropped 92 mm (-16%)" is a raw window difference (`cmp`), not an anomaly | unchanged by the patch | correct |
| `NEWS.md:3` ("vpd, swe_max and snowmelt_rate_peak are absolute") | prose | under released `# cd 0.6.9` (tag v0.6.9) | historical entry; correct for that release |

Live paths the vignettes run at render time against the patched rds
(`cd::cd_trend(ano[...])` in `snow-annual`, `cd_summary(trn_tbl)`): both read
the carried `pct_normal`/`%`, so they agree with the new figure labels.

Verdict for the cd repo itself: clean. The one exposure is the three downstream
report repos above, which consume the bundled rds directly (Peace) or rebuild
through the registry (Fraser, Skeena), and which hard-code mm.
