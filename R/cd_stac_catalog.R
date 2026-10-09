#' Generate a static STAC catalog from COGs
#'
#' Scans a directory for Cloud-Optimized GeoTIFFs and builds a
#' STAC catalog JSON file. Each COG becomes one item with
#' `cd:variable` and `cd:period` properties parsed from the filename.
#' The resulting catalog is compatible with [cd_catalog()].
#'
#' Each item's `data` asset carries `file:checksum` (a sha256 multihash,
#' `"1220"` + hex digest) and `file:size` from the
#' [STAC file extension](https://github.com/stac-extensions/file) v2.1.0,
#' taken from the local file, so build the catalog after the COGs are final.
#' Run provenance written into a COG by [cd_cog_write()] (`CD_VERSION`,
#' `CD_SHA`, `CD_RUN_TIME`, `CD_RUN_ID` tags) is copied into the item's
#' properties as `cd:version`, `cd:sha`, `cd:run_time` and `cd:run_id`.
#' Because the run time is part of the bytes, a checksum identifies a build,
#' not values: rebuilding unchanged data gives a new checksum.
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

  # Parse variable and period from filename. Expected pattern:
  # "{variable}_{period}.tif". Variable names may themselves contain
  # underscores (e.g. "swe_max", "snowmelt_doy_50") so substring matching
  # is unsafe — "swe" substring-matches "swe_max_annual" and would
  # mis-route the file. Use exact "{var}_{period}" matching against the
  # registries; fall back to filename-as-variable / "unknown" period if
  # nothing matches.
  known_vars <- cd_variables()$variable
  known_periods <- cd_periods(include_monthly = TRUE)

  variable <- name_parts
  period <- "unknown"
  for (v in known_vars) {
    for (p in known_periods) {
      if (identical(name_parts, paste0(v, "_", p))) {
        variable <- v
        period <- p
        break
      }
    }
    if (period != "unknown") break
  }

  # Extract spatial metadata
  r <- terra::rast(cog_path)
  tags <- terra::metags(r)
  tag <- function(key) {
    v <- as.character(tags$value)[as.character(tags$name) == key &
                                    as.character(tags$domain) == ""]
    if (length(v) == 1 && nzchar(v)) v else NULL
  }
  e <- as.vector(terra::ext(r))
  n_bands <- terra::nlyr(r)
  band_names <- names(r)

  # Parse years from band names if numeric
  years <- suppressWarnings(as.integer(band_names))
  years <- years[!is.na(years)]

  item_id <- paste(variable, period, sep = "-")

  # Absent tags are left out rather than written: jsonlite writes NULL as {}.
  provenance <- Filter(Negate(is.null), list(
    `cd:version` = tag("CD_VERSION"),
    `cd:sha` = tag("CD_SHA"),
    `cd:run_time` = tag("CD_RUN_TIME"),
    `cd:run_id` = tag("CD_RUN_ID")
  ))

  list(
    type = "Feature",
    stac_version = "1.0.0",
    stac_extensions = list(stac_file_extension),
    id = item_id,
    geometry = NA,
    bbox = e[c(1, 3, 2, 4)],
    properties = list(
      `cd:variable` = variable,
      `cd:period` = period,
      datetime = NA,
      start_datetime = if (length(years) > 0) paste0(min(years), "-01-01T00:00:00Z") else NULL,
      end_datetime = if (length(years) > 0) paste0(max(years), "-12-31T23:59:59Z") else NULL
    ) |> c(provenance),
    links = list(),
    assets = list(
      data = list(
        href = paste0(base_url, "/", fname),
        type = "image/tiff; application=geotiff; profile=cloud-optimized",
        title = paste(variable, period),
        `file:checksum` = file_multihash(cog_path),
        `file:size` = file.size(cog_path)
      )
    )
  )
}

stac_file_extension <- "https://stac-extensions.github.io/file/v2.1.0/schema.json"

#' sha256 of a file as a hex multihash
#'
#' `"1220"` (sha2-256, 32 bytes) + the lowercase hex digest, the form the
#' STAC file extension's `file:checksum` takes. A bare digest is not a valid
#' multihash, and the extension's schema (`^[a-f0-9]+$`) cannot tell, so the
#' shape is asserted here.
#'
#' @param path Path to a file.
#' @return A 68-character string.
#' @noRd
file_multihash <- function(path) {
  con <- file(path, open = "rb")
  on.exit(close(con))
  out <- paste0("1220", as.character(openssl::sha256(con)))
  if (!grepl("^1220[0-9a-f]{64}$", out)) {
    rlang::abort(paste0("Malformed multihash for ", path, ": ", out))
  }
  out
}
