# Findings — Snow-departure vignette for the Kootenay Lake region (#56)

## Issue context (verbatim from #56)

The package's original `climate-departure` (KOTL) vignette ran the
consumer pipeline on a single watershed group at single-watershed
scale. That made the snow story underpowered — there's no climatic
gradient inside one WSG, and no inherited geography for readers to
anchor on. Now that snow vars exist (#48, v0.2.0) and the FWCP Peace
vignette has demonstrated the regional-AOI pattern with per-ecoregion
breakdowns and citation-grounded interpretation, the natural KOTL
evolution is to expand the AOI to the four-WSG Kootenay Lake region
and tell the snow story properly.

This supersedes the deferred KOTL decision in #49 with a concrete
plan: keep KOTL as a worked example, expand its AOI, mirror the
`peace-fwcp.Rmd` structure.

## Geographic scope (user-confirmed)

- `KOTL` — Kootenay Lake, 9,370 km², anchor
- `LARL` — Lower Arrow Lake, 6,612 km², W — covers Trail / Rossland /
  Red Mountain
- `DUNC` — Duncan Lake, 4,763 km², N — drains north Kootenay Lake
  (Duncan + Lardeau)
- `SLOC` — Slocan River, 3,431 km², NW — Selkirks / Monashees

Total ~24,200 km². Verified WSG codes via FWA query during planning
(LARL is Lower Arrow Lake, NOT Lardeau as initial guess; SLOC is
Slocan; SMAR/BULL/ELKR are out-of-scope eastern WSGs).

## State found during plan-mode exploration

### KOTL legacy

KOTL bundled assets remaining in repo:

- `inst/extdata/example_aoi_kotl.gpkg`
- `inst/extdata/context_kotl.gpkg`
- `inst/extdata/context_kotl_towns.gpkg`

Used only by README quick-start (`README.md` line 23). No tests, no
roxygen examples, no other vignettes. Function examples use the
generic `example_aoi.gpkg` and `example_climate.tif`. So: keep the
KOTL polygons bundled (small, fast single-watershed README demo)
and build the new 4-WSG AOI alongside under a `kootenay_lake_*`
namespace.

`vignettes/climate-departure.Rmd` was already removed in v0.1.4
(commit `914f737`).

### Patterns to mirror

- `data-raw/example_aoi_fwcp_peace.R` — AOI builder via FWA query
- `data-raw/example_context_fwcp_peace.R` — context layers via fresh
  / bcdata. Includes 16-WSG canonical list pattern (#51 / v0.1.5).
- `data-raw/peace_fwcp_vignette_data.R` — precompute structure
  (regional + per-ecoregion). Recently extended with snow-aware
  `pct_normal_vars` list for snow vars.
- `vignettes/peace-fwcp.Rmd` — current canonical vignette.
  Bibliography wired (`vignettes/references.bib` from #54). 11
  citations, snow methodology grounded in lit review.
- `data-raw/qa_snow_validation.R` — ASWS QA pattern; uses
  `bcsnowdata::snow_auto_location()` + spatial filter.

### Citations reusable

`vignettes/references.bib` (22 KB, 11 entries from #54) covers:

- `mote_etal2018Dramaticdeclines` — PNW snowpack decline (npj OA)
- `najafi_etal2017AttributionObserved` — **BC Columbia basin SWE
  attribution** — directly covers the Kootenays (Columbia basin
  parent of Kootenay sub-basins)
- `kang_etal2016ImpactsRapidly` — Fraser freshet timing; neighbouring
  basin
- `knowles_etal2006TrendsSnowfall` — SFE/P methodology
- `stewart_etal2005ChangesEarlier` — DOY-50 / center timing
- `cayan_etal2001ChangesOnset` — spring onset
- `pederson_etal2011UnusualNature` — long-record cordillera context
- `mote_etal2005DECLININGMOUNTAIN` — foundational PNW
- `kouki_etal2023Evaluationsnow` — ERA5-Land snow validation
- `yue_wang2002Applicabilityprewhitening` — MK + autocorrelation
- `munoz-sabater_etal2021ERA5Landstateoftheart` — ERA5-Land dataset

No new lit review needed.

## Architecture decisions taken (user-confirmed)

1. **Scope: KOTL + LARL + DUNC + SLOC** (not the broader 6-WSG option
   crossing into the Rockies). Cleanest local-Kootenay story without
   crossing into FWCP East Kootenay reporting territory.
2. **KOTL bundled polygons stay** for README quick-start (single-
   watershed small/fast example). New 4-WSG AOI lives alongside.
3. **Reuse `vignettes/references.bib`** — same papers cover Kootenay
   snow methodology as Peace.
4. **Per-WSG facet plot** added to the snow section — 4 facets is
   compact enough vs the 5-facet per-ecoregion plot inherited from
   Peace, and maps directly to the FWCP reporting unit.
5. **East-west precip gradient is the snow-story angle** — Selkirks
   getting Pacific spillover (LARL/SLOC west) vs Purcell rain shadow
   (KOTL east shore). Distinct from Peace where the gradient is
   continental + latitudinal.

## Anchors for downstream work

- The vignette is the second of three reporting climate-departure
  appendices (cf #47). Ports directly to a hypothetical
  `fish_passage_kootenay_2025` reporting context, mirroring the
  `peace-fwcp` → `fish_passage_peace_reporting_2025` mapping.
- After v0.2.1 release: file follow-ups for the third reporting region
  (e.g., FWCP East Kootenay covering BULL/ELKR) if motivated.
