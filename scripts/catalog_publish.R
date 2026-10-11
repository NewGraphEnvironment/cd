#!/usr/bin/env Rscript
#
# catalog_publish.R
#
# Rebuild s3://stac-era5-land/catalog.json from the live COGs and publish it,
# without touching a COG (#128). For a catalog whose COGs are right but whose
# metadata is not: a change to what cd_stac_catalog() writes, such as the
# processing:* provenance of #128. Not for a catalog a failed STEP 5 left
# behind its COGs: those COGs are ahead of the live catalog's span, which this
# script refuses; follow catalog_repair_hint() in _lib.R instead.
#
# The COGs are downloaded from the bucket, so every checksum in the new
# catalog is of the bytes live, by construction, and each download's ETag is
# checked against its file before anything is built. The item set and the year
# span must be the live catalog's: this republishes metadata, so a COG that is
# missing, extra, or out of step with the rest is refused here and needs
# scripts/pipeline_stage3_edh.R (or the next pipeline_update_edh.R run, for a
# partial sync, #119).
#
# A live run must be a clean checkout of a commit on origin/main
# (publish_sha_problems()): load_cd() loads the checkout, and the catalog is
# whatever its cd_stac_catalog() writes. The upload is conditional on the live
# catalog's ETag, so a pipeline run publishing meanwhile is not overwritten.
# Every checksum the live catalog states must survive unchanged: this
# republishes metadata, and a changed checksum means a COG changed under it.
#
# Usage (repo root):
#   Rscript scripts/catalog_publish.R --dry-run   # build + check, no upload
#   Rscript scripts/catalog_publish.R

source("scripts/_lib.R")
source("scripts/_publish.R")
load_cd()
suppressMessages(library(terra))

dry_run <- "--dry-run" %in% commandArgs(trailingOnly = TRUE)
log_msg <- function(...) {
  cat(sprintf("[%s] %s\n", format(Sys.time(), "%H:%M:%S"), paste0(...)))
}
refuse <- function(what, problems) {
  log_msg("ERROR: ", what, "; nothing was published.")
  for (p in problems) log_msg("  - ", p)
  quit(status = 1L)
}

bucket <- "stac-era5-land"
cog_base <- paste0("https://", bucket, ".s3.us-west-2.amazonaws.com")
catalog_url <- paste0(cog_base, "/catalog.json")
work <- "data/backfill/catalog_publish"
cog_dir <- file.path(work, "cogs")
# Outside cog_dir, so stray_problems() and the item listing never see it.
catalog_path <- file.path(work, "catalog.json")
live_path <- file.path(work, "catalog_live.json")

log_msg("=== catalog_publish (", if (dry_run) "DRY RUN" else "LIVE", ") ===")

# -- The live catalog: the item set and year span the new one must keep ------
dir.create(cog_dir, recursive = TRUE, showWarnings = FALSE)
res <- curl::curl_fetch_disk(catalog_url, live_path,
                             handle = curl::new_handle(timeout = 60L))
if (res$status_code != 200L) {
  refuse("could not read the live catalog",
         paste0(catalog_url, " answered HTTP ", res$status_code))
}
live_etag <- head_object(catalog_url)$etag
live_json <- jsonlite::read_json(live_path)
live <- catalog_item_years(live_json)
years <- seq(min(live$start, na.rm = TRUE), max(live$end, na.rm = TRUE))
problems <- catalog_problems(live$keys, unique(live$keys), live$start, live$end, years)
if (length(problems) > 0) refuse("the live catalog is not one whole span", problems)
expected <- paste0(live$keys, ".tif")
log_msg("Live catalog: ", length(expected), " items, ", min(years), "-", max(years))

