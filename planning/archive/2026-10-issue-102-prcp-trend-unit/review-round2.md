## Findings

Round 2, branch 102-vignettes-per-ecoregion-prcp-trend-is-of (HEAD 76c572a). No bugs. Two low-severity items:

- **[severity: fragile]** data-raw/kootenay_lake_vignette_data.R:106-113 — the caption-claim block does not check the count in "Precipitation declines in all four ecoregions". `all(p51$slope < 0)` holds for any number of ecoregions, and the `setequal()` on the significant set still holds if a non-significant ecoregion is added or dropped. So if `context_kootenay_lake.gpkg` (rebuilt by `data-raw/example_context_kootenay_lake.R`, with no area filter here, unlike Peace's `> 100` km2) ever yields three or five ecoregions, the block passes while "all four" and "not in SBF or TOP" are false. The fix is one more claim: `prcp_four_ecoregions = setequal(names(ecoregion_results), c("NCM", "SBF", "PTR", "TOP"))`. Today the set is exactly NCM/SBF/PTR/TOP, so the shipped caption is true.
- **[severity: fragile]** planning/active/findings.md:51 — says the slope is "percentage points of the 1951-1980 normal per year, which is what the new column header (`prcp %/yr`) and caption say". Since 76c572a the caption says "percent of the 1951-1980 baseline mean per year", so this sentence (which goes to the public archive) is now false about the vignette. It is the same stale wording that review-plan.md item 2 asked to remove. task_plan.md:17 keeps the old wording too, but there it reads as the Phase 1 record, with Phase 4 recording the change.

## Verified (no issue)

- **Assertion blocks run against the committed rds.** I put each `ecoregion_results` read from `inst/vignette-data/*.rds` into a fresh env and sourced the block (Kootenay lines 93-118, Peace lines 76-95). Every claim is TRUE.
  - Kootenay, 1951 (slope, p): NCM -0.121, 0.030; SBF -0.110, 0.061; PTR -0.141, 0.010; TOP -0.063, 0.356.
  - Kootenay, 1981 p-values: 0.278, 0.140, 0.323, 0.343.
  - Peace: BMP +0.144, p 0.023 and NRM +0.156, p 0.015. OMM, CRM and FAB have p > 0.25.
- **Each claim maps to its caption clause.**
  - "declines in all four" maps to every 1951 slope < 0 (apart from the count gap above).
  - "significant in NCM and PTR, not in SBF or TOP" maps to `setequal()` of the p < 0.05 set.
  - "None of the 45-year trends is significant" maps to every 1981 prcp p >= 0.05. Every 1981 row has `n_years` = 45, and every 1951 row has 75.
  - Peace "BMP, NRM significant increases; the others do not" maps to `setequal()` plus slope > 0.
  - Both blocks filter on `variable == "prcp"`, `period == "annual"` and the right `trend_start`, and `stopifnot(nrow(r) == 1)` holds on both rds (each `trn` has one annual prcp row per start).
- **Fails closed.**
  - An NA p-value puts an NA into the subset, so `setequal()` is FALSE.
  - An NA in `all()` makes `if (!NA)` error, so the script still stops (with a less specific message).
  - A missing ecoregion trend makes `stopifnot()` fire.
  - The `< 0.05` / `>= 0.05` boundaries are complementary.
- **Threshold.** The vignettes state no alpha anywhere (grep for 0.05, `p <` and 95 in both Rmd finds none). p < 0.05 matches how the prose already treats the regional trend p of about 0.02 as significant. SBF at 0.061 is "not significant" under that threshold, consistent with the rollup's `prcp p` column.
- **Name collisions.** `p51`, `p81`, `claims` and `prcp_trend` appear nowhere else in either script. The local `t` shadows `base::t` only inside the closure. Both blocks sit before `saveRDS()`, after `ecoregion_results` is defined.
- **Roll-up caption wording.** `R/cd_anomaly.R:137-138`: a `pct_normal` anomaly is `value / baseline_mean * 100 - 100` (capped at ±cap_pct, which does not bind for annual prcp). The baseline is 1951:1980 in both data-raw scripts, so a Theil-Sen slope on it is a percent of the 1951-1980 baseline mean per year. "Baseline" matches the figure captions' "% of the 1951-1980 baseline".
- **Recipe `method = "pct_change"`.** It is a valid `match.arg` value in `cd_compare()`. The bundled `cmp_pct` is built with `method = "pct_change"` (on the `pct_normal_vars` subset), and the rollup reads only the prcp and soil_moisture `difference` from it, so the shown recipe reproduces those columns. On the full `ts`, the recipe would also warn and give NA for tmean and similar rows (#138), but the chunk is `eval = FALSE` and those rows are unused, so this is not a defect.
- **Facet-prcp line types.** The dashed/solid assignment follows the alphabetical window levels ("1951–2025" before "1981–2025"), so dashed is the 75-year line, as the caption says. Prcp anomaly years run 1950-2025 for all four Kootenay ecoregions.
- **Downstream issues and cd#146.** cd#146 exists, is open and is titled for the out-of-scope Kootenay prose. The bodies of fish_passage_peace_2025_reporting#50 and fish_passage_skeena_2025_reporting#21 carry the final "percent of the 1951-1980 baseline mean per year" wording.

/Users/airvine/Projects/repo/cd/planning/active/review-round2.md
