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

## Details

Each item's `data` asset carries `file:checksum` (a sha256 multihash,
`"1220"` + hex digest) and `file:size` from the [STAC file
extension](https://github.com/stac-extensions/file) v2.1.0, taken from
the local file, so build the catalog after the COGs are final. Run
provenance written into a COG by
[`cd_cog_write()`](https://newgraphenvironment.github.io/cd/reference/cd_cog_write.md)
(`CD_VERSION`, `CD_SHA`, `CD_RUN_TIME`, `CD_RUN_ID` tags) is copied into
the item in the [STAC processing
extension](https://github.com/stac-extensions/processing) v1.2.0:
`processing:version`, `processing:software` (`{"cd": "<sha>"}`),
`processing:datetime` (the tag's string, unchanged) and, for a GitHub
Actions run, a `processing-execution` link to the run. An item from an
untagged COG carries none of them and does not declare the extension.
Because the run time is part of the bytes, a checksum identifies a
build, not values: rebuilding unchanged data gives a new checksum.

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
