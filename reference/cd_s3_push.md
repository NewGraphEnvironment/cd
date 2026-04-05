# Push files to S3

Syncs a local directory to an S3 bucket using `aws s3 sync`. Only
uploads new or changed files (`--size-only`). Requires the AWS CLI to be
installed and configured.

## Usage

``` r
cd_s3_push(local_dir, bucket = "stac-era5-land", prefix = "", dry_run = FALSE)
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

## Value

The exit code from `aws s3 sync` (invisibly). Zero on success.

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
