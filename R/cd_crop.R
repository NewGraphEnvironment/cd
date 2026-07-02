#' Crop and mask a raster to an AOI
#'
#' Reads a COG (local or remote) and crops it to a user-supplied area
#' of interest polygon. Works with local file paths and remote URLs
#' via GDAL's `/vsicurl/`.
#'
#' @param href Character. Path or URL to a COG or raster file.
#' @param aoi An `sf` or `SpatVector` polygon to crop to.
#' @param cache Logical. If `TRUE` (default), route remote http(s) hrefs
#'   through the on-disk cache via [cd_cache_fetch()] so repeated reads
#'   pull from S3 once instead of every call. Local paths are unaffected.
#'
#' @return A [terra::SpatRaster] cropped and masked to the AOI.
#'
#' @examples
#' href <- system.file("extdata", "example_climate.tif", package = "cd")
#' aoi <- sf::st_read(
#'   system.file("extdata", "example_aoi.gpkg", package = "cd"),
#'   quiet = TRUE
#' )
#' r <- cd_crop(href, aoi)
#' r
#'
#' @export
cd_crop <- function(href, aoi, cache = TRUE) {
  if (isTRUE(cache)) {
    href <- cd_cache_fetch(href)
  }
  r <- terra::rast(href)
  if (inherits(aoi, "sf") || inherits(aoi, "sfc")) {
    aoi <- terra::vect(aoi)
  }
  if (!terra::same.crs(r, aoi)) {
    aoi <- terra::project(aoi, r)
  }
  terra::crop(r, aoi, snap = "out", mask = TRUE)
}
