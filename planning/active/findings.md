# Findings — Kootenay vignette: five sentences inherited from Peace contradict the Kootenay data (#146)

## Issue context

**If we do it:** every sentence in the Kootenay Lake article agrees with the numbers it renders. **If we never do:** the article states five things its own tables contradict, and the fish passage report appendices ported from it inherit them.

## Problem

The Kootenay Lake vignette was templated from the Peace one, and several sentences that are true for Peace are false for Kootenay. Each was measured against the committed `inst/vignette-data/kootenay_lake.rds` (v0.6.10); line numbers are as of the #102 branch's merge, with the sentence quoted so a shifted line can still be found.

1. **Soil moisture is not flat.** `vignettes/kootenay-lake.Rmd:273` ("Soil moisture is roughly flat") and `:992` ("Soil moisture is essentially flat despite the precipitation decline"). The regional annual trend is negative and significant: 1951 slope −0.029 %/yr, Mann-Kendall p = 0.040, and p = 0.004 from 1981. By ecoregion, NCM (p 0.041) and PTR (0.016) are significant from 1951, and all four are significant from 1981 (p 0.002–0.02).
2. **PTR is outside the stated warming range.** `:964` says "All four ecoregions warmed between +1.6 °C and +1.9 °C". The annual tmean window differences (2015–2025 minus 1951–1980) are NCM 1.60, SBF 1.88 and **PTR 1.49**; TOP (1.71) is not shown in the article (item 5).
3. **"Three findings" introduces four.** This is at `:962`, and in Peace at `peace-fwcp.Rmd:854`: four bold findings follow in each.
4. **The WSG drying is consistent in direction, not in strength.** `:977-979` says all four watershed groups sit "in the same drying signal". All four annual prcp slopes from 1951 are negative, but only KOTL is significant (p 0.015); DUNC is 0.094, LARL 0.054 and SLOC 0.051.
5. **The prose counts four ecoregions; the article shows three.** `kootenay-lake.Rmd:98` keeps ecoregions over 50 km², so Thompson-Okanagan Plateau (TOP, 26 km², about one ERA5-Land cell) is left out of every per-ecoregion trend figure and the roll-up table. (The WSG × ecoregion overlap table does list it, as `TOP %`, since its data comes from the unfiltered set.) Peace uses 100 km² (`peace-fwcp.Rmd:92`; since #102 the Peace data script reads that threshold from the vignette rather than restating it). The Kootenay data script has no filter, so TOP is in the rds but never shown. "Four ecoregions" survives where only three are shown: `:614` ("All four ecoregions warmed at roughly the same rate"), `:964` ("All four ecoregions warmed between") and `:976` ("consistent across all four ecoregions of the AOI"). (`:886`, "They span the four ecoregions", introduces the overlap table, which does show four.) The #102 branch already fixed the prcp captions and the intro (`:603-611`), which now says TOP is left out.

(An earlier version of this item said the Kootenay article had no area filter. That was wrong: the filter is in the vignette, not the data script.)

## Proposed Solution

- Rewrite sentences 1–4 from the data. Prefer inline numbers or a `data-raw` assertion, as `northern-bc.Rmd` does, over static text.
- Make the count in the prose follow the filter (three ecoregions shown), and decide whether the two articles share one area threshold.

Found by the plan review for #102.






## Measured against committed kootenay_lake.rds (2026-10-16)

All issue numbers reproduce. Additional values:

- Regional soil_moisture: window Δ −2.13 % (pct_change), window p 0.062 (Welch); trend 1951 slope −0.0294 p 0.040; 1981 slope −0.0947 p 0.0037.
- Ecoregion soil_moisture trend p, 1951 / 1981: NCM 0.041 / 0.0055, SBF 0.108 / 0.0044, PTR 0.016 / 0.0020, TOP 0.297 / 0.020.
- Ecoregion tmean window Δ (°C): NCM 1.60, SBF 1.88, PTR 1.49, TOP 1.71. 1951 slope °C/dec: 0.253, 0.303, 0.228, 0.276; all p < 0.001.
- Ecoregion prcp window Δ %: NCM −6.4, SBF −6.6, PTR −7.0, TOP −3.1.
- WSG prcp 1951 slope / p: DUNC −0.091 / 0.094, KOTL −0.143 / 0.015, LARL −0.113 / 0.054, SLOC −0.118 / 0.051.
- Ecoregion areas (km²): Kootenay TOP 26, PTR 495, SBF 4201, NCM 19445; Peace PRB 66 (dropped at 100), smallest kept NRM 9109. A 100 km² Kootenay filter shows the same three as 50.

## Phase 6 sweep — remaining quantified sentences (measured 2026-10-16, committed rds)

| sentence | verdict |
|---|---|
| Trends: "1.6 to 1.8 °C warmer … tmean/tmax/tmin, window and trend p < 0.001" | true (1.56 / 1.65 / 1.66; all p < 0.001) |
| "VPD up significantly on both tests"; "RH small significant decline" | true (VPD p < 0.001 both; RH window 0.0003, trend 0.0006) |
| "precipitation 6 to 7 % lower … trend p ≈ 0.02" | true (−6.5 %, p 0.021) |
| tmax/tmin: "+0.024 °C/yr (+1.8)", "+0.027 (+2.0)", "roughly 0.2 °C more" | true (0.0245 / 1.81; 0.0271 / 2.01; gap 0.19) |
| Snowpack: SWE −23 % (206 → 160), snowfall and snowmelt ~15 %, DOY-50 12.6 d, peak SWE −92 mm (−16 %) | true |
| **Seasonal table caption: "Summer SWE collapse (−75%) and spring snowmelt rise (+37%)"** | **false — Peace's numbers.** Kootenay: summer SWE −72.9 %, spring snowmelt +12.1 % (winter snowmelt +138 %). Caption now computed inline; claims `snow_summer_largest_losses`, `snowmelt_winter_spring_rose` |
| **"The headline numbers above (summer SWE collapse, spring snowmelt rise)"** | **false** — the Kootenay text above the table states neither. Rewritten |
| "Summer SWE collapsed by 73 % and summer snowmelt is down 61 %" | true (−72.9, −60.9) |
| Spatial: departure "+1.2 °C to +2.2 °C, regional mean near +1.7 °C" | true (1.24 / 2.19 / 1.65) |
| Spatial: "Higher-elevation pixels tend to show stronger warming" | not checked: needs a DEM, which the vignette data does not carry |
| Per-ecoregion "VPD is up significantly across the region" | true in every ecoregion shown (p < 0.001) |
| Roll-up caption "All temperature p-values are below 0.001" | true; now asserted (`temperature_p_below_0.001_every_shown`) |
| WSG text/caption: KOTL, DUNC, SLOC "almost entirely" / "essentially" NCM; LARL the only meaningful split | true (DUNC 99.8, SLOC 99.8, KOTL 93.8 + PTR 5.2; LARL NCM 37.5 / SBF 62.1) |
| Interpretation "no warming hot-spot at the ecoregion scale" | judgment, left: ecoregion window Δ 1.5–1.9 °C, now printed inline beside it |
| Interpretation "freshet-timing shift … in all four watershed groups; not concentrated in any one ecoregion" | true (DOY-50 1951 trend p ≤ 0.002 in every WSG; window Δ −11.1 to −13.8 d across ecoregions) |

Static numbers that are true today (tmax/tmin rates, snow percentages, spatial range) are not inline: a full regen would move them, which is the article's existing state and the job of a regen's patch script, not this issue.

## Errors Encountered

| Error | Resolution |
|-------|------------|

## Plan review (review-plan.md) — dispositions

- Three more false or overstated sentences fixed: "1.6 to 1.8 °C" (actual 1.6 to 1.7, now inline); "four monthly-native snow variables" (the table shows three); "arriving weeks earlier" (12.6 d → "nearly two weeks"); summer snowpack "no longer does" (27 % remains → "about a quarter"); "roughly the same rate" / "no warming hot-spot" reworded beside the printed 0.23–0.30 °C/dec range.
- Guards added: `prose_states_filter` (the intro's "Ecoregions under N km²" must match the filter; fired when the filter was set back to 50), `prcp_window_down_every_shown`.
- `fp()` now 2 significant figures, so a p of 0.046–0.049 cannot print as "≈ 0.05" beside "significant".
- Snow-station numbers (74 station-years, 40–63 % low, r = 0.90) come from `data-raw/qa_snow_validation_kootenay_lake.R`, not the rds; not re-derived here.
- Not fixed, recorded: patch scripts (`data-raw/vignette_data_*_patch.R`) write `kootenay_lake.rds` without running the claims block, so the guards cover a full regen only. The `per-ecoregion-reshape` comment "already by area_km2 desc on disk" is wrong (gpkg order TOP, SBF, NCM, PTR) but harmless, and outside this diff.
- Peace "cumulative since 1951" range is window Δ, not slope × years: reproduced, filed as #148.

## Code-check enumeration — every static word the branch added, and what guards it

Rounds 1 and 2 found one mechanism twice: a claim checked significance or order but not the sign the sentence states, and round 2's instances sat inside round 1's "every claim" fix. Enumerated from every `+` prose/caption line of `git diff merge-base...HEAD -- vignettes` that carries a quantity, direction or set word (grep over the branch diff, 2026-10-16). Numbers printed inline are not listed: they cannot disagree with the data they are computed from.

| added words (Rmd) | guard |
|---|---|
| Trends: "warmer … mean, max, min", "window and trend p-values below 0.001" | `regional_temperature_warmer_p_below_0.001` (window Δ > 0, window p, 1951 slope > 0, trend p) |
| "Soil moisture is down" (twice) | `soil_window_down` |
| "too small a step for the window test" / "cannot separate from noise" | `soil_window_not_significant` |
| "the trend test finds a steady decline" / "significant long-term decline" from 1951 and 1981 | `soil_declines_both_starts` |
| "From 1981 the decline is significant in every ecoregion shown" | `soil_significant_every_shown_1981` (p and slope < 0) |
| "Three of the monthly-native snow variables — SWE, snowfall and snowmelt" / "snow cover … has no percent change" | `snow_cover_has_no_pct_change` (the table reads `cmp_pct`, which `pct_normal_vars` builds without snow_cover) |
| "Relative humidity shows a small significant decline" (re-wrapped line) | `rh_declines_significantly` (window and 1951 trend: sign and p) |
| "(trend p ≈ 0.02)" for precipitation (re-wrapped line, words unchanged from main) | static number, true today (0.021): the static-number tradeoff |
| "winter and spring snowmelt rose" (prose and caption) | `snowmelt_winter_spring_rose` |
| caption "carry the largest losses" | `snow_summer_largest_losses` (two lowest and < 0) |
| summer snowpack "now holds about a quarter" | `summer_swe_about_a_quarter` (−78 < Δ < −70 %: 22–30 % remains) |
| "Ecoregions under 100 km² … so they show three" | `prose_states_filter`, `shown_are_ncm_sbf_ptr` |
| "All three ecoregions shown warmed, at rates …" | `temperature_p_below_0.001_every_shown` (slopes > 0) |
| "TOP … appears only in the table" | accepted: fixed by the context gpkg's geometry (TOP 26 km², in LARL), which a data regen does not change |
| "between … °C warmer in 2015–2025", "differ by a few tenths of a degree" | `ecoregion_window_warmer_few_tenths` (Δ > 0; 0.15 ≤ spread < 0.6 °C and under half the smallest Δ; 0.39 today) |
| "p-values below 0.001 in every ecoregion" | `temperature_p_below_0.001_every_shown` |
| "Spatially the decline is consistent across the three ecoregions shown, down between" | `prcp_window_down_every_shown` |
| "points down in all four" | `wsg_prcp_declines_everywhere` (4 rows, slopes < 0) |
| "only in KOTL is it statistically significant … DUNC, LARL and SLOC it is not" | `wsg_prcp_significant_kotl_only` |
| "arriving nearly two weeks earlier" | `doy50_nearly_two_weeks_earlier` (−14 < Δ < −11.5 d) |
| "Four findings" (both articles) | structural: four bold findings follow in each |

Every row has a guard or a stated reason. Significance words are tested on the p-value as printed (`signif(p, 2)` for `fp()`, `round(p, 3)` for the WSG p), so a p of 0.0496 cannot print "0.050" beside "significant". Harness: 27 perturbations, one or more per claim, each fires where the words turn false; perturbing TOP (not shown) passes, and SLOC at p 0.0501 passes correctly (it prints 0.050 under "it is not").

Round 3 audited this table and found three bounds that admitted false words ("a quarter" took a third, "nearly two weeks" took 10 d, "a few tenths" took 0), two missed rows (RH, the static prcp p) and a wrong guard named for snow cover; fixed above.
