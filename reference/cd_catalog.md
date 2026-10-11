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

- checksum:

  The file's sha256 as a multihash (`"1220"` + hex), from the item's
  `file:checksum`.

- size:

  The file's size in bytes, from `file:size`.

- cd_version:

  Version of cd that built the file (`processing:version`).

- cd_sha:

  Git commit of the cd code that built the file (`processing:software`'s
  `cd` entry).

- run_time:

  When the build ran, UTC, RFC 3339 (`processing:datetime`).

- run_url:

  The CI run that built the file (the item's `processing-execution`
  link); `NA` for a local build.

Each of the last six is `NA` where the catalog does not carry it.

## Provenance

The `checksum` and `cd_sha` columns say which build of each file the
catalog describes, so an analysis can record them and notice when a
republish changes a file. A checksum identifies a build, not values: the
run time is written into the file, so rebuilding unchanged data gives a
new checksum. A changed checksum means "rebuilt", not "different data".

## Examples

``` r
cd_catalog(
  system.file("extdata", "example_catalog.json", package = "cd")
)
#> # A tibble: 1 × 9
#>   variable period href         checksum  size cd_version cd_sha run_time run_url
#>   <chr>    <chr>  <chr>        <chr>    <dbl> <chr>      <chr>  <chr>    <chr>  
#> 1 tmean    annual /home/runne… NA          NA NA         NA     NA       NA     
```
