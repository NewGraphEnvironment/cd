# Task: Snow-departure vignette for the Kootenay Lake region (#56)

## Problem

The original single-WSG `climate-departure` (KOTL) vignette was
removed in v0.1.4 because it was too narrow to tell the
climate-departure story. Now that snow vars exist (#48, v0.2.0), the
"keep + expand" resolution of #49 is to build a regional vignette
covering KOTL plus three adjacent watershed groups in the southern
BC Kootenays:

| WSG | Name | km² | Direction |
|---|---|---|---|
| `KOTL` | Kootenay Lake | 9,370 | (anchor) |
| `LARL` | Lower Arrow Lake | 6,612 | W — Trail / Rossland / Red Mountain |
| `DUNC` | Duncan Lake | 4,763 | N — Lardeau drainage into N Kootenay Lake |
| `SLOC` | Slocan River | 3,431 | NW — between Selkirks and Monashees |

Total ~24,200 km². Anchored on Kootenay Lake; spans the east-west
precip gradient from Selkirk Pacific spillover (LARL/SLOC west) to
Purcell rain shadow (KOTL east shore into the Purcells). This
gradient is the climatic backbone of the snow story for this AOI —
materially different from the Peace vignette where the gradient is
mostly continental + latitudinal.

Mirror the FWCP Peace pattern. Reuse the v0.2.0 snow vars + the
11-paper `vignettes/references.bib` from #54. Keep the existing
`inst/extdata/example_aoi_kotl.gpkg` for the README quick-start —
the new 4-WSG AOI lives alongside under a `kootenay_lake_*`
namespace.

## Phase 1 — AOI + bundled context geodata

- [ ] `data-raw/example_aoi_kootenay_lake.R` — pull KOTL, LARL, DUNC,
      SLOC from FWA, union → 4326 → write
      `inst/extdata/example_aoi_kootenay_lake.gpkg`. Mirrors
      `data-raw/example_aoi_fwcp_peace.R`.
- [ ] `data-raw/example_context_kootenay_lake.R` — towns (Nelson,
      Castlegar, Trail, Rossland, Kaslo, Nakusp, Slocan, New Denver,
      Argenta), lakes (>200 ha — Kootenay Lake, Slocan Lake, Duncan
      Lake, Trout Lake, Lower/Upper Arrow), named rivers, highways,
      the 4 WSGs as polygons, ecoregions intersecting AOI. Simplify
      ~50 m. Write `inst/extdata/context_kootenay_lake.gpkg`.
      Mirrors `data-raw/example_context_fwcp_peace.R`.

## Phase 2 — Pre-compute vignette data

- [ ] `data-raw/kootenay_lake_vignette_data.R` — regional + per-ecoregion
      `cd_extract` → `cd_baseline` → `cd_anomaly` → `cd_trend` →
      `cd_compare`, plus the spatial-pattern tmean departure raster.
      Mirrors `data-raw/peace_fwcp_vignette_data.R` (reuses the
      `pct_normal_vars` snow extension).
- [ ] Save `inst/vignette-data/kootenay_lake.rds` (compressed) +
      `inst/vignette-data/kootenay_lake_departure_tmean.tif`. Target
      <500 KB total.

## Phase 3 — Vignette build

- [ ] `vignettes/kootenay-lake.Rmd` — sections mirroring peace-fwcp:
      Area of Interest, Connect to the Data Catalog, Extract Climate
      Time Series, Trends, Daytime Highs and Overnight Lows,
      **Snowpack** (with seasonal-curve table + 4 annual time-series
      + per-WSG facet), Recent vs Pre-warming, Spatial Pattern,
      Per-Ecoregion Variation, Watershed Groups Across Ecoregions,
      Interpretation, References.
- [ ] YAML reuses `bibliography: references.bib` + `link-citations: true`.
- [ ] Snowpack interpretation reflects the **east-west precip
      gradient** (Selkirks vs Purcells) — distinct from Peace.
- [ ] Per-WSG facet plot for `swe_max` and `snowmelt_doy_50` (4
      facets, compact, maps to FWCP reporting unit).
- [ ] Place names worked into the prose: Nelson, Castlegar,
      Trail/Rossland/Red Mountain, Kaslo, Nakusp, Slocan, New Denver,
      Argenta.
- [ ] Render time stays under ~30 s.

## Phase 4 — Watershed Groups Across Ecoregions section (4-WSG version)

- [ ] WSG × ecoregion overlap percentages computed inline in the
      precompute script (no separate commentary CSV — 4 rows is
      small enough).
- [ ] WSG map labelled with codes on top of ecoregion fills.
- [ ] WSG × ecoregion area-share table.

## Phase 5 — ASWS QA cross-check

- [ ] `data-raw/qa_snow_validation_kootenay_lake.R` — filter
      `bcsnowdata::snow_auto_location()` against the 4-WSG AOI; pick
      4–5 representative sites with usable records.
- [ ] Pull daily SWE → annual peak per site-year.
- [ ] Extract ERA5-Land `swe_max` at each site's lat/lon; scatter,
      correlation, mean bias, bias-trend regression.
- [ ] Save `planning/active/qa_snow_validation_kootenay_lake_results.md`
      + scatter PNG. Move to archive on `/planning-archive`.
- [ ] Snowpack-section methodology footnote summarizes the
      Kootenay-specific bias structure.

## Phase 6 — pkgdown + README

- [ ] Update README links to list both vignettes.
- [ ] Local pkgdown render check.
- [ ] (Optional) `_pkgdown.yml` articles ordering: peace-fwcp,
      kootenay-lake.

## Phase 7 — Release v0.2.1

- [ ] `/code-check` clean on each commit.
- [ ] Atomic commits per phase.
- [ ] PR with `Fixes #56`. SRED ref in PR body
      (`Relates to NewGraphEnvironment/sred-2025-2026#23`) — not in
      issue body per memory.
- [ ] Bump DESCRIPTION 0.2.0 → 0.2.1; NEWS entry; tag v0.2.1.

## Validation

- [ ] AOI + context gpkg build and validate.
- [ ] precompute rds covers all 15 vars × regional + per-ecoregion.
- [ ] vignette renders <30 s, citations resolve to References.
- [ ] ASWS QA bias is approximately stable over time.
- [ ] `devtools::test()` clean.
- [ ] `lintr::lint_package()` clean.
- [ ] PWF checkboxes match landed work.
- [ ] `/planning-archive` on completion.

## Out of scope

- Rockies / Elk Valley (different FWCP region, BULL/ELKR).
- Anadromous salmon framing (FWCP Columbia is dam-fragmented; resident
  salmonids only).
- Removing existing KOTL bundled polygons (stay for README quick-start).
- New methodology / lit review (reuse v0.2.0 + #54 stack).
- Updating README quick-start to use the new 4-WSG AOI (would bloat
  the example; quick-start stays on `example_aoi_kotl.gpkg`).
