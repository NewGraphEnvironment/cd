# Findings — FWCP Peace vignette

## AOI source

- `~/Projects/gis/sern_peace_fwcp_2023/fwcp_peace_region.geojson` — single multi-polygon, EPSG:3005, extent (894641, 1030751) – (1297055, 1449403). ~400 × 420 km, ~170,000 km².
- `background_layers.gpkg` in same project has `whse_basemapping.fwa_watershed_groups_poly` with 11 WSGs (CARP, CRKD, FINA, LOMI, MESI, NATR, PARA, PARS, PCEA, UOMI, UPCE) — clipped to fieldwork extent. Not used for iter 1.
- Iter 2 will pull the canonical WSG list via fwapg / `fresh::frs_clip()`.

## Sizing vs KOTL

- KOTL AOI: ~6,500 km², 121 × 261 raster window
- FWCP Peace: ~170,000 km² (~26× larger). Expect proportionally larger COG range reads, but should still be fast (single-digit seconds) given STAC/COG architecture.

## Decisions

- AOI ships as `inst/extdata/example_aoi_fwcp_peace.gpkg` to match KOTL pattern (self-contained vignette, no external dep).
- Vignette is intentionally bare-bones for iter 1 — no interpretation prose, no per-WSG. KOTL got the deep critical interpretation; this one stays pipeline-focused until we layer narrative in iter 2/3.
