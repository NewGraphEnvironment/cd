# Networked publish helpers for the cd producer pipelines (#124).
#
# scripts/_lib.R holds the checks; everything here talks to S3, anonymously
# over HTTPS for reads and through the AWS CLI for writes and listings. Source
# it after _lib.R, from the repo root:
#
#   source("scripts/_lib.R"); source("scripts/_publish.R")

s3_base <- function(bucket) paste0("https://", bucket, ".s3.us-west-2.amazonaws.com")

# Status and ETag of one object, by anonymous HEAD. Status 0 = no response.
head_object <- function(url) {
  res <- tryCatch(
    curl::curl_fetch_memory(url, handle = curl::new_handle(nobody = TRUE, timeout = 30L)),
    error = function(e) NULL
  )
  if (is.null(res)) return(list(code = 0L, etag = NA_character_))
  h <- curl::parse_headers_list(res$headers)
  list(code = as.integer(res$status_code),
       etag = if (is.null(h$etag)) NA_character_ else gsub('"', "", h$etag))
}

# Why the live objects under `base_url` are not the local files of the same
# name, or character(0). Compares each object's ETag with the file (see
# s3_etag_matches()): the one check that what went up is what was hashed. A
# sync, even without --size-only, skips a same-size file whose local copy is
# older than the object, and a catalog or manifest checksum would then
# describe bytes that are not live.
etag_problems <- function(base_url, dir, names) {
  bad <- character()
  for (n in names) {
    h <- head_object(paste0(base_url, "/", n))
    if (h$code != 200L) {
      bad <- c(bad, paste0(n, ": HTTP ", h$code))
    } else if (!s3_etag_matches(file.path(dir, n), h$etag)) {
      bad <- c(bad, paste0(n, ": live ETag ", h$etag, " is not the local file"))
    }
  }
  if (length(bad) == 0L) return(character(0))
  paste0(length(bad), " of ", length(names), " live object(s) are not the ",
         "bytes that were hashed: ", paste(utils::head(bad, 5), collapse = "; "),
         if (length(bad) > 5) "; ..." else "")
}

# Why the object at `url` is not, byte for byte, the local file, or
# character(0). Compared as bytes rather than parsed JSON, which would accept
# a different file that parses the same.
readback_problems <- function(url, path) {
  res <- tryCatch(
    curl::curl_fetch_memory(url, handle = curl::new_handle(timeout = 60L)),
    error = function(e) NULL
  )
  if (is.null(res) || res$status_code != 200L) {
    return(paste0(url, " could not be read back (HTTP ",
                  if (is.null(res)) 0L else res$status_code, ")"))
  }
  if (!identical(res$content, readBin(path, "raw", file.size(path)))) {
    return(paste0(url, " read back is not the file uploaded (", path, ")"))
  }
  character(0)
}

# Upload one file to one key with `aws s3 cp`, or stop().
s3_put <- function(path, bucket, key, dry_run = FALSE) {
  out <- suppressWarnings(system2(
    "aws", c("s3", "cp", shQuote(path), shQuote(paste0("s3://", bucket, "/", key)),
             if (dry_run) "--dryrun"),
    stdout = TRUE, stderr = TRUE
  ))
  if (!is.null(attr(out, "status"))) {
    stop("aws s3 cp of ", key, " failed (exit ", attr(out, "status"), "): ",
         paste(out, collapse = " "), call. = FALSE)
  }
  invisible(out)
}

# Upload a manifest only if the live one is still the one this run read: its
# ETag, or no object at all when `etag` is NA (S3 conditional writes,
# --if-match / --if-none-match). Two publishers merging into one manifest at
# once (a hand-run daily_publish.R beside CI's STEP D; the workflow's
# concurrency group covers only CI) would otherwise lose one's entries with
# nothing to show it. Stops on a failed or refused write.
s3_put_if <- function(path, bucket, key, etag) {
  cond <- if (is.na(etag)) c("--if-none-match", "'*'") else c("--if-match", shQuote(etag))
  out <- suppressWarnings(system2(
    "aws", c("s3api", "put-object", "--bucket", bucket, "--key", shQuote(key),
             "--body", shQuote(path), "--content-type", "application/json", cond),
    stdout = TRUE, stderr = TRUE
  ))
  if (!is.null(attr(out, "status"))) {
    stop("upload of ", key, " refused or failed (exit ", attr(out, "status"),
         "): ", paste(out, collapse = " "),
         if (any(grepl("PreconditionFailed|412", out))) {
           paste0(". Another publish changed it since this run read it; ",
                  "re-run to merge onto the new one.")
         } else "", call. = FALSE)
  }
  invisible(out)
}

