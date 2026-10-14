# Code-check round 2: #137 northern BC vignette

Reviewer: subagent, 2026-10-14. Checked against the bundled `inst/vignette-data/northern_bc.rds`, `northern_bc_bulkley.tif`, the rendered `docs/articles/northern-bc.html`, and the round-1 fixes patch. I changed no repo file except this one.

## Round-1 fixes: verdicts

- (1) Ocean wording: now true. The AOI `drains_to` is Pacific/Pacific/Arctic, and the map caption agrees.
- (2) "Not just their average": true. The figures show each of the last 3 years, and the scorecard shows their average.
- (3) Base R pivot: correct. `tab` has automatic row names (`.row_names_info = -7`), so kable adds no stray row-name column, and the rendered table has 4 header cells.
- (5) Reproduce chunk: renders as `2016:2025` / `1951:1980` in the HTML. The `code =` option works under `eval = FALSE`.
- (6) Research wording: fine. Its table values match the rds (1.94/1.74/1.57 °C, −12.2 %, 13.2 d, 7).
- (4) Claims block: its predicates are coded correctly, and every one is TRUE on the bundled data. But it does not cover every sentence, and one claim tests a different window from the one its sentence uses (findings 1 and 3).

## Findings

1. **[bug] vignettes/northern-bc.Rmd:217 (heading "recent summers were dry"), with data-raw/northern_bc_vignette_data.R:217-218 (`spring_summer_drier_last3`)**
   The claim tests the last-3 average only. Elsewhere on the page, "recent" means the last 10 years: `every_recent_year_warm` ("Almost every recent year", temperature caption) and `snow_low` ("No recent year fell below", snow caption) both test `last10`. Over the last 10 years, summer rain was *wetter* than normal in the Bulkley (+4.7 %) and the Parsnip (+10.0 %). Those two scorecard cells are white, and the large "2016–2025 average" dots directly under this heading sit above zero in the summer rain panel for 2 of 3 watersheds. So the heading is unscoped, it is false under the page's own meaning of "recent", and the visually dominant marks contradict it. The caption scopes its version ("over the last three years ... springs and summers were drier"); the heading does not. Either scope the heading to the last three years, or make the claim test what the heading says.

2. **[bug] vignettes/northern-bc.Rmd:351, "It is the same change, landing on a drier upper watershed."**
   The sentence before it says summer rain over the last 3 years fell **25 %** upstream against **14 %** below Houston. That is almost twice the drop, chosen dynamically as "further". So the antecedent of "It" is a change the data shows was *not* the same. The stopifnot at data-raw/...R:147-152 backs "same" only for warming (<0.2 °C apart) and snowpack share (<3 points apart), not summer rain. Name what is the same (the warming and the snow loss), or drop "same" after the summer-rain sentence.

3. **[fragile] Sentences with no matching claim, so a regen can turn them false silently.** Each was walked against the `claims` block, the `stopifnot`s and the inline code:
   - Temperature caption (Rmd:182), "a year warmer than any in 1951–1980 is **now common**: 7 … 5 … 4". Nothing asserts a floor on `warm$n_last10_warmer`. It is 4 for the Parsnip now, and research/baseline_period.md shows how fast this count moves. A regen giving 0–2 prints "is now common: 1 of the last 10".
   - Bulkley paragraph (Rmd:343-344), "it warmed by X °C and the lower Bulkley by Y °C". `r1()` takes `abs()`, and no claim asserts `bulkley_parts$tmean_change_last10 > 0`. `warmer_both` covers only BULK/NECR/PARS, and the stopifnot tests only the difference. Same gap in the Bulkley caption's "both warmed".
   - Seasons caption (Rmd:219), "winters … were **a little** wetter". `winter_wetter_last3` asserts only `> 0`. The current values are +4.7 / +7.0 / +7.5 %, and two of them already exceed the 6 % the same block uses as its bound for "moved little" (`prcp_moved_little`).
   - Bulkley caption (Rmd:299), "**far** less snow". Only `upper < lower` is asserted (now 55 %).

4. **[fragile] vignettes/northern-bc.Rmd:334, `scale_fill_distiller(..., limits = c(0, 2.5))` on `tmean_change_last10`**
   ggplot's default `oob = censor` turns any cell outside [0, 2.5] into NA, and `na.value = NA` draws it transparent. A cell that warms more than 2.5 °C on a future regen therefore vanishes from the map, which is the opposite of what it should show. Nothing in the data script checks the raster's range (now 1.77–2.18 °C; the BULK last-3 mean is already 2.55). Assert the range in the data script, or set `oob = scales::squish`, or take the limits from the data.

5. **[fragile, docs] R/cd_compare.R:7-11, 33-34 (and man/cd_compare.Rd)**
   The new wording calls 1951–1980 a "pre-warming reference". research/baseline_period.md and the vignette (Rmd:384-386) both say "Some warming had already happened by 1951–1980". The roxygen also now quotes the WMO periods (1901–30, 1931–60, 1961–90), which research/baseline_period.md still marks as "**not** checked against WMO or IPCC documents. Verify them before quoting". The same research file still says the roxygen "is wrong (fix in #137)", which is now stale. These are low-stakes, but they are package docs asserting things the branch's own record contradicts or calls unverified.

6. **[fragile] data-raw/example_context_northern_bc.R:70-76 (towns)**
   The GNS query filters by `GEOGRAPHICAL_NAME` alone, with no spatial filter. `!duplicated()` then keeps whichever feature of that name came first. That is the "a name is not a key" trap. The bundled output is correct (I checked all 6 coordinates), but a regen could pick a same-named feature elsewhere in BC, and `setequal()` on the names would not notice. Clip to `env_sf`, or assert that the towns fall inside it.

## Checked and fine

- Claims predicates are correct as R. `all()` over several vectors, named `vapply`, and `which.max` names are all right, and the block runs before any write.
- "Winter is December, January and February of the same calendar year" matches `cd_aggregate()` on a 12-band calendar year and the `_lib.R` note that DJF is named for its January.
- "About 6.5 by 11 km" matches a 0.1° grid at about 54.5° N.
- The snow caption's "no recent year below the normal minimum" is asserted for all 5 areas.
- Every package the vignette uses at render time is in Suggests/Imports. The vignette reads only bundled files, so it renders offline.
- No `.aux.json` / `.aux.xml` sidecar sits beside the bundled tif. Chunk labels are unique.
