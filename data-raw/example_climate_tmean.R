# Create example data for cd package tests and vignettes
#
# Crops real ERA5-Land NC data to a small anonymous bbox.
# Run interactively — requires bc_climate_anomaly repo at ../bc_climate_anomaly/
#
# Output:
#   inst/extdata/example_aoi.gpkg      — simple bbox polygon (no place names)
#   inst/extdata/example_climate.tif   — tmean annual, 10 years, COG format
#   inst/extdata/example_catalog.json  — minimal STAC catalog pointing to the COG

library(terra)
library(sf)
library(jsonlite)

# -- Source data ---------------------------------------------------------------
nc_path <- "../bc_climate_anomaly/ano_clm_trn_data/tmean_ano_annual_1950_+_res25.nc"
stopifnot(file.exists(nc_path))

# -- Create AOI (anonymous bbox) ----------------------------------------------
# Small area in northern BC — just coordinates, no place names
bbox <- c(xmin = -126.75, ymin = 54.1, xmax = -125.75, ymax = 54.7)
aoi <- st_as_sfc(st_bbox(bbox, crs = 4326))
aoi <- st_sf(geometry = aoi)

sf::st_write(aoi, "inst/extdata/example_aoi.gpkg", delete_dsn = TRUE, quiet = TRUE)
message("Wrote: inst/extdata/example_aoi.gpkg")

# -- Crop and subset raster ---------------------------------------------------
r <- rast(nc_path)

# Use first 10 years (bands 1-10) for manageable size
r_sub <- r[[1:10]]

# Crop to AOI
r_crop <- crop(r_sub, vect(aoi), snap = "out")

# Set band names to years
names(r_crop) <- 1951:1960

# Write as COG
writeRaster(
  r_crop,
  "inst/extdata/example_climate.tif",
  filetype = "COG",
  overwrite = TRUE,
  gdal = c("COMPRESS=DEFLATE")
)
message("Wrote: inst/extdata/example_climate.tif (",
        file.size("inst/extdata/example_climate.tif"), " bytes)")

# -- Create minimal STAC catalog ----------------------------------------------
catalog <- list(
  type = "Catalog",
  id = "cd-example",
  stac_version = "1.0.0",
  description = "Example climate data for cd package tests",
  links = list(
    list(rel = "root", href = "./example_catalog.json", type = "application/json"),
    list(rel = "item", href = "#tmean-annual", type = "application/json")
  ),
  items = list(
    list(
      type = "Feature",
      stac_version = "1.0.0",
      id = "tmean-annual",
      geometry = NULL,
      bbox = as.numeric(bbox),
      properties = list(
        `cd:variable` = "tmean",
        `cd:period` = "annual",
        datetime = NULL,
        start_datetime = "1951-01-01T00:00:00Z",
        end_datetime = "1960-12-31T23:59:59Z"
      ),
      links = list(),
      assets = list(
        data = list(
          href = "./example_climate.tif",
          type = "image/tiff; application=geotiff; profile=cloud-optimized",
          title = "Mean temperature annual values"
        )
      )
    )
  )
)

write_json(catalog, "inst/extdata/example_catalog.json", pretty = TRUE, auto_unbox = TRUE)
message("Wrote: inst/extdata/example_catalog.json")
message("Done.")
