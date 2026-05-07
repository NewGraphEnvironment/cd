# Crop and mask a raster to an AOI

Reads a COG (local or remote) and crops it to a user-supplied area of
interest polygon. Works with local file paths and remote URLs via GDAL's
`/vsicurl/`.

## Usage

``` r
cd_crop(href, aoi)
```

## Arguments

- href:

  Character. Path or URL to a COG or raster file.

- aoi:

  An `sf` or `SpatVector` polygon to crop to.

## Value

A
[terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
cropped and masked to the AOI.

## Examples

``` r
href <- system.file("extdata", "example_climate.tif", package = "cd")
aoi <- sf::st_read(
  system.file("extdata", "example_aoi.gpkg", package = "cd"),
  quiet = TRUE
)
r <- cd_crop(href, aoi)
r
#> class       : SpatRaster
#> size        : 4, 5, 10  (nrow, ncol, nlyr)
#> resolution  : 0.25, 0.25  (x, y)
#> extent      : -126.875, -125.625, 53.875, 54.875  (xmin, xmax, ymin, ymax)
#> coord. ref. : lon/lat WGS 84 (EPSG:4326)
#> source(s)   : memory
#> varname     : example_climate
#> names       :      1951,      1952,      1953,      1954,      1955,      1956, ...
#> min values  :  -3.02646,  -2.06612, -1.047644, -0.334275, -1.447783, -2.927964, ...
#> max values  : -2.723417, -1.877674,  -0.73699, -0.093931, -1.106457, -2.837888, ...
```
