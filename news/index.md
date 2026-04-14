# Changelog

## cd 0.1.0 (2026-04-14)

CRAN release: 2020-10-22

First minor release. Producer pipeline migrated from Copernicus CDS to
DestinE Earth Data Hub (Zarr). Same ERA5-Land data at the same 9 km
native grid, no rate limiting, ~5x faster fetches. All 7 cd variables
(tmax, tmin, tmean, prcp, vpd, rh, soil_moisture) regenerated on a
single internally-consistent EPSG:4326 BC grid. Monthly GitHub Action
rewired to use EDH. Consumer API unchanged —
[`cd_catalog()`](https://newgraphenvironment.github.io/cd/reference/cd_catalog.md)
and friends work exactly as before against the refreshed STAC catalog on
`s3://stac-era5-land`. See [pkgdown
reference](https://newgraphenvironment.com/cd/reference/) for the
current function list.
([\#36](https://github.com/NewGraphEnvironment/cd/issues/36))

## cd 0.0.0.9000

Initial development version. Consumer and producer pipelines for
ERA5-Land climate departure analysis.
