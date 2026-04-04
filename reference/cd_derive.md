# Derive climate variables from raw ERA5-Land fields

Computes VPD, RH, composite soil moisture, and monthly tmax/tmin from
raw ERA5-Land GRIB files downloaded by
[`cd_fetch()`](https://newgraphenvironment.github.io/cd/reference/cd_fetch.md).
Also converts temperature from Kelvin to Celsius and precipitation from
m/day to mm/month.

## Usage

``` r
cd_derive(
  input_dir,
  output_dir,
  variables = c("vpd", "rh", "soil_moisture"),
  force = FALSE
)
```

## Arguments

- input_dir:

  Character path containing raw GRIB files from
  [`cd_fetch()`](https://newgraphenvironment.github.io/cd/reference/cd_fetch.md).

- output_dir:

  Character path to write derived rasters.

- variables:

  Character vector of variables to derive. Default derives all: VPD, RH,
  soil moisture, tmax, tmin.

- force:

  Logical. Re-derive even if output files exist. Default `FALSE`.

## Value

Character vector of derived file paths.

## Examples

``` r
if (FALSE) { # \dontrun{
cd_fetch(years = 2024, months = 1, output_dir = "data/raw")
cd_derive("data/raw", "data/derived")
} # }
```
