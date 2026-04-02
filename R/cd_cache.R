#' Get cd cache directory path
#'
#' Returns the path to the cd cache directory. Creates it if
#' it doesn't exist.
#'
#' @param cache_dir Character. Override the default cache location.
#'   If NULL, uses `rappdirs::user_cache_dir("cd")`.
#'
#' @return Character path to the cache directory.
#'
#' @examples
#' cd_cache_path()
#'
#' @export
cd_cache_path <- function(cache_dir = NULL) {
  path <- cache_dir %||% rappdirs::user_cache_dir("cd")
  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }
  path
}

#' Clear the cd cache
#'
#' Removes all cached files from the cd cache directory.
#'
#' @param cache_dir Character. Override the default cache location.
#'
#' @return Invisibly returns the number of files removed.
#'
#' @examples
#' \dontrun{
#' cd_cache_clear()
#' }
#'
#' @export
cd_cache_clear <- function(cache_dir = NULL) {
  path <- cd_cache_path(cache_dir)
  if (!dir.exists(path)) return(invisible(0L))
  files <- list.files(path, recursive = TRUE, full.names = TRUE)
  n <- length(files)
  if (n > 0) unlink(path, recursive = TRUE)
  invisible(n)
}

#' Show cd cache info
#'
#' Reports the cache location and size.
#'
#' @param cache_dir Character. Override the default cache location.
#'
#' @return A list with `path`, `n_files`, and `size_mb`.
#'
#' @examples
#' cd_cache_info()
#'
#' @export
cd_cache_info <- function(cache_dir = NULL) {
  path <- cd_cache_path(cache_dir)
  files <- list.files(path, recursive = TRUE, full.names = TRUE)
  size <- if (length(files) > 0) sum(file.size(files), na.rm = TRUE) else 0
  list(
    path = path,
    n_files = length(files),
    size_mb = round(size / 1024^2, 2)
  )
}
