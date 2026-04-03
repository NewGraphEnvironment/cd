# Compute climate anomalies

Calculates departure from a baseline for each year. Uses
[`cd_variables()`](https://newgraphenvironment.github.io/cd/reference/cd_variables.md)
to determine the anomaly type: absolute deviation for temperature, VPD,
and RH; percent of normal for precipitation and soil moisture.

## Usage

``` r
cd_anomaly(x, baseline, cap_pct = 200)
```

## Arguments

- x:

  A tibble from
  [`cd_extract()`](https://newgraphenvironment.github.io/cd/reference/cd_extract.md)
  with columns `variable`, `period`, `year`, `value`.

- baseline:

  A tibble from
  [`cd_baseline()`](https://newgraphenvironment.github.io/cd/reference/cd_baseline.md)
  with columns `variable`, `period`, `baseline_mean`.

- cap_pct:

  Numeric. Cap for percent-of-normal anomalies. Values beyond +/-
  `cap_pct` are clamped. Default `200`.

## Value

A tibble with columns `variable`, `period`, `year`, `anomaly`,
`anomaly_type`, `unit`.

## Examples

``` r
catalog <- cd_catalog(
  system.file("extdata", "example_catalog.json", package = "cd")
)
aoi <- sf::st_read(
  system.file("extdata", "example_aoi.gpkg", package = "cd"),
  quiet = TRUE
)
ts <- cd_extract(catalog, aoi)

# Compute anomalies relative to early-period baseline
# Absolute deviation for temperature; percent of normal for precipitation
bl <- cd_baseline(ts, baseline_years = 1951:1955)
cd_anomaly(ts, bl)
#> # A tibble: 10 × 6
#>    variable period  year anomaly anomaly_type unit 
#>    <chr>    <chr>  <int>   <dbl> <chr>        <chr>
#>  1 tmean    annual  1951 -1.43   absolute     °C   
#>  2 tmean    annual  1952 -0.571  absolute     °C   
#>  3 tmean    annual  1953  0.562  absolute     °C   
#>  4 tmean    annual  1954  1.22   absolute     °C   
#>  5 tmean    annual  1955  0.218  absolute     °C   
#>  6 tmean    annual  1956 -1.43   absolute     °C   
#>  7 tmean    annual  1957  0.0707 absolute     °C   
#>  8 tmean    annual  1958  0.106  absolute     °C   
#>  9 tmean    annual  1959  1.98   absolute     °C   
#> 10 tmean    annual  1960 -0.171  absolute     °C   
```
