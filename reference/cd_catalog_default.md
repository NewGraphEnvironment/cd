# Default STAC catalog URL

Returns the default S3-hosted STAC catalog URL for the cd package.
Override with `options(cd.catalog_url = "...")`.

## Usage

``` r
cd_catalog_default()
```

## Value

Character URL.

## Examples

``` r
cd_catalog_default()
#> [1] "https://stac-era5-land.s3.us-west-2.amazonaws.com/catalog.json"
```
