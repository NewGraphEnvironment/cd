#' Fetch a remote COG through the on-disk cache
#'
#' Given a remote `href` (http/https), downloads the file once to the cd
#' cache directory and returns a local path; subsequent calls read the
#' local copy instead of re-pulling from the network. Freshness is
#' checked with a cheap HTTP HEAD request (comparing the S3 ETag), so a
#' monthly catalog republish is picked up automatically while repeat
#' builds do near-zero egress. Local paths — and non-http URLs such as
#' `s3://`, which GDAL reads directly — are returned unchanged.
#'
#' @param href Character. Path or URL to a COG.
#' @param refresh Logical. If `TRUE`, force a re-download even when a
#'   valid cached copy exists. Default `FALSE`.
#' @param cache_dir Character. Override the cache location. If `NULL`,
#'   uses [cd_cache_path()].
#'
#' @details
#' Freshness uses the ETag when the server provides one, falling back to
#' the `Content-Length` size when it does not. A host that returns
#' neither validator cannot be proven fresh, so the file is re-downloaded
#' on each call (safe, but un-cached) — S3, the default host, always
#' returns both. Revalidation can be disabled for a fully-offline fast
#' path with `options(cd.cache_revalidate = FALSE)`, which serves any
#' existing cached copy without an HTTP HEAD. When the HEAD fails (e.g.
#' offline) but a cached copy exists, the cached copy is served with a
#' message. Downloads are written to a temporary file, validated against
#' the advertised `Content-Length`, then atomically renamed, so a
#' truncated download is never served as complete.
#'
#' @return Character path to the local (cached) file, or `href`
#'   unchanged for local / non-http inputs.
#'
#' @examples
#' # Local files pass through untouched:
#' f <- system.file("extdata", "example_climate.tif", package = "cd")
#' identical(cd_cache_fetch(f), f)
#'
#' @export
cd_cache_fetch <- function(href, refresh = FALSE, cache_dir = NULL) {
  if (length(href) != 1L || is.na(href) || !cd_is_remote(href)) {
    return(href)
  }

  dir <- cd_cache_path(cache_dir)
  ext <- tools::file_ext(href)
  key <- rlang::hash(href)
  fname <- if (nzchar(ext)) paste0(key, ".", ext) else key
  local_path <- file.path(dir, fname)
  meta_path <- paste0(local_path, ".meta")

  have_local <- file.exists(local_path) && file.exists(meta_path)
  revalidate <- isTRUE(getOption("cd.cache_revalidate", default = TRUE))

  # Offline fast path: trust an existing cache without a HEAD request.
  if (have_local && !refresh && !revalidate) {
    return(local_path)
  }

  head <- cd_remote_head(href)

  # HEAD failed (offline / server error): serve a cached copy if present.
  if (is.null(head)) {
    if (have_local && !refresh) {
      rlang::inform(
        paste0("cd_cache_fetch: could not reach '", href,
               "'; serving cached copy.")
      )
      return(local_path)
    }
    stop("cd_cache_fetch: failed to reach '", href,
         "' and no cached copy is available.", call. = FALSE)
  }

  # Valid cache: serve local, no download.
  if (have_local && !refresh) {
    meta <- jsonlite::read_json(meta_path)
    if (cd_cache_valid(head, meta)) {
      return(local_path)
    }
  }

  # Download to a temp file, validate size, atomic rename, write meta.
  tmp <- tempfile(tmpdir = dir, fileext = if (nzchar(ext)) paste0(".", ext) else "")
  on.exit(if (file.exists(tmp)) unlink(tmp), add = TRUE)
  cd_remote_download(href, tmp)

  if (!is.null(head$size) && !is.na(head$size)) {
    got <- file.size(tmp)
    if (is.na(got) || got != head$size) {
      stop("cd_cache_fetch: incomplete download of '", href, "' (",
           got, " of ", head$size, " bytes).", call. = FALSE)
    }
  }

  if (!file.rename(tmp, local_path)) {
    stop("cd_cache_fetch: failed to move the download into the cache for '",
         href, "'.", call. = FALSE)
  }
  jsonlite::write_json(
    list(url = href, etag = head$etag, size = head$size,
         downloaded_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")),
    meta_path, auto_unbox = TRUE
  )
  local_path
}

#' Is an href a cacheable remote (http/https) URL?
#' @noRd
cd_is_remote <- function(href) {
  grepl("^https?://", href)
}

#' Is a cached copy still valid against fresh HEAD metadata?
#'
#' Prefers the ETag; falls back to Content-Length size when the server
#' (or the stored meta) carries no ETag, so ETag-less hosts still get a
#' cache hit instead of re-downloading on every call.
#' @noRd
cd_cache_valid <- function(head, meta) {
  if (!is.null(head$etag) && !is.null(meta$etag)) {
    return(identical(head$etag, meta$etag))
  }
  if (!is.null(head$size) && !is.na(head$size) && !is.null(meta$size)) {
    return(isTRUE(as.numeric(meta$size) == head$size))
  }
  FALSE
}

#' HTTP HEAD a remote COG; return its ETag and size, or NULL on failure.
#' @noRd
cd_remote_head <- function(href) {
  handle <- curl::new_handle(nobody = TRUE)
  res <- tryCatch(
    curl::curl_fetch_memory(href, handle = handle),
    error = function(e) NULL
  )
  if (is.null(res) || res$status_code >= 400) {
    return(NULL)
  }
  hdrs <- curl::parse_headers_list(res$headers)
  etag <- hdrs[["etag"]]
  cl <- hdrs[["content-length"]]
  list(
    etag = if (!is.null(etag)) gsub('"', "", etag) else NULL,
    size = if (!is.null(cl)) as.numeric(cl) else NA_real_
  )
}

#' Download a remote COG to destfile (binary).
#' @noRd
cd_remote_download <- function(href, destfile) {
  curl::curl_download(href, destfile, mode = "wb")
}
