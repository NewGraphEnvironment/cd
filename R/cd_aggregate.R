#' Aggregate monthly rasters to seasonal and annual periods
#'
#' Takes a multi-band raster with one band per month and aggregates
#' to annual and seasonal periods. Season definitions are configurable.
#'
#' @param x A [terra::SpatRaster] with 12 bands (one per month,
#'   Jan through Dec).
#' @param method Character. Aggregation method: `"mean"` or `"sum"`.
#'   Default `"mean"`. Use `"sum"` for precipitation.
#' @param seasons Named list of integer vectors defining month groups.
#'   Default uses standard meteorological seasons:
#'   winter (DJF), spring (MAM), summer (JJA), fall (SON).
#'
#' @return A named list of [terra::SpatRaster] objects, one per period.
#'   Names are `"annual"`, plus the names from `seasons`.
#'
#' @examples
#' \dontrun{
#' # 12-band raster (one per month)
#' r <- terra::rast(nrows = 10, ncols = 10, nlyrs = 12)
#' terra::values(r) <- matrix(rnorm(1200), 100, 12)
#'
#' # Default seasons
#' periods <- cd_aggregate(r)
#' names(periods)  # "annual", "winter", "spring", "summer", "fall"
#'
#' # Custom seasons (e.g., wet/dry)
#' cd_aggregate(r, seasons = list(wet = 10:3, dry = 4:9))
#' }
#'
#' @export
cd_aggregate <- function(x,
                         method = "mean",
                         seasons = cd_seasons()) {

  if (terra::nlyr(x) != 12) {
    rlang::abort(paste0(
      "`x` must have exactly 12 bands (one per month), not ", terra::nlyr(x), "."
    ))
  }

  method <- match.arg(method, c("mean", "sum"))

  agg <- function(r) {
    if (method == "mean") terra::mean(r) else terra::app(r, "sum")
  }

  results <- list()

  # Annual
  results[["annual"]] <- agg(x)

  # Seasons
  for (nm in names(seasons)) {
    months <- seasons[[nm]]
    valid_months <- months[months >= 1 & months <= terra::nlyr(x)]
    if (length(valid_months) > 0) {
      results[[nm]] <- agg(x[[valid_months]])
    }
  }

  results
}

#' Default meteorological season definitions
#'
#' Returns a named list of month numbers for standard meteorological
#' seasons. Override to define custom seasons (e.g., wet/dry, growing
#' season).
#'
#' @return Named list of integer vectors.
#'
#' @examples
#' cd_seasons()
#'
#' # Custom: hydrological year
#' list(wet = c(10, 11, 12, 1, 2, 3), dry = 4:9)
#'
#' @export
cd_seasons <- function() {
  list(
    winter = c(12L, 1L, 2L),
    spring = 3L:5L,
    summer = 6L:8L,
    fall = 9L:11L
  )
}
