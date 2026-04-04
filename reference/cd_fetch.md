# Download ERA5-Land climate data

Downloads ERA5-Land data from the Copernicus Climate Data Store (CDS)
for a specified bounding box, time period, and set of variables. Uses
two CDS products: monthly means for most variables, and daily statistics
for tmax/tmin (which are not available as monthly means).

## Usage

``` r
cd_fetch(
  years,
  months = 1:12,
  variables = cd_variables()$variable,
  bbox = c(60, -140, 48, -114),
  output_dir,
  source = "era5_land",
  force = FALSE
)
```

## Arguments

- years:

  Integer vector of years to download.

- months:

  Integer vector of months (1-12). Default `1:12`.

- variables:

  Character vector of cd variable names to fetch raw inputs for. Default
  fetches inputs needed for all 7 variables.

- bbox:

  Numeric vector `c(north, west, south, east)` in degrees. Default
  covers British Columbia.

- output_dir:

  Character path to write downloaded files.

- source:

  Character. Data source identifier. Currently only `"era5_land"` is
  supported.

- force:

  Logical. Re-download even if files exist. Default `FALSE`.

## Value

Character vector of downloaded file paths (GRIBs extracted from zip
archives).

## Examples

``` r
if (FALSE) { # \dontrun{
# Download January 2024 for BC
cd_fetch(years = 2024, months = 1, output_dir = "data/raw")

# Download full year for custom bbox
cd_fetch(years = 2023, bbox = c(55, -128, 53, -124), output_dir = "data/raw")
} # }
```
