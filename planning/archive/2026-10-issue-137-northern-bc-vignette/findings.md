# Findings — Vignette: a plain-language climate story for three northern BC watershed groups (#137)

## Issue context

## Why

The two existing vignettes (`peace-fwcp`, `kootenay-lake`) are thorough, but they run to about 1,000 lines each and are built around the method: catalog, extract, trend statistics, ecoregion breakdowns. This one is the opposite. It tells **one story in plain language**: how the weather has changed in three northern BC watersheds, and what that means for streams. Someone with no climate background should be able to read the figures alone and follow it.

Three watershed groups, one per major river system:

| Code | Watershed group | Area | River system | Drains to |
|---|---|---|---|---|
| BULK | Bulkley River | 7,762 km² | Skeena | Pacific |
| NECR | Nechako River | 4,148 km² | Fraser | Pacific |
| PARS | Parsnip River | 5,597 km² | Peace → Mackenzie | Arctic (Beaufort Sea) |

Each one is also the anchor watershed of a 2025 fish-passage report's climate appendix ([Skeena](https://github.com/NewGraphEnvironment/fish_passage_skeena_2025_reporting), [Fraser](https://github.com/NewGraphEnvironment/fish_passage_fraser_2025_reporting), [Peace](https://github.com/NewGraphEnvironment/fish_passage_peace_2025_reporting)). This vignette is the side-by-side view of all three.

## The question, in the reader's words

1. **Compared with what used to be normal, what is different about the last 10 years?**
2. **And the last 3 years: is it getting more extreme?**
3. **What does that mean for streams and fish?**

Windows: the normal is **1951–1980** (see decision 1), the last 10 years are **2016–2025**, the last 3 are **2023–2025**. The catalog currently ends at 2025.

Three years is mostly weather and ten years is closer to climate. The vignette says so in one sentence and shows the last three years **one dot per year**, never as a single average. 2023 was a hot, dry year, and the reader needs to see that one year is not carrying the whole result.

## What the data already shows (probe, 2026-10-14)

`cd_extract()` from the live catalog for each watershed group's polygon (BC WFS `FWA_WATERSHED_GROUPS_POLY`), then `cd_compare()` against 1951–1980. Every number below gets re-derived by the `data-raw/` script; it is here so the figure design is built on the real signal.

| Signal (plain name) | Variable | BULK 10 yr / 3 yr | NECR 10 yr / 3 yr | PARS 10 yr / 3 yr |
|---|---|---|---|---|
| Average temperature | `tmean` annual | +1.9 / +2.6 °C | +1.7 / +2.4 °C | +1.6 / +2.3 °C |
| Winter temperature | `tmean` winter | +2.0 / +3.2 °C | +2.2 / +3.4 °C | +1.7 / +3.0 °C |
| Summer daytime highs | `tmax` summer | +2.0 / +2.9 °C | +1.7 / +2.5 °C | +1.6 / +2.2 °C |
| Total precipitation | `prcp` annual | +2 / −4 % | −2 / −11 % | +5 / −3 % |
| Summer rain | `prcp` summer | +5 / −17 % | −6 / −22 % | +10 / −6 % |
| Peak snowpack | `swe_max` | −8 / −14 % | −12 / −26 % | −3 / −17 % |
| Half the snow gone by | `snowmelt_doy_50` | 13 / 13 days earlier | 13 / 15 days earlier | 9 / 13 days earlier |
| Share of precipitation falling as snow | `snowfall_fraction` | −3 / −2 points | −1 / −1 points | −3 / −5 points |
| Summer air dryness | `vpd` summer | +21 / +37 % | +16 / +27 % | +10 / +20 % |
| Summer soil moisture | `soil_moisture` summer | −5 / −9 % | −3 / −9 % | −3 / −7 % |

Things this changes for the design:

