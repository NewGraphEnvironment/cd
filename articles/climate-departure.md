# Climate Departure Analysis for a Watershed

The cd package computes climate departure statistics from ERA5-Land
reanalysis data for any area of interest. This vignette demonstrates the
full analysis pipeline: connecting to the cloud-hosted data catalog,
extracting zonal means for a watershed, computing anomalies against a
pre-warming baseline, and running trend analysis.

## Area of Interest

We use the Kootenay Lake (KOTL) watershed group from the BC Freshwater
Atlas, shipped with the package. Any `sf` polygon works as an AOI.

``` r
library(cd)
library(sf)

aoi <- st_read(
  system.file("extdata", "example_aoi_kotl.gpkg", package = "cd"),
  quiet = TRUE
)
```

``` r
ggplot(aoi) +
  geom_sf(fill = "#4575b4", alpha = 0.3, color = "#2166ac") +
  labs(title = "Kootenay Lake Watershed Group (KOTL)") +
  theme_minimal(base_size = 12) +
  theme(axis.title = element_blank())
```

![Kootenay Lake (KOTL) watershed group in southeastern British
Columbia.](climate-departure_files/figure-html/map-location-1.png)

Kootenay Lake (KOTL) watershed group in southeastern British Columbia.

## Connect to the Data Catalog