# -- The live COGs, downloaded ----------------------------------------------
# Only the top level: daily/, _backup/ and _healthcheck/ are not catalogued.
# --exact-timestamps: a local copy left by an earlier run, newer than the
# live object, is replaced rather than kept (the ETag check below would refuse
# it otherwise).
sync <- suppressWarnings(system2(
  "aws", c("s3", "sync", shQuote(paste0("s3://", bucket, "/")), shQuote(cog_dir),
           "--exclude", shQuote("*"), "--include", shQuote("*.tif"),
           "--exclude", shQuote("*/*"), "--delete", "--exact-timestamps",
           "--only-show-errors"),
  stdout = TRUE, stderr = TRUE
))
if (!is.null(attr(sync, "status"))) {
  refuse("could not download the live COGs",
         paste0("aws s3 sync exited ", attr(sync, "status"), ": ",
                paste(sync, collapse = " ")))
}
on_disk <- sort(list.files(cog_dir, pattern = "\\.tif$"), method = "radix")
paths <- file.path(cog_dir, on_disk)
cog_years <- stats::setNames(lapply(paths, function(f) names(terra::rast(f))), on_disk)
spans <- live_spans(cog_years)
problems <- c(
  # What is on disk is what is live, byte for byte, before anything is hashed.
  etag_problems(cog_base, cog_dir, on_disk),
  stray_problems(cog_dir, expected),
  if (!identical(on_disk, sort(expected, method = "radix"))) {
    paste0("the live COGs are not the catalog's items: not catalogued ",
           paste(utils::head(setdiff(on_disk, expected), 3), collapse = ", "),
           "; not on S3 ",
           paste(utils::head(setdiff(expected, on_disk), 3), collapse = ", "))
  },
  spans$problems,
  if (length(spans$ahead) > 0) {
    paste0(length(spans$ahead), " COG(s) hold years beyond the rest (a partial ",
           "sync, #119): ", paste(utils::head(names(spans$ahead), 3), collapse = ", "),
           "; the next pipeline_update_edh.R run repairs it")
  },
  if (!identical(as.integer(spans$common), as.integer(years))) {
    paste0("the COGs hold ", min(spans$common), "-", max(spans$common),
           ", the live catalog says ", min(years), "-", max(years))
  },
  grid_problems(paths),
  provenance_problems(paths)
)
if (length(problems) > 0) refuse("the live COGs are not one whole set", problems)
log_msg("Live COGs: ", length(on_disk), " downloaded, ETags match")

# -- Build and check ------------------------------------------------------------
cd_stac_catalog(cog_dir, output_path = catalog_path, base_url = cog_base)
built_json <- jsonlite::read_json(catalog_path)
built <- catalog_item_years(built_json)
problems <- c(
  catalog_problems(built$keys, live$keys, built$start, built$end, years),
  catalog_vocab_problems(built_json),
  checksum_problems(catalog_entries(built_json), cog_dir)
)
if (length(problems) > 0) refuse("the catalog built is not fit to publish", problems)

# A metadata republish changes no COG, so every checksum the live catalog
# states must survive. One it does not state (a catalog from before #124) is
# only counted.
live_ck <- catalog_entries(live_json)
built_ck <- catalog_entries(built_json)
stated <- vapply(names(built_ck), function(n) {
  !is.null(live_ck[[n]]$`file:checksum`)
}, logical(1))
changed <- names(built_ck)[stated & !vapply(names(built_ck), function(n) {
  identical(live_ck[[n]]$`file:checksum`, built_ck[[n]]$`file:checksum`)
}, logical(1))]
if (length(changed) > 0) {
  refuse("a COG's checksum differs from the live catalog's", paste0(
    length(changed), " item(s): ", paste(utils::head(changed, 5), collapse = ", "),
    "; a COG changed, so this is not a metadata republish"
  ))
}
log_msg("Checksums unchanged from the live catalog: ", sum(stated), " of ",
        length(stated), if (any(!stated)) " (the rest state none)" else "")
log_msg("Built ", catalog_path, " (", length(built$keys), " items)")

if (dry_run) {
  log_msg("DRY RUN: would upload ", catalog_path, " to s3://", bucket, "/catalog.json")
  log_msg("=== DONE ===")
  quit(status = 0L)
}

problems <- publish_sha_problems(run_provenance()[["CD_SHA"]])
if (length(problems) > 0) refuse("this checkout may not publish", problems)
put <- tryCatch(s3_put_if(catalog_path, bucket, "catalog.json", live_etag,
                          on_conflict = paste0("Nothing was uploaded; re-run ",
                                               "scripts/catalog_publish.R.")),
                error = function(e) e)
if (inherits(put, "error")) {
  refuse("the catalog upload was refused or failed", conditionMessage(put))
}
# Byte for byte, checksums included.
problems <- readback_problems(catalog_url, catalog_path)
if (length(problems) > 0) {
  log_msg("ERROR: catalog.json uploaded, but ", problems)
  quit(status = 1L)
}
log_msg("Published catalog.json: ", length(built$keys), " items, ",
        min(years), "-", max(years))
log_msg("=== DONE ===")
