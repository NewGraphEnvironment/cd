# Claims enumeration — vignettes/northern-bc.Rmd (#137, code-check rounds 2–3)

**Mechanism** (named by round 3): each sentence's check was written beside the sentence and tested the statistic that was to hand, usually the sign of one window mean. It did not test what the words quantify. The page's quantifiers ("little", "drier", "the same", "most", "the last three") had no shared definition. So sentences could contradict each other, and a last-three-years claim could rest on 2023 alone (annual precipitation: −17 / +2 / +3 % in the Bulkley).

**One rule now covers the whole page**, in `data-raw/northern_bc_vignette_data.R`:

- **Last three years:** a sentence holds only if the 3-yr mean **and** at least 2 of the 3 single years point its way (`last3_holds()`).
- **Quantities:** printed from the data ("5 % or less", "9 to 13 days", "55 % as deep"), never worded.
- **Scorecard tint:** needs both windows to agree **and** the 10-yr change to clear a band (0.5 °C, 5 days, 2 points, 5 %). Words like "only a little" are printed only when such a white cell exists.
- **"About the same":** asserted with a tolerance (0.2 °C; 3 points of snowpack share).

**How this enumeration was built (terminal):** every occurrence in the rendered text (`docs/articles/northern-bc.html`) of a quantifier or direction word was listed by regex: little, less, more, drier, wetter, warmer, cooler, sooner, earlier, smaller, same, most, almost, every, all, far, clearly, common, only, further, both, never, thirstier, down, swung, lower, higher. That gave 84 occurrences on 2026-10-14, each mapped below. Figure labels and scales were walked separately.

| Where | Words | Backed by |
|---|---|---|
| intro | all three clearly warmer | claims `warmer_both` (10 yr > 0; last-3 rule) and `every_recent_year_warm` (≥ 9 of 10 years above normal) |
| intro | hold less snow | `smaller_snowpack` (10 yr < 0; last-3 rule) |
| intro | melts sooner; summers thirstier | `melt_earlier`; `drier_summer_air` |
| intro, scorecard caption | 5 % or less over ten years | printed; `prcp_moved_little` (< 6 %) keeps the story |
| intro | last three years swung between dry and wet | `prcp_last3_swung` (each area has a year below and a year above normal) |
| scorecard caption | every watershed warmer, snow melts sooner, summer air drier | `warmer_both`, `melt_earlier`, `drier_summer_air` |
| scorecard caption | snowpack and summer soil moisture down everywhere | `smaller_snowpack`, `drier_summer_soil` (both windows < 0) |
| scorecard caption | in places only a little | printed only if a snowpack or soil cell is white (inside the band) |
| scorecard legend | orange / blue / white | definitional; the band rule above |
| scorecard cells | "N / N days earlier" | `melt_earlier` holds both windows < 0, so the words cannot invert |
| temperature heading and caption | almost every recent year warmer | `every_recent_year_warm` |
| temperature caption | warmer than any 1951–1980 year is now common (7 / 5 / 4) | `warmer_than_any_common` (≥ 3 each); counts printed |
| seasons heading and caption | every season warmer | `every_season_warmer` (10 yr, all four seasons) |
| seasons heading and caption | last three springs and summers drier, winters wetter | `spring_drier_last3`, `summer_drier_last3`, `winter_wetter_last3` (last-3 rule; the caption states the rule). "Winters warmed most" was dropped: 2025's winter warmed least |
| snow heading and caption | less snow, smaller, 9 to 13 days sooner | `smaller_snowpack`, `melt_earlier`; range printed |
| snow caption | spring rise earlier, less snow left for summer | cited (Stewart 2005, Kang 2016), `review-references.md` |
| snow caption | no recent year below the smallest normal snowpack | stopifnot `snow_low` |
| Bulkley caption | far less snow upstream | `bulkley_far_less_snow_upstream` (< 75 % of the lower) |
| Bulkley caption | both warmed by about the same amount | stopifnot \|Δ\| < 0.2 °C; `bulkley_both_warmed` |
| Bulkley paragraph | only 55 % as deep; 758 vs 1,055 mm | printed; stopifnot upper < lower for both |
| Bulkley paragraph | both lost about the same share (9 %, 8 %) | `bulkley_both_lost_snow`; stopifnot \|Δ\| < 3 points |
| Bulkley paragraph | fell further upstream; 25 % less | "further" or "less" chosen at render; `bulkley_summer_rain_less` |
| Bulkley paragraph | about the same warming and loss of snow, on a drier upper watershed | the stopifnots above (tmean, snowpack share, normal prcp and snowpack) |
| health table | less snow, 9 to 13 days sooner; warmer summers, drier air and soil | `smaller_snowpack`, `melt_earlier`, `every_season_warmer`, `drier_summer_air`, `drier_summer_soil` |
| health table and dryness paragraph | earlier, lower, warmer flows; fish; VPD; attribution | cited, with each source's region named |
| static | same calendar year; lower Bulkley; higher values; not only local weather | definitional, geographic or cited |

**Figures, walked separately:**

- **Temperature y-axis:** "°C warmer (+) or cooler (−)", two-sided.
- **Seasons facet label:** now two-sided (round 3).
- **Snow axes:** "% of normal" and dates, neutral.
- **Bulkley temperature scale:** `range(0, 2.5, data)`, so no cell is censored at either end (round 3; round 2 fixed only the top).
- **Bulkley snowpack scale:** unbounded.

Round 2's row 12 had a factual slip: the Parsnip's wet summer (+6 %) was 2025, not 2023.

**CLAUDE.md** now says the windows are derived from the data ("2016–2025 when written").
