# Valid temporal aggregation periods

Returns the set of temporal periods supported by the cd package. Used
for input validation and iteration in extraction and analysis functions.

## Usage

``` r
cd_periods(include_monthly = FALSE)
```

## Arguments

- include_monthly:

  Logical. If `TRUE`, appends the 12 calendar months (Jan, Feb, ...,
  Dec) to the seasonal periods. Default `FALSE`.

## Value

Character vector of period names.

## Examples

``` r
cd_periods()
#> [1] "annual" "winter" "spring" "summer" "fall"  
cd_periods(include_monthly = TRUE)
#>  [1] "annual" "winter" "spring" "summer" "fall"   "Jan"    "Feb"    "Mar"   
#>  [9] "Apr"    "May"    "Jun"    "Jul"    "Aug"    "Sep"    "Oct"    "Nov"   
#> [17] "Dec"   
```
