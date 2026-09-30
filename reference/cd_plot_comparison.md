# Plot time window comparison

Creates a dot plot or bar chart showing the mean value for two time
windows and their difference. Useful for communicating cumulative change
(e.g., "recent decade vs pre-warming").

## Usage

``` r
cd_plot_comparison(x, title = NULL, labels = c(a = "Recent", b = "Historical"))
```

## Arguments

- x:

  A tibble from
  [`cd_compare()`](https://newgraphenvironment.github.io/cd/reference/cd_compare.md)
  with columns `variable`, `period`, `mean_a`, `mean_b`, `difference`,
  optionally `long_name`. Facets are labelled by `long_name` where
  present and not `NA`, otherwise by
  [`cd_variables()`](https://newgraphenvironment.github.io/cd/reference/cd_variables.md),
  otherwise by `variable`; a label shared by several variables gets the
  variable name appended, as in
  [`cd_summary()`](https://newgraphenvironment.github.io/cd/reference/cd_summary.md).
  Each variable gets its own facet whatever the labels.

- title:

  Optional plot title.

- labels:

  Named character vector of length 2 for window labels. Default
  `c(a = "Recent", b = "Historical")`.

## Value

A [ggplot2::ggplot](https://ggplot2.tidyverse.org/reference/ggplot.html)
object.

## Examples

``` r
if (FALSE) { # \dontrun{
ts <- cd_extract(catalog, aoi)
cmp <- cd_compare(ts, window_a = 2015:2025, window_b = 1951:1980)
cd_plot_comparison(cmp, labels = c(a = "2015-2025", b = "1951-1980"))
} # }
```
