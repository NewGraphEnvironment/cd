# Findings

## Example data sizing

From bc_climate_anomaly NCs (0.25° resolution):
- Small bbox crops to 2×3 = 6 grid cells
- 5-year cropped COG: ~7KB
- AOI GeoJSON is 449K (too detailed) — use simple bbox polygon instead

## Example data approach

Crop real NC data to anonymous bbox. No place names, no identifying attributes.
`data-raw/create_example_data.R` documents provenance. Shipped data is generic.

## STAC catalog structure

Minimal static catalog for cd — one JSON file with inline items:
- Each item: variable, period, href to COG
- `cd_catalog()` parses to tibble: variable, period, href
- Relative hrefs resolved against catalog file path (works for local + remote)

## cd_extract() architecture

For each variable × period in catalog:
1. Filter catalog tibble
2. `cd_crop(href, aoi)` → cropped SpatRaster (bands = years)
3. `terra::global("mean", na.rm = TRUE)` → one value per year
4. Bind into tibble: variable, period, year, value

Returns RAW values. Anomalies computed downstream by `cd_anomaly()`.

## No S3 needed yet

All consumer functions work against local files. Remote COG support via `/vsicurl/`
tested later when producer infra (#7, #8) is built.
