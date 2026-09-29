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
`intercept`, `mk_pvalue`, `n_years`, and `trend_on` (`"value"` or
`"anomaly"`, the column the trend was run on). When `x` carries them,
`anomaly_type`, `unit` and `long_name` are passed through — see the
input contract in
[`cd_anomaly()`](https://newgraphenvironment.github.io/cd/reference/cd_anomaly.md).
`unit` is the anomaly's unit, so on raw values it is kept only for
`absolute` and `pct_point_diff` series, where it is also the unit of the
values.
[`cd_summary()`](https://newgraphenvironment.github.io/cd/reference/cd_summary.md)
reads them.

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
#> # A tibble: 1 × 8
#>   variable period trend_start slope intercept mk_pvalue n_years trend_on
#>   <chr>    <chr>        <dbl> <dbl>     <dbl>     <dbl>   <int> <chr>   
#> 1 tmean    annual        1951 0.128     -253.     0.592      10 value   

# Also works on anomalies — uses 'anomaly' column automatically
bl <- cd_baseline(ts, baseline_years = 1951:1955)
ano <- cd_anomaly(ts, bl)
cd_trend(ano, trend_start = 1951)
#> # A tibble: 1 × 10
#>   variable period trend_start slope intercept mk_pvalue n_years trend_on
#>   <chr>    <chr>        <dbl> <dbl>     <dbl>     <dbl>   <int> <chr>   
#> 1 tmean    annual        1951 0.128     -251.     0.592      10 anomaly 
#> # ℹ 2 more variables: anomaly_type <chr>, unit <chr>
```
