#' Push files to S3
#'
#' Syncs a local directory to an S3 bucket using `aws s3 sync`.
#' Only uploads new or changed files. Requires the AWS CLI to be installed
#' and configured.
#'
#' With `size_only = TRUE` (the default) a file is changed only when its size
#' differs, so a rebuilt file of the same size is not uploaded. Pass `FALSE`
#' whenever something published describes the bytes, such as a checksum in a
#' catalog: the sync then also uploads any file newer than its S3 copy.
#'
#' @param local_dir Character. Local directory to sync.
#' @param bucket Character. S3 bucket name. Default `"stac-era5-land"`.
#' @param prefix Character. S3 key prefix (subdirectory in bucket).
#'   Default `""` (bucket root).
#' @param dry_run Logical. If `TRUE`, shows what would be uploaded
#'   without actually uploading. Default `FALSE`.
#' @param size_only Logical. Compare by size alone (`--size-only`).
#'   Default `TRUE`.
#'
#' @return The exit code from `aws s3 sync` (invisibly). Zero on success.
#'
#' @examples
#' \dontrun{
#' # Preview what would be uploaded
#' cd_s3_push("data/cogs", dry_run = TRUE)
#'
#' # Upload for real
#' cd_s3_push("data/cogs")
#'
#' # Upload to a subdirectory in the bucket
#' cd_s3_push("data/cogs", prefix = "v1")
#' }
#'
#' @export
cd_s3_push <- function(local_dir,
                       bucket = "stac-era5-land",
                       prefix = "",
                       dry_run = FALSE,
                       size_only = TRUE) {
  if (!dir.exists(local_dir)) {
    rlang::abort(paste("Directory not found:", local_dir))
  }

  s3_target <- if (nchar(prefix) > 0) {
    paste0("s3://", bucket, "/", prefix)
  } else {
    paste0("s3://", bucket)
  }

  cmd <- sprintf(
    "aws s3 sync %s %s --exclude '.*' --exclude '*.aux.json'%s%s",
    shQuote(local_dir),
    shQuote(s3_target),
    if (size_only) " --size-only" else "",
    if (dry_run) " --dryrun" else ""
  )

  message("Running: ", cmd)
  exit_code <- system(cmd)

  if (exit_code != 0 && !dry_run) {
    rlang::abort(paste("S3 sync failed with exit code", exit_code))
  }

  invisible(exit_code)
}
