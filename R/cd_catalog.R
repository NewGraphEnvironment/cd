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
#'     \item{checksum}{The file's sha256 as a multihash (`"1220"` + hex), from
#'       the item's `file:checksum`.}
#'     \item{size}{The file's size in bytes, from `file:size`.}
#'     \item{cd_version}{Version of cd that built the file
#'       (`processing:version`).}
#'     \item{cd_sha}{Git commit of the cd code that built the file
#'       (`processing:software`'s `cd` entry).}
#'     \item{run_time}{When the build ran, UTC, RFC 3339
#'       (`processing:datetime`).}
#'     \item{run_url}{The CI run that built the file (the item's
#'       `processing-execution` link); `NA` for a local build.}
#'   }
#'   Each of the last six is `NA` where the catalog does not carry it.
#'
#' @section Provenance:
#' The `checksum` and `cd_sha` columns say which build of each file the
#' catalog describes, so an analysis can record them and notice when a
#' republish changes a file. A checksum identifies a build, not values: the
#' run time is written into the file, so rebuilding unchanged data gives a
#' new checksum. A changed checksum means "rebuilt", not "different data".
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
    items <- list()
  }

  tibble::tibble(
    variable = vapply(items, function(x) x$properties$`cd:variable`, character(1)),
    period = vapply(items, function(x) x$properties$`cd:period`, character(1)),
    href = vapply(items, function(x) {
      h <- x$assets$data$href
      if (grepl("^(http|s3|/)", h)) h else file.path(base_dir, h)
    }, character(1)),
    checksum = catalog_field(items, function(x) x$assets$data$`file:checksum`),
    size = as.numeric(catalog_field(items, function(x) x$assets$data$`file:size`)),
    cd_version = catalog_field(items, function(x) x$properties$`processing:version`),
    cd_sha = catalog_field(items, function(x) x$properties$`processing:software`[["cd"]]),
    run_time = catalog_field(items, function(x) x$properties$`processing:datetime`),
    run_url = catalog_field(items, function(x) {
      rel <- vapply(x$links, function(l) l$rel %||% NA_character_, character(1))
      x$links[[which(rel %in% "processing-execution")[1]]]$href
    })
  )
}

#' One optional field per item, as character with NA where it is absent.
#' `get` may fail on a malformed item (a missing link list); that is absence
#' too, since provenance is informational and must not stop a read.
#' @noRd
catalog_field <- function(items, get) {
  vapply(items, function(x) {
    v <- tryCatch(get(x), error = function(e) NULL)
    if (length(v) == 1L && !is.list(v) && !is.na(v)) as.character(v) else NA_character_
  }, character(1))
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
