# Format trend results as a reporting table

Joins trend statistics with variable metadata from
[`cd_variables()`](https://newgraphenvironment.github.io/cd/reference/cd_variables.md)
and computes Total Change (slope x years). Returns a tibble ready for
`DT::datatable()` or
[`gt::gt()`](https://gt.rstudio.com/reference/gt.html).

## Usage

``` r
cd_summary(trend, region_name = NULL)
```

## Arguments

- trend:

  A tibble from
  [`cd_trend()`](https://newgraphenvironment.github.io/cd/reference/cd_trend.md).

- region_name:

  Optional character label for the AOI. If provided, adds a `Region`
  column.

## Value

A tibble with columns `Parameter`, `Period`, `Slope`, `Years`,
`Total Change`, `Unit`, `p-value`, and optionally `Region`.

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
trn <- cd_trend(ts, trend_start = 1951)

# Reporting table with Total Change = slope * years
cd_summary(trn)
#> # A tibble: 1 × 7
#>   Parameter        Period Slope Years `Total Change` Unit  `p-value`
#>   <chr>            <chr>  <dbl> <int>          <dbl> <chr>     <dbl>
#> 1 Mean temperature Annual 0.128    10            1.3 °C        0.592

# Add region label for multi-AOI reports
cd_summary(trn, region_name = "Example AOI")
#> # A tibble: 1 × 8
#>   Parameter        Period Slope Years `Total Change` Unit  `p-value` Region     
#>   <chr>            <chr>  <dbl> <int>          <dbl> <chr>     <dbl> <chr>      
#> 1 Mean temperature Annual 0.128    10            1.3 °C        0.592 Example AOI
```
