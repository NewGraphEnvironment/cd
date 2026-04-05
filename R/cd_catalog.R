#' Load and parse a STAC catalog
#'
#' Reads a static STAC catalog JSON file and returns a tidy tibble
#' of available climate data COGs. This is the entry point for
#' consumer-side workflows.
#'
#' @param catalog Path or URL to a STAC catalog JSON file.
#'   Defaults to [cd_catalog_default()].
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{variable}{Climate variable short name (e.g., "tmean").}
#'     \item{period}{Temporal aggregation period (e.g., "annual").}
#'     \item{href}{Resolved path or URL to the COG file.}
#'   }
#'
#' @examples
#' cd_catalog(
#'   system.file("extdata", "example_catalog.json", package = "cd")
#' )
#'
#' @export
cd_catalog <- function(catalog = cd_catalog_default()) {
  cat_json <- jsonlite::read_json(catalog)
  base_dir <- dirname(catalog)

  items <- cat_json$items
  if (is.null(items) || length(items) == 0) {
    return(tibble::tibble(variable = character(), period = character(), href = character()))
  }

  tibble::tibble(
    variable = vapply(items, function(x) x$properties$`cd:variable`, character(1)),
    period = vapply(items, function(x) x$properties$`cd:period`, character(1)),
    href = vapply(items, function(x) {
      h <- x$assets$data$href
      if (grepl("^(http|s3|/)", h)) h else file.path(base_dir, h)
    }, character(1))
  )
}

#' Default STAC catalog URL
#'
#' Returns the default S3-hosted STAC catalog URL for the cd package.
#' Override with `options(cd.catalog_url = "...")`.
#'
#' @return Character URL.
#'
#' @examples
#' cd_catalog_default()
#'
#' @export
cd_catalog_default <- function() {
  getOption("cd.catalog_url", default = "https://stac-era5-land.s3.us-west-2.amazonaws.com/catalog.json")
}
