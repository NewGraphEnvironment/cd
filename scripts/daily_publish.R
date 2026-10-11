#!/usr/bin/env Rscript
#
# daily_publish.R
#
# Publish the daily air-temperature cube on disk (data/backfill/daily/) to
# s3://stac-era5-land/daily/ with its manifest, daily/manifest.json (#124):
# each file's size, sha256 multihash and the provenance of the run that
# wrote it, in the STAC processing extension's keys (#128).
# pipeline_update_edh.R STEP D publishes a new year the same way,
# through daily_publish() in scripts/_publish.R; this is the entry point for a
# local backfill or re-tag (uv run scripts/backfill_edh_daily.py --rewrite).
#
# The first manifest needs the whole cube on disk: the manifest must name
# exactly the files S3 will hold. A live publish refuses files whose CD_SHA is
# dirty, unknown, or (off CI) not on origin/main, so build them from a clean
# checkout of main.
#
# --manifest-only republishes daily/manifest.json alone, for a change to what
# the manifest says about files already live (the processing:* keys of #128):
# no file is uploaded, and every local file's ETag must match its live object.
#
# Usage (repo root):
#   Rscript scripts/daily_publish.R --dry-run   # checks + aws --dryrun, no upload
#   Rscript scripts/daily_publish.R
#   Rscript scripts/daily_publish.R --manifest-only [--dry-run]

source("scripts/_lib.R")
source("scripts/_publish.R")
load_cd()
suppressMessages(library(terra))

args <- commandArgs(trailingOnly = TRUE)
dry_run <- "--dry-run" %in% args
manifest_only <- "--manifest-only" %in% args
log_msg <- function(...) {
  cat(sprintf("[%s] %s\n", format(Sys.time(), "%H:%M:%S"), paste0(...)))
}

daily_publish(
  daily_dir = "data/backfill/daily",
  bucket = "stac-era5-land",
  manifest_path = "data/backfill/daily_manifest.json",
  dry_run = dry_run,
  sync = !manifest_only,
  log = log_msg
)
log_msg("=== DONE ===")
