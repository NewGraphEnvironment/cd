# Extract zonal mean time series for an AOI

For each variable and period in the catalog, crops the COG to the AOI
and computes the spatial mean per year (band). Returns a tidy tibble of
raw climate values suitable for
[`cd_baseline()`](https://newgraphenvironment.github.io/cd/reference/cd_baseline.md),
[`cd_anomaly()`](https://newgraphenvironment.github.io/cd/reference/cd_anomaly.md),
or
[`cd_trend()`](https://newgraphenvironment.github.io/cd/reference/cd_trend.md).

## Usage

``` r
cd_extract(
  catalog,
  aoi,
  variables = catalog$variable,
  periods = catalog$period,
  years = NULL
)
```

## Arguments

- catalog:

  A tibble from
  [`cd_catalog()`](https://newgraphenvironment.github.io/cd/reference/cd_catalog.md)
  with columns `variable`, `period`, `href`.

- aoi:

  An `sf` or `SpatVector` polygon.

- variables:

  Character vector of variables to extract. Defaults to all variables in
  `catalog`.

- periods:

  Character vector of periods to extract. Defaults to all periods in
  `catalog`.

- years:

  Optional integer vector to filter specific years.

## Value

A tibble with columns:

- variable:

  Climate variable short name.

- period:

  Temporal aggregation period.

- year:

  Year (integer).

- value:

  Spatial mean of the climate value for this AOI.

## Examples

``` r
catalog <- cd_catalog(
  system.file("extdata", "example_catalog.json", package = "cd")
)
aoi <- sf::st_read(
  system.file("extdata", "example_aoi.gpkg", package = "cd"),
  quiet = TRUE
)
cd_extract(catalog, aoi)
#> # A tibble: 10 × 4
#>    variable period  year  value
#>    <chr>    <chr>  <int>  <dbl>
#>  1 tmean    annual  1951 -2.87 
#>  2 tmean    annual  1952 -2.01 
#>  3 tmean    annual  1953 -0.881
#>  4 tmean    annual  1954 -0.223
#>  5 tmean    annual  1955 -1.22 
#>  6 tmean    annual  1956 -2.88 
#>  7 tmean    annual  1957 -1.37 
#>  8 tmean    annual  1958 -1.34 
#>  9 tmean    annual  1959  0.537
#> 10 tmean    annual  1960 -1.61 
```
