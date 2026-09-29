# Plot climate anomaly time series

Creates a bar chart of anomalies over time with optional Theil-Sen trend
lines. Positive and negative anomalies are colored differently.

## Usage

``` r
cd_plot_timeseries(
  x,
  variable = NULL,
  period = "annual",
  trend = NULL,
  title = NULL,
  colors = c(pos = "#d73027", neg = "#4575b4")
)
```

## Arguments

- x:

  A tibble from
  [`cd_anomaly()`](https://newgraphenvironment.github.io/cd/reference/cd_anomaly.md)
  with columns `variable`, `period`, `year`, `anomaly`, optionally
  `anomaly_type`, `unit` and `long_name`. Also works with
  [`cd_extract()`](https://newgraphenvironment.github.io/cd/reference/cd_extract.md)
  output (uses `value` column). One row per year in the plotted series.

- variable:

  Character. Which variable to plot. Default uses the first variable in
  `x`.

- period:

  Character. Which period to plot. Default `"annual"`.

- trend:

  Optional tibble from
  [`cd_trend()`](https://newgraphenvironment.github.io/cd/reference/cd_trend.md)
  to overlay trend lines.

- title:

  Optional plot title.

- colors:

  Named character vector of length 2 for positive/negative bar colors.
  Default `c(pos = "#d73027", neg = "#4575b4")`.

## Value

A [ggplot2::ggplot](https://ggplot2.tidyverse.org/reference/ggplot.html)
object.

## Details

The y-axis label is `long_name` and `unit` from `x` where present and
not `NA`, otherwise from
[`cd_variables()`](https://newgraphenvironment.github.io/cd/reference/cd_variables.md)
— resolved by the same rules as
[`cd_summary()`](https://newgraphenvironment.github.io/cd/reference/cd_summary.md)
(see the input contract in
[`cd_anomaly()`](https://newgraphenvironment.github.io/cd/reference/cd_anomaly.md))
— else the plotted column's name. `unit` is the anomaly's unit, so on
raw `value` input it is shown only where the anomaly type is `absolute`
or `pct_point_diff`, whose anomaly unit is the unit of the values.

## Examples

``` r
if (FALSE) { # \dontrun{
catalog <- cd_catalog()
aoi <- sf::st_read("my_aoi.gpkg")
ts <- cd_extract(catalog, aoi, variables = "tmean", periods = "annual")
bl <- cd_baseline(ts, baseline_years = 1951:1980)
ano <- cd_anomaly(ts, bl)
trn <- cd_trend(ano, trend_start = c(1951, 1981))
cd_plot_timeseries(ano, trend = trn)
} # }
```
