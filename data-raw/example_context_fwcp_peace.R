# Fetch spatial context layers for FWCP Peace vignette from fwapg
#
# Same recipe as example_context_kotl.R but tuned for the much larger
# Peace region: bigger lake threshold, higher minimum stream order to
# keep map density reasonable, town list relevant to the Peace.
#
# Output:
#   inst/extdata/context_fwcp_peace.gpkg (multi-layer: towns, lakes, streams, highways)
#
# Prerequisites:
#   - docker container fresh-db running
#   - PG_* env vars set
#   - R packages: fresh, sf, DBI

library(fresh)
library(sf)

conn <- frs_db_conn()
aoi <- st_read("inst/extdata/example_aoi_fwcp_peace.gpkg", quiet = TRUE)
aoi_3005 <- st_transform(aoi, 3005)

# Widen the query envelope ~30 km to catch towns / features just outside
# the AOI (e.g. Prince George at the south edge) for orientation.
bb <- st_bbox(aoi_3005)
buffer_m <- 30000
env <- sprintf(
  "ST_MakeEnvelope(%s, %s, %s, %s, 3005)",
  bb["xmin"] - buffer_m, bb["ymin"] - buffer_m,
  bb["xmax"] + buffer_m, bb["ymax"] + buffer_m
)
out_path <- "inst/extdata/context_fwcp_peace.gpkg"

# -- Towns --------------------------------------------------------------------
town_names <- c("Prince George", "Mackenzie", "Hudson's Hope", "Fort Ware")
town_list_sql <- paste0("'", gsub("'", "''", town_names), "'", collapse = ", ")

