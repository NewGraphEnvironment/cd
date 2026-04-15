# cd 0.1.1 (2026-04-15)

Vignette and docs patch. The `climate-departure` vignette gained a "Daytime Highs and Overnight Lows" section using the tmax/tmin variables now on STAC, with honest framing for the example watershed (the textbook day-night asymmetry doesn't show at Kootenay Lake — the dominant signal is summer daytime maximum, the temperature envelope for salmonid thermal stress in tributaries). Existing maps now clip context layers and mask departure rasters to the watershed group polygon for tighter framing. Interpretation section corrected: precipitation has declined ~10% (statistically significant) and soils are drying due to both falling precipitation and rising evapotranspiration. README quick-start fixed (was referencing files that don't exist) and now links to the live pkgdown vignette. ([#39](https://github.com/NewGraphEnvironment/cd/issues/39))

# cd 0.1.0 (2026-04-14)

First minor release. Producer pipeline migrated from Copernicus CDS to DestinE Earth Data Hub (Zarr). Same ERA5-Land data at the same 9 km native grid, no rate limiting, ~5x faster fetches. All 7 cd variables (tmax, tmin, tmean, prcp, vpd, rh, soil_moisture) regenerated on a single internally-consistent EPSG:4326 BC grid. Monthly GitHub Action rewired to use EDH. Consumer API unchanged — `cd_catalog()` and friends work exactly as before against the refreshed STAC catalog on `s3://stac-era5-land`. See [pkgdown reference](https://newgraphenvironment.com/cd/reference/) for the current function list. ([#36](https://github.com/NewGraphEnvironment/cd/issues/36))

# cd 0.0.0.9000

Initial development version. Consumer and producer pipelines for ERA5-Land climate departure analysis.
