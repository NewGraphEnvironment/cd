# Fetch spatial context layers for KOTL vignette from fwapg docker database
#
# Uses fresh::frs_db_conn() to query the local fwapg/bcfishpass database.
# Run interactively — requires the fresh-db docker container running.
#
# Output:
#   inst/extdata/context_kotl.gpkg (multi-layer: towns, lakes, streams, highways)
#
# Prerequisites:
#   - docker container fresh-db running (see fresh package)
#   - PG_* env vars set (PG_HOST_SHARE, etc.)
#   - R packages: fresh, sf, DBI

library(fresh)
library(sf)

conn <- frs_db_conn()
aoi <- st_read("inst/extdata/example_aoi_kotl.gpkg", quiet = TRUE)
aoi_3005 <- st_transform(aoi, 3005)
bb <- st_bbox(aoi_3005)
env <- sprintf(
  "ST_MakeEnvelope(%s, %s, %s, %s, 3005)",
  bb["xmin"], bb["ymin"], bb["xmax"], bb["ymax"]
)
out_path <- "inst/extdata/context_kotl.gpkg"

# -- Towns (from BC Geographical Names) ----------------------------------------
towns <- frs_db_query(conn, sprintf("
  SELECT geographical_name AS name, feature_type, geom
  FROM whse_basemapping.gns_geographical_names_sp
  WHERE feature_type IN ('City', 'Town', 'Village', 'Locality',
                         'Community', 'Unincorporated Community')
  AND ST_Intersects(geom, %s)
  AND geographical_name IN ('Nelson', 'Creston', 'Slocan', 'Castlegar')
", env))

# Castlegar/Slocan may be outside KOTL — widen search if needed
if (!("Castlegar" %in% towns$name)) {
  extra <- frs_db_query(conn, "
    SELECT geographical_name AS name, feature_type, geom
    FROM whse_basemapping.gns_geographical_names_sp
    WHERE geographical_name IN ('Castlegar', 'Slocan')
    AND feature_type IN ('City', 'Town', 'Village', 'Locality',
                         'Community', 'Unincorporated Community')
  ")
  towns <- rbind(towns, extra)
}
towns <- st_transform(towns, 4326)
cat("Towns:", paste(towns$name, collapse = ", "), "\n")

# -- Lakes (> 100 ha) ---------------------------------------------------------
lakes <- frs_db_query(conn, sprintf("
  SELECT gnis_name_1 AS name, area_ha, geom
  FROM whse_basemapping.fwa_lakes_poly
  WHERE area_ha > 100
  AND ST_Intersects(geom, %s)
", env))
lakes <- st_transform(lakes, 4326)
cat("Lakes >100 ha:", nrow(lakes), "\n")

# -- Rivers (polygon features — major rivers only) ----------------------------
rivers <- frs_db_query(conn, sprintf("
  SELECT gnis_name_1 AS name, geom
  FROM whse_basemapping.fwa_rivers_poly
  WHERE ST_Intersects(geom, %s)
", env))
rivers <- st_zm(rivers, drop = TRUE, what = "ZM")
rivers <- st_transform(rivers, 4326)
cat("River polygons:", nrow(rivers), "\n")

# -- Streams (order >= 5 for context lines) -----------------------------------
streams <- frs_db_query(conn, sprintf("
  SELECT gnis_name AS name, stream_order, geom
  FROM whse_basemapping.fwa_stream_networks_sp
  WHERE stream_order >= 5
  AND ST_Intersects(geom, %s)
", env))
streams <- st_zm(streams, drop = TRUE, what = "ZM")
streams <- st_collection_extract(st_intersection(streams, aoi_3005), "LINESTRING")
streams <- st_transform(streams, 4326)
cat("Stream segments (order >= 5):", nrow(streams), "\n")

# -- Highways ------------------------------------------------------------------
highways <- frs_db_query(conn, sprintf("
  SELECT transport_line_type_code AS road_type, geom
  FROM whse_basemapping.transport_line
  WHERE transport_line_type_code IN ('RH1', 'RH2')
  AND ST_Intersects(geom, %s)
", env))
highways <- st_zm(highways, drop = TRUE, what = "ZM")
highways <- st_collection_extract(st_intersection(highways, aoi_3005), "LINESTRING")
highways <- st_transform(highways, 4326)
cat("Highway segments:", nrow(highways), "\n")

DBI::dbDisconnect(conn)

# -- Write multi-layer gpkg ----------------------------------------------------
if (file.exists(out_path)) file.remove(out_path)
st_write(towns, out_path, layer = "towns", quiet = TRUE)
st_write(lakes, out_path, layer = "lakes", quiet = TRUE, append = TRUE)
st_write(rivers, out_path, layer = "rivers", quiet = TRUE, append = TRUE)
st_write(streams, out_path, layer = "streams", quiet = TRUE, append = TRUE)
st_write(highways, out_path, layer = "highways", quiet = TRUE, append = TRUE)

cat("\nWrote:", out_path, "\n")
cat("Layers:", paste(st_layers(out_path)$name, collapse = ", "), "\n")
cat("Size:", round(file.size(out_path) / 1e6, 1), "MB\n")
