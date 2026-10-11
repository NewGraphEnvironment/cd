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
  years = NULL,
  cache = TRUE
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

- cache:

  Logical. If `TRUE` (default), remote COGs are read through the on-disk
  cache (see
  [`cd_cache_fetch()`](https://newgraphenvironment.github.io/cd/reference/cd_cache_fetch.md))
  so repeated extractions and report rebuilds download each COG from S3
  once rather than on every call. Passed through to
  [`cd_crop()`](https://newgraphenvironment.github.io/cd/reference/cd_crop.md).

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

- checksum:

  The checksum `catalog` gives for the file read, kept only when the
  file is shown to be that build (see Provenance); otherwise `NA`.

- cd_sha:

  Git commit of the cd code that built the file read, from the file's
  own tags; `NA` for an untagged file.

## Provenance

`checksum` and `cd_sha` record which build of each file the values came
from, so a later run can tell when a republish changed it. `cd_sha` is
read from the file itself. `checksum` comes from `catalog` (see
[`cd_catalog()`](https://newgraphenvironment.github.io/cd/reference/cd_catalog.md))
and is kept only when the file's run-time tag matches the catalog's
`run_time`, so a stale cached copy or an out-of-date catalog gives `NA`
rather than another build's checksum, and a warning for a row carrying
both a checksum and a `run_time`. A catalog row with no `run_time`
cannot be checked and gives `NA` without a warning. A checksum
identifies a build, not values.

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
#> # A tibble: 10 × 6
#>    variable period  year  value checksum cd_sha
#>    <chr>    <chr>  <int>  <dbl> <chr>    <chr> 
#>  1 tmean    annual  1951 -2.87  NA       NA    
#>  2 tmean    annual  1952 -2.01  NA       NA    
#>  3 tmean    annual  1953 -0.881 NA       NA    
#>  4 tmean    annual  1954 -0.223 NA       NA    
#>  5 tmean    annual  1955 -1.22  NA       NA    
#>  6 tmean    annual  1956 -2.88  NA       NA    
#>  7 tmean    annual  1957 -1.37  NA       NA    
#>  8 tmean    annual  1958 -1.34  NA       NA    
#>  9 tmean    annual  1959  0.537 NA       NA    
#> 10 tmean    annual  1960 -1.61  NA       NA    
```
