# Extract daily air temperature at points

Samples cd's daily ERA5-Land air-temperature cube at a set of points and
returns one row per point, day and variable. The cube holds daily mean,
maximum and minimum 2 m temperature (°C) for British Columbia from 1950,
on **local days** (UTC−8), on the same 0.1° grid as the monthly layers.
It is built from ERA5-Land hourly data by
`scripts/backfill_edh_daily.py` and published to S3 as one
Cloud-Optimized GeoTIFF per variable and year
(`<source>/<variable>_daily_<year>.tif`, one band per day). It is not in
the STAC catalog read by
[`cd_catalog()`](https://newgraphenvironment.github.io/cd/reference/cd_catalog.md).

## Usage

``` r
cd_extract_daily(
  points,
  from,
  to,
  variables = c("tmean", "tmax", "tmin"),
  id = "id",
  coords = c("lon", "lat"),
  source = getOption("cd.daily_url",
    "https://stac-era5-land.s3.us-west-2.amazonaws.com/daily"),
  cache = TRUE
)
```

## Arguments

- points:

  Point locations: an `sf` or
  [terra::SpatVector](https://rspatial.github.io/terra/reference/SpatVector-class.html)
  of points in any CRS, carrying the `id` column, or a data frame with
  longitude/latitude columns (WGS84) named by `coords`.

- from, to:

  First and last day to return, as `Date` or `"YYYY-MM-DD"`.

- variables:

  Any of `"tmean"`, `"tmax"`, `"tmin"`.

- id:

  Name of the column in `points` that identifies each point. Its values
  must be unique and not missing.

- coords:

  For a data frame `points`, the longitude and latitude column names.

- source:

  Directory or base URL holding the cube files. Defaults to the
  published cube on S3; override with `options(cd.daily_url = ...)`.

- cache:

  Logical. If `TRUE` (default), each remote file is downloaded once
  through
  [`cd_cache_fetch()`](https://newgraphenvironment.github.io/cd/reference/cd_cache_fetch.md)
  and read locally: fastest for many points and for repeat calls (about
  9–17 MB per variable and year). If `FALSE`, only the 16 × 16-cell
  tiles holding the points are read over the network, which suits a few
  points in one call.

## Value

A tibble with one row per point, variable and day:

- id:

  The point's identifier, from the `id` column.

- date:

  Local day (`Date`).

- variable:

  `"tmean"`, `"tmax"` or `"tmin"`.

- value:

  Air temperature, °C.

- cell:

  ERA5-Land cell number on the cube's grid.

- cell_x, cell_y:

  Longitude and latitude of the cell centre.

- cell_moved:

  `TRUE` when the point's own cell had no data and a neighbour was used.

Rows are ordered by point (input order), variable, then date.

## Day boundary

A local day runs from 08:00 UTC to 07:00 UTC the next day: Pacific
Standard Time, with no daylight saving. A UTC day would split BC's
afternoon peak (22:00–00:00 UTC) across two days, biasing daily maximum
low and minimum high, and that bias does not cancel in absolute
thresholds such as degree-days. The fixed offset is an hour off for the
Mountain Standard Time corner of eastern BC. The monthly `tmax`/`tmin`
layers in the catalog are not built from this cube and still use UTC
days (cd#37).

## Cell choice

Each point takes the ERA5-Land cell containing it. ERA5-Land covers land
only, so a point on the coast or a large lake can fall in a cell with no
data. Such a point moves to the nearest cell with data among the eight
around it, measured geodesically from the point to each cell centre
(ties go to the lower cell number), and its rows carry
`cell_moved = TRUE`. If none of the eight has data, the point keeps its
own cell, its values are `NA`, and a warning names it. Points sharing a
cell share a `cell` value, so identical series are easy to spot. There
is no elevation adjustment between the cell and the point.

## Examples

``` r
# One year (2002) of a 5 x 5-cell crop of the cube ships with the package.
src <- system.file("extdata", "example_daily", package = "cd")
stations <- data.frame(
  id = c("upper", "lower"),
  lon = c(-126.38, -126.07),
  lat = c(54.62, 54.31)
)
d <- cd_extract_daily(stations, "2002-06-01", "2002-08-31", source = src)
head(d)
#> # A tibble: 6 × 8
#>   id    date       variable value  cell cell_x cell_y cell_moved
#>   <chr> <date>     <chr>    <dbl> <int>  <dbl>  <dbl> <lgl>     
#> 1 upper 2002-06-01 tmean     4.34     6  -126.   54.6 FALSE     
#> 2 upper 2002-06-02 tmean     6.54     6  -126.   54.6 FALSE     
#> 3 upper 2002-06-03 tmean     6.73     6  -126.   54.6 FALSE     
#> 4 upper 2002-06-04 tmean     5.89     6  -126.   54.6 FALSE     
#> 5 upper 2002-06-05 tmean     4.14     6  -126.   54.6 FALSE     
#> 6 upper 2002-06-06 tmean     3.44     6  -126.   54.6 FALSE     

# Growing degree-days above 5 °C over the summer, per station
tm <- d[d$variable == "tmean", ]
tapply(pmax(tm$value - 5, 0), tm$id, sum)
#>    lower    upper 
#> 629.7610 574.8422 

if (FALSE) { # \dontrun{
# The published cube, 2002 to 2025
cd_extract_daily(stations, "2002-01-01", "2025-12-31")
} # }
```
