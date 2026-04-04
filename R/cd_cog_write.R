#' Write a SpatRaster as a Cloud-Optimized GeoTIFF
#'
#' Wrapper around [terra::writeRaster()] with COG format defaults.
#' Compression and other GDAL creation options are parameterized
#' for flexibility across data types and use cases.
#'
#' @param x A [terra::SpatRaster] to write.
#' @param path Character. Output file path.
#' @param overwrite Logical. Overwrite existing file. Default `FALSE`.
#' @param gdal Character vector of GDAL creation options.
#'   Default `c("COMPRESS=DEFLATE")`. Other common options:
#'   `"COMPRESS=LZW"`, `"COMPRESS=ZSTD"`, `"OVERVIEW_RESAMPLING=AVERAGE"`,
#'   `"BLOCKSIZE=512"`.
#' @param ... Additional arguments passed to [terra::writeRaster()].
#'
#' @return The output file path (invisibly).
#'
#' @examples
#' r <- terra::rast(nrows = 10, ncols = 10, vals = rnorm(100))
#' tmp <- tempfile(fileext = ".tif")
#' cd_cog_write(r, tmp, overwrite = TRUE)
#'
#' # Custom compression
#' cd_cog_write(r, tmp, overwrite = TRUE, gdal = c("COMPRESS=LZW"))
#'
#' @export
cd_cog_write <- function(x, path, overwrite = FALSE,
                         gdal = c("COMPRESS=DEFLATE"), ...) {
  terra::writeRaster(
    x, path,
    filetype = "COG",
    overwrite = overwrite,
    gdal = gdal,
    ...
  )
  invisible(path)
}
