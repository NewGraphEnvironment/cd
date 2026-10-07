# Fixture values decode as offset + cell * 1000 + day-of-year; see
# helper-daily.R. tmean offset 0, tmax 100000, tmin 200000.

test_that("returns one row per point, variable and day, typed and ordered", {
  src <- daily_fixture()
  d <- cd_extract_daily(daily_pts(c(16, 30)), "2003-12-30", "2004-01-02",
                        source = src)

  expect_named(d, c("id", "date", "variable", "value", "cell",
                    "cell_x", "cell_y", "cell_moved"))
  expect_s3_class(d$date, "Date")
  expect_type(d$value, "double")
  expect_type(d$cell, "integer")
  expect_type(d$cell_moved, "logical")
  expect_equal(nrow(d), 2 * 3 * 4)

  p1 <- d[d$id == "p1" & d$variable == "tmean", ]
  expect_equal(p1$date, as.Date(c("2003-12-30", "2003-12-31", "2004-01-01", "2004-01-02")))
  # Crossing the year boundary reads the next year's file from day 1.
  expect_equal(p1$value, c(16364, 16365, 16001, 16002))
  expect_equal(d$value[d$id == "p2" & d$variable == "tmin"][1], 200000 + 30364)
  # Input order of points, then the variables as asked for, then date.
  expect_equal(unique(d$id), c("p1", "p2"))
  expect_equal(unique(d$variable[d$id == "p1"]), c("tmean", "tmax", "tmin"))
  expect_false(is.unsorted(p1$date))
  expect_equal(unique(p1$cell), 16L)
  expect_equal(unique(p1$cell_x), daily_centre(16)[1])
  expect_equal(unique(p1$cell_y), daily_centre(16)[2])
  expect_false(any(d$cell_moved))
})

test_that("variables are returned in the order requested", {
  src <- daily_fixture()
  d <- cd_extract_daily(daily_pts(16), "2004-03-01", "2004-03-02",
                        variables = c("tmin", "tmean"), source = src)
  expect_equal(d$variable, c("tmin", "tmin", "tmean", "tmean"))
  expect_equal(d$value, c(216061, 216062, 16061, 16062))
})

test_that("a leap year has 366 days", {
  src <- daily_fixture()
  d <- cd_extract_daily(daily_pts(16), "2004-01-01", "2004-12-31",
                        variables = "tmax", source = src)
  expect_equal(nrow(d), 366)
  expect_equal(d$value[366], 100000 + 16366)
})

test_that("points sharing a cell share its cell number and series", {
  src <- daily_fixture()
  pts <- daily_pts(c(16, 16), ids = c("a", "b"), nudge = rbind(c(0, 0), c(0.03, -0.02)))
  d <- cd_extract_daily(pts, "2003-05-01", "2003-05-03", variables = "tmean", source = src)
  expect_equal(d$cell[d$id == "a"], d$cell[d$id == "b"])
  expect_equal(d$value[d$id == "a"], d$value[d$id == "b"])
})

test_that("a no-data cell moves to the nearest neighbour with data, flagged", {
  src <- daily_fixture()
  # Cell 15's neighbours with data: 10 (NE), 16 (E), 20 (SW), 21 (S), 22 (SE).
  # At 54 N an east neighbour (~6.5 km) is nearer than a south one (~11 km).
  d <- cd_extract_daily(daily_pts(15), "2003-01-01", "2003-01-01",
                        variables = "tmean", source = src)
  expect_equal(d$cell, 16L)
  expect_true(d$cell_moved)
  expect_equal(d$value, 16001)
  expect_equal(d$cell_x, daily_centre(16)[1])

  # Distance is from the point, not from its cell's centre: a point near the
  # south edge of cell 15 is nearer cell 21's centre (~6.1 km) than 16's (~8.2).
  d2 <- cd_extract_daily(daily_pts(15, nudge = c(0, -0.045)), "2003-01-01",
                         "2003-01-01", variables = "tmean", source = src)
  expect_equal(d2$cell, 21L)
  expect_equal(d2$value, 21001)
})

