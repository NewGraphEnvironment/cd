# Push files to S3

Syncs a local directory to an S3 bucket using `aws s3 sync`. Only
uploads new or changed files. Requires the AWS CLI to be installed and
configured.

## Usage

``` r
cd_s3_push(
  local_dir,
  bucket = "stac-era5-land",
  prefix = "",
  dry_run = FALSE,
  size_only = FALSE
)
```

## Arguments

- local_dir:

  Character. Local directory to sync.

- bucket:

  Character. S3 bucket name. Default `"stac-era5-land"`.

- prefix:

  Character. S3 key prefix (subdirectory in bucket). Default `""`
  (bucket root).

- dry_run:

  Logical. If `TRUE`, shows what would be uploaded without actually
  uploading. Default `FALSE`.

- size_only:

  Logical. Compare by size alone (`--size-only`). Default `FALSE`.

## Value

The exit code from `aws s3 sync` (invisibly). Zero on success.

## Details

By default a file is uploaded when its size differs from its S3 copy or
it is newer than that copy, so a rebuilt file of unchanged size still
goes up. That matters wherever something published describes the bytes,
such as the checksums in the catalog and the daily manifest (#124).
`size_only = TRUE` compares sizes alone (`--size-only`), the default
before \#124, and skips such a file.

## Examples

``` r
if (FALSE) { # \dontrun{
# Preview what would be uploaded
cd_s3_push("data/cogs", dry_run = TRUE)

# Upload for real
cd_s3_push("data/cogs")

# Upload to a subdirectory in the bucket
cd_s3_push("data/cogs", prefix = "v1")
} # }
```
