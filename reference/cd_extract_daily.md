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

  ERA5-Land cell number on the cube's grid; `NA` for a point outside the
  cube.

- cell_x, cell_y:

  Longitude and latitude of the cell centre; `NA` for a point outside
  the cube.

- cell_moved:

  `TRUE` when the point's own cell had no data and a neighbour was used.

- checksum:

  The checksum the cube's manifest gives for the file the row was read
  from, kept only when the file is shown to be that build (see
  Provenance); otherwise `NA`.

- cd_sha:

  Git commit of the cd code that built that file, from the file's own
  tags; `NA` for an untagged file.

Rows are ordered by point (input order), variable, then date.

## Day boundary

A local day runs from 08:00 UTC to 07:00 UTC the next day: Pacific
Standard Time, with no daylight saving. A UTC day would run from one
afternoon peak (22:00–00:00 UTC) to the next, so a hot afternoon would
count toward two days and the daily maximum would read high, a bias that
does not cancel in absolute thresholds such as degree-days. The fixed
offset is an hour off for the Mountain Standard Time corner of eastern
BC. The monthly `tmax`/`tmin` layers in the catalog average these same
local days (cd#37).

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

A point outside the cube (British Columbia's box, 47.95–60.05° N,
140.05–113.95° W) gets `NA` values and `NA` cell columns, and a warning
names it with the cube's extent; the other points are unaffected.

## Provenance

Each file of the cube is one variable and year, and `checksum` and
`cd_sha` say which build of it a row came from. `cd_sha` is read from
the file itself. `checksum` comes from `<source>/manifest.json`, read
once per call (through the cache when `cache = TRUE`, so it follows
`cd.cache_revalidate` like the files), and is kept only when the file's
run-time tag matches the manifest's `processing:datetime` for it, so a
stale cached copy gives `NA` and, for an entry carrying both a checksum
and a run time, a warning rather than another build's checksum. An entry
with no `processing:datetime` cannot be checked and gives `NA` silently,
as does a file the manifest does not list. A local `source` with no
manifest (such as the bundled example) gives `NA` silently. A manifest
that cannot be read or is not the published shape (`files`, an object
keyed by file name) gives `NA` and a warning; with `cache = TRUE`, a
cached manifest is used instead when the remote one cannot be reached. A
cached manifest can be older than a file downloaded after it (with
`cd.cache_revalidate = FALSE`): a republished year then warns, and a
year it does not list yet is `NA` silently.
`cd_cache_fetch("<source>/manifest.json", refresh = TRUE)` replaces it.
A checksum identifies a build, not values.

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
#> # A tibble: 6 × 10
#>   id    date       variable value  cell cell_x cell_y cell_moved checksum cd_sha
#>   <chr> <date>     <chr>    <dbl> <int>  <dbl>  <dbl> <lgl>      <chr>    <chr> 
#> 1 upper 2002-06-01 tmean     4.34     6  -126.   54.6 FALSE      NA       NA    
#> 2 upper 2002-06-02 tmean     6.54     6  -126.   54.6 FALSE      NA       NA    
#> 3 upper 2002-06-03 tmean     6.73     6  -126.   54.6 FALSE      NA       NA    
#> 4 upper 2002-06-04 tmean     5.89     6  -126.   54.6 FALSE      NA       NA    
#> 5 upper 2002-06-05 tmean     4.14     6  -126.   54.6 FALSE      NA       NA    
#> 6 upper 2002-06-06 tmean     3.44     6  -126.   54.6 FALSE      NA       NA    

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
