# Default meteorological season definitions

Returns a named list of month numbers for standard meteorological
seasons. Override to define custom seasons (e.g., wet/dry, growing
season).

## Usage

``` r
cd_seasons()
```

## Value

Named list of integer vectors.

## Examples

``` r
cd_seasons()
#> $winter
#> [1] 12  1  2
#> 
#> $spring
#> [1] 3 4 5
#> 
#> $summer
#> [1] 6 7 8
#> 
#> $fall
#> [1]  9 10 11
#> 

# Custom: hydrological year
list(wet = c(10, 11, 12, 1, 2, 3), dry = 4:9)
#> $wet
#> [1] 10 11 12  1  2  3
#> 
#> $dry
#> [1] 4 5 6 7 8 9
#> 
```
