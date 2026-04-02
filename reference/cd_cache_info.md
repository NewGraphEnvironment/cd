# Show cd cache info

Reports the cache location and size.

## Usage

``` r
cd_cache_info(cache_dir = NULL)
```

## Arguments

- cache_dir:

  Character. Override the default cache location.

## Value

A list with `path`, `n_files`, and `size_mb`.

## Examples

``` r
cd_cache_info()
#> $path
#> [1] "~/.cache/cd"
#> 
#> $n_files
#> [1] 0
#> 
#> $size_mb
#> [1] 0
#> 
```
