# Aggregate monthly rasters to seasonal and annual periods

Takes a multi-band raster with one band per month and aggregates to
annual and seasonal periods. Season definitions are configurable.

## Usage

``` r
cd_aggregate(x, method = "mean", seasons = cd_seasons())
```

## Arguments

- x:

  A
  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  with 12 bands (one per month, Jan through Dec).

- method:

  Character. Aggregation method: `"mean"` or `"sum"`. Default `"mean"`.
  Use `"sum"` for precipitation.

- seasons:

  Named list of integer vectors defining month groups. Default uses
  standard meteorological seasons: winter (DJF), spring (MAM), summer
  (JJA), fall (SON).

## Value

A named list of
[terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
objects, one per period. Names are `"annual"`, plus the names from
`seasons`.

## Examples

``` r
if (FALSE) { # \dontrun{
# 12-band raster (one per month)
r <- terra::rast(nrows = 10, ncols = 10, nlyrs = 12)
terra::values(r) <- matrix(rnorm(1200), 100, 12)

# Default seasons
periods <- cd_aggregate(r)
names(periods)  # "annual", "winter", "spring", "summer", "fall"

# Custom seasons (e.g., wet/dry)
cd_aggregate(r, seasons = list(wet = 10:3, dry = 4:9))
} # }
```
