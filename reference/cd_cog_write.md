# Write a SpatRaster as a Cloud-Optimized GeoTIFF

Wrapper around
[`terra::writeRaster()`](https://rspatial.github.io/terra/reference/writeRaster.html)
with COG format defaults. Compression and other GDAL creation options
are parameterized for flexibility across data types and use cases.

## Usage

``` r
cd_cog_write(x, path, overwrite = FALSE, gdal = c("COMPRESS=DEFLATE"), ...)
```

## Arguments

- x:

  A
  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  to write.

- path:

  Character. Output file path.

- overwrite:

  Logical. Overwrite existing file. Default `FALSE`.

- gdal:

  Character vector of GDAL creation options. Default
  `c("COMPRESS=DEFLATE")`. Other common options: `"COMPRESS=LZW"`,
  `"COMPRESS=ZSTD"`, `"OVERVIEW_RESAMPLING=AVERAGE"`, `"BLOCKSIZE=512"`.

- ...:

  Additional arguments passed to
  [`terra::writeRaster()`](https://rspatial.github.io/terra/reference/writeRaster.html).

## Value

The output file path (invisibly).

## Examples

``` r
r <- terra::rast(nrows = 10, ncols = 10, vals = rnorm(100))
tmp <- tempfile(fileext = ".tif")
cd_cog_write(r, tmp, overwrite = TRUE)
#> Warning: GDAL Message 6: driver MEM does not support creation option COMPRESS

# Custom compression
cd_cog_write(r, tmp, overwrite = TRUE, gdal = c("COMPRESS=LZW"))
#> Warning: GDAL Message 6: driver MEM does not support creation option COMPRESS
```
