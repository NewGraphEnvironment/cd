# Synthetic daily cube for cd_extract_daily(): a 6 x 5 grid at 0.1 deg over
# (-124.0, -123.4) x (53.8, 54.3). Cell numbers run row-major from the top
# left, 1..30. Every value is exact in float32 and decodes to where it came
# from: variable offset (tmean 0, tmax 100000, tmin 200000) + cell * 1000 +
# day of year. The top-left 3 x 3 block (cells 1-3, 7-9, 13-15) and the
# bottom-left cell (25) hold no data, standing in for sea.
daily_fixture <- function(years = c(2003, 2004)) {
  dir <- tempfile("cd_daily")
  dir.create(dir)
  sea <- c(1, 2, 3, 7, 8, 9, 13, 14, 15, 25)
  offs <- c(tmean = 0, tmax = 100000, tmin = 200000)
  for (v in names(offs)) {
    for (yr in years) {
      days <- seq(as.Date(paste0(yr, "-01-01")), as.Date(paste0(yr, "-12-31")), by = "day")
      r <- terra::rast(
        ncols = 6, nrows = 5, nlyrs = length(days),
        xmin = -124.0, xmax = -123.4, ymin = 53.8, ymax = 54.3,
        crs = "EPSG:4326"
      )
      doy <- seq_along(days)
      m <- outer(1:30, doy, function(cell, d) offs[[v]] + cell * 1000 + d)
      m[sea, ] <- NA
      terra::values(r) <- m
      names(r) <- format(days, "%Y-%m-%d")
      terra::writeRaster(
        r, file.path(dir, paste0(v, "_daily_", yr, ".tif")),
        datatype = "FLT4S", overwrite = TRUE
      )
    }
  }
  dir
}

# Centre of a fixture cell, as a lon/lat pair.
daily_centre <- function(cell) {
  row <- (cell - 1) %/% 6
  col <- (cell - 1) %% 6
  c(-124.0 + 0.05 + 0.1 * col, 54.3 - 0.05 - 0.1 * row)
}

daily_pts <- function(cells, ids = paste0("p", seq_along(cells)), nudge = NULL) {
  xy <- t(vapply(cells, daily_centre, numeric(2)))
  if (!is.null(nudge)) xy <- xy + nudge
  data.frame(id = ids, lon = xy[, 1], lat = xy[, 2])
}
