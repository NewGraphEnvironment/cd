# Get cd cache directory path

Returns the path to the cd cache directory. Creates it if it doesn't
exist.

## Usage

``` r
cd_cache_path(cache_dir = NULL)
```

## Arguments

- cache_dir:

  Character. Override the default cache location. If NULL, uses
  `rappdirs::user_cache_dir("cd")`.

## Value

Character path to the cache directory.

## Examples

``` r
cd_cache_path()
#> [1] "~/.cache/cd"
```