towns <- frs_db_query(conn, sprintf("
  SELECT geographical_name AS name, feature_type, geom
  FROM whse_basemapping.gns_geographical_names_sp
  WHERE feature_type IN ('City', 'Town', 'Village', 'Locality',
                         'Community', 'Unincorporated Community',
                         'District Municipality (1)')
  AND geographical_name IN (%s)
", town_list_sql))
towns <- towns[!duplicated(towns$name), ]
towns <- st_transform(towns, 4326)
cat("Towns found:", paste(towns$name, collapse = ", "), "\n")
missing <- setdiff(town_names, towns$name)
if (length(missing)) cat("Towns missing from gns:", paste(missing, collapse = ", "), "\n")

# -- Lakes (> 1000 ha — Williston dominates; smaller lakes clutter) -----------
lakes <- frs_db_query(conn, sprintf("
  SELECT gnis_name_1 AS name, area_ha, geom
  FROM whse_basemapping.fwa_lakes_poly
  WHERE area_ha > 1000
  AND ST_Intersects(geom, %s)
", env))
lakes <- st_transform(lakes, 4326)
cat("Lakes >1000 ha:", nrow(lakes), "\n")

# -- Rivers (named river polygons clipped to AOI) -----------------------------
aoi_wkt <- sf::st_as_text(sf::st_geometry(sf::st_union(aoi_3005)))
aoi_geom_sql <- sprintf("ST_GeomFromText('%s', 3005)", aoi_wkt)
rivers <- frs_db_query(conn, sprintf("
  SELECT gnis_name_1 AS name,
         ST_Intersection(geom, %s) AS geom
  FROM whse_basemapping.fwa_rivers_poly
  WHERE gnis_name_1 IS NOT NULL
  AND ST_Intersects(geom, %s)
", aoi_geom_sql, aoi_geom_sql))
rivers <- st_zm(rivers, drop = TRUE, what = "ZM")
rivers <- st_transform(rivers, 4326)
cat("Named river polygons inside AOI:", nrow(rivers), "\n")

# -- Streams (order >= 7, clipped to AOI — keeps file size manageable) --------
streams <- frs_db_query(conn, sprintf("
  SELECT gnis_name AS name, stream_order,
         ST_Intersection(geom, %s) AS geom
  FROM whse_basemapping.fwa_stream_networks_sp
  WHERE stream_order >= 7
  AND ST_Intersects(geom, %s)
", aoi_geom_sql, aoi_geom_sql))
streams <- st_zm(streams, drop = TRUE, what = "ZM")
streams <- st_transform(streams, 4326)
cat("Stream segments (order >= 7) inside AOI:", nrow(streams), "\n")

# -- Highways ------------------------------------------------------------------
highways <- frs_db_query(conn, sprintf("
  SELECT transport_line_type_code AS road_type, geom
  FROM whse_basemapping.transport_line
  WHERE transport_line_type_code IN ('RH1', 'RH2')
  AND ST_Intersects(geom, %s)
", env))
highways <- st_zm(highways, drop = TRUE, what = "ZM")
highways <- st_transform(highways, 4326)
cat("Highway segments:", nrow(highways), "\n")

# -- Watershed groups intersecting the AOI ------------------------------------
# Full WSG extent (not clipped to AOI) — some will spill outside the FWCP
# admin boundary, which honestly shows that the boundary is administrative
# rather than hydrological. Filter out WSGs that only edge-touch the AOI
# (intersection area < 50 km^2).
wsgs <- frs_db_query(conn, sprintf("
  SELECT watershed_group_code AS code,
         watershed_group_name AS name,
         geom
  FROM whse_basemapping.fwa_watershed_groups_poly
  WHERE ST_Area(ST_Intersection(geom, %s)) > 50000000
", aoi_geom_sql))
wsgs <- st_zm(wsgs, drop = TRUE, what = "ZM")
wsgs <- st_transform(wsgs, 4326)
cat("Watershed groups intersecting AOI (>50 km^2):", nrow(wsgs), "\n")
cat("  ", paste(wsgs$code, collapse = ", "), "\n")

DBI::dbDisconnect(conn)

# -- Ecoregions (BCDC) clipped to AOI -----------------------------------------
# Pulled via bcdata since ecoregion polygons are not in the local fwapg db.
# Drop slivers <50 km^2 to keep the map readable.
suppressPackageStartupMessages(library(bcdata))
ecoregions_bc <- bcdc_query_geodata("d00389e0-66da-4895-bd56-39a0dd64aa78") |>
  bcdata::filter(bcdata::INTERSECTS(aoi_3005)) |>
  collect()
ecoregions <- suppressWarnings(st_intersection(
  st_transform(ecoregions_bc, 3005), aoi_3005
))
ecoregions$area_km2 <- as.numeric(st_area(ecoregions)) / 1e6
ecoregions <- ecoregions[ecoregions$area_km2 > 50, ]
ecoregions <- ecoregions[, c("ECOREGION_CODE", "ECOREGION_NAME", "area_km2")]
names(ecoregions)[1:2] <- c("code", "name")
ecoregions <- st_transform(ecoregions, 4326)
cat("Ecoregions inside AOI:", nrow(ecoregions), "\n")
cat("  ", paste(ecoregions$code, collapse = ", "), "\n")

# -- Simplify geometries -------------------------------------------------------
# Regional scale (~73,000 km^2) doesn't need meter-level precision.
# 200 m tolerance keeps shape recognizable on a province-scale map and
# cuts vertex counts by ~10x. Apply in BC Albers (units = m), then back
# to WGS84 for shipping.
simplify_m <- 200
simplify_layer <- function(x) {
  st_transform(
    sf::st_simplify(st_transform(x, 3005), dTolerance = simplify_m,
                    preserveTopology = TRUE),
    4326
  )
}
lakes      <- simplify_layer(lakes)
rivers     <- simplify_layer(rivers)
streams    <- simplify_layer(streams)
highways   <- simplify_layer(highways)
wsgs       <- simplify_layer(wsgs)
ecoregions <- simplify_layer(ecoregions)

# -- Write multi-layer gpkg ---------------------------------------------------
if (file.exists(out_path)) file.remove(out_path)
st_write(towns,    out_path, layer = "towns",    quiet = TRUE)
st_write(lakes,    out_path, layer = "lakes",    quiet = TRUE, append = TRUE)
st_write(rivers,   out_path, layer = "rivers",   quiet = TRUE, append = TRUE)
st_write(streams,  out_path, layer = "streams",  quiet = TRUE, append = TRUE)
st_write(highways, out_path, layer = "highways", quiet = TRUE, append = TRUE)
st_write(wsgs,       out_path, layer = "wsgs",       quiet = TRUE, append = TRUE)
st_write(ecoregions, out_path, layer = "ecoregions", quiet = TRUE, append = TRUE)

cat("\nWrote:", out_path, "\n")
cat("Layers:", paste(st_layers(out_path)$name, collapse = ", "), "\n")
cat("Size:", round(file.size(out_path) / 1e6, 1), "MB\n")
