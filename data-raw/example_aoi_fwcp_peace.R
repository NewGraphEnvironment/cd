# Bundle FWCP Peace region polygon for vignette example
#
# Source: ~/Projects/gis/sern_peace_fwcp_2023/fwcp_peace_region.geojson
# Single multi-polygon, EPSG:3005 (BC Albers). Reprojected to WGS84 for
# consistency with ERA5-Land data and matching the KOTL example.
#
# Output:
#   inst/extdata/example_aoi_fwcp_peace.gpkg

library(sf)

src <- "~/Projects/gis/sern_peace_fwcp_2023/fwcp_peace_region.geojson"

aoi <- st_read(src, quiet = TRUE)
aoi <- st_transform(aoi, 4326)

# Keep only geometry + a label column
aoi$region <- "FWCP Peace"
aoi <- aoi[, "region"]

st_write(aoi, "inst/extdata/example_aoi_fwcp_peace.gpkg",
         delete_dsn = TRUE, quiet = TRUE)

cat("Wrote: inst/extdata/example_aoi_fwcp_peace.gpkg\n")
cat("Bbox:", paste(round(st_bbox(aoi), 4), collapse = ", "), "\n")
cat("CRS:", st_crs(aoi)$Name, "\n")
cat("Area (km^2):", round(as.numeric(sum(st_area(st_transform(aoi, 3005)))) / 1e6), "\n")
