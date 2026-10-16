# Code-check round 1: #146 branch (kootenay-lake vignette sentences)

Reviewer: subagent, 2026-10-16. Diff: `git diff merge-base...HEAD` over vignettes/ and data-raw/.

## What was verified (no issue)

- The claims block evaluated offline against the committed rds: all 16 claims TRUE.
- Every inline expression parses (16 of them), and the chunks parse after purl. Every binding an
  inline uses (`rng`, `fp`, `sm_*`, `t_cmp`, `er_num`, `wsg_p`) is defined in an earlier chunk
  and never reassigned. `ecoregions` is assigned only at lines 97-98.
- Rendered values match the rds: temp window "1.6 and 1.7" (tmax 1.56, tmean 1.65, tmin 1.66);
  soil "down 2.1 %", window p ≈ 0.062, trend p ≈ 0.04 / 0.0037; ecoregion rates "+0.23 and +0.30",
  deltas "1.5 and 1.9", prcp "6.4 and 7.0"; KOTL p 0.015, others "0.051 and 0.094"; snow caption
  -73 / -61 / +138 / +12 %. The vignette's fresh `cd_compare()` p-values equal the rds `cmp`
  p-values for every row, so the claim (rds) and the render (fresh) read the same number.
- Snow cover has no `cmp_pct` row, so "three of the monthly-native snow variables" is true. TOP
  (26 km², LARL 0.4 %) is in the overlap table and is filtered out of all three maps. Changing the
  filter from 50 to 100 changes nothing that is shown (TOP is 26 km²), and the guards in
  `vignette_min_km2()` still hold. Peace's Interpretation has four bold findings, so "Four" is correct.
- NA handling: every claim is NA-safe under `claims %in% TRUE`.

## Findings

- **[severity: fragile]** data-raw/kootenay_lake_vignette_data.R:178. `soil_significant_every_shown_1981`
  tests `mk_pvalue < 0.05` only, but the sentence it guards (kootenay-lake.Rmd:1050, "From 1981 the
  **decline** is significant in every ecoregion shown") also states a direction. A regen where one
  ecoregion's 1981 soil-moisture trend is a significant *rise* passes the claim and renders a false
  sentence. Proved in memory: flipping SBF's 1981 slope positive leaves all claims passing. Fix: add
  `all(slope < 0)` for the same rows. `er_p()` returns only p, so it needs a slope twin or a row return.

- **[severity: fragile]** data-raw/kootenay_lake_vignette_data.R:173-176, vs kootenay-lake.Rmd:287 and
  1045. Both sentences render "Soil moisture is down `r sprintf("%.1f", -sm_pct)` %" ("falling too:
  down X % between the two windows"), but no claim asserts that the window mean fell (`mean_a <
  mean_b`, or `regional_cmp_pct` soil `difference < 0`). `soil_declines_both_starts` checks the trend
  slopes, and `soil_window_not_significant` checks only the p. Window means can rise while the
  Theil-Sen slope stays negative. If they do, the page prints "down -1.2 %". Proved in memory: soil
  `mean_a` set above `mean_b` and `cmp_pct` difference set to +2, and all claims still pass. Fix:
  add `soil_window_down = regional_cmp_pct$difference[soil annual] < 0`.

- **[severity: fragile, low]** kootenay-lake.Rmd:280-283. This branch rewrote the regional temperature
  sentence, but its static words "with both window and trend p-values below 0.001" are not in
  `claims`. `temperature_p_below_0.001_every_shown` covers the per-ecoregion trend p-values, not the
  regional window or trend p. Today it is true (regional window p = 0, 1951 trend p = 0), so the
  sentence is not false now. The gap is that the guard the chunk comment implies does not exist for
  this sentence. The regional 1981 trend p-values sit at 0.0009 to 0.0012, so this is safe only
  while "trend" means 1951.
