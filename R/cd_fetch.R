#' Download ERA5-Land climate data
#'
#' Downloads ERA5-Land data from the Copernicus Climate Data Store (CDS)
#' for a specified bounding box, time period, and set of variables.
#' Uses two CDS products: monthly means for most variables, and daily
#' statistics for tmax/tmin (which are not available as monthly means).
#'
#' @param years Integer vector of years to download.
#' @param months Integer vector of months (1-12). Default `1:12`.
#' @param variables Character vector of cd variable names to fetch raw
#'   inputs for. Default fetches inputs needed for all 7 variables.
#' @param bbox Numeric vector `c(north, west, south, east)` in degrees.
#'   Default covers British Columbia.
#' @param output_dir Character path to write downloaded files.
#' @param source Character. Data source identifier. Currently only
#'   `"era5_land"` is supported.
#' @param force Logical. Re-download even if files exist. Default `FALSE`.
#'
#' @return Character vector of downloaded file paths (GRIBs extracted
#'   from zip archives).
#'
#' @examples
#' \dontrun{
#' # Download January 2024 for BC
#' cd_fetch(years = 2024, months = 1, output_dir = "data/raw")
#'
#' # Download full year for custom bbox
#' cd_fetch(years = 2023, bbox = c(55, -128, 53, -124), output_dir = "data/raw")
#' }
#'
#' @export
cd_fetch <- function(years,
                     months = 1:12,
                     variables = cd_variables()$variable,
                     bbox = c(60, -140, 48, -114),
                     output_dir,
                     source = "era5_land",
                     force = FALSE) {
  rlang::check_installed("ecmwfr",
    reason = "to download ERA5-Land data from the CDS API"
  )

  source <- match.arg(source, "era5_land")
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

  # Determine which raw CDS variables we need
  monthly_vars <- c()
  need_daily <- FALSE

  if (any(c("tmean", "vpd", "rh") %in% variables)) {
    monthly_vars <- c(monthly_vars, "2m_temperature")
  }
  if (any(c("vpd", "rh") %in% variables)) {
    monthly_vars <- c(monthly_vars, "2m_dewpoint_temperature")
  }
  if ("prcp" %in% variables) {
    monthly_vars <- c(monthly_vars, "total_precipitation")
  }
  if ("soil_moisture" %in% variables) {
    monthly_vars <- c(monthly_vars, paste0("volumetric_soil_water_layer_", 1:4))
  }
  if (any(c("tmax", "tmin") %in% variables)) {
    need_daily <- TRUE
  }

  monthly_vars <- unique(monthly_vars)
  downloaded <- character()

  # Download monthly means
  if (length(monthly_vars) > 0) {
    for (yr in years) {
      out_file <- file.path(output_dir, paste0("era5land_monthly_", yr, ".grib"))
      if (file.exists(out_file) && !force) {
        message("  Skipping ", basename(out_file), " (exists)")
        downloaded <- c(downloaded, out_file)
        next
      }
      message("Fetching monthly means for ", yr, "...")
      result <- cd_fetch_cds(
        dataset = "reanalysis-era5-land-monthly-means",
        product_type = "monthly_averaged_reanalysis",
        variable = monthly_vars,
        year = as.character(yr),
        month = sprintf("%02d", months),
        time = "00:00",
        area = bbox,
        output_dir = output_dir,
        target = basename(out_file)
      )
      downloaded <- c(downloaded, result)
    }
  }

  # Download daily statistics for tmax/tmin
  if (need_daily) {
    for (yr in years) {
      for (stat in c("daily_maximum", "daily_minimum")) {
        short <- if (stat == "daily_maximum") "tmax" else "tmin"
        out_file <- file.path(output_dir, paste0("era5land_", short, "_", yr, ".grib"))
        if (file.exists(out_file) && !force) {
          message("  Skipping ", basename(out_file), " (exists)")
          downloaded <- c(downloaded, out_file)
          next
        }
        message("Fetching ", short, " for ", yr, "...")
        result <- cd_fetch_cds(
          dataset = "derived-era5-land-daily-statistics",
          product_type = NULL,
          variable = "2m_temperature",
          year = as.character(yr),
          month = sprintf("%02d", months),
          time = NULL,
          area = bbox,
          output_dir = output_dir,
          target = basename(out_file),
          daily_statistic = stat,
          frequency = "1_hourly"
        )
        downloaded <- c(downloaded, result)
      }
    }
  }

  downloaded
}

#' Submit a CDS API request and extract the GRIB
#' @noRd
cd_fetch_cds <- function(dataset, product_type, variable, year, month,
                         time, area, output_dir, target, ...) {
  request <- list(
    variable = variable,
    year = year,
    month = month,
    area = area,
    format = "grib",
    dataset_short_name = dataset,
    target = target
  )

  if (!is.null(product_type)) request$product_type <- product_type
  if (!is.null(time)) request$time <- time

  # Add extra params (daily_statistic, frequency, etc.)
  dots <- list(...)
  for (nm in names(dots)) {
    request[[nm]] <- dots[[nm]]
  }

  result <- ecmwfr::wf_request(
    request = request,
    path = output_dir
  )

  # ecmwfr renames .grib to .zip — extract the actual GRIB
  if (grepl("\\.zip$", result)) {
    grib_dir <- tempfile("cd_grib_", tmpdir = output_dir)
    dir.create(grib_dir, showWarnings = FALSE)
    utils::unzip(result, exdir = grib_dir)
    grib_files <- list.files(grib_dir, pattern = "\\.grib$", full.names = TRUE)

    if (length(grib_files) == 0) {
      unlink(grib_dir, recursive = TRUE)
      rlang::abort(paste("No GRIB files found in CDS download:", basename(result)))
    }
    if (length(grib_files) > 1) {
      warning(length(grib_files), " GRIB files in zip, using first", call. = FALSE)
    }

    out_path <- file.path(output_dir, sub("\\.zip$", ".grib", basename(result)))
    file.rename(grib_files[1], out_path)
    unlink(result)
    unlink(grib_dir, recursive = TRUE)
    result <- out_path
  }

  message("  Saved: ", basename(result))
  result
}
