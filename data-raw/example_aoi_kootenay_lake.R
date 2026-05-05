# Bundle the Kootenay Lake region AOI for the kootenay-lake vignette.
#
# Union of four contiguous BC FWA watershed groups in the southern
# Kootenays:
#   KOTL  Kootenay Lake          (anchor)
#   LARL  Lower Arrow Lake       (W; covers Trail / Rossland / Red Mtn)
#   DUNC  Duncan Lake            (N; drains north Kootenay Lake)
#   SLOC  Slocan River           (NW; Selkirks / Monashees)
#
# Total ~24,200 km^2. The union polygon is the AOI; the per-WSG
# polygons are written separately to context_kootenay_lake.gpkg for
# per-WSG analysis and labelling in the vignette.
#
# Run interactively. bcdata is not a package dependency; install with
#   pak::pak("bcgov/bcdata")
# if not already available.
#
# Output:
#   inst/extdata/example_aoi_kootenay_lake.gpkg

library(bcdata)
library(sf)
library(dplyr)

wsg_codes <- c("KOTL", "LARL", "DUNC", "SLOC")

wsgs <- bcdc_query_geodata("WHSE_BASEMAPPING.FWA_WATERSHED_GROUPS_POLY") |>
  bcdata::filter(WATERSHED_GROUP_CODE %in% wsg_codes) |>
  collect()

stopifnot(nrow(wsgs) == length(wsg_codes))
cat("Pulled WSGs:", paste(wsgs$WATERSHED_GROUP_CODE, collapse = ", "), "\n")

# Union into the single AOI polygon. Preserve geometry only — no
# per-WSG attribution after union (the per-WSG features go into
# context_kootenay_lake.gpkg).
aoi_3005 <- st_union(wsgs)
aoi <- st_transform(st_sf(region = "Kootenay Lake region", geometry = aoi_3005),
                    4326)

st_write(aoi, "inst/extdata/example_aoi_kootenay_lake.gpkg",
         delete_dsn = TRUE, quiet = TRUE)

cat("Wrote: inst/extdata/example_aoi_kootenay_lake.gpkg\n")
cat("Bbox:", paste(round(st_bbox(aoi), 4), collapse = ", "), "\n")
cat("CRS:", st_crs(aoi)$Name, "\n")
cat("Area (km^2):",
    round(as.numeric(sum(st_area(st_transform(aoi, 3005)))) / 1e6), "\n")
