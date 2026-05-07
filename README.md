# cd <img src="man/figures/logo.png" align="right" height="139" />

Climate Departure Analysis from ERA5-Land Reanalysis

## Overview

cd fetches [ERA5-Land](https://www.ecmwf.int/en/era5-land) hourly reanalysis (1950–present, ~9 km native grid) from the [DestinE Earth Data Hub](https://earthdatahub.destine.eu/), subsets to British Columbia, aggregates to monthly, seasonal, and annual periods, derives additional climate variables (vapour pressure deficit and relative humidity from temperature + dewpoint via the Tetens equation; soil moisture as a 4-depth mean) and snow-pack variables (snow water equivalent, snowfall, snowmelt, snow cover, plus annual derived scalars: peak SWE, snowfall fraction, snowmelt 50% day-of-year, peak weekly melt rate), and writes Cloud-Optimized GeoTIFFs alongside a static SpatioTemporal Asset Catalog (STAC) in a public S3 bucket. A monthly GitHub Action keeps the catalog current. On the consumer side, R functions (`cd_catalog`, `cd_extract`, `cd_baseline`, `cd_anomaly`, `cd_trend`, `cd_compare`, `cd_summary`, `cd_plot_timeseries`, `cd_plot_comparison`) read the COGs directly via GDAL's `/vsicurl/` — no credentials, no tile server — crop to a user-supplied area of interest, compute baselines and anomalies for arbitrary reference periods, and run Mann-Kendall and Theil-Sen trend statistics. All baseline and comparison logic stays on the consumer side, so reference periods are not baked into the served data.

## Installation

```r
pak::pak("NewGraphEnvironment/cd")
```

## Quick start

```r
library(cd)

# Load the live STAC catalog and an example area of interest
catalog <- cd_catalog()
aoi <- sf::st_read(
  system.file("extdata", "example_aoi_kotl.gpkg", package = "cd"),
  quiet = TRUE
)

# Extract zonal mean time series
ts <- cd_extract(catalog, aoi)

# Compute baseline and anomalies
bl <- cd_baseline(ts, baseline_years = 1951:1955)
ano <- cd_anomaly(ts, bl)

# Trend analysis
trn <- cd_trend(ano, trend_start = 1951)

# Reporting table
cd_summary(trn)

# Compare time windows directly
cd_compare(ts, window_a = 1956:1960, window_b = 1951:1955)
```

## Data

The producer pipeline fetches ERA5-Land hourly reanalysis from
[DestinE Earth Data Hub](https://earthdatahub.destine.eu/), derives
additional variables (VPD, RH, soil moisture), aggregates to monthly,
seasonal, and annual periods on a single EPSG:4326 BC grid, and writes
Cloud-Optimized GeoTIFFs alongside a static SpatioTemporal Asset
Catalog (STAC) in a public S3 bucket.

- Catalog (JSON): <https://stac-era5-land.s3.us-west-2.amazonaws.com/catalog.json>
- Region: BC (~48–60° N, 114–140° W), 1950–2025, ~9 km native grid
- Variables (15):
  - **Core climate** (7): tmean, tmax, tmin, prcp, vpd, rh, soil_moisture
  - **Snow monthly natives** (4): swe, snowfall, snowmelt, snow_cover
  - **Snow annual derived** (4): swe_max, snowfall_fraction, snowmelt_doy_50, snowmelt_rate_peak
- Periods: seasonal (DJF/MAM/JJA/SON) and annual for monthly-native vars; annual only for snow_max / snowfall_fraction / snowmelt_doy_50 / snowmelt_rate_peak

The catalog is consumable directly outside R — for example, in QGIS via
the STAC plugin, in `gdalcubes`, or with any STAC-aware client. The
`cd_catalog()` consumer function reads the catalog URL by default.

## Links

- [Function reference](https://newgraphenvironment.github.io/cd/reference/)
- Vignettes:
  - [Climate Departure for the FWCP Peace Region](https://newgraphenvironment.github.io/cd/articles/peace-fwcp.html)
  - [Climate Departure for the Kootenay Lake Region](https://newgraphenvironment.github.io/cd/articles/kootenay-lake.html)

## Acknowledgements

This package is inspired by [`bcgov/bc_climate_anomaly`](https://github.com/bcgov/bc_climate_anomaly), a Shiny app developed by the Province of British Columbia (Aseem Sharma and contributors) that visualizes monthly, seasonal, and annual climate anomalies for temperature, precipitation, humidity, vapor pressure, and soil moisture across BC. The variable set and the eco-region / watershed framing in `cd` follow directly from that work. `bc_climate_anomaly` is licensed under the Apache License 2.0.
