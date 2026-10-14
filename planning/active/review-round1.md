# Code-check round 1: #137 branch (northern-bc vignette)

Reviewer: subagent, 2026-10-14. Evidence came from reading the bundled `inst/vignette-data/northern_bc.rds`, `northern_bc_bulkley.tif` and the two gpkgs, plus the rendered `docs/articles/northern-bc.html`.

## Findings

- **[severity: bug]** vignettes/northern-bc.Rmd:61-62. The opening sentence is false. It reads "Three watersheds ..., each draining to a different ocean by a different great river." The Bulkley (Skeena) and the Nechako (Fraser) both drain to the Pacific, so only two oceans are involved. The page says so itself: the map caption on line 74 reads "the Skeena and the Fraser run to the Pacific, and the Peace runs to the Arctic", and `aoi$drains_to` is Pacific/Pacific/Arctic. The sentence is in the rendered article. Suggested wording: "...each on a different great river, two running to the Pacific and one to the Arctic."

- **[severity: bug]** vignettes/northern-bc.Rmd:68-70. "the last three years are shown one at a time, never as one average" is contradicted by the same page in three places:
  - The "At a glance" table's second number in every cell is a 2023-2025 mean, for example "+2.6 °C" from `cmp` window `last3` computed by `cd_compare()`. Its caption (line 159-161) says each cell compares 2023–2025 with the normal.
  - The Bulkley paragraph (lines 335-338) gives a single 3-year figure: "Summer rain over the last three years ... 25 % less than normal, against 14 %".
  - The seasons caption (line 207) makes an aggregate 3-year claim ("over the last three years winters warmed most and were a little wetter").

  Either the sentence goes, or the table and the paragraph stop averaging the 3 years.

- **[severity: fragile]** vignettes/northern-bc.Rmd:149. `tidyr::pivot_wider()` is called in a vignette chunk that is evaluated, but `tidyr` is not in DESCRIPTION (not in Imports, not in Suggests). Today it renders only because `tidyterra` imports tidyr, so pkgdown's `setup-r-dependencies` installs it transitively. `R CMD check`'s "unstated dependencies in vignettes" check reports `'::' import not declared from: 'tidyr'`. If tidyterra ever drops tidyr, the article breaks on CI. Fix: add `tidyr` to Suggests, or reshape with base R.

- **[severity: fragile]** vignettes/northern-bc.Rmd, several places. These claims are not asserted by data-raw/northern_bc_vignette_data.R, so a regen can make them false while every inline number still prints. The project rule is that the data script asserts the sentences that could turn false, but that only covers the snowpack record-low and Bulkley warming/snowpack-difference sentences. All of these are true of the current rds (checked):
  - Lines 333-338. `r0()`/`r1()` print `abs()`, and the words carry the sign. Two sentences have signs nothing checks:
    - "both lost about the same share of their peak snowpack (9 % and 8 %)". The script asserts `abs(diff(swe_max_pct_last10)) < 3` but never that both values are < 0.
    - "(25 % less than normal, against 14 %)". `prcp_summer_pct_last3` is never asserted < 0 for either half. If the lower half turns positive, this prints "14 % less" for an increase.
  - Lines 140-142. `fmt_cell()` prints `-a` followed by "days earlier". A later melt would read "-3 days earlier".
  - Line 207, the seasons caption: "Every season is warmer ...; over the last three years winters warmed most and were a little wetter, while springs and summers were drier." The heading on line 205 is "recent summers were dry". None of this is asserted. Current values: last-3 winter tmean is the largest season in all three watersheds, winter prcp is +4.7/+7.0/+7.5 %, and spring/summer prcp is negative in all three.
  - Lines 64-66 and 155-159. "Total rain and snow moved little over ten years, though the last three were drier" and the scorecard caption ("Every watershed is warmer, with a smaller snowpack that melts sooner and drier summer air and soil") are hard-coded. `scorecard$direction` is not checked for those rows. Parsnip peak snowpack over the last 10 years is only -3 %.

  Suggestion: add `stopifnot()` lines for each of these to the data script, as was done for `snow_low`.

- **[severity: fragile]** vignettes/northern-bc.Rmd:377 and 385-388. The windows elsewhere come from the data (`w$last10`, `last_year` from the catalog), but the reproduce chunk hard-codes `window_a = 2016:2025` and the prose hard-codes "they compare 2015–2025". After the next annual catalog advance and a regen, the page will say "The last 10 years are 2017–2026" while the code that claims "To reproduce the Bulkley's numbers" uses 2016:2025, which gives different numbers. Either build the chunk text from `w`, or have the data script stop when `last_year != 2025` until the chunk is updated.

- **[severity: bug, docs]** research/baseline_period.md:7. The revised text says 1951–1980 "starts one year into the ERA5-Land record (which begins in 1950), so it is the closest this data gets to IPCC's pre-industrial baseline". The "so" does not follow: 1950–1979 is an earlier 30-year window in the same record and would be closer. The previous wording ("earliest 30-year window") was wrong, and so is the new conclusion. The real reason in the same paragraph is that it is the GISS base period and nearly the earliest. Reword so it does not claim to be the closest.

## Checked and clean

- Winter as DJF of the same calendar year (vignette line 207) matches `cd_aggregate()`/`cd_seasons()`. Stage 3 aggregates months 12, 1 and 2 of one year's 12-band file.
- Grid-cell size "about 6.5 by 11 km" is right for 0.1° at about 54.5° N.
- Every inline number in the rendered HTML matches the rds: 55 %, 1.9/2.0 °C, 9 to 13 days, 7/5/4 years.
- Bulkley tif: 156 non-NA cells. This equals `cells["BULK"]`, so the raster is masked. Values are inside the `limits = c(0, 2.5)` scale (max 2.18), so no cells drop to NA. The swe max of 1000 mm passes the glacier guard.
- Towns layer: all six resolve to the correct BC towns by coordinate (the GNS name-ambiguity trap was checked). The AOI polygons are valid, EPSG:4326 and all POLYGON, and they fit inside the map window.
- `ts` and `cmp` have no NA values, so the formula `aggregate()` calls drop nothing.
- `regenerate_bib.R` globbing `vignettes/*.Rmd` is fine. The 6 cited keys rendered in the References section.
- No `articles:` index in `_pkgdown.yml`, so the new article needs no index entry. The root-page gate in pkgdown.yaml does not cover `docs/articles/`.
- `cd_compare.R` doc wording: GISS base period 1951–1980 is correct.

Not verified: the citation paraphrases (Stewart 2005, Kang 2016, Mantua 2010, Eaton & Scheller 1996, Ficklin & Novick 2017, Najafi 2017). The Zotero MCP had no API key in this session.
