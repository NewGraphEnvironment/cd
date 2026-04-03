# Compare arbitrary time windows

Computes the mean value for two user-defined time windows and the
difference between them. Enables custom comparisons beyond standard
baseline anomalies.

## Usage

``` r
cd_compare(x, window_a, window_b, method = "mean_diff")
```

## Arguments

- x:

  A tibble from
  [`cd_extract()`](https://newgraphenvironment.github.io/cd/reference/cd_extract.md)
  with columns `variable`, `period`, `year`, `value`.

- window_a:

  Integer vector of years for the first window.

- window_b:

  Integer vector of years for the second window.

- method:

  Character. Comparison method: `"mean_diff"` for `mean_a - mean_b`, or
  `"pct_change"` for percentage change relative to window_b.

## Value

A tibble with columns `variable`, `period`, `mean_a`, `mean_b`,
`difference`, `method`.

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

# How has the recent period shifted from the early period?
cd_compare(ts, window_a = 1956:1960, window_b = 1951:1955)
#> # A tibble: 1 × 6
#>   variable period mean_a mean_b difference method   
#>   <chr>    <chr>   <dbl>  <dbl>      <dbl> <chr>    
#> 1 tmean    annual  -1.33  -1.44      0.110 mean_diff

# Same comparison as percentage change
cd_compare(ts, window_a = 1956:1960, window_b = 1951:1955, method = "pct_change")
#> # A tibble: 1 × 6
#>   variable period mean_a mean_b difference method    
#>   <chr>    <chr>   <dbl>  <dbl>      <dbl> <chr>     
#> 1 tmean    annual  -1.33  -1.44       7.63 pct_change
```
