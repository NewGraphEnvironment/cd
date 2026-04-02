# Load and parse a STAC catalog

Reads a static STAC catalog JSON file and returns a tidy tibble of
available climate data COGs. This is the entry point for consumer-side
workflows.

## Usage

``` r
cd_catalog(catalog = cd_catalog_default())
```

## Arguments

- catalog:

  Path or URL to a STAC catalog JSON file. Defaults to
  [`cd_catalog_default()`](https://newgraphenvironment.github.io/cd/reference/cd_catalog_default.md).

## Value

A tibble with columns:

- variable:

  Climate variable short name (e.g., "tmean").

- period:

  Temporal aggregation period (e.g., "annual").

- href:

  Resolved path or URL to the COG file.

## Examples

``` r
cd_catalog(
  system.file("extdata", "example_catalog.json", package = "cd")
)
#> # A tibble: 1 × 3
#>   variable period href                                                          
#>   <chr>    <chr>  <chr>                                                         
#> 1 tmean    annual /home/runner/work/_temp/Library/cd/extdata/./example_climate.…
```
