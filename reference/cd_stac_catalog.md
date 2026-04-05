# Generate a static STAC catalog from COGs

Scans a directory for Cloud-Optimized GeoTIFFs and builds a STAC catalog
JSON file. Each COG becomes one item with `cd:variable` and `cd:period`
properties parsed from the filename. The resulting catalog is compatible
with
[`cd_catalog()`](https://newgraphenvironment.github.io/cd/reference/cd_catalog.md).

## Usage

``` r
cd_stac_catalog(
  cog_dir,
  output_path = "catalog.json",
  catalog_id = "era5-land",
  title = "ERA5-Land Climate Data",
  description = NULL,
  base_url = "https://stac-era5-land.s3.us-west-2.amazonaws.com"
)
```

## Arguments

- cog_dir:

  Character. Directory containing COG files (.tif).

- output_path:

  Character. Path to write the catalog JSON. Default `"catalog.json"`.

- catalog_id:

  Character. STAC catalog ID. Default `"era5-land"`.

- title:

  Character. Human-readable catalog title.

- description:

  Character. Optional catalog description.

- base_url:

  Character. Base URL where COGs will be served. Asset hrefs are built
  as `{base_url}/{filename}`.

## Value

The output path (invisibly).

## Examples

``` r
if (FALSE) { # \dontrun{
cd_stac_catalog(
  "data/cogs",
  output_path = "data/catalog.json",
  base_url = "https://stac-era5-land.s3.us-west-2.amazonaws.com"
)
} # }
```
