#' Extract daily air temperature at points
#'
#' Samples cd's daily ERA5-Land air-temperature cube at a set of points and
#' returns one row per point, day and variable. The cube holds daily mean,
#' maximum and minimum 2 m temperature (°C) for British Columbia from 1950,
#' on **local days** (UTC−8), on the same 0.1° grid as the monthly layers.
#' It is built from ERA5-Land hourly data by `scripts/backfill_edh_daily.py`
#' and published to S3 as one Cloud-Optimized GeoTIFF per variable and year
#' (`<source>/<variable>_daily_<year>.tif`, one band per day). It is not in
#' the STAC catalog read by [cd_catalog()].
#'
#' @section Day boundary:
#' A local day runs from 08:00 UTC to 07:00 UTC the next day: Pacific
#' Standard Time, with no daylight saving. A UTC day would run from one
#' afternoon peak (22:00–00:00 UTC) to the next, so a hot afternoon would
#' count toward two days and the daily maximum would read high, a bias that
#' does not cancel in absolute thresholds such as degree-days. The fixed
#' offset is an hour off for the Mountain Standard Time corner of eastern
#' BC. The monthly `tmax`/`tmin` layers in the catalog average these same
#' local days (cd#37).
#'
#' @section Cell choice:
#' Each point takes the ERA5-Land cell containing it. ERA5-Land covers land
#' only, so a point on the coast or a large lake can fall in a cell with no
#' data. Such a point moves to the nearest cell with data among the eight
#' around it, measured geodesically from the point to each cell centre
#' (ties go to the lower cell number), and its rows carry
#' `cell_moved = TRUE`. If none of the eight has data, the point keeps its
#' own cell, its values are `NA`, and a warning names it. Points sharing a
#' cell share a `cell` value, so identical series are easy to spot. There is
#' no elevation adjustment between the cell and the point.
#'
#' A point outside the cube (British Columbia's box, 47.95–60.05° N,
#' 140.05–113.95° W) gets `NA` values and `NA` cell columns, and a warning
#' names it with the cube's extent; the other points are unaffected.
#'
#' @param points Point locations: an `sf` or [terra::SpatVector] of points
#'   in any CRS, carrying the `id` column, or a data frame with longitude/latitude columns
#'   (WGS84) named by `coords`.
#' @param from,to First and last day to return, as `Date` or `"YYYY-MM-DD"`.
#' @param variables Any of `"tmean"`, `"tmax"`, `"tmin"`.
#' @param id Name of the column in `points` that identifies each point. Its
#'   values must be unique and not missing.
#' @param coords For a data frame `points`, the longitude and latitude
#'   column names.
#' @param source Directory or base URL holding the cube files. Defaults to
#'   the published cube on S3; override with `options(cd.daily_url = ...)`.
#' @param cache Logical. If `TRUE` (default), each remote file is downloaded
#'   once through [cd_cache_fetch()] and read locally: fastest for many
#'   points and for repeat calls (about 9–17 MB per variable and year).
#'   If `FALSE`, only the 16 × 16-cell tiles holding the points are read
#'   over the network, which suits a few points in one call.
#'
#' @return A tibble with one row per point, variable and day:
#'   \describe{
#'     \item{id}{The point's identifier, from the `id` column.}
#'     \item{date}{Local day (`Date`).}
#'     \item{variable}{`"tmean"`, `"tmax"` or `"tmin"`.}
#'     \item{value}{Air temperature, °C.}
#'     \item{cell}{ERA5-Land cell number on the cube's grid; `NA` for a
#'       point outside the cube.}
#'     \item{cell_x, cell_y}{Longitude and latitude of the cell centre;
#'       `NA` for a point outside the cube.}
#'     \item{cell_moved}{`TRUE` when the point's own cell had no data and a
#'       neighbour was used.}
#'   }
#'   Rows are ordered by point (input order), variable, then date.
#'
#' @examples
#' # One year (2002) of a 5 x 5-cell crop of the cube ships with the package.
#' src <- system.file("extdata", "example_daily", package = "cd")
#' stations <- data.frame(
#'   id = c("upper", "lower"),
#'   lon = c(-126.38, -126.07),
#'   lat = c(54.62, 54.31)
#' )
#' d <- cd_extract_daily(stations, "2002-06-01", "2002-08-31", source = src)
#' head(d)
#'
#' # Growing degree-days above 5 °C over the summer, per station
#' tm <- d[d$variable == "tmean", ]
#' tapply(pmax(tm$value - 5, 0), tm$id, sum)
#'
#' \dontrun{
#' # The published cube, 2002 to 2025
#' cd_extract_daily(stations, "2002-01-01", "2025-12-31")
#' }
#'
#' @export
cd_extract_daily <- function(points, from, to,
                             variables = c("tmean", "tmax", "tmin"),
                             id = "id",
                             coords = c("lon", "lat"),
                             source = getOption(
                               "cd.daily_url",
                               "https://stac-era5-land.s3.us-west-2.amazonaws.com/daily"
                             ),
                             cache = TRUE) {
  variables <- unique(rlang::arg_match(
    variables, c("tmean", "tmax", "tmin"), multiple = TRUE
  ))
  from <- daily_date(from, "from")
  to <- daily_date(to, "to")
  if (from > to) {
    rlang::abort(paste0("`from` (", from, ") is after `to` (", to, ")."))
  }

  pts <- daily_points(points, id, coords)
  ids <- pts$ids
  years <- seq(as.integer(format(from, "%Y")), as.integer(format(to, "%Y")))

  out_empty <- tibble::tibble(
    id = ids[0], date = as.Date(character()), variable = character(),
    value = numeric(), cell = integer(), cell_x = numeric(),
    cell_y = numeric(), cell_moved = logical()
  )
  if (length(ids) == 0L) {
    return(out_empty)
  }

  # Fail on an unpublished year before downloading anything: the last year
  # asked for is the one most likely to be missing.
  daily_read(source, variables[1], years[length(years)], cache)
  template <- daily_read(source, variables[1], years[1], cache)

  cells <- daily_cells(template, pts$xy, ids)
  # sort() drops the NA of points outside the cube; match() gives them NA rows.
  ucell <- sort(unique(cells$cell))

  pieces <- vector("list", length(variables) * length(years))
  k <- 0L
  for (v in variables) {
    for (yr in years) {
      r <- if (v == variables[1] && yr == years[1]) {
        template
      } else {
        daily_read(source, v, yr, cache)
      }
      if (!isTRUE(terra::compareGeom(r, template, stopOnError = FALSE))) {
        rlang::abort(paste0(
          "The ", v, " cube for ", yr, " is not on the same grid as the ",
          variables[1], " cube for ", years[1], "; cell numbers would not ",
          "match. Check `source`."
        ))
      }
      dates <- as.Date(names(r), format = "%Y-%m-%d")
      if (anyNA(dates)) {
        rlang::abort(paste0(
          "The ", v, " cube for ", yr, " has bands not named YYYY-MM-DD."
        ))
      }
      keep <- which(dates >= from & dates <= to)
      vals <- if (length(ucell) > 0L) {
        as.matrix(terra::extract(r, ucell)[, keep, drop = FALSE])
      } else {
        matrix(NA_real_, 0L, length(keep))
      }
      # Point-major: each point's days in order, read from its cell's row.
      rows <- match(cells$cell, ucell)
      k <- k + 1L
      pieces[[k]] <- tibble::tibble(
        .pt = rep(seq_along(ids), each = length(keep)),
        date = rep(dates[keep], times = length(ids)),
        variable = v,
        value = as.numeric(t(vals[rows, , drop = FALSE]))
      )
    }
  }

  long <- dplyr::bind_rows(pieces)
  long <- long[order(long$.pt, match(long$variable, variables), long$date), ]
  tibble::tibble(
    id = ids[long$.pt],
    date = long$date,
    variable = long$variable,
    value = long$value,
    cell = cells$cell[long$.pt],
    cell_x = cells$cell_x[long$.pt],
    cell_y = cells$cell_y[long$.pt],
    cell_moved = cells$cell_moved[long$.pt]
  )
}

