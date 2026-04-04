# cd

Climate Departure Analysis from ERA5-Land Reanalysis

## Overview

cd computes climate anomalies from
[ERA5-Land](https://www.ecmwf.int/en/era5-land) reanalysis data for
custom areas of interest. It downloads raw climate data, derives
variables (VPD, RH, soil moisture), publishes Cloud-Optimized GeoTIFFs
to a STAC catalog, and provides consumer functions to extract zonal
statistics, compute baselines and anomalies for arbitrary reference
periods, and run trend analysis.

## Installation

``` r
pak::pak("NewGraphEnvironment/cd")
```

## Quick start

``` r
library(cd)

# Load a STAC catalog and an area of interest
catalog <- cd_catalog(
  system.file("extdata", "example_catalog.json", package = "cd")
)
aoi <- sf::st_read(
  system.file("extdata", "example_aoi.gpkg", package = "cd"),
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

## Links

- [Function
  reference](https://newgraphenvironment.github.io/cd/reference/)
- [Vignette](https://newgraphenvironment.github.io/cd/articles/) (coming
  soon)
