# Climate variable metadata

Returns a tibble of metadata for the seven climate variables supported
by the cd package. Used internally for unit labels, anomaly type
routing, and ERA5-Land API variable names.

## Usage

``` r
cd_variables()
```

## Value

A tibble with columns:

- variable:

  Short name used throughout the package.

- long_name:

  Human-readable label for plots and tables.

- unit:

  Measurement unit (degree C, percent, Pa).

- anomaly_type:

  "absolute" for direct departures, "pct_normal" for percent-of-normal
  anomalies.

- era5_name:

  ERA5-Land variable name for CDS API requests, or NA for derived
  variables.

## Examples

``` r
cd_variables()
#> # A tibble: 15 × 5
#>    variable           long_name                     unit  anomaly_type era5_name
#>    <chr>              <chr>                         <chr> <chr>        <chr>    
#>  1 tmean              Mean temperature              °C    absolute     2m_tempe…
#>  2 tmax               Maximum temperature           °C    absolute     NA       
#>  3 tmin               Minimum temperature           °C    absolute     NA       
#>  4 prcp               Precipitation                 %     pct_normal   total_pr…
#>  5 vpd                Vapour pressure deficit       Pa    absolute     NA       
#>  6 rh                 Relative humidity             %     absolute     NA       
#>  7 soil_moisture      Soil moisture                 %     pct_normal   NA       
#>  8 swe                Snow water equivalent         %     pct_normal   NA       
#>  9 snowfall           Snowfall                      %     pct_normal   NA       
#> 10 snowmelt           Snowmelt                      %     pct_normal   NA       
#> 11 snow_cover         Snow cover                    %     pct_point_d… NA       
#> 12 swe_max            Annual peak snow water equiv… mm    absolute     NA       
#> 13 snowfall_fraction  Snowfall fraction             %     pct_point_d… NA       
#> 14 snowmelt_doy_50    Day of 50% melt               day   absolute     NA       
#> 15 snowmelt_rate_peak Peak weekly melt rate         mm/wk absolute     NA       
cd_variables()$variable
#>  [1] "tmean"              "tmax"               "tmin"              
#>  [4] "prcp"               "vpd"                "rh"                
#>  [7] "soil_moisture"      "swe"                "snowfall"          
#> [10] "snowmelt"           "snow_cover"         "swe_max"           
#> [13] "snowfall_fraction"  "snowmelt_doy_50"    "snowmelt_rate_peak"
```
