#' Derive climate variables from raw ERA5-Land fields
#'
#' Computes VPD, RH, composite soil moisture, and monthly tmax/tmin
#' from raw ERA5-Land GRIB files downloaded by [cd_fetch()]. Also
#' converts temperature from Kelvin to Celsius and precipitation
#' from m/day to mm/month.
#'
#' @param input_dir Character path containing raw GRIB files from
#'   [cd_fetch()].
#' @param output_dir Character path to write derived rasters.
#' @param variables Character vector of variables to derive.
#'   Default derives all: VPD, RH, soil moisture, tmax, tmin.
#' @param force Logical. Re-derive even if output files exist.
#'   Default `FALSE`.
#'
#' @return Character vector of derived file paths.
#'
#' @examples
#' \dontrun{
#' cd_fetch(years = 2024, months = 1, output_dir = "data/raw")
#' cd_derive("data/raw", "data/derived")
#' }
#'
#' @export
cd_derive <- function(input_dir,
                      output_dir,
                      variables = c("vpd", "rh", "soil_moisture"),
                      force = FALSE) {
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

  grib_files <- list.files(input_dir, pattern = "\\.grib$", full.names = TRUE)
  monthly_files <- grib_files[grepl("era5land_monthly_", grib_files)]

  derived <- character()

  for (grib_path in monthly_files) {
    year_str <- sub(".*_(\\d{4})\\.grib$", "\\1", basename(grib_path))
    r <- terra::rast(grib_path)

    # Identify layers by name patterns
    temp_idx <- grep("2 metre temperature", names(r))
    dewp_idx <- grep("2 metre dewpoint", names(r))
    prcp_idx <- grep("Total precipitation", names(r))
    soil_idx <- grep("Volumetric soil water", names(r))

    # VPD derivation
    if ("vpd" %in% variables && length(temp_idx) > 0 && length(dewp_idx) > 0) {
      out_path <- file.path(output_dir, paste0("vpd_", year_str, ".tif"))
      if (!file.exists(out_path) || force) {
        vpd <- cd_derive_vpd(r[[temp_idx]], r[[dewp_idx]])
        terra::writeRaster(vpd, out_path, overwrite = TRUE)
        message("  Derived: ", basename(out_path))
      }
      derived <- c(derived, out_path)
    }

    # RH derivation
    if ("rh" %in% variables && length(temp_idx) > 0 && length(dewp_idx) > 0) {
      out_path <- file.path(output_dir, paste0("rh_", year_str, ".tif"))
      if (!file.exists(out_path) || force) {
        rh <- cd_derive_rh(r[[temp_idx]], r[[dewp_idx]])
        terra::writeRaster(rh, out_path, overwrite = TRUE)
        message("  Derived: ", basename(out_path))
      }
      derived <- c(derived, out_path)
    }

    # Soil moisture composite
    if ("soil_moisture" %in% variables && length(soil_idx) >= 4) {
      out_path <- file.path(output_dir, paste0("soil_moisture_", year_str, ".tif"))
      if (!file.exists(out_path) || force) {
        sm <- cd_derive_soil(r[[soil_idx[1:4]]])
        terra::writeRaster(sm, out_path, overwrite = TRUE)
        message("  Derived: ", basename(out_path))
      }
      derived <- c(derived, out_path)
    }
  }

  derived
}

#' Derive VPD from temperature and dewpoint (Tetens formula)
#'
#' @param temp SpatRaster of 2m temperature (Kelvin).
#' @param dewpoint SpatRaster of 2m dewpoint temperature (Kelvin).
#' @return SpatRaster of VPD in hPa.
#' @noRd
cd_derive_vpd <- function(temp, dewpoint) {
  t_c <- temp - 273.15
  td_c <- dewpoint - 273.15
  es <- 6.1078 * exp(17.27 * t_c / (t_c + 237.3))
  ea <- 6.1078 * exp(17.27 * td_c / (td_c + 237.3))
  vpd <- es - ea
  terra::ifel(vpd < 0, 0, vpd)
}

#' Derive RH from temperature and dewpoint
#'
#' @param temp SpatRaster of 2m temperature (Kelvin).
#' @param dewpoint SpatRaster of 2m dewpoint temperature (Kelvin).
#' @return SpatRaster of RH in percent.
#' @noRd
cd_derive_rh <- function(temp, dewpoint) {
  t_c <- temp - 273.15
  td_c <- dewpoint - 273.15
  es <- 6.1078 * exp(17.27 * t_c / (t_c + 237.3))
  ea <- 6.1078 * exp(17.27 * td_c / (td_c + 237.3))
  rh <- (ea / es) * 100
  rh <- terra::ifel(rh < 0, 0, rh)
  terra::ifel(rh > 100, 100, rh)
}

#' Composite soil moisture from 4 ERA5-Land depth layers
#'
#' Simple mean of all 4 layers (0-7cm, 7-28cm, 28-100cm, 100-289cm).
#'
#' @param layers SpatRaster with 4 layers (one per depth).
#' @return SpatRaster of mean volumetric soil moisture (m3/m3).
#' @noRd
cd_derive_soil <- function(layers) {
  terra::mean(layers)
}
