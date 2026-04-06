#!/usr/bin/env Rscript
#
# pipeline_daily_stats_submit.R
#
# Pass 1 of 2: Submit all tmax/tmin daily statistics requests to CDS
# WITHOUT waiting for results. Saves job URLs to a file for retrieval
# by pipeline_daily_stats_retrieve.R.
#
# This avoids rate limiting from aggressive polling. CDS processes
# the jobs in the background — retrieve hours later.
#
# Usage:
#   Rscript scripts/pipeline_daily_stats_submit.R
#
# Output:
#   data/backfill/daily_stats_jobs.csv — job URLs for retrieval

library(ecmwfr)

# -- Configuration ------------------------------------------------------------
years <- 1950:2025
bbox <- c(60, -140, 48, -114)
output_dir <- "data/backfill/raw"
jobs_file <- "data/backfill/daily_stats_jobs.csv"

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# -- Check what's already downloaded -------------------------------------------
existing <- list.files(output_dir, pattern = "era5land_t(max|min)_\\d{4}\\.(nc|grib)$")
existing_keys <- sub("era5land_(tmax|tmin)_(\\d{4})\\..+$", "\\1_\\2", existing)

# -- Build request list --------------------------------------------------------
# Initialize or resume jobs file
if (file.exists(jobs_file)) {
  jobs <- read.csv(jobs_file, stringsAsFactors = FALSE)
  message("Resuming from existing jobs file: ", nrow(jobs), " jobs already submitted")
} else {
  jobs <- data.frame(
    variable = character(), year = integer(), stat = character(),
    target = character(), job_url = character(),
    stringsAsFactors = FALSE
  )
}

for (stat in c("daily_maximum", "daily_minimum")) {
  short <- if (stat == "daily_maximum") "tmax" else "tmin"

  for (yr in years) {
    key <- paste0(short, "_", yr)
    target <- paste0("era5land_", short, "_", yr, ".grib")

    # Skip if already downloaded or already submitted
    already_submitted <- paste0(jobs$variable, "_", jobs$year)
    if (key %in% existing_keys) {
      message("  Skipping ", target, " (downloaded)")
      next
    }
    if (key %in% already_submitted) {
      message("  Skipping ", target, " (already submitted)")
      next
    }

    request <- list(
      variable = "2m_temperature",
      year = as.character(yr),
      month = sprintf("%02d", 1:12),
      day = sprintf("%02d", 1:31),
      daily_statistic = stat,
      frequency = "1_hourly",
      time_zone = "utc+00:00",
      area = bbox,
      format = "grib",
      dataset_short_name = "derived-era5-land-daily-statistics",
      target = target
    )

    message("Submitting ", short, " ", yr, "...")
    result <- wf_request(request = request, path = output_dir, transfer = FALSE)

    # Extract job URL from the returned environment
    job_url <- result$get_url()

    new_row <- data.frame(
      variable = short, year = yr, stat = stat,
      target = target, job_url = job_url,
      stringsAsFactors = FALSE
    )
    jobs <- rbind(jobs, new_row)

    # Write incrementally so a crash doesn't lose submitted job URLs
    write.csv(jobs, jobs_file, row.names = FALSE)

    # Small delay between submissions to avoid flooding
    Sys.sleep(2)
  }
}

already_submitted <- paste0(jobs$variable, "_", jobs$year)

message("\nSubmitted ", nrow(jobs), " jobs")
message("Job URLs saved to: ", jobs_file)
message("\nWait a few hours, then run:")
message("  Rscript scripts/pipeline_daily_stats_retrieve.R")
