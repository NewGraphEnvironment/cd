# Code-check round 3 — #146 branch (enumeration audit)

Reviewed 2026-10-16 against `branch.diff` (merge-base...HEAD). Claims block evaluated offline from the committed rds: all 21 claims TRUE today. Perturbations run on in-memory copies only; the repo tree was not edited.

## Findings

- **[fragile]** data-raw/kootenay_lake_vignette_data.R:236-237 (`summer_swe_about_a_quarter`) — the bound does not match what the words claim. −80 < Δ < −67 % means summer SWE now holds 20–33 % of the baseline, so the claim passes for "a fifth" and for "a third" as well as "about a quarter". Perturbation: summer SWE Δ set to −67.5 % (32.5 % remains) and all claims still pass. A band that "about a quarter" actually covers is roughly −78 < Δ < −70 (22–30 % remains). Today's value is −72.9 %.

- **[fragile]** data-raw/kootenay_lake_vignette_data.R:243 (`doy50_nearly_two_weeks_earlier`) — −14 < Δ < −10 d accepts 10 days, which is not "nearly two weeks". The article also cites Kang et al.'s "~10-day" Fraser advance as a comparison, so at 10 d the two would be the same shift described in different words. Perturbation: Δ = −10.2 d and all claims pass. The lower edge should sit near −11.5 to −12 d. Today's value is −12.6 d.

- **[fragile]** data-raw/kootenay_lake_vignette_data.R:240-241 (`ecoregion_window_warmer_few_tenths`) — the claim has no lower bound, so it fails toward pass. "The ecoregions differ by a few tenths of a degree" asserts a spread of about 0.2–0.6 °C, but the claim checks only `spread < 0.6`. Perturbation: all three ecoregion tmean window deltas set to 1.60, giving a spread of 0, and all claims pass. The article would then render "between 1.6 and 1.6 °C warmer … the ecoregions differ by a few tenths of a degree". "Small beside the warming itself" is also untested, since nothing relates the spread to `min(er_tmean_window)`. Today the spread is 0.39 and the deltas are 1.49–1.88.

- **[fragile]** planning/active/findings.md "Code-check enumeration" — the enumeration is incomplete against its own method (every `+` prose line with a quantity, direction or set word). Two re-wrapped lines are `+` lines and do not appear in it:
  - `kootenay-lake.Rmd:286-287`, "Relative humidity shows a small significant decline": a direction word and a significance word, with no claim. It is true today: window Δ −2.56, p 0.0003; 1951 trend slope −0.040, p 0.0006.
  - `kootenay-lake.Rmd:283`, "(trend p ≈ 0.02)": a static number. It is true today (0.0206) and is arguably covered by the "static numbers already in the article" tradeoff, but the table should say so.

  A further row is listed as guarded by a check that cannot fire for it. "Three of the monthly-native snow variables … (snow cover … has no percent change)" names `stopifnot(length(snow_season_pct) == 12)` as its guard, but `snow_season` filters to swe/snowfall/snowmelt before counting. Snow-cover rows in `regional_cmp_pct` would reach the table (its `snow_monthly` includes `snow_cover`) and never reach the stopifnot. It is safe only because `pct_normal_vars` in the same script excludes snow_cover, so the row should name that, not the stopifnot.

- **[fragile]** vignettes/kootenay-lake.Rmd:1024-1025 and :280, :1047-1049 — the guards cut at p < 0.05 on the unrounded value, but the prose prints the rounded one. A KOTL p of 0.0496 passes `wsg_prcp_significant_kotl_only` and renders "statistically significant (p 0.050)". A DUNC/LARL/SLOC p of 0.0501 renders as "0.050" under "it is not". The same holds for `fp()` (2 significant figures) on the soil trend p: 0.046 renders "significant … trend p ≈ 0.046", but 0.0496 renders "≈ 0.05". The rendered sentence then contradicts itself on its own number. It is unlikely at today's values (0.015 vs 0.051–0.094; 0.040), but the nearest non-KOTL p (SLOC 0.0513) is 0.0013 from the edge.

## Checked and sound

- Sign, set and threshold, row by row, for every other claim in the enumeration. Each reads the table, column, period and `trend_start` the rendered sentence reads: regional `trn` 1951/1981; `regional_cmp` equals `cd_compare(ts)` exactly (max |Δ| 0 on difference and p_value); `regional_cmp_pct` soil −2.135 equals the Rmd's `sm_pct`; per-ecoregion `cd_compare` defaults equal `er_num$delta`; WSG prcp is 1951.
- Fail-open paths. An NA claim fails closed through `%in% TRUE`; `&&` with NA gives NA or FALSE, never TRUE. A missing `[[` name errors. No claim can be length 0, which would let `c()` drop it silently: each scalar input has a `stopifnot(length == 1)` or `NROW == 1`. `sort()` dropping NA can only make `snow_summer_largest_losses` FALSE. A `vapply` over an empty `shown` returns `numeric(0)`, so `all()` gives TRUE, but `shown_are_ncm_sbf_ptr` is FALSE in that case.
- The 50 → 100 km² filter change. Areas are TOP 26, PTR 495, SBF 4201 and NCM 19445, so nothing lies between 50 and 100, and "here TOP" and "show three" hold.
- "Four findings", in both articles: four bold findings follow in each. The three bold knock-on sentences after them are not findings.
