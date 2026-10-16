## Outcome

`swe_max` (annual peak SWE) moved from `absolute` (mm) to `pct_normal` (%) in `cd_variables()`, matching `swe`, BC snow-bulletin practice and the northern-bc vignette; `CLAUDE.md` had already said `pct_normal`, and #48's original `absolute` was the side changed. The bundled `peace_fwcp.rds` and `kootenay_lake.rds` carried absolute swe_max rows that would have outlived the registry fix (a carried type wins in `meta_resolve()`), so `data-raw/vignette_data_swe_max_type_patch.R` rebuilt only those rows from each group's stored series, guarded by reproducing the stored rows with the old chain first, rather than a full regen that would have moved every published number. The bundled-data test now holds carried types to the registry as well as units. Both regional vignettes' swe_max figures are relabelled in percent; a Peace sentence that quoted annual mean SWE as "peak" was corrected. `cd_compare()` keeps `window_a = 2015:2025`, now described as the recent 11 years. Lessons: a second hardcoded pct_normal list (`test-cd_fetch.R`) never names swe_max, so grep for the list, not the variable; and `pkgdown::build_article()` renders against the installed cd's `inst/vignette-data`, so verifying a data patch needs the branch installed first.

## Measurement

Patch rebuilt 15 groups (peace 6, kootenay 9); only swe_max `ano`/`trn` rows changed. Mann-Kendall p-values identical in all 15; slopes = old × 100 / baseline mean. Regional 1951– slopes: peace −0.0216 %/yr (p 0.77), kootenay −0.2928 %/yr (p 0.0042). Patched anomaly range about ±54 %, below the ±200 cap. A mutant guard (`baseline_years = 1952:1980`) was refused before writing; the tightened test fails 60 expectations on the old data.

Spawned: cd#144 (prcp roll-up labelled mm/yr, is %/yr), fish_passage_peace_2025_reporting#49, fish_passage_fraser_2025_reporting#39, fish_passage_skeena_2025_reporting#20 (appendices hardcode mm for swe_max).

Closed by: PR (see branch `139-swe-max-anomaly-type-registry-says-absol`)
