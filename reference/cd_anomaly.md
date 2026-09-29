# Compute climate anomalies

Calculates departure from a baseline for each year. The anomaly type
decides the arithmetic: absolute deviation for temperature, VPD, RH, and
the annual snow scalars; percent of normal for precipitation, soil
moisture, and the monthly snow vars (`swe`, `snowfall`, `snowmelt`);
percentage-point difference for variables that are already
fractions/percentages (`snow_cover`, `snowfall_fraction`).

## Usage

``` r
cd_anomaly(x, baseline, cap_pct = 200)
```

## Arguments

- x:

  A tibble from
  [`cd_extract()`](https://newgraphenvironment.github.io/cd/reference/cd_extract.md)
  with columns `variable`, `period`, `year`, `value`.

- baseline:

  A tibble from
  [`cd_baseline()`](https://newgraphenvironment.github.io/cd/reference/cd_baseline.md)
  with columns `variable`, `period`, `baseline_mean`.

- cap_pct:

  Numeric. Cap for percent-of-normal anomalies. Values beyond +/-
  `cap_pct` are clamped. Default `200`. Only applies to `pct_normal`
  variables; `absolute` and `pct_point_diff` anomalies are not capped.

## Value

A tibble with columns `variable`, `period`, `year`, `anomaly`,
`anomaly_type`, `unit`, and `long_name` when `x` carries one.

## Input contract

`cd_anomaly()` works on any annual series in cd's long format, not only
the ERA5-Land variables in
[`cd_variables()`](https://newgraphenvironment.github.io/cd/reference/cd_variables.md)
— streamflow or stream temperature produced by another package included.
Required columns:

- `variable`:

  Series name.

- `period`:

  Free text: a season, a month, or any window the producer defines (e.g.
  `"spawn"`). Nothing requires
  [`cd_periods()`](https://newgraphenvironment.github.io/cd/reference/cd_periods.md)
  values.

- `year`:

  Integer year.

- `value`:

  Numeric, one row per variable, period and year — duplicates (two
  stations stacked under one `variable`) are an error in
  [`cd_baseline()`](https://newgraphenvironment.github.io/cd/reference/cd_baseline.md),
  `cd_anomaly()`,
  [`cd_compare()`](https://newgraphenvironment.github.io/cd/reference/cd_compare.md)
  and
  [`cd_trend()`](https://newgraphenvironment.github.io/cd/reference/cd_trend.md),
  not pooled.

Optional columns, resolved row by row; where absent or `NA` they fall
back to
[`cd_variables()`](https://newgraphenvironment.github.io/cd/reference/cd_variables.md):

- `anomaly_type`:

  One of `"absolute"`, `"pct_normal"`, `"pct_point_diff"`. Required for
  any variable not in
  [`cd_variables()`](https://newgraphenvironment.github.io/cd/reference/cd_variables.md);
  a variable whose type cannot be resolved is an error, never a silent
  `NA`.

- `unit`:

  Unit of the **anomaly**, passed through as given — the same meaning as
  `cd_variables()$unit`, so `"%"` for a `pct_normal` series whatever the
  unit of `value`.

- `long_name`:

  Label, carried through to
  [`cd_trend()`](https://newgraphenvironment.github.io/cd/reference/cd_trend.md)
  and used by
  [`cd_summary()`](https://newgraphenvironment.github.io/cd/reference/cd_summary.md).

Each variable and period must resolve to a single `anomaly_type`, `unit`
and `long_name`, so for a variable outside
[`cd_variables()`](https://newgraphenvironment.github.io/cd/reference/cd_variables.md)
carry each on every row or on none. A registered variable that carries
an `anomaly_type` different from the registry's gets no registry unit. A
`pct_normal` series whose baseline mean is `0` (a dry-window minimum
flow, say) has no percent of normal: its anomalies come back `NaN` or
clamped at `cap_pct`, so use `absolute` for such series.

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

# Compute anomalies relative to early-period baseline
# Absolute deviation for temperature; percent of normal for precipitation
bl <- cd_baseline(ts, baseline_years = 1951:1955)
cd_anomaly(ts, bl)
#> # A tibble: 10 × 6
#>    variable period  year anomaly anomaly_type unit 
#>    <chr>    <chr>  <int>   <dbl> <chr>        <chr>
#>  1 tmean    annual  1951 -1.43   absolute     °C   
#>  2 tmean    annual  1952 -0.571  absolute     °C   
#>  3 tmean    annual  1953  0.562  absolute     °C   
#>  4 tmean    annual  1954  1.22   absolute     °C   
#>  5 tmean    annual  1955  0.218  absolute     °C   
#>  6 tmean    annual  1956 -1.43   absolute     °C   
#>  7 tmean    annual  1957  0.0707 absolute     °C   
#>  8 tmean    annual  1958  0.106  absolute     °C   
#>  9 tmean    annual  1959  1.98   absolute     °C   
#> 10 tmean    annual  1960 -0.171  absolute     °C   

# Any series in the same long format, e.g. mean discharge over a
# spawning window, carrying its own anomaly type and unit
q <- data.frame(
  variable = "q_mean", period = "spawn", year = 2001:2006,
  value = c(12, 9, 14, 7, 6, 8),
  anomaly_type = "pct_normal", unit = "%", long_name = "Mean discharge"
)
cd_anomaly(q, cd_baseline(q, baseline_years = 2001:2003))
#>   variable period year    anomaly anomaly_type unit      long_name
#> 1   q_mean  spawn 2001   2.857143   pct_normal    % Mean discharge
#> 2   q_mean  spawn 2002 -22.857143   pct_normal    % Mean discharge
#> 3   q_mean  spawn 2003  20.000000   pct_normal    % Mean discharge
#> 4   q_mean  spawn 2004 -40.000000   pct_normal    % Mean discharge
#> 5   q_mean  spawn 2005 -48.571429   pct_normal    % Mean discharge
#> 6   q_mean  spawn 2006 -31.428571   pct_normal    % Mean discharge
```
