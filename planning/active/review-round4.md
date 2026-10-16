# Code-check round 4: terminal check of the enumeration (#146)

Reviewer: subagent, 2026-10-16. Repo tree not edited. Harness: the claims block (lines from
"# -- Sentences the vignette states" to "# -- Spatial pattern raster") extracted and eval'd
in a fresh env per perturbation, from the package root, with the setup in the brief. The
scripts are in the scratchpad `r4/` (`setup.R`, `today.R`, `perturb.R`, `p2.R`, `p3.R`).

(a) Every claim passes today's rds. The rds `regional$cmp` p-values and differences equal
the current `cd_compare(ts)` defaults exactly (max |diff| 0), so the claims read the same
numbers the page prints.

43 perturbations: 37 behave as intended, 6 do not (rows 1, 3, 6, 7, 32, 34/35 below), plus
the printed-spread probe in `p2.R`. The Rmd-copy probes for `shown_are_ncm_sbf_ptr` and
`prose_states_filter` fire as intended (filter set to 20: both fail; prose reworded: the
filter claim fails).

## Findings

- **[bug]** data-raw/kootenay_lake_vignette_data.R:214-216 —
  `regional_temperature_warmer_p_below_0.001` tests the raw p, but the only place the page
  prints these p-values is the compare table, which prints `round(p, 3)`
  (vignettes/kootenay-lake.Rmd:304 `trend_p`, :323 `window_p`). p is stored at 4 dp, so a
  p of 0.0006–0.0009 prints as `0.001` beside "both window and trend p-values below
  0.001", and the claim passes. Perturbation: tmax window p 0.0007 gives PASS (should fail),
  and tmin 1951 trend p 0.0008 gives PASS (should fail). 0.0004 prints `0` and correctly
  passes. This is round 3's printed-value mechanism, which the fix did not carry to this
  row. Fix: `all(p_dp3(temp_window$p_value) < 0.001) && all(p_dp3(temp_trend$mk_pvalue) < 0.001)`.
  Today every value is 0, so the fix does not change the verdict.

- **[bug]** data-raw/kootenay_lake_vignette_data.R:227-228 — `rh_declines_significantly`
  (added in round 3) tests the raw `p_value < 0.05` and `mk_pvalue < 0.05`. The page prints
  RH's p-values only in the compare table, as `round(p, 3)` (Rmd :304, :323). Window p 0.0497
  and trend p 0.0495 both print `0.050`, which the article's own rule reads as not
  significant, beside "a small significant decline". The claim passes both: harness rows 6
  and 7 give PASS where they should fail. This is the round-3 fix's mechanism again, inside
  the row round 3 added. Fix: use `p_dp3()` on both p-values. Today's values are 0.0003 and
  0.0006, so the verdict does not change.

- **[bug]** data-raw/kootenay_lake_vignette_data.R:255-257 —
  `ecoregion_window_warmer_few_tenths` tests the raw spread (`>= 0.15`). The reader sees the
  printed range `rng(er_num$delta, "%.1f")`, one sentence before "the ecoregions differ by a
  few tenths of a degree" (Rmd :1017-1021). In `p2.R`, deltas 1.75/1.84/1.66 (spread 0.18)
  and 1.70/1.849/1.651 (spread 0.198) both PASS and print "between 1.7 and 1.8 °C warmer":
  one tenth apart on the page. Fix: test the printed values,
  `diff(range(round(er_tmean_window, 1))) >= 0.2`, keeping the upper bound and the
  half-of-minimum test. Today's printed range is 1.5 and 1.9, so this passes.

- **[fragile]** data-raw/kootenay_lake_vignette_data.R:249-250 —
  `summer_swe_about_a_quarter` (−78 < Δ < −70) still admits values whose remaining share is
  nearer another simple fraction:
  - At Δ −70.5, 29.5 % remains, nearer a third (33.3) than a quarter (25). The crossover is
    29.2 %, Δ −70.8.
  - At Δ −77.8, 22.2 % remains, nearer a fifth. The crossover is 22.5 %, Δ −77.5.

  Harness rows 34 and 35 PASS. Tighten to `> -77.5 && < -70.8` if "about a quarter" is meant
  as the nearest simple fraction. Today's value is −72.9 (27 % remains).

- **[fragile]** sign words are checked on raw values, while the page prints rounded numbers
  beside them:
  - `snowmelt_winter_spring_rose` (:260) passes spring snowmelt at +0.4. The caption then
    reads "spring (+0%) snowmelt rose": `pct_of()` is `sprintf("%+.0f%%")` of the value
    rounded to 1 dp. This is harness row 32.
  - `soil_window_down` (:207) and `prcp_window_down_every_shown` pass −0.04, which prints
    "down 0.0 %".

  Today these values are far from the threshold (+12 %, +138 %, −2.1 %, prcp −6 to −8 %),
  so this is low priority. The same printed-value test would close it: `round(x, 0) > 0` for
  the caption and `round(x, 1) < 0` for the two "down" sentences.

- **[fragile]** Missed word: "small" in "Relative humidity shows a small significant
  decline" (Rmd :287-288, a re-wrapped `+` line). The enumeration's RH row guards the sign
  and p but not "small", and nothing bounds the magnitude. Today the window difference is
  −2.56 % points. Either add a bound or record it under the static-word tradeoff for
  re-wrapped lines, as the table does for "(trend p ≈ 0.02)".

## Round-3 changes re-checked

- `p_sig2()` is `signif(p, 2)`, which is identical to `fp()`'s `format(signif(p, 2))`. Correct.
- `p_dp3()` (`round(p, 3)`) and the Rmd's `sprintf("%.3f")` disagree on 41 of the 999 4-dp
  values 0.0001–0.0999: the x.xxx5 ties, for example 0.0005 rounds to 0 but prints `0.001`.
  They never disagree on the < 0.05 decision, because 0.0495 is `0.050` both ways. The WSG
  claim is therefore sound, and harness rows 23-25 behave as intended. For the compare table,
  `p_dp3` is exactly the table's own `round(p, 3)`.
- The RH rows read the right tables. `rh_window` comes from `regional_cmp` (the mean_diff
  method with default windows), which equals the table's `cd_compare(ts)`, and `rh51` is the
  table's 75-yr column. Only the raw-p issue above remains.
- New bounds:
  - "nearly two weeks" (−14, −11.5): fires at −10 and −14.5, and passes −13.
  - "a few tenths": fires at a spread of 0. Its lower bound still reads raw rather than
    printed values (above).
  - "a quarter": fires at −66.7. Its edge cases are above.
- `snow_cover_has_no_pct_change` fires when a snow_cover row is added.

## Enumeration completeness

Independently derived from the diff's `+` prose and caption lines. Every quantity, direction
and set word maps to a row except:

- "small" (above).
- "Daily maximum, daily minimum, and daily mean temperatures all tell the same story"
  (re-wrapped `+` line). It is covered in substance by
  `temperature_p_below_0.001_every_shown`, which checks the sign and p for all three, but the
  table has no row for it.

"TOP … appears only in the table", "too small to draw" and "left out of the maps" all hold.
The WSG map draws the filtered `ecoregions`, and the overlap table is the only place TOP
renders. Peace's Interpretation has four bold findings.

## Outside the diff (pre-existing, for the record)

`prcp_significant_ncm_ptr` and `prcp_none_significant_1981` (:198-200) test raw p. The
roll-up prints `prcp p` as `round(p, 3)`, so the same printed-value gap exists on the
#102 caption claims. This is not a `+` line.