test_that("a no-data cell on the grid edge searches the truncated ring", {
  src <- daily_fixture()
  # Cell 25 is bottom-left: neighbours 19 (N), 20 (NE), 26 (E) only.
  d <- cd_extract_daily(daily_pts(25), "2003-01-01", "2003-01-01",
                        variables = "tmean", source = src)
  expect_equal(d$cell, 26L)
  expect_true(d$cell_moved)
})

test_that("a point with no data anywhere in its ring gets NA and a warning", {
  src <- daily_fixture()
  expect_warning(
    d <- cd_extract_daily(daily_pts(c(8, 16), ids = c("sea", "land")),
                          "2003-01-01", "2003-01-02", variables = "tmean",
                          source = src),
    "sea"
  )
  expect_true(all(is.na(d$value[d$id == "sea"])))
  expect_equal(unique(d$cell[d$id == "sea"]), 8L)
  expect_false(any(d$cell_moved[d$id == "sea"]))
  expect_equal(d$value[d$id == "land"], c(16001, 16002))
})

test_that("sf input in a projected CRS gives the same result as lon/lat", {
  skip_if_not_installed("sf")
  src <- daily_fixture()
  df <- daily_pts(c(16, 15, 30), nudge = c(0.01, 0.01))
  pts_sf <- sf::st_transform(
    sf::st_as_sf(df, coords = c("lon", "lat"), crs = 4326), 3005
  )
  a <- cd_extract_daily(df, "2003-07-01", "2003-07-03", source = src)
  b <- cd_extract_daily(pts_sf, "2003-07-01", "2003-07-03", source = src)
  expect_equal(b, a)
})

test_that("SpatVector input and custom id / coords names work", {
  src <- daily_fixture()
  df <- daily_pts(c(16, 30))
  names(df) <- c("station", "x", "y")
  a <- cd_extract_daily(df, "2003-07-01", "2003-07-01", variables = "tmax",
                        id = "station", coords = c("x", "y"), source = src)
  expect_equal(a$id, c("p1", "p2"))
  v <- terra::vect(df, geom = c("x", "y"), crs = "EPSG:4326")
  b <- cd_extract_daily(v, "2003-07-01", "2003-07-01", variables = "tmax",
                        id = "station", source = src)
  expect_equal(b, a)
})

test_that("an unpublished year aborts naming the year", {
  src <- daily_fixture()
  expect_error(
    cd_extract_daily(daily_pts(16), "2004-12-01", "2005-01-10", source = src),
    "2005"
  )
  expect_error(
    cd_extract_daily(daily_pts(16), "2001-12-01", "2003-01-10", source = src),
    "2001"
  )
})

test_that("a point off the grid aborts naming it", {
  src <- daily_fixture()
  pts <- rbind(daily_pts(16), data.frame(id = "far", lon = -100, lat = 40))
  expect_error(
    cd_extract_daily(pts, "2003-01-01", "2003-01-01", source = src),
    "far"
  )
})

test_that("bad arguments abort", {
  src <- daily_fixture()
  pts <- daily_pts(16)
  expect_error(cd_extract_daily(pts, "2004-01-02", "2004-01-01", source = src), "after")
  expect_error(cd_extract_daily(pts, "not a date", "2004-01-01", source = src), "from")
  expect_error(cd_extract_daily(pts, "2004-01-01", "2004-01-01", variables = "prcp",
                                source = src))
  expect_error(cd_extract_daily(daily_pts(c(16, 30), ids = c("a", "a")),
                                "2004-01-01", "2004-01-01", source = src), "unique")
  expect_error(cd_extract_daily(pts, "2004-01-01", "2004-01-01", id = "nope",
                                source = src), "nope")
  skip_if_not_installed("sf")
  geom <- sf::st_geometry(sf::st_as_sf(pts, coords = c("lon", "lat"), crs = 4326))
  expect_error(cd_extract_daily(geom, "2004-01-01", "2004-01-01", source = src),
               "geometry column")
})

test_that("no points gives a zero-row tibble with every column", {
  src <- daily_fixture()
  d <- cd_extract_daily(daily_pts(16)[0, ], "2003-01-01", "2003-01-02", source = src)
  expect_equal(nrow(d), 0)
  expect_named(d, c("id", "date", "variable", "value", "cell",
                    "cell_x", "cell_y", "cell_moved"))
  expect_s3_class(d$date, "Date")
  expect_type(d$id, "character")
})