# The .tif names directly under s3://<bucket>/<prefix>/, from the AWS CLI
# (the bucket grants no anonymous ListBucket). Stops when the listing fails.
s3_tifs <- function(bucket, prefix) {
  out <- suppressWarnings(system2(
    "aws", c("s3", "ls", shQuote(paste0("s3://", bucket, "/", prefix, "/"))),
    stdout = TRUE, stderr = TRUE
  ))
  if (!is.null(attr(out, "status"))) {
    stop("aws s3 ls s3://", bucket, "/", prefix, "/ failed (exit ",
         attr(out, "status"), "): ", paste(out, collapse = " "), call. = FALSE)
  }
  out <- out[!grepl("^\\s*PRE ", out)]
  f <- sub("^\\S+\\s+\\S+\\s+[0-9]+\\s+", "", out)
  sort(f[grepl("\\.tif$", f)], method = "radix")
}

# The live daily manifest: list(files = its entries, etag = the object's
# ETag), or NULL when there is none yet (S3 answers 403 for a missing key on a
# bucket without anonymous ListBucket). Stops on anything else, which is not
# evidence of absence.
daily_manifest_live <- function(bucket) {
  url <- paste0(s3_base(bucket), "/daily/manifest.json")
  res <- tryCatch(
    curl::curl_fetch_memory(url, handle = curl::new_handle(timeout = 60L)),
    error = function(e) NULL
  )
  code <- if (is.null(res)) 0L else as.integer(res$status_code)
  if (code %in% c(403L, 404L)) return(NULL)
  if (code != 200L) stop("could not read ", url, " (HTTP ", code, ")", call. = FALSE)
  h <- curl::parse_headers_list(res$headers)
  list(files = jsonlite::fromJSON(rawToChar(res$content), simplifyVector = FALSE)$files,
       etag = if (is.null(h$etag)) NA_character_ else gsub('"', "", h$etag))
}

