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
      rel <- vapply(x$links, function(l) scalar_chr(l[["rel"]]), character(1))
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
    scalar_chr(tryCatch(get(x), error = function(e) NULL))
  }, character(1))
}

#' One JSON scalar as character; NA for NULL, NA, an object or an array.
#' @noRd
scalar_chr <- function(v) {
  if (length(v) == 1L && !is.list(v) && !is.na(v)) as.character(v) else NA_character_
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

#' The build a raster says it is, from its own `CD_SHA` and `CD_RUN_TIME`
#' tags (written by cd_cog_write() and write_cog()), NA where untagged.
#' Read from the file actually opened, so a stale cached copy reports its own
#' build rather than the one the catalog describes.
#' @noRd
build_tags <- function(r) {
  m <- terra::metags(r)
  tag <- function(key) {
    if (is.null(m) || nrow(m) == 0L) return(NA_character_)
    v <- as.character(m$value)[as.character(m$name) == key &
                                 as.character(m$domain) == ""]
    if (length(v) == 1L && nzchar(v)) v else NA_character_
  }
  list(sha = tag("CD_SHA"), run_time = tag("CD_RUN_TIME"))
}

#' A catalog or manifest checksum, kept only where the file read can be shown
#' to be the build the entry describes: its `CD_RUN_TIME` tag equals the
#' entry's run time. The run time is in the bytes, so two builds never share
#' one. Anything else is NA, never the entry's value. The comparison is of
#' exact strings, so the catalog and manifest writers must copy the tag
#' verbatim into `processing:datetime` (#128).
#' @noRd
build_checksum <- function(checksum, entry_run_time, file_run_time) {
  ok <- !is.na(checksum) & !is.na(entry_run_time) & !is.na(file_run_time) &
    entry_run_time == file_run_time
  ifelse(ok, checksum, NA_character_)
}

#' Whether an entry names a build the file read is not: it states a checksum
#' and a run time, and the file's run-time tag differs or is missing. An entry
#' with no run time cannot be checked, which is NA without a warning: the user
#' can do nothing about it, and a catalog or manifest from before the
#' processing: keys (#128) is exactly that shape.
#' @noRd
build_stale <- function(checksum, entry_run_time, file_run_time) {
  !is.na(checksum) & !is.na(entry_run_time) &
    (is.na(file_run_time) | entry_run_time != file_run_time)
}

#' Warn once about the files build_stale() picked out. `advice` says what
#' clears it, which differs by caller.
#' @noRd
build_warn <- function(files, what, advice) {
  if (length(files) == 0L) return(invisible())
  rlang::warn(paste0(
    "Not the build ", what, " describes (its run-time tag differs or is ",
    "missing), so `checksum` is NA: ", paste(files, collapse = ", "), ". ",
    advice
  ))
}