The cd package serves ERA5-Land climate data as Cloud-Optimized GeoTIFFs
on S3, indexed by a STAC catalog.
[`cd_catalog()`](https://newgraphenvironment.github.io/cd/reference/cd_catalog.md)
reads the catalog and returns a tidy tibble of available variables and
periods.

``` r
catalog <- cd_catalog()
catalog
#> # A tibble: 25 × 3
#>    variable period href                                                         
#>    <chr>    <chr>  <chr>                                                        
#>  1 prcp     annual https://stac-era5-land.s3.us-west-2.amazonaws.com/prcp_annua…
#>  2 prcp     fall   https://stac-era5-land.s3.us-west-2.amazonaws.com/prcp_fall.…
#>  3 prcp     spring https://stac-era5-land.s3.us-west-2.amazonaws.com/prcp_sprin…
#>  4 prcp     summer https://stac-era5-land.s3.us-west-2.amazonaws.com/prcp_summe…
#>  5 prcp     winter https://stac-era5-land.s3.us-west-2.amazonaws.com/prcp_winte…
#>  6 rh       annual https://stac-era5-land.s3.us-west-2.amazonaws.com/rh_annual.…
#>  7 rh       fall   https://stac-era5-land.s3.us-west-2.amazonaws.com/rh_fall.tif
#>  8 rh       spring https://stac-era5-land.s3.us-west-2.amazonaws.com/rh_spring.…
#>  9 rh       summer https://stac-era5-land.s3.us-west-2.amazonaws.com/rh_summer.…
#> 10 rh       winter https://stac-era5-land.s3.us-west-2.amazonaws.com/rh_winter.…
#> # ℹ 15 more rows
```

## Extract Climate Time Series

[`cd_extract()`](https://newgraphenvironment.github.io/cd/reference/cd_extract.md)
crops each COG to the AOI and computes the spatial mean per year. This
runs directly against the cloud-hosted data — no local download needed.

``` r
ts <- cd_extract(catalog, aoi)
head(ts, 10)
#> # A tibble: 10 × 4
#>    variable period  year value
#>    <chr>    <chr>  <int> <dbl>
#>  1 prcp     annual  1950 1107.
#>  2 prcp     annual  1951 1075.
#>  3 prcp     annual  1952  702.
#>  4 prcp     annual  1953 1174.
#>  5 prcp     annual  1954 1252.
#>  6 prcp     annual  1955 1133.
#>  7 prcp     annual  1956 1030.
#>  8 prcp     annual  1957  918.
#>  9 prcp     annual  1958 1054.
#> 10 prcp     annual  1959 1221.
```

We now have annual and seasonal values for five climate variables across
76 years (1950–2025) for the Kootenay Lake watershed.

## Choosing a Baseline

The choice of reference period shapes the story. The WMO standard
1981–2010 baseline is widely used for comparability, but it includes
decades of warming. A pre-warming baseline (1951–1980) reveals the full
magnitude of departure — what Pauly (1995) called avoiding the “shifting
baseline syndrome.”

``` r
# Pre-warming baseline
bl_early <- cd_baseline(ts, baseline_years = 1951:1980)

# WMO standard
bl_wmo <- cd_baseline(ts, baseline_years = 1981:2010)

bl_early
#> # A tibble: 25 × 3
#>    variable period baseline_mean
#>    <chr>    <chr>          <dbl>
#>  1 prcp     annual        1061. 
#>  2 prcp     fall           261. 
#>  3 prcp     spring         251. 
#>  4 prcp     summer         208. 
#>  5 prcp     winter         340. 
#>  6 rh       annual          71.3
#>  7 rh       fall            74.9
#>  8 rh       spring          70.8
#>  9 rh       summer          57.7
#> 10 rh       winter          81.8
#> # ℹ 15 more rows
```

## Anomalies

[`cd_anomaly()`](https://newgraphenvironment.github.io/cd/reference/cd_anomaly.md)
computes departures from the baseline. Temperature, VPD, and RH use
absolute deviations. Precipitation and soil moisture use percent of
normal.

``` r
ano <- cd_anomaly(ts, bl_early)
head(ano)
#> # A tibble: 6 × 6
#>   variable period  year anomaly anomaly_type unit 
#>   <chr>    <chr>  <int>   <dbl> <chr>        <chr>
#> 1 prcp     annual  1950    4.39 pct_normal   %    
#> 2 prcp     annual  1951    1.37 pct_normal   %    
#> 3 prcp     annual  1952  -33.8  pct_normal   %    
#> 4 prcp     annual  1953   10.6  pct_normal   %    
#> 5 prcp     annual  1954   18.1  pct_normal   %    
#> 6 prcp     annual  1955    6.80 pct_normal   %
```

## Temperature Departure

``` r
trn <- cd_trend(ano, trend_start = c(1951, 1981))
cd_plot_timeseries(
  ano,
  variable = "tmean",
  period = "annual",
  trend = trn,
  title = "Mean Temperature Anomaly — Kootenay Lake Watershed"
)
```

![Annual mean temperature anomaly for the Kootenay Lake watershed
relative to 1951-1980 baseline. Red bars indicate warmer-than-baseline
years.](climate-departure_files/figure-html/plot-tmean-1.png)

Annual mean temperature anomaly for the Kootenay Lake watershed relative
to 1951-1980 baseline. Red bars indicate warmer-than-baseline years.

``` r
cd_summary(trn[trn$variable == "tmean", ])
#> # A tibble: 10 × 7
#>    Parameter        Period Slope Years `Total Change` Unit  `p-value`
#>    <chr>            <chr>  <dbl> <int>          <dbl> <chr>     <dbl>
#>  1 Mean temperature Annual 0.025    75            1.9 °C       0     
#>  2 Mean temperature Fall   0.024    75            1.8 °C       0.0014
#>  3 Mean temperature Spring 0.027    75            2.1 °C       0     
#>  4 Mean temperature Summer 0.038    75            2.9 °C       0     
#>  5 Mean temperature Winter 0.016    75            1.2 °C       0.037 
#>  6 Mean temperature Annual 0.031    45            1.4 °C       0.0015
#>  7 Mean temperature Fall   0.033    45            1.5 °C       0.0037
#>  8 Mean temperature Spring 0.004    45            0.2 °C       0.822 
#>  9 Mean temperature Summer 0.053    45            2.4 °C       0     
#> 10 Mean temperature Winter 0.02     45            0.9 °C       0.278
```

The Kootenay Lake watershed has warmed substantially since the mid-20th
century. The annual mean temperature trend since 1951 gives a Total
Change that quantifies this cumulative shift.

## Comparing Time Windows

[`cd_compare()`](https://newgraphenvironment.github.io/cd/reference/cd_compare.md)
directly answers: “How different is the recent climate from the
historical climate?”

``` r
cmp <- cd_compare(ts,
  window_a = 2015:2025,
  window_b = 1951:1980,
  method = "mean_diff"
)
cmp
#> # A tibble: 25 × 6
#>    variable period mean_a mean_b difference method   
#>    <chr>    <chr>   <dbl>  <dbl>      <dbl> <chr>    
#>  1 prcp     annual  914.  1061.   -147.     mean_diff
#>  2 prcp     fall    250.   261.    -11.3    mean_diff
#>  3 prcp     spring  238.   251.    -13.7    mean_diff
#>  4 prcp     summer  163.   208.    -45.1    mean_diff
#>  5 prcp     winter  263.   340.    -77.0    mean_diff
#>  6 rh       annual   68.7   71.3    -2.57   mean_diff
#>  7 rh       fall     72.9   74.9    -2.00   mean_diff
#>  8 rh       spring   68.3   70.8    -2.46   mean_diff
#>  9 rh       summer   51.9   57.7    -5.85   mean_diff
#> 10 rh       winter   81.9   81.8     0.0333 mean_diff
#> # ℹ 15 more rows
```

``` r
cd_plot_comparison(
  cmp,
  labels = c(a = "2015-2025", b = "1951-1980"),
  title = "Climate Shift — Kootenay Lake Watershed"
)
```

![Comparison of recent (2015-2025) vs pre-warming (1951-1980) climate
for the Kootenay Lake
watershed.](climate-departure_files/figure-html/plot-compare-1.png)

Comparison of recent (2015-2025) vs pre-warming (1951-1980) climate for
the Kootenay Lake watershed.

## Spatial Patterns of Departure

The zonal mean tells us the watershed average, but departure varies
across the landscape. Valley bottoms, high elevation areas, and rain
shadows respond differently. We can map this by computing the difference
between recent and historical period means directly from the rasters.

``` r
# Read the annual tmean COG and crop to AOI
tmean_row <- catalog[catalog$variable == "tmean" & catalog$period == "annual", ]
r_tmean <- cd_crop(tmean_row$href, aoi)

# Compute period means from the multi-year raster bands
years <- as.integer(names(r_tmean))
recent_idx <- which(years >= 2015 & years <= 2025)
historical_idx <- which(years >= 1951 & years <= 1980)

recent_mean <- mean(r_tmean[[recent_idx]])
historical_mean <- mean(r_tmean[[historical_idx]])
departure <- recent_mean - historical_mean
names(departure) <- "Temperature departure"

ggplot() +
  geom_spatraster(data = departure) +
  geom_sf(data = aoi, fill = NA, color = "black", linewidth = 0.5) +
  scale_fill_distiller(
    palette = "RdBu", direction = -1,
    name = expression(Delta * degree * C)
  ) +
  labs(title = "Temperature Departure (2015-2025 vs 1951-1980)") +
  theme_minimal(base_size = 12) +
  theme(axis.title = element_blank())
```

![Spatial pattern of annual mean temperature departure across the
Kootenay Lake watershed. Difference between 2015-2025 mean and 1951-1980
mean (degrees
C).](climate-departure_files/figure-html/spatial-tmean-1.png)

Spatial pattern of annual mean temperature departure across the Kootenay
Lake watershed. Difference between 2015-2025 mean and 1951-1980 mean
(degrees C).

``` r
sm_row <- catalog[catalog$variable == "soil_moisture" & catalog$period == "summer", ]
r_sm <- cd_crop(sm_row$href, aoi)

years_sm <- as.integer(names(r_sm))
recent_sm <- mean(r_sm[[which(years_sm >= 2015 & years_sm <= 2025)]])
historical_sm <- mean(r_sm[[which(years_sm >= 1951 & years_sm <= 1980)]])
departure_sm <- recent_sm - historical_sm
names(departure_sm) <- "Soil moisture departure"

ggplot() +
  geom_spatraster(data = departure_sm) +
  geom_sf(data = aoi, fill = NA, color = "black", linewidth = 0.5) +
  scale_fill_distiller(
    palette = "BrBG", direction = 1,
    name = expression(Delta ~ m^3/m^3)
  ) +
  labs(title = "Summer Soil Moisture Departure (2015-2025 vs 1951-1980)") +
  theme_minimal(base_size = 12) +
  theme(axis.title = element_blank())
```

![Spatial pattern of summer soil moisture departure. Difference between
2015-2025 mean and 1951-1980 mean (m3/m3). Negative values (brown)
indicate drying.](climate-departure_files/figure-html/spatial-sm-1.png)

Spatial pattern of summer soil moisture departure. Difference between
2015-2025 mean and 1951-1980 mean (m3/m3). Negative values (brown)
indicate drying.

## Seasonal Patterns

Temperature warming is often strongest in specific seasons. Let’s look
at summer and winter separately.

``` r
summer_ano <- ano[ano$period == "summer" & ano$variable == "tmean", ]
winter_ano <- ano[ano$period == "winter" & ano$variable == "tmean", ]

trn_summer <- cd_trend(summer_ano, trend_start = 1951)
trn_winter <- cd_trend(winter_ano, trend_start = 1951)

cd_plot_timeseries(summer_ano, period = "summer", trend = trn_summer,
  title = "Summer Temperature Anomaly")
```

![](climate-departure_files/figure-html/seasonal-1.png)

``` r
cd_summary(rbind(trn_summer, trn_winter))
#> # A tibble: 2 × 7
#>   Parameter        Period Slope Years `Total Change` Unit  `p-value`
#>   <chr>            <chr>  <dbl> <int>          <dbl> <chr>     <dbl>
#> 1 Mean temperature Summer 0.038    75            2.9 °C        0    
#> 2 Mean temperature Winter 0.016    75            1.2 °C        0.037
```

## Precipitation and Soil Moisture

While temperature shows clear departure, precipitation trends in BC are
often less pronounced. Soil moisture integrates both temperature and
precipitation signals — warmer temperatures drive more
evapotranspiration even when rainfall is stable.

``` r
sm_ano <- ano[ano$variable == "soil_moisture" & ano$period == "summer", ]
trn_sm <- cd_trend(sm_ano, trend_start = 1951)

cd_plot_timeseries(sm_ano, variable = "soil_moisture", period = "summer",
  trend = trn_sm, title = "Summer Soil Moisture Anomaly")
```

![](climate-departure_files/figure-html/soil-moisture-1.png)

``` r
all_trends <- cd_trend(
  ano[ano$period == "annual", ],
  trend_start = c(1951, 1981)
)
cd_summary(all_trends)
#> # A tibble: 10 × 7
#>    Parameter               Period  Slope Years `Total Change` Unit  `p-value`
#>    <chr>                   <chr>   <dbl> <int>          <dbl> <chr>     <dbl>
#>  1 Precipitation           Annual -0.168    75          -12.6 %        0.0062
#>  2 Relative humidity       Annual -0.038    75           -2.8 %        0.0008
#>  3 Soil moisture           Annual -0.028    75           -2.1 %        0.068 
#>  4 Mean temperature        Annual  0.025    75            1.9 °C       0     
#>  5 Vapour pressure deficit Annual  0.012    75            0.9 Pa       0     
#>  6 Precipitation           Annual -0.222    45          -10   %        0.0944
#>  7 Relative humidity       Annual -0.089    45           -4   %        0.0001
#>  8 Soil moisture           Annual -0.085    45           -3.8 %        0.0058
#>  9 Mean temperature        Annual  0.031    45            1.4 °C       0.0015
#> 10 Vapour pressure deficit Annual  0.023    45            1.1 Pa       0
```

## Interpretation

The analysis reveals the climate departure pattern common across British
Columbia’s interior watersheds:

- **Temperature is rising.** The cumulative shift since the mid-20th
  century is substantial and statistically significant across all
  seasons.
- **Precipitation trends are weak.** Year-to-year variability is high
  but there is no strong directional change.
- **Soils are drying despite stable precipitation.** Warmer temperatures
  increase evapotranspiration, pulling moisture from soils even when the
  same amount of rain falls. For aquatic ecosystems, drier soils mean
  reduced summer baseflows during the period when flows are already
  lowest.

This pattern — warming without precipitation change leading to
hydrological drought — is the mechanism connecting climate departure to
habitat degradation in salmon-bearing watersheds.

## Data Source

All data are from the [ERA5-Land](https://www.ecmwf.int/en/era5-land)
reanalysis dataset produced by ECMWF for the Copernicus Climate Change
Service (Muñoz-Sabater et al. 2021). Anomalies are relative to
user-defined baseline periods. Trends are computed using the
Mann-Kendall test for significance and the Theil-Sen estimator for slope
magnitude.