# Publish the local daily cube files with a manifest that describes every
# published year (#124).
#
# A CI runner holds only the year(s) it built, so the manifest is the live one
# with this run's entries laid over it. Before anything is uploaded, the
# manifest must be one whole cube (manifest_problems()) and name exactly the
# files S3 will hold after the sync: the live listing plus the local files. So
# a first manifest can only come from a directory holding the whole cube,
# which needs no special case for CI. After the sync each uploaded object's
# ETag is checked against its file, the manifest goes up last, and its bytes
# are read back.
#
#   manifest_path  where to write the manifest locally; outside daily_dir, so
#                  the sync never carries it (it goes up on its own, last).
#   log            a function of one string, for progress lines.
daily_publish <- function(daily_dir, bucket, manifest_path, dry_run = FALSE,
                          log = message) {
  # A backfill or --rewrite still writing would change files after they are
  # hashed here. Not on GitHub Actions, where STEP D has already waited for the
  # backfill and pgrep matches wrapper shells (preflight_single_instance() in
  # _lib.py skips there for the same reason).
  busy <- if (identical(Sys.getenv("GITHUB_ACTIONS"), "true")) character(0) else
    suppressWarnings(system2("pgrep", c("-f", "backfill_edh_daily"),
                             stdout = TRUE, stderr = FALSE))
  if (is.null(attr(busy, "status")) && length(busy) > 0) {
    stop("backfill_edh_daily.py is running (pid ", paste(busy, collapse = ", "),
         "); publish once it has finished.", call. = FALSE)
  }
  paths <- list.files(daily_dir, pattern = "\\.tif$", full.names = TRUE)
  if (length(paths) == 0L) stop("no .tif files in ", daily_dir, call. = FALSE)
  local <- manifest_entries(paths)
  live_manifest <- daily_manifest_live(bucket)
  live <- live_manifest$files
  merged <- manifest_merge(live, local)
  log(paste0("Daily manifest: ", length(local), " local file(s) over ",
             length(live), " live entr", if (length(live) == 1L) "y" else "ies"))

  problems <- c(
    manifest_problems(merged),
    provenance_problems(paths),
    stray_problems(daily_dir, names(local))
  )
  if (!dry_run) {
    shas <- unique(vapply(local, function(e) e$`cd:sha` %||% "unknown", character(1)))
    problems <- c(problems, unlist(lapply(shas, function(x) sha_problems(c(CD_SHA = x)))))
  }
  after <- sort(union(s3_tifs(bucket, "daily"), names(local)), method = "radix")
  if (!identical(after, names(merged))) {
    problems <- c(problems, paste0(
      "the manifest would name ", length(merged), " file(s), S3 would hold ",
      length(after), " after the sync",
      if (is.null(live)) paste0(" (there is no live manifest, so the first ",
                                "one needs the whole cube on disk)") else "",
      ": not in the manifest ",
      paste(utils::head(setdiff(after, names(merged)), 3), collapse = ", "),
      "; not on S3 ", paste(utils::head(setdiff(names(merged), after), 3), collapse = ", ")
    ))
  }
  if (length(problems) > 0) {
    stop("Refusing to publish the daily cube:\n  - ",
         paste(problems, collapse = "\n  - "), call. = FALSE)
  }

  dir.create(dirname(manifest_path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(list(files = merged), manifest_path, pretty = TRUE,
                       auto_unbox = TRUE, digits = NA)
  if (dry_run) {
    log(paste0("DRY RUN: would sync ", length(local), " file(s) to s3://", bucket,
               "/daily/ and upload a manifest of ", length(merged), " (",
               manifest_path, ")"))
    cd::cd_s3_push(daily_dir, bucket = bucket, prefix = "daily", dry_run = TRUE,
                   size_only = FALSE)
    return(invisible(TRUE))
  }

  cd::cd_s3_push(daily_dir, bucket = bucket, prefix = "daily", size_only = FALSE)
  # What is live is what is on disk (ETags), and what is on disk is still what
  # was hashed: a file rewritten after manifest_entries() would pass the ETag
  # check alone.
  problems <- c(etag_problems(paste0(s3_base(bucket), "/daily"), daily_dir, names(local)),
                checksum_problems(merged, daily_dir, names(local)))
  if (!identical(s3_tifs(bucket, "daily"), names(merged))) {
    problems <- c(problems, "the live daily/ listing is not the manifest's file set")
  }
  if (length(problems) > 0) {
    stop("Daily files synced, manifest NOT uploaded:\n  - ",
         paste(problems, collapse = "\n  - "), call. = FALSE)
  }
  s3_put_if(manifest_path, bucket, "daily/manifest.json",
            if (is.null(live_manifest)) NA_character_ else live_manifest$etag)
  problems <- readback_problems(paste0(s3_base(bucket), "/daily/manifest.json"),
                                manifest_path)
  if (length(problems) > 0) stop(problems, call. = FALSE)
  log(paste0("Published ", length(local), " daily file(s); manifest lists ",
             length(merged), ", through ", manifest_last_year(merged)))
  invisible(TRUE)
}

# Why the live daily manifest does not describe the published cube through
# `newest`, the newest year STEP D found published by HEAD, or character(0).
# Without this, a run whose manifest upload failed after its sync would leave
# that year out of the manifest for good: the next run sees the files, calls
# the cube current and goes green.
daily_manifest_problems <- function(bucket, newest) {
  live <- tryCatch(daily_manifest_live(bucket), error = function(e) e)
  if (inherits(live, "error")) return(conditionMessage(live))
  live <- live$files
  if (is.null(live)) {
    return(paste0("there is no s3://", bucket, "/daily/manifest.json; build it ",
                  "from the whole cube on disk: Rscript scripts/daily_publish.R"))
  }
  problems <- manifest_problems(live)
  last <- manifest_last_year(live)
  if (!identical(last, as.integer(newest))) {
    problems <- c(problems, paste0(
      "the live manifest ends in ", last, " but the cube is published through ",
      newest, "; repair from a full local cube: Rscript scripts/daily_publish.R"))
  }
  problems
}
