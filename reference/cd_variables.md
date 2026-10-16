# Climate variable metadata

Returns a tibble of metadata for the climate variables supported by the
cd package. Used internally for unit labels, anomaly type routing, which
variables can take a percent change, and ERA5-Land API variable names.
Covers the seven core climate variables plus eight snow-related
variables (four monthly natives, four annual derived) added in v0.2.0.

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

  Unit of the anomaly (degree C, percent, hPa, day, mm/wk): percent for
  every `pct_normal` and `pct_point_diff` variable, whatever the unit of
  its values.

- anomaly_type:

  "absolute" for direct departures (value - baseline, reported in the
  variable's native unit), "pct_normal" for percent-of-normal anomalies
  (100 \* value / baseline - 100, capped), "pct_point_diff" for
  departures in percentage points (used for variables that are already
  fractions/percentages, e.g. snow cover, snowfall fraction, where
  pct-of-normal is meaningless and the natural delta is value - baseline
  interpreted as percentage points).

- pct_change:

  `TRUE` where a percent change between two windows means something,
  because the values have a real zero. `FALSE` for temperatures in
  degree C and the day of 50% melt, whose zero is arbitrary (a base mean
  near 0 degree C makes the percent unbounded and its sign arbitrary),
  and for variables whose values are already in percent (`rh`,
  `snow_cover`, `snowfall_fraction`). Read by
  [`cd_compare()`](https://newgraphenvironment.github.io/cd/reference/cd_compare.md).
  Independent of `anomaly_type`: `vpd` and `snowmelt_rate_peak` are
  `absolute` and still take a percent.

- era5_name:

  ERA5-Land variable name for CDS API requests, or NA for derived
  variables.

## Details

`tmax` and `tmin` are monthly means of the daily maximum and minimum of
hourly 2 m temperature, over **local days** at a fixed UTC-8 (Pacific
Standard Time, no daylight saving; an hour off in the Mountain Standard
Time corner of eastern BC), the same days as
[`cd_extract_daily()`](https://newgraphenvironment.github.io/cd/reference/cd_extract_daily.md).
Before cd#37 the published layers used UTC days, which run from one
afternoon peak to the next and read tmax about 0.5-0.8 degrees C high.
`tmean`, `vpd`, `rh` and `soil_moisture` average hourly values over UTC
months.

## Examples

``` r
cd_variables()
#> # A tibble: 15 × 6
#>    variable           long_name          unit  anomaly_type pct_change era5_name
#>    <chr>              <chr>              <chr> <chr>        <lgl>      <chr>    
#>  1 tmean              Mean temperature   °C    absolute     FALSE      2m_tempe…
#>  2 tmax               Maximum temperatu… °C    absolute     FALSE      NA       
#>  3 tmin               Minimum temperatu… °C    absolute     FALSE      NA       
#>  4 prcp               Precipitation      %     pct_normal   TRUE       total_pr…
#>  5 vpd                Vapour pressure d… hPa   absolute     TRUE       NA       
#>  6 rh                 Relative humidity  %     absolute     FALSE      NA       
#>  7 soil_moisture      Soil moisture      %     pct_normal   TRUE       NA       
#>  8 swe                Snow water equiva… %     pct_normal   TRUE       NA       
#>  9 snowfall           Snowfall           %     pct_normal   TRUE       NA       
#> 10 snowmelt           Snowmelt           %     pct_normal   TRUE       NA       
#> 11 snow_cover         Snow cover         %     pct_point_d… FALSE      NA       
#> 12 swe_max            Annual peak snow … %     pct_normal   TRUE       NA       
#> 13 snowfall_fraction  Snowfall fraction  %     pct_point_d… FALSE      NA       
#> 14 snowmelt_doy_50    Day of 50% melt    day   absolute     FALSE      NA       
#> 15 snowmelt_rate_peak Peak weekly melt … mm/wk absolute     TRUE       NA       
cd_variables()$variable
#>  [1] "tmean"              "tmax"               "tmin"              
#>  [4] "prcp"               "vpd"                "rh"                
#>  [7] "soil_moisture"      "swe"                "snowfall"          
#> [10] "snowmelt"           "snow_cover"         "swe_max"           
#> [13] "snowfall_fraction"  "snowmelt_doy_50"    "snowmelt_rate_peak"
```