- **The headline is temperature, and it is not subtle.** 7 of the last 10 years in BULK were warmer than the *warmest* year from 1951 to 1980 (NECR 5, PARS 4). "Warmer than any year your grandparents saw" reads at a glance, and it is the strongest plain-language device we have.
- **Precipitation has barely changed over 10 years, but the last 3 were drier, especially in summer.** Wetter or drier is not the story. Warmer, so less of it stays as snow and it leaves the land sooner, is.
- **Snow shifted on average, not at the extremes.** No recent year fell below the lowest peak snowpack of 1951–1980. The text must not imply record-low snow.
- **BULK from one end to the other: the change is about the same, the starting point is not.** Split at the median longitude (near Telkwa), the west half (Smithers–Hazelton) and the east half (Houston–Bulkley Lake) warmed by the same amount (+2.0 / +1.9 °C) and lost the same share of their peak snowpack (−8 %). But the east half starts with much less water: 803 mm of precipitation and a 330 mm snowpack, against 1,094 mm and 566 mm in the west. Its summer rain also fell further in the last 3 years (−23 % vs −13 %). So the BULK story is *the same change landing on a drier upper watershed*. That story is honest and plain. "The two ends are changing differently" is not, and the vignette must not say it.
- **`cd_compare(method = "pct_change")` returns a number for temperature (+343 %, say), and it is meaningless.** The script chooses the method per variable from an explicit lookup: °C and days as differences, precipitation and snow as percent, snowfall share as percentage points. It does not read `cd_variables()$anomaly_type`, whose `swe_max` is `absolute` (CLAUDE.md's table says `pct_normal`).
- **There are no monthly COGs** (59 = 11 natives × 5 periods + 4 derived annuals), so a month-by-month snowpack curve is not available. The snow figure uses peak snowpack and melt date.

## The story and its figures

Six figures and one table, at most. Each one answers one question, and **the first sentence of every caption is the takeaway**, not a description ("Nearly every year since 2000 has been warmer than the old normal", not "Annual mean temperature anomaly, 1950–2025").

1. **Where these watersheds are.** A map of northern BC: the three watershed groups filled and labelled by name, the main rivers drawn and named (Skeena, Bulkley, Fraser, Nechako, Peace, Parsnip, Williston Reservoir), a few towns for orientation (Smithers, Houston, Vanderhoof, Prince George, Mackenzie), and a note on where each river goes: Pacific, Pacific, Arctic. Symbology from the `gq` registry, with the `cartography` self-review including the communicate half.
2. **At a glance (table).** A scorecard: rows are about six plain-named signals, columns are the three watersheds, and each cell holds "last 10 yr / last 3 yr" with a warm/dry or cool/wet tint. The one-screen summary. Everything after it explains a row.
3. **It is warmer, almost every year.** Annual temperature as a departure from normal, one bar per year, 1950–2025, three panels stacked on a shared axis. Bars above the normal are warm-coloured and bars below are cool. The normal period is shaded and the last 10 and last 3 years are bracketed. A dashed line marks the warmest year of the normal period, so "warmer than any year back then" can be seen, not just stated.
4. **Winters warmed most.** Change by season (winter, spring, summer, fall) for temperature and for precipitation: a dot chart, last 10 years and last 3 years side by side, one panel per watershed. It shows winter warming most and summer rain dropping recently.
5. **Less snow, gone sooner: the link to streams.** Two parts, one row per watershed. (a) Peak snowpack: the normal, the last-10 average, and each of the last 3 years. (b) The date half the snow is gone, on a calendar axis with month labels (late May → mid May, for example). This is the figure the streamflow paragraph hangs on: the spring freshet comes earlier, and the snow that used to feed summer flow is gone sooner.
6. **The Bulkley from one end to the other.** Two small maps of BULK on the ERA5-Land grid (about 9 km). (a) The normal peak snowpack, showing the strong west–east contrast in how much water the land starts with. (b) The change in temperature over the last 10 years, nearly even across the watershed. A one-line comparison of the upper and lower Bulkley under it. Takeaway: same change, drier starting point upstream.
7. **Summer is thirstier** (optional; fold it into the scorecard if the vignette runs long). Summer air dryness (vapour pressure deficit, explained as "how strongly the air pulls water out of soil and plants") and summer soil moisture, the last 10 and last 3 years against the normal.

Then two short prose sections:

- **What this means for watershed health.** A small table: *what changed → what it does to streams → why fish care*. For example: earlier melt → earlier spring peak flow and lower, warmer late-summer flow; warmer summers and drier air → warmer water and stress on cold-water species; more winter rain, less snow → more winter high flows. Mechanism claims use keys already in `vignettes/references.bib` where they fit (`stewart_etal2005ChangesEarlier`, `kang_etal2016ImpactsRapidly`, `mantua_etal2010Climatechange`, `eaton_scheller1996Effectsclimate`, `ficklin_novick2017Historicprojected`, `najafi_etal2017AttributionObserved`), each checked against its PDF. Any new reference goes through Zotero and `data-raw/regenerate_bib.R`.
- **Next steps: from weather to water.** Climate departure is the first half of the chain. Stream flow and water temperature are the next half, and that work lives in [wet](https://www.newgraphenvironment.com/wet/). Link the pkgdown **home page only**, never an article, because wet's article names are expected to change.

The vignette closes with a short "How this was made" note: two or three sentences naming ERA5-Land and the windows, a link to the two regional vignettes for the method, and (per decision 2) one small chunk of the `cd::` calls that reproduce the numbers.

## Plain-language rules (acceptance)

- No p-values, Mann-Kendall, Theil-Sen, "anomaly", "reanalysis" or "SWE" in the body text or on axis labels. Use "change from normal", "peak snowpack", "the date half the snow has melted". The one technical note goes in "How this was made".
- Units in words on axes ("°C warmer than normal", "% less than normal", "days earlier").
- Each figure is readable at the pkgdown column width (about 700 px): type checked at the delivered width, colour-blind-safe palette, at most three colours per panel, no legend a reader has to decode when a direct label would do.
- A reader who looks at the figures and captions alone gets the whole story.
- Target length: under about 400 lines of Rmd, a ten-minute read.

## Data and build

- `data-raw/example_aoi_northern_bc.R` writes `inst/extdata/example_aoi_northern_bc.gpkg`: the three watershed groups plus the upper and lower Bulkley split (decision 3), in EPSG:4326.
- `data-raw/northern_bc_vignette_data.R` loads the checkout with `pkgload::load_all()` (#135) and writes `inst/vignette-data/northern_bc.rds` (per-watershed `ts` plus the window comparisons) and a small BULK raster stack for figure 6. Bundled output stays under 1 MB, the same as the existing two.
- `data-raw/example_context_northern_bc.R` writes the map context (rivers, towns, reservoir) to `inst/extdata/context_northern_bc.gpkg`, following `example_context_fwcp_peace.R`.
- `vignettes/northern-bc.Rmd` renders offline from the bundled files.

## Out of scope (follow-up candidates)

- Hot days per summer from the daily cube (`cd_extract_daily()` reads points, not polygons, and an area-mean daily high blurs the extremes).
- Streamflow and water temperature themselves (wet).
- Trend rates per decade. The window comparison is the story, which also keeps #102's mislabelled precipitation trend out of this vignette.

## Decisions for the plan gate

1. **What "normal" means.** **Decided (2026-10-14): 1951–1980.** It is the earliest 30 years in the ERA5-Land record, so it is the closest this data gets to IPCC's pre-industrial 1850–1900 baseline, and it matches NASA GISS, the other vignettes and the fish-passage appendices. The vignette says in one plain sentence that some warming had already happened by then, so these numbers *understate* the change since pre-industrial times. For the record: against 1961–1990, BULK's last 10 years are +1.6 °C, not +1.9 °C, and the "warmer than any year in the normal" count falls from 7 to 2. In scope here: `cd_compare()`'s roxygen calls 1951–1980 the "WMO-style standard normal", which it never was (WMO's fixed periods were 1901–30, 1931–60 and 1961–90). Reword it to "pre-warming reference (the GISS base period)".
2. **How much code shows.** **Decided (2026-10-14): hide all code** and end with one short "reproduce this" chunk. The alternative is the existing vignettes' `cd::` showcase pattern (CLAUDE.md, "Chunk pattern"), which is the reverse of what this vignette is for.
3. **How to split the Bulkley.** **Decided (2026-10-14): upper Bulkley (Neexdzii Kwa, above Houston) vs lower Bulkley (Houston to the Skeena)**, delineated from the FWA network at Houston. The split is hydrologically real and named locally. The alternatives are the grid maps alone, or the median-longitude halves the probe used.


## Exploration (plan mode, 2026-10-14)


- **Pattern to follow:** `data-raw/peace_fwcp_vignette_data.R` (load_all per #135,
  `cd_extract` → compare → `saveRDS(compress = "xz")` + small masked tif),
  `data-raw/example_aoi_fwcp_peace.R`, `data-raw/example_context_fwcp_peace.R`
  (fresh/fwapg queries, 200 m simplify, multi-layer gpkg). `fresh-db` is up locally.
- **Bulkley split:** `fresh::frs_watershed_at_measure(conn, blue_line_key, drm)` on the
  Bulkley mainstem just upstream of the Morice confluence at Houston. Morice is its own
  WSG (MORR), so upper = that watershed ∩ BULK, lower = BULK − upper. The Morice stem's
  `drm = 0` sits on the Bulkley centreline (code-check-spatial), so locate it with
  `ST_LineLocatePoint` and step a little upstream.
- **gq is GitHub-only**, so it cannot go in Suggests (CLAUDE.md, CI). The existing
  vignettes hardcode hex with a "gq …" comment. Instead the data-raw script reads
  `gq::gq_reg_main()` (`lake`, `rivers_poly`, `watershed_group_boundary`) and stores the
  colours in the rds, so the vignette uses registry values without depending on gq.
- **Compare method:** explicit lookup in the data script, not `cd_variables()$anomaly_type`
  (which says `swe_max` is `absolute`; CLAUDE.md's table says `pct_normal`; confirmed in
  `R/cd_variables.R`). Differences: tmean, tmax, snowmelt_doy_50 (days),
  snowfall_fraction (points). Percent: prcp, swe_max, vpd, soil_moisture.
  `test = NULL` (no p-values in this vignette; the 3-yr window would warn anyway).
  Windows passed explicitly: `cd_compare()`'s default `window_a` is `2015:2025` (11 yr).
- **Bib:** all six named keys are already in `vignettes/references.bib`, but
  `data-raw/regenerate_bib.R` hardcodes the two old vignettes, so a key used only in the
  new one would be dropped at the next regen. Switch it to every `vignettes/*.Rmd`.
- **Discoverability:** `_pkgdown.yml` has no articles index (auto-listed); README.md
  lines 113–121 and CLAUDE.md "Vignettes" both name only the two existing vignettes.
- `cd_compare()` roxygen (R/cd_compare.R lines 7–8 and 32) says "WMO-style standard
  normal" — reworded per decision 1. `cd_baseline()`'s "1981:2010 (WMO standard)" is
  correct and stays.
- wet home page `https://www.newgraphenvironment.com/wet/` returns 200.


## Errors Encountered

| Error | Resolution |
|-------|------------|

## Context data sources (Phase 3)

- `whse_basemapping.gns_geographical_names_sp` is absent from the current fwapg, although `example_context_fwcp_peace.R` and `example_context_kootenay_lake.R` query it; those two scripts would fail if re-run today. Towns here come from `bcdc_query_geodata("WHSE_BASEMAPPING.GNS_GEOGRAPHICAL_NAMES_SP")`.
- The union of all FWA watershed groups (2 km simplify) is 939,760 km², BC's land area to within half a percent. It serves as the keymap outline.

## Vignette data (Phase 4, measured 2026-10-14)

Producer: `data-raw/northern_bc_vignette_data.R`, run against the live catalog (34 s with a warm cache). Windows derived from the last year every area holds: 2016–2025 and 2023–2025.

- **The issue's probe table reproduces to its rounding** for BULK, NECR, PARS, every row.
- **Warmer than the warmest normal year (1958 everywhere):** BULK 7, NECR 5, PARS 4 of the last 10, as the issue said. Upper Bulkley 6, lower 7.
- **2023 does not carry the 3-yr result:** without 2023, the 3-yr warming is BULK +2.1, NECR +1.9, PARS +1.7 °C (with 2023: +2.6, +2.4, +2.3).
- **No recent peak snowpack fell below the lowest normal year** in any area (asserted in the script).
- **Upper vs lower Bulkley (Houston split):** 10-yr warming +1.86 vs +1.97 °C; peak snowpack −9.2 vs −8.1 %. Normal precipitation 758 vs 1,055 mm; normal peak snowpack 293 vs 534 mm. Summer rain over the last 3 years −25 vs −14 %. The issue's median-longitude halves gave the same story (+2.0 / +1.9 °C; 803 vs 1,094 mm). Over 10 years summer rain went opposite ways: upper −6 %, lower +8 %.
- **Winter precipitation fell** over the last 10 years in every area (−2 to −5 %). The last 3 were wetter (+1 to +8 %). "More winter rain → more winter high flows" is therefore not supported as a total-precipitation statement; only the snowfall share (−1 to −4 points over 10 yr) supports a "less of it falls as snow" row.
- **Grid cells touched:** BULK 156, NECR 81, PARS 112, upper Bulkley 49, lower 111.
- **No glacier artefact in BULK:** normal peak snowpack per cell runs 225–1,000 mm.
- **Semantics (review A1, A2):** "winter" for year Y = Jan, Feb and Dec of Y (`cd_aggregate()` over one calendar year). `swe_max` = the mean over cells of each cell's calendar-year peak. `snowmelt_doy_50` = the day by which half of that calendar year's snowmelt has happened (`backfill_edh_snow.py:290-299`).

## Seasonal pattern (checked before writing captions)

- **"Winters warmed most" holds for the last 3 years only.** Over 10 years summer warmed more than winter in BULK (+2.3 vs +2.0 °C) and PARS (+1.9 vs +1.7); NECR's winter led (+2.2 vs +1.9). Over the last 3 years winter led everywhere (+3.2, +3.4, +3.0). The issue's figure title "Winters warmed most" would be wrong as a 10-year statement; the caption says what the data show.
- **Last 3 years: wetter winters, drier springs and summers.** Winter precipitation +5 / +7 / +7.5 %; spring −6 / −18 / −19 %; summer −17 / −22 / −6 %.
- **Melt date:** half the year's snowmelt done by day 149 (≈ 29 May) in BULK's normal, day 136 (≈ 16 May) over the last 10 years.

## Reference check (Phase 6)

`planning/active/review-references.md` (background agent, PDFs read from Zotero storage; the Zotero MCP has no API key on this machine). Verdicts: Stewart 2005, Kang 2016 and Eaton & Scheller 1996 SUPPORTED. Najafi 2017, Mantua 2010 and Ficklin & Novick 2017 PARTLY, so the vignette uses the narrower supported wording: four BC basins 1961–2005; salmon and steelhead in Washington projections; VPD rise shown for the US 1979–2013. I re-checked Kang's abstract sentence against the PDF myself: it matches word for word. The vignette names each source's study region.

## Figure QA (Phase 7)

- pkgdown 2.2.0 renders the article without bookdown numbering, as the review said; figures are referred to by name.
- ggrepel 0.9.8 with ggplot2 4.0.3 ignores `label.size = 0`; `linewidth = 0` removes the label border.
- Separate ggrepel layers do not avoid each other's text, so the map uses one label layer for watershed, river and town names, with per-row style via identity scales.
- Simplifying each watershed group before the union left slivers in the BC keymap; a 2 km buffer out and back in closes them (context gpkg 392 → 272 KB).
- The Bulkley temperature-change map on a 1.5–2.3 °C scale made a nearly uniform change look patchy; the scale now starts at 0.
- Captions corrected against data: "most years warmer than the warmest normal year" (PARS 4 of 10) → "now common"; "about two weeks sooner" → computed range (9 to 13 days); "winters warmed most" restricted to the last 3 years.
- `pkgdown::init_site()` generated `pkgdown/favicon/` through an external service; removed, not part of this work.