#' Parse a from/to argument to a single Date.
#' @noRd
daily_date <- function(x, arg) {
  d <- tryCatch(as.Date(x), error = function(e) as.Date(NA))
  if (length(d) != 1L || is.na(d)) {
    rlang::abort(paste0("`", arg, "` must be one date (Date or \"YYYY-MM-DD\")."))
  }
  d
}

#' Normalise points to WGS84 lon/lat plus their ids.
#' @noRd
daily_points <- function(points, id, coords) {
  if (inherits(points, "sfc")) {
    rlang::abort(paste0(
      "`points` is a bare geometry column with no `", id, "`; ",
      "pass an sf data frame carrying one."
    ))
  }
  if (inherits(points, "sf")) {
    points <- terra::vect(points)
  }
  if (inherits(points, "SpatVector")) {
    if (nrow(points) > 0L && terra::geomtype(points) != "points") {
      rlang::abort("`points` must be point geometries.")
    }
    if (!id %in% names(points)) {
      rlang::abort(paste0("`points` has no `", id, "` column; set `id`."))
    }
    ids <- terra::values(points)[[id]]
    xy <- if (nrow(points) > 0L) {
      terra::crds(terra::project(points, "EPSG:4326"))
    } else {
      matrix(numeric(), ncol = 2)
    }
  } else if (is.data.frame(points)) {
    miss <- setdiff(c(id, coords), names(points))
    if (length(miss) > 0L) {
      rlang::abort(paste0(
        "`points` has no column ", paste0("`", miss, "`", collapse = ", "),
        "; set `id` and `coords`."
      ))
    }
    ids <- points[[id]]
    xy <- cbind(as.numeric(points[[coords[1]]]), as.numeric(points[[coords[2]]]))
  } else {
    rlang::abort("`points` must be an sf, SpatVector or data frame.")
  }
  if (anyNA(ids) || anyDuplicated(ids)) {
    rlang::abort(paste0("`", id, "` must be unique and not missing."))
  }
  if (anyNA(xy)) {
    rlang::abort("`points` has missing coordinates.")
  }
  list(ids = ids, xy = unname(xy))
}

