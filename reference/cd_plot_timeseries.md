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
  with columns `variable`, `period`, `year`, `anomaly`. Also works with
  [`cd_extract()`](https://newgraphenvironment.github.io/cd/reference/cd_extract.md)
  output (uses `value` column).

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
