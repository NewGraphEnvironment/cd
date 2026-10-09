#' Write a SpatRaster as a Cloud-Optimized GeoTIFF
#'
#' Wrapper around [terra::writeRaster()] with COG format defaults.
#' Compression and other GDAL creation options are parameterized
#' for flexibility across data types and use cases.
#'
#' `tags` are written into the file as GDAL dataset metadata, so they are
#' part of the bytes and of any checksum taken afterwards. The producer
#' pipelines pass the run's provenance here (`CD_VERSION`, `CD_SHA`,
#' `CD_RUN_TIME`, `CD_RUN_ID`). Any `CD_*` tag the input already carries,
#' such as one read back from a published COG, is dropped first, so a
#' rewrite never inherits an earlier run's provenance.
#'
#' @param x A [terra::SpatRaster] to write.
#' @param path Character. Output file path.
#' @param overwrite Logical. Overwrite existing file. Default `FALSE`.
#' @param gdal Character vector of GDAL creation options.
#'   Default `c("COMPRESS=DEFLATE")`. Other common options:
#'   `"COMPRESS=LZW"`, `"COMPRESS=ZSTD"`, `"OVERVIEW_RESAMPLING=AVERAGE"`,
#'   `"BLOCKSIZE=512"`.
#' @param tags Named character vector of dataset metadata to write, or
#'   `NULL` (default) for none. Names may not contain `:`, which GDAL reads
#'   as a metadata domain separator.
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
#' # Record where the file came from, inside the file
#' cd_cog_write(r, tmp, overwrite = TRUE,
#'              tags = c(CD_VERSION = "0.6.2", CD_RUN_ID = "local"))
#' terra::metags(terra::rast(tmp))
#'
#' @export
cd_cog_write <- function(x, path, overwrite = FALSE,
                         gdal = c("COMPRESS=DEFLATE"), tags = NULL, ...) {
  if (!is.null(tags)) {
    if (!is.character(tags) || is.null(names(tags)) ||
        any(!nzchar(names(tags))) || anyNA(names(tags)) || anyNA(tags)) {
      rlang::abort("`tags` must be a named character vector with no NA.")
    }
    if (any(grepl(":", names(tags), fixed = TRUE))) {
      rlang::abort(paste0(
        "`tags` names may not contain ':' (GDAL reads it as a metadata ",
        "domain): ", paste(names(tags)[grepl(":", names(tags))], collapse = ", ")
      ))
    }
  }
  # `metags<-` merges rather than replaces, and copies rather than modifying
  # the caller's raster (terra 1.9.50). So clear, then put back what is not
  # provenance, then add this write's tags. An untagged raster's metags() has
  # zero rows of non-character columns, and clearing it errors.
  old <- terra::metags(x)
  old_name <- as.character(old$name)
  if (any(startsWith(old_name, "CD_")) || !is.null(tags)) {
    keep <- !startsWith(old_name, "CD_") & as.character(old$domain) == ""
    if (length(old_name) > 0) terra::metags(x) <- NULL
    if (any(keep)) {
      terra::metags(x) <- stats::setNames(as.character(old$value[keep]), old_name[keep])
    }
    if (!is.null(tags)) terra::metags(x) <- tags
  }
  terra::writeRaster(
    x, path,
    filetype = "COG",
    overwrite = overwrite,
    gdal = gdal,
    ...
  )
  invisible(path)
}
