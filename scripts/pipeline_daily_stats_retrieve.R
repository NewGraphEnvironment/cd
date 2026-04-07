#!/usr/bin/env Rscript
#
# pipeline_daily_stats_retrieve.R
#
# Pass 2 of 2: Download completed daily stats jobs from CDS.
# Reads job URLs from data/backfill/daily_stats_jobs.csv
# (created by pipeline_daily_stats_submit.R).
#
# Run this hours after submitting — CDS needs time to compute
# daily max/min from hourly ERA5-Land data.
#
# Usage:
#   Rscript scripts/pipeline_daily_stats_retrieve.R

library(ecmwfr)

# -- Configuration ------------------------------------------------------------
jobs_file <- "data/backfill/daily_stats_jobs.csv"
output_dir <- "data/backfill/raw"

if (!file.exists(jobs_file)) {
  stop("No jobs file found at ", jobs_file,
       "\nRun pipeline_daily_stats_submit.R first")
}

jobs <- read.csv(jobs_file, stringsAsFactors = FALSE)
message("Found ", nrow(jobs), " jobs to retrieve")

# -- Check which are already downloaded ---------------------------------------
existing <- list.files(output_dir, pattern = "era5land_t(max|min)_\\d{4}\\.(nc|grib)$")
already_done <- jobs$target %in% existing |
  sub("\\.grib$", ".nc", jobs$target) %in% existing

message("Already downloaded: ", sum(already_done))
message("Remaining: ", sum(!already_done))

# -- Retrieve ------------------------------------------------------------------
failed <- character()

for (i in which(!already_done)) {
  message("\nRetrieving ", jobs$variable[i], " ", jobs$year[i],
          " (", i, "/", nrow(jobs), ")...")

  tryCatch({
    wf_transfer(
      url = jobs$job_url[i],
      path = output_dir,
      filename = jobs$target[i]
    )

    # Check what was actually written (CDS may return .nc instead of .grib)
    downloaded <- file.path(output_dir, jobs$target[i])
    nc_version <- sub("\\.grib$", ".nc", downloaded)
    actual <- if (file.exists(downloaded)) downloaded else if (file.exists(nc_version)) nc_version else NULL

    if (!is.null(actual)) {
      fsize <- file.size(actual)
      if (fsize < 10000) {
        warning("Suspicious file size (", fsize, " bytes) for ", basename(actual),
                " — deleting", call. = FALSE)
        file.remove(actual)
        failed <<- c(failed, paste(jobs$variable[i], jobs$year[i]))
      } else {
        message("  OK: ", basename(actual), " (", round(fsize / 1e6, 1), " MB)")
      }
    } else {
      message("  WARNING: no file found after transfer")
      failed <<- c(failed, paste(jobs$variable[i], jobs$year[i]))
    }
  }, error = function(e) {
    message("  FAILED: ", e$message)
    failed <<- c(failed, paste(jobs$variable[i], jobs$year[i]))
  })

  # Small delay between downloads
  Sys.sleep(1)
}

# -- Summary -------------------------------------------------------------------
all_files <- list.files(output_dir, pattern = "era5land_t(max|min)_\\d{4}\\.(nc|grib)$")
message("\n=== RETRIEVAL COMPLETE ===")
message("Daily stats files on disk: ", length(all_files))
if (length(failed) > 0) {
  message("Failed (re-run to retry): ", paste(failed, collapse = ", "))
}
message("\nNext: re-run pipeline_backfill.R to process tmax/tmin into COGs")
