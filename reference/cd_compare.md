# Compare arbitrary time windows

Computes the mean value for two user-defined time windows, the
difference between them, and (by default) a p-value testing whether the
two windows differ.

## Usage

``` r
cd_compare(
  x,
  window_a = 2015:2025,
  window_b = 1951:1980,
  method = "mean_diff",
  test = "t"
)
```

## Arguments

- x:

  A tibble from
  [`cd_extract()`](https://newgraphenvironment.github.io/cd/reference/cd_extract.md)
  with columns `variable`, `period`, `year`, `value`.

- window_a:

  Integer vector of years for the recent / impact window. Default
  `2015:2025`.

- window_b:

  Integer vector of years for the reference window. Default `1951:1980`
  (WMO-style standard normal).

- method:

  Character. Comparison method: `"mean_diff"` for `mean_a - mean_b`, or
  `"pct_change"` for percentage change relative to window_b.

- test:

  Character or NULL. Window-vs-window significance test: `"t"` for
  Welch's two-sample t-test (default) or `"wilcox"` for Mann-Whitney U.
  Set to `NULL` to skip — output then drops the `p_value` column. Rows
  where either window has fewer than 8 non-NA values get `p_value = NA`
  and a single batched warning.

## Value

A tibble with columns `variable`, `period`, `mean_a`, `mean_b`,
`difference`, `method`, and (when `test` is non-NULL) `p_value`.

## Details

Defaults compare a recent decade (`2015:2025`) to the WMO-style standard
normal reference period (`1951:1980`) — the framing used in the package
vignettes. This is a *cumulative-impact* comparison ("how much warmer is
the recent decade than the pre-warming reference?") rather than a
rate-of-change comparison; for the latter use
[`cd_trend()`](https://newgraphenvironment.github.io/cd/reference/cd_trend.md).

The window-vs-window p-value (`test = "t"` Welch t-test or
`test = "wilcox"` Mann-Whitney U) tests whether the means of the two
windows differ — a different question than
[`cd_trend()`](https://newgraphenvironment.github.io/cd/reference/cd_trend.md)'s
Mann-Kendall test, which checks for a monotonic trend across the full
series. Two windows can differ significantly without a monotonic trend
(step changes, U-shapes) and a non-significant trend doesn't always mean
the windows are indistinguishable. The test treats annual values as
independent; for series with strong autocorrelation the t-test p is
mildly anti-conservative — the Wilcoxon alternative is more robust to
non-Gaussian tails / outliers but shares the independence assumption.

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

# The toy example catalog only spans 1951:1960, so the windows
# below override the defaults (2015:2025 vs 1951:1980) — those
# are the right choice on the live STAC catalog. test = NULL
# because the toy windows have < 8 years.
cd_compare(ts, window_a = 1956:1960, window_b = 1951:1955, test = NULL)
#> # A tibble: 1 × 6
#>   variable period mean_a mean_b difference method   
#>   <chr>    <chr>   <dbl>  <dbl>      <dbl> <chr>    
#> 1 tmean    annual  -1.33  -1.44      0.110 mean_diff

# Same comparison as percentage change
cd_compare(ts, window_a = 1956:1960, window_b = 1951:1955,
           method = "pct_change", test = NULL)
#> # A tibble: 1 × 6
#>   variable period mean_a mean_b difference method    
#>   <chr>    <chr>   <dbl>  <dbl>      <dbl> <chr>     
#> 1 tmean    annual  -1.33  -1.44       7.63 pct_change
```
