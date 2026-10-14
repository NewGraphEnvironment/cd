# Task: Vignette: a plain-language climate story for three northern BC watershed groups (BULK, NECR, PARS) (#137)

## Why

The two existing vignettes (`peace-fwcp`, `kootenay-lake`) are thorough, but they run to about 1,000 lines each and are built around the method: catalog, extract, trend statistics, ecoregion breakdowns. This one is the opposite. It tells **one story in plain language**: how the weather has changed in three northern BC watersheds, and what that means for streams. Someone with no climate background should be able to read the figures alone and follow it.

Three watershed groups, one per major river system:

| Code | Watershed group | Area | River system | Drains to |
|---|---|---|---|---|
| BULK | Bulkley River | 7,762 km² | Skeena | Pacific |
| NECR | Nechako River | 4,148 km² | Fraser | Pacific |
| PARS | Parsnip River | 5,597 km² | Peace → Mackenzie | Arctic (Beaufort Sea) |

Each one is also the anchor watershed of a 2025 fish-passage report's climate appendix ([Skeena](https://github.com/NewGraphEnvironment/fish_passage_skeena_2025_reporting), [Fraser](https://github.com/NewGraphEnvironment/fish_passage_fraser_2025_reporting), [Peace](https://github.com/NewGraphEnvironment/fish_passage_peace_2025_reporting)). This vignette is the side-by-side view of all three.

Full issue body in findings.md. Plan-gate decisions (baseline 1951–1980, hide code, upper/lower Bulkley at Houston) are decided in the issue.

## Phase 1: `cd_compare()` wording (decision 1)
- [x] Reword `R/cd_compare.R` description and `window_b` param: 1951–1980 is the
      "pre-warming reference (the GISS base period)", not a WMO standard normal
- [x] `devtools::document()`; man/cd_compare.Rd regenerated; tests still pass

## Phase 2: AOI — three watershed groups + the Bulkley split
- [x] `data-raw/example_aoi_northern_bc.R`: BULK, NECR, PARS from
      `fwa_watershed_groups_poly`, plus upper Bulkley (Neexdzii Kwa, above Houston, via
      `frs_watershed_at_measure` just upstream of the Morice confluence) and lower
      Bulkley (BULK − upper); columns `code`, `name`, `river_system`, `drains_to`, `role`;
      EPSG:4326
- [x] Checks printed and asserted: WSG areas match the issue table (7,762 / 4,148 /
      5,597 km²) within 1 %; upper + lower = BULK within 1 %; upper contains Houston's
      upstream mainstem and not the Morice
- [x] Write `inst/extdata/example_aoi_northern_bc.gpkg`

## Phase 3: Map context
- [x] `data-raw/example_context_northern_bc.R` (pattern of `example_context_fwcp_peace.R`):
      towns (Smithers, Houston, Vanderhoof, Prince George, Mackenzie), named mainstems
      (Skeena, Bulkley, Fraser, Nechako, Peace, Parsnip), Williston Lake polygon, a BC
      outline for the keymap; clipped to a padded envelope, simplified
- [x] Write `inst/extdata/context_northern_bc.gpkg`, kept small (target < 1 MB)

## Phase 4: Vignette data
- [ ] `data-raw/northern_bc_vignette_data.R` (`pkgload::load_all()`, #135): `cd_extract()`
      for the five AOIs from the live catalog; window comparisons (2016–2025 and
      2023–2025 vs 1951–1980) with the explicit per-variable method lookup; per-year
      values for 2023–2025; the warmest normal-period year per watershed
- [ ] BULK raster pair for figure 6: normal peak snowpack (1951–1980 mean `swe_max`) and
      10-yr temperature change, masked to BULK → `inst/vignette-data/northern_bc_bulkley.tif`
- [ ] gq registry colours stored in the rds; write `inst/vignette-data/northern_bc.rds`;
      bundled vignette-data < 1 MB
- [ ] Re-derive the issue's probe table and "7 / 5 / 4 years warmer than the warmest
      normal year" from the bundled data; record any differences in findings.md

## Phase 5: Vignette `vignettes/northern-bc.Rmd`
- [ ] Skeleton: `bookdown::html_document2` header as the other two, hidden setup, every
      number in prose and captions computed inline from the rds (none typed)
- [ ] Fig 1 map (three WSGs filled + named, rivers named, towns, Pacific/Pacific/Arctic
      note, keymap) and Table 2 scorecard (≈6 signals × 3 watersheds, "10 yr / 3 yr",
      warm/dry vs cool/wet tint, kableExtra)
- [ ] Fig 3 annual temperature bars 1950–2025 (three stacked panels, warm/cool colours,
      normal shaded, last 10 / last 3 bracketed, dashed warmest-normal-year line)
- [ ] Fig 4 seasonal dot chart (temperature + precipitation, 10 yr and 3 yr, per watershed)
- [ ] Fig 5 snow: (a) peak snowpack normal / 10-yr mean / each of 2023–2025, (b) half-melt
      date on a calendar axis with month labels; text makes no record-low claim
- [ ] Fig 6 Bulkley grid maps (normal peak snowpack; 10-yr temperature change) + the
      upper-vs-lower one-liner: same change, drier starting point upstream
- [ ] Fig 7 summer dryness (VPD, soil moisture) only if the Rmd stays under ~400 lines;
      otherwise those rows live in the scorecard
- [ ] Prose: "What this means for watershed health" (changed → streams → fish table) and
      "Next steps: from weather to water" (wet home page only); "How this was made" with
      the one-sentence baseline caveat and one `eval = FALSE` reproduce chunk

## Phase 6: References
- [ ] Check each mechanism claim against its PDF (Zotero full text) for the six keys;
      cut or reword any claim the source does not make
- [ ] `data-raw/regenerate_bib.R` reads every `vignettes/*.Rmd`; run it if any key is
      added (Zotero + BBT up), otherwise confirm the bib already holds every key cited

## Phase 7: Figure and language QA
- [ ] Render (`pkgdown::build_article("northern-bc")`) and read every figure PNG at
      ~700 px: type size, ≤ 3 colours per panel, colour-blind-safe, direct labels
- [ ] Cartography self-review, all 12 checks, on figures 1 and 6
- [ ] Plain-language grep of body text and axis labels (p-value, Mann-Kendall, Theil-Sen,
      anomaly, reanalysis, SWE) — only "How this was made" may name a technical term;
      captions lead with the takeaway; no footnotes; Rmd line count ≤ ~400

## Phase 8: Docs and follow-ups
- [ ] README.md vignette list and CLAUDE.md "Vignettes" section name the third vignette
- [ ] File follow-up issue: `cd_variables()` says `swe_max` is `absolute`, CLAUDE.md's
      table says `pct_normal` (decide which is right)

## Validation

- [ ] Tests pass (`devtools::test()`)
- [ ] `devtools::check()` builds the vignette offline; `pkgdown::check_pkgdown()` clean
- [ ] `/code-check` clean (each commit, or once over the branch with `/code-check branch`)
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
