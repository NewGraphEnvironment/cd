# Compute trend statistics

Runs Mann-Kendall significance test and Theil-Sen slope estimator on
time series data for each variable, period, and trend start year.

## Usage

``` r
cd_trend(x, trend_start = c(1950, 1980))
```

## Arguments

- x:

  A tibble from
  [`cd_extract()`](https://newgraphenvironment.github.io/cd/reference/cd_extract.md)
  or
  [`cd_anomaly()`](https://newgraphenvironment.github.io/cd/reference/cd_anomaly.md)
  with columns `variable`, `period`, `year`, and either `value` or
  `anomaly`.

- trend_start:

  Integer vector of start years for trend windows. Default
  `c(1950, 1980)`.

## Value

A tibble with columns `variable`, `period`, `trend_start`, `slope`,
`intercept`, `mk_pvalue`, `n_years`.

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

# Trend on raw values
cd_trend(ts, trend_start = 1951)
#> # A tibble: 1 × 7
#>   variable period trend_start slope intercept mk_pvalue n_years
#>   <chr>    <chr>        <dbl> <dbl>     <dbl>     <dbl>   <int>
#> 1 tmean    annual        1951 0.128     -253.     0.592      10

# Also works on anomalies — uses 'anomaly' column automatically
bl <- cd_baseline(ts, baseline_years = 1951:1955)
ano <- cd_anomaly(ts, bl)
cd_trend(ano, trend_start = 1951)
#> # A tibble: 1 × 7
#>   variable period trend_start slope intercept mk_pvalue n_years
#>   <chr>    <chr>        <dbl> <dbl>     <dbl>     <dbl>   <int>
#> 1 tmean    annual        1951 0.128     -251.     0.592      10
```
