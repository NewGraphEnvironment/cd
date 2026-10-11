#' Extract zonal mean time series for an AOI
#'
#' For each variable and period in the catalog, crops the COG to the AOI
#' and computes the spatial mean per year (band). Returns a tidy tibble
#' of raw climate values suitable for [cd_baseline()], [cd_anomaly()],
#' or [cd_trend()].
#'
#' @param catalog A tibble from [cd_catalog()] with columns
#'   `variable`, `period`, `href`.
#' @param aoi An `sf` or `SpatVector` polygon.
#' @param variables Character vector of variables to extract.
#'   Defaults to all variables in `catalog`.
#' @param periods Character vector of periods to extract.
#'   Defaults to all periods in `catalog`.
#' @param years Optional integer vector to filter specific years.
#' @param cache Logical. If `TRUE` (default), remote COGs are read
#'   through the on-disk cache (see [cd_cache_fetch()]) so repeated
#'   extractions and report rebuilds download each COG from S3 once
#'   rather than on every call. Passed through to [cd_crop()].
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{variable}{Climate variable short name.}
#'     \item{period}{Temporal aggregation period.}
#'     \item{year}{Year (integer).}
#'     \item{value}{Spatial mean of the climate value for this AOI.}
#'     \item{checksum}{The checksum `catalog` gives for the file read, kept
#'       only when the file is shown to be that build (see Provenance);
#'       otherwise `NA`.}
#'     \item{cd_sha}{Git commit of the cd code that built the file read,
#'       from the file's own tags; `NA` for an untagged file.}
#'   }
#'
#' @section Provenance:
#' `checksum` and `cd_sha` record which build of each file the values came
#' from, so a later run can tell when a republish changed it. `cd_sha` is
#' read from the file itself. `checksum` comes from `catalog` (see
#' [cd_catalog()]) and is kept only when the file's run-time tag matches the
#' catalog's `run_time`, so a stale cached copy or an out-of-date catalog
#' gives `NA` and a warning rather than another build's checksum. A catalog
#' row with no `run_time` cannot be checked and gives `NA` without a warning.
#' A checksum identifies a build, not values.
#'
#' @examples
#' catalog <- cd_catalog(
#'   system.file("extdata", "example_catalog.json", package = "cd")
#' )
#' aoi <- sf::st_read(
#'   system.file("extdata", "example_aoi.gpkg", package = "cd"),
#'   quiet = TRUE
#' )
#' cd_extract(catalog, aoi)
#'
#' @export
cd_extract <- function(catalog, aoi,
                       variables = catalog$variable,
                       periods = catalog$period,
                       years = NULL,
                       cache = TRUE) {
  rows <- catalog[catalog$variable %in% variables & catalog$period %in% periods, ]
  checksum <- col_or_na(rows, "checksum")
  run_time <- col_or_na(rows, "run_time")
  unmatched <- character()

  results <- lapply(seq_len(nrow(rows)), function(i) {
    # Resolve the cache once, so the raster cropped and the tags read are
    # the same file.
    src <- if (isTRUE(cache)) cd_cache_fetch(rows$href[i]) else rows$href[i]
    r <- cd_crop(src, aoi, cache = FALSE)
    build <- build_tags(terra::rast(src))
    ck <- build_checksum(checksum[i], run_time[i], build$run_time)
    if (build_stale(checksum[i], run_time[i], build$run_time)) {
      unmatched <<- c(unmatched, rows$href[i])
    }
    means <- terra::global(r, fun = "mean", na.rm = TRUE)
    yr <- as.integer(names(r))

    tibble::tibble(
      variable = rows$variable[i],
      period = rows$period[i],
      year = yr,
      value = round(means$mean, 4),
      checksum = ck,
      cd_sha = build$sha
    )
  })
  build_warn(unmatched, "the catalog")

  out <- dplyr::bind_rows(
    tibble::tibble(
      variable = character(), period = character(), year = integer(),
      value = numeric(), checksum = character(), cd_sha = character()
    ),
    results
  )

  if (!is.null(years)) {
    out <- out[out$year %in% years, ]
  }

  out
}
