#' Generate a static STAC catalog from COGs
#'
#' Scans a directory for Cloud-Optimized GeoTIFFs and builds a
#' STAC catalog JSON file. Each COG becomes one item with
#' `cd:variable` and `cd:period` properties parsed from the filename.
#' The resulting catalog is compatible with [cd_catalog()].
#'
#' @param cog_dir Character. Directory containing COG files (.tif).
#' @param output_path Character. Path to write the catalog JSON.
#'   Default `"catalog.json"`.
#' @param catalog_id Character. STAC catalog ID.
#'   Default `"era5-land"`.
#' @param title Character. Human-readable catalog title.
#' @param description Character. Optional catalog description.
#' @param base_url Character. Base URL where COGs will be served.
#'   Asset hrefs are built as `{base_url}/{filename}`.
#'
#' @return The output path (invisibly).
#'
#' @examples
#' \dontrun{
#' cd_stac_catalog(
#'   "data/cogs",
#'   output_path = "data/catalog.json",
#'   base_url = "https://stac-era5-land.s3.us-west-2.amazonaws.com"
#' )
#' }
#'
#' @export
cd_stac_catalog <- function(cog_dir,
                            output_path = "catalog.json",
                            catalog_id = "era5-land",
                            title = "ERA5-Land Climate Data",
                            description = NULL,
                            base_url = "https://stac-era5-land.s3.us-west-2.amazonaws.com") {

  tif_files <- list.files(cog_dir, pattern = "\\.tif$", full.names = TRUE)
  if (length(tif_files) == 0) {
    rlang::abort(paste("No .tif files found in", cog_dir))
  }

  items <- lapply(tif_files, function(f) {
    cd_stac_item(f, base_url)
  })

  catalog <- list(
    type = "Catalog",
    id = catalog_id,
    stac_version = "1.0.0",
    description = description %||% paste(title, "- static STAC catalog"),
    links = list(
      list(rel = "root", href = paste0("./", basename(output_path)),
           type = "application/json")
    ),
    items = items
  )

  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(catalog, output_path, pretty = TRUE, auto_unbox = TRUE)
  message("Wrote STAC catalog: ", output_path, " (", length(items), " items)")
  invisible(output_path)
}

#' Build a STAC item from a COG file
#'
#' Parses variable and period from the filename, extracts spatial
#' metadata from the raster.
#'
#' @param cog_path Path to a COG file.
#' @param base_url Base URL for asset hrefs.
#' @return A list representing a STAC Feature item.
#' @noRd
cd_stac_item <- function(cog_path, base_url) {
  fname <- basename(cog_path)
  name_parts <- tools::file_path_sans_ext(fname)

  # Parse variable and period from filename
  # Expected patterns: "tmean_annual.tif", "vpd_2024.tif",
  # "example_climate.tif", etc.
  known_vars <- cd_variables()$variable
  known_periods <- cd_periods(include_monthly = TRUE)

  var_match <- known_vars[vapply(known_vars, function(v) grepl(v, name_parts), logical(1))]
  period_match <- known_periods[vapply(known_periods, function(p) grepl(p, name_parts), logical(1))]

  variable <- if (length(var_match) > 0) var_match[1] else name_parts
  period <- if (length(period_match) > 0) period_match[1] else "unknown"

  # Extract spatial metadata
  r <- terra::rast(cog_path)
  e <- as.vector(terra::ext(r))
  n_bands <- terra::nlyr(r)
  band_names <- names(r)

  # Parse years from band names if numeric
  years <- suppressWarnings(as.integer(band_names))
  years <- years[!is.na(years)]

  item_id <- paste(variable, period, sep = "-")

  list(
    type = "Feature",
    stac_version = "1.0.0",
    id = item_id,
    geometry = NA,
    bbox = e[c(1, 3, 2, 4)],
    properties = list(
      `cd:variable` = variable,
      `cd:period` = period,
      datetime = NA,
      start_datetime = if (length(years) > 0) paste0(min(years), "-01-01T00:00:00Z") else NULL,
      end_datetime = if (length(years) > 0) paste0(max(years), "-12-31T23:59:59Z") else NULL
    ),
    links = list(),
    assets = list(
      data = list(
        href = paste0(base_url, "/", fname),
        type = "image/tiff; application=geotiff; profile=cloud-optimized",
        title = paste(variable, period)
      )
    )
  )
}
