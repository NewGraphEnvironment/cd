# Compute climatological baseline

Computes the mean value over a reference period for each variable and
period combination. The result is used by
[`cd_anomaly()`](https://newgraphenvironment.github.io/cd/reference/cd_anomaly.md)
to calculate departures.

## Usage

``` r
cd_baseline(x, baseline_years = 1981:2010)
```

## Arguments

- x:

  A tibble from
  [`cd_extract()`](https://newgraphenvironment.github.io/cd/reference/cd_extract.md)
  with columns `variable`, `period`, `year`, `value`.

- baseline_years:

  Integer vector of years to average. Default `1981:2010` (WMO
  standard).

## Value

A tibble with columns `variable`, `period`, `baseline_mean`.

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

# Early period baseline — pre-warming reference for departure communication
cd_baseline(ts, baseline_years = 1951:1955)
#> # A tibble: 1 × 3
#>   variable period baseline_mean
#>   <chr>    <chr>          <dbl>
#> 1 tmean    annual         -1.44

# Later period baseline — shows how baseline choice affects anomaly magnitude
cd_baseline(ts, baseline_years = 1956:1960)
#> # A tibble: 1 × 3
#>   variable period baseline_mean
#>   <chr>    <chr>          <dbl>
#> 1 tmean    annual         -1.33
```
