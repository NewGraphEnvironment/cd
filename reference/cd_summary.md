# Format trend results as a reporting table

Joins trend statistics with variable metadata and computes Total Change
(slope x years). Returns a tibble ready for `DT::datatable()` or
[`gt::gt()`](https://gt.rstudio.com/reference/gt.html).

## Usage

``` r
cd_summary(trend, region_name = NULL)
```

## Arguments

- trend:

  A tibble from
  [`cd_trend()`](https://newgraphenvironment.github.io/cd/reference/cd_trend.md).

- region_name:

  Optional character label for the AOI. If provided, adds a `Region`
  column.

## Value

A tibble with columns `Parameter`, `Period`, `Slope`, `Years`,
`Total Change`, `Unit`, `p-value`, and optionally `Region`. When `trend`
mixes raw-value and anomaly trends, a `Trend on` column follows
`Period`.

## Details

Labels and units come from `long_name` and `unit` columns on `trend`
where present and not `NA` (carried by
[`cd_trend()`](https://newgraphenvironment.github.io/cd/reference/cd_trend.md)
from the input contract in
[`cd_anomaly()`](https://newgraphenvironment.github.io/cd/reference/cd_anomaly.md)),
otherwise from
[`cd_variables()`](https://newgraphenvironment.github.io/cd/reference/cd_variables.md)
— by the same rules as
[`cd_anomaly()`](https://newgraphenvironment.github.io/cd/reference/cd_anomaly.md),
so a registered variable trended under a different `anomaly_type` gets
no registry unit. A variable found in neither is labelled by its name,
with no unit. On a trend of raw values (`trend_on == "value"`) `Unit` is
shown only for `absolute` and `pct_point_diff` series — the anomaly unit
of a `pct_normal` series is `"%"`, which does not describe a slope in mm
— so it agrees with the axis label of
[`cd_plot_timeseries()`](https://newgraphenvironment.github.io/cd/reference/cd_plot_timeseries.md)
on the same series.

Rows are kept distinguishable. A `long_name` shared by several variables
(one label on many stations) gets the variable name appended, as in
[`cd_plot_comparison()`](https://newgraphenvironment.github.io/cd/reference/cd_plot_comparison.md):
`"Mean discharge (q_site1)"`. A table holding both raw-value and anomaly
trends, such as `dplyr::bind_rows(cd_trend(x), cd_trend(ano))`, gains a
`Trend on` column (`"Value"` or `"Anomaly"`; a missing or `NA`
`trend_on` reads as `"Anomaly"`). A table on one scale has no such
column. Both are decided within one call, so summaries bound together
(one per region, each with its `region_name`) can differ in suffixes,
and a `Trend on` column present in only some of them is `NA` for the
rest.

## Examples

``` r
catalog <- cd_catalog(
  system.file("extdata", "example_catalog.json", package = "cd")
)
aoi <- sf::st_read(
  system.file("extdata", "example_aoi.gpkg", package = "cd"),
  quiet = TRUE
)
ts <- cd_extract(catalog, aoi)
trn <- cd_trend(ts, trend_start = 1951)

# Reporting table with Total Change = slope * years
cd_summary(trn)
#> # A tibble: 1 × 7
#>   Parameter        Period Slope Years `Total Change` Unit  `p-value`
#>   <chr>            <chr>  <dbl> <int>          <dbl> <chr>     <dbl>
#> 1 Mean temperature Annual 0.128    10            1.3 °C        0.592

# Add region label for multi-AOI reports
cd_summary(trn, region_name = "Example AOI")
#> # A tibble: 1 × 8
#>   Parameter        Period Slope Years `Total Change` Unit  `p-value` Region     
#>   <chr>            <chr>  <dbl> <int>          <dbl> <chr>     <dbl> <chr>      
#> 1 Mean temperature Annual 0.128    10            1.3 °C        0.592 Example AOI
```
