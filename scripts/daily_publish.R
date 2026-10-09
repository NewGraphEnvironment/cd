#!/usr/bin/env Rscript
#
# daily_publish.R
#
# Publish the daily air-temperature cube on disk (data/backfill/daily/) to
# s3://stac-era5-land/daily/ with its manifest, daily/manifest.json (#124):
# each file's size, sha256 multihash and the provenance tags of the run that
# wrote it. pipeline_update_edh.R STEP D publishes a new year the same way,
# through daily_publish() in scripts/_publish.R; this is the entry point for a
# local backfill or re-tag (uv run scripts/backfill_edh_daily.py --rewrite).
#
# The first manifest needs the whole cube on disk: the manifest must name
# exactly the files S3 will hold. A live publish refuses files tagged with a
# dirty or unknown SHA, so build them from a clean checkout.
#
# Usage (repo root):
#   Rscript scripts/daily_publish.R --dry-run   # checks + aws --dryrun, no upload
#   Rscript scripts/daily_publish.R

if (requireNamespace("cd", quietly = TRUE)) {
  library(cd)
} else if (requireNamespace("devtools", quietly = TRUE)) {
  devtools::load_all()
} else {
  stop("cd is not installed and devtools is unavailable to load_all() it.",
       call. = FALSE)
}
suppressMessages(library(terra))
source("scripts/_lib.R")
source("scripts/_publish.R")

dry_run <- "--dry-run" %in% commandArgs(trailingOnly = TRUE)
log_msg <- function(...) {
  cat(sprintf("[%s] %s\n", format(Sys.time(), "%H:%M:%S"), paste0(...)))
}

daily_publish(
  daily_dir = "data/backfill/daily",
  bucket = "stac-era5-land",
  manifest_path = "data/backfill/daily_manifest.json",
  dry_run = dry_run,
  log = log_msg
)
log_msg("=== DONE ===")
