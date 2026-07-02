# Fetch a remote COG through the on-disk cache

Given a remote `href` (http/https), downloads the file once to the cd
cache directory and returns a local path; subsequent calls read the
local copy instead of re-pulling from the network. Freshness is checked
with a cheap HTTP HEAD request (comparing the S3 ETag), so a monthly
catalog republish is picked up automatically while repeat builds do
near-zero egress. Local paths — and non-http URLs such as `s3://`, which
GDAL reads directly — are returned unchanged.

## Usage

``` r
cd_cache_fetch(href, refresh = FALSE, cache_dir = NULL)
```

## Arguments

- href:

  Character. Path or URL to a COG.

- refresh:

  Logical. If `TRUE`, force a re-download even when a valid cached copy
  exists. Default `FALSE`.

- cache_dir:

  Character. Override the cache location. If `NULL`, uses
  [`cd_cache_path()`](https://newgraphenvironment.github.io/cd/reference/cd_cache_path.md).

## Value

Character path to the local (cached) file, or `href` unchanged for local
/ non-http inputs.

## Details

Freshness uses the ETag when the server provides one, falling back to
the `Content-Length` size when it does not. A host that returns neither
validator cannot be proven fresh, so the file is re-downloaded on each
call (safe, but un-cached) — S3, the default host, always returns both.
Revalidation can be disabled for a fully-offline fast path with
`options(cd.cache_revalidate = FALSE)`, which serves any existing cached
copy without an HTTP HEAD. When the HEAD fails (e.g. offline) but a
cached copy exists, the cached copy is served with a message. Downloads
are written to a temporary file, validated against the advertised
`Content-Length`, then atomically renamed, so a truncated download is
never served as complete.

## Examples

``` r
# Local files pass through untouched:
f <- system.file("extdata", "example_climate.tif", package = "cd")
identical(cd_cache_fetch(f), f)
#> [1] TRUE
```
