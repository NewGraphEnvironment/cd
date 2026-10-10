# Write a SpatRaster as a Cloud-Optimized GeoTIFF

Wrapper around
[`terra::writeRaster()`](https://rspatial.github.io/terra/reference/writeRaster.html)
with COG format defaults. Compression and other GDAL creation options
are parameterized for flexibility across data types and use cases.

## Usage

``` r
cd_cog_write(
  x,
  path,
  overwrite = FALSE,
  gdal = c("COMPRESS=DEFLATE"),
  tags = NULL,
  ...
)
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

- tags:

  Named character vector of dataset metadata to write, or `NULL`
  (default) for none. Names may not contain `:`, which GDAL reads as a
  metadata domain separator.

- ...:

  Additional arguments passed to
  [`terra::writeRaster()`](https://rspatial.github.io/terra/reference/writeRaster.html).

## Value

The output file path (invisibly).

## Details

`tags` are written into the file as GDAL dataset metadata, so they are
part of the bytes and of any checksum taken afterwards. The producer
pipelines pass the run's provenance here (`CD_VERSION`, `CD_SHA`,
`CD_RUN_TIME`, `CD_RUN_ID`). Any `CD_*` tag the input already carries,
such as one read back from a published COG, is dropped first, so a
rewrite never inherits an earlier run's provenance.

## Examples

``` r
r <- terra::rast(nrows = 10, ncols = 10, vals = rnorm(100))
tmp <- tempfile(fileext = ".tif")
cd_cog_write(r, tmp, overwrite = TRUE)

# Custom compression
cd_cog_write(r, tmp, overwrite = TRUE, gdal = c("COMPRESS=LZW"))

# Record where the file came from, inside the file
cd_cog_write(r, tmp, overwrite = TRUE,
             tags = c(CD_VERSION = "0.6.2", CD_RUN_ID = "local"))
terra::metags(terra::rast(tmp))
#>            name value domain
#> 1 AREA_OR_POINT  Area       
#> 2     CD_RUN_ID local       
#> 3    CD_VERSION 0.6.2       
```
