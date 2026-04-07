# Fetch Kootenay Lake (KOTL) FWA watershed group for vignette example
#
# Uses bcdata to query BC Data Catalogue. Run interactively — bcdata
# is not a package dependency, only needed to regenerate this file.
#
# Output:
#   inst/extdata/example_aoi_kotl.gpkg

library(bcdata)
library(sf)

# FWA Watershed Groups layer
aoi <- bcdc_query_geodata("51f20b1a-ab75-42de-809d-bf415a0f9c62") |>
  filter(WATERSHED_GROUP_CODE == "KOTL") |>
  collect()

# Transform to WGS84 for consistency with ERA5-Land data
aoi <- st_transform(aoi, 4326)

# Keep only geometry + the code (minimal, no unnecessary attributes)
aoi <- aoi[, "WATERSHED_GROUP_CODE"]

st_write(aoi, "inst/extdata/example_aoi_kotl.gpkg",
         delete_dsn = TRUE, quiet = TRUE)

cat("Wrote: inst/extdata/example_aoi_kotl.gpkg\n")
cat("Bbox:", paste(round(st_bbox(aoi), 2), collapse = ", "), "\n")
cat("CRS:", st_crs(aoi)$Name, "\n")