#' Open one variable-year of the cube, local or remote.
#' @noRd
daily_read <- function(source, variable, year, cache) {
  href <- paste0(sub("/+$", "", source), "/", variable, "_daily_", year, ".tif")
  unpublished <- function(detail = NULL) {
    rlang::abort(paste0(
      "No ", variable, " daily cube for ", year, " at '", href, "'. ",
      "The cube covers complete years from 1950; the latest year appears ",
      "about two months after it ends.",
      if (!is.null(detail)) paste0(" (", detail, ")")
    ))
  }
  if (!cd_is_remote(href)) {
    if (!file.exists(href)) unpublished()
    return(terra::rast(href))
  }
  if (isTRUE(cache)) {
    path <- tryCatch(cd_cache_fetch(href), error = function(e) {
      unpublished(conditionMessage(e))
    })
    return(terra::rast(path))
  }
  if (is.null(cd_remote_head(href))) unpublished()
  terra::rast(paste0("/vsicurl/", href))
}

#' Pick each point's cell, moving off no-data cells to the nearest neighbour.
#' @noRd
daily_cells <- function(template, xy, ids) {
  cell <- terra::cellFromXY(template, xy)
  outside <- is.na(cell)
  if (any(outside)) {
    # Stated from the cube itself, so it cannot drift from the data (#123).
    e <- vapply(as.vector(terra::ext(template)),
                function(v) format(round(v, 4)), character(1))
    rlang::warn(paste0(
      "Outside the daily cube's extent (", e[1], " to ", e[2], " E, ",
      e[3], " to ", e[4], " N): ", paste(ids[outside], collapse = ", "),
      ". Their values are NA."
    ))
  }
  # Read band 1 only at the cells in question, never the whole grid: the
  # cube's tiles hold all 365 bands, so a whole-grid read pulls the entire
  # file over /vsicurl/ when cache = FALSE (code-check round 3).
  has_data <- function(cl) !is.na(terra::extract(template[[1]], cl)[, 1])
  moved <- rep(FALSE, length(cell))
  stranded <- character()

  inside <- which(!outside)
  dry <- if (length(inside) > 0L) inside[!has_data(cell[inside])] else integer()
  for (i in dry) {
    nb <- terra::adjacent(template, cell[i], directions = "queen")
    nb <- nb[!is.na(nb)]
    nb <- nb[has_data(nb)]
    if (length(nb) == 0L) {
      stranded <- c(stranded, as.character(ids[i]))
      next
    }
    d <- terra::distance(
      xy[i, , drop = FALSE], terra::xyFromCell(template, nb), lonlat = TRUE
    )
    cell[i] <- nb[order(as.vector(d), nb)[1]]
    moved[i] <- TRUE
  }
  if (length(stranded) > 0L) {
    rlang::warn(paste0(
      "No ERA5-Land data in or around the cell for: ",
      paste(stranded, collapse = ", "), ". Their values are NA."
    ))
  }

  centre <- matrix(NA_real_, length(cell), 2)
  if (length(inside) > 0L) {
    centre[inside, ] <- terra::xyFromCell(template, cell[inside])
  }
  list(
    cell = as.integer(cell),
    cell_x = unname(centre[, 1]),
    cell_y = unname(centre[, 2]),
    cell_moved = moved
  )
}
