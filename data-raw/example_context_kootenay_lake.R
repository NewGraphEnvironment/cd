# Fetch spatial context layers for the kootenay-lake vignette from fwapg.
#
# Same recipe as example_context_fwcp_peace.R but tuned for the smaller
# Kootenay Lake AOI (~24,200 km^2): lower lake threshold (200 ha) and
# stream order threshold (5) since the smaller map can support more
# detail. Town list focused on Kootenay places.
#
# Output:
#   inst/extdata/context_kootenay_lake.gpkg (multi-layer: towns, lakes,
#                                            rivers, streams, highways,
#                                            wsgs, ecoregions)
#
# Prerequisites:
#   - docker container fresh-db running
#   - PG_* env vars set
#   - R packages: fresh, sf, DBI

library(fresh)
library(sf)

conn <- frs_db_conn()
aoi <- st_read("inst/extdata/example_aoi_kootenay_lake.gpkg", quiet = TRUE)
aoi_3005 <- st_transform(aoi, 3005)

# Widen the query envelope ~20 km to catch towns / features just outside
# the AOI for orientation. Tighter than the Peace ~30 km because the AOI
# itself is smaller.
bb <- st_bbox(aoi_3005)
buffer_m <- 20000
env <- sprintf(
  "ST_MakeEnvelope(%s, %s, %s, %s, 3005)",
  bb["xmin"] - buffer_m, bb["ymin"] - buffer_m,
  bb["xmax"] + buffer_m, bb["ymax"] + buffer_m
)
out_path <- "inst/extdata/context_kootenay_lake.gpkg"

# -- Towns --------------------------------------------------------------------
town_names <- c(
  "Nelson", "Castlegar", "Trail", "Rossland", "Kaslo", "Nakusp",
  "Slocan", "New Denver", "Argenta", "Crawford Bay", "Kimberley", "Cranbrook"
)
town_list_sql <- paste0("'", gsub("'", "''", town_names), "'", collapse = ", ")

towns <- frs_db_query(conn, sprintf("
  SELECT geographical_name AS name, feature_type, geom
  FROM whse_basemapping.gns_geographical_names_sp
  WHERE feature_type IN ('City', 'Town', 'Village', 'Village (1)',
                         'Locality', 'Community', 'Unincorporated Community',
                         'District Municipality (1)')
  AND geographical_name IN (%s)
", town_list_sql))
towns <- towns[!duplicated(towns$name), ]
towns <- st_transform(towns, 4326)
cat("Towns found:", paste(towns$name, collapse = ", "), "\n")
missing <- setdiff(town_names, towns$name)
if (length(missing)) cat("Towns missing from gns:", paste(missing, collapse = ", "), "\n")

# -- Lakes (> 200 ha — Kootenay Lake itself plus Slocan, Duncan, Trout, Arrows) -
lakes <- frs_db_query(conn, sprintf("
  SELECT gnis_name_1 AS name, area_ha, geom
  FROM whse_basemapping.fwa_lakes_poly
  WHERE area_ha > 200
  AND ST_Intersects(geom, %s)
", env))
lakes <- st_transform(lakes, 4326)
cat("Lakes >200 ha:", nrow(lakes), "\n")

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

# -- Streams (order >= 5, clipped to AOI) ------------------------------------
# Lower threshold than Peace (5 vs 7) because the smaller AOI can support
# more detail without cluttering the maps.
streams <- frs_db_query(conn, sprintf("
  SELECT gnis_name AS name, stream_order,
         ST_Intersection(geom, %s) AS geom
  FROM whse_basemapping.fwa_stream_networks_sp
  WHERE stream_order >= 5
  AND ST_Intersects(geom, %s)
", aoi_geom_sql, aoi_geom_sql))
streams <- st_zm(streams, drop = TRUE, what = "ZM")
streams <- st_transform(streams, 4326)
cat("Stream segments (order >= 5) inside AOI:", nrow(streams), "\n")

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

# -- Watershed groups (the 4 that make up the AOI) ----------------------------
kootenay_lake_wsg_codes <- c("KOTL", "LARL", "DUNC", "SLOC")
wsg_codes_sql <- paste0("'", kootenay_lake_wsg_codes, "'", collapse = ", ")
wsgs <- frs_db_query(conn, sprintf("
  SELECT watershed_group_code AS code,
         watershed_group_name AS name,
         geom
  FROM whse_basemapping.fwa_watershed_groups_poly
  WHERE watershed_group_code IN (%s)
", wsg_codes_sql))
wsgs <- st_zm(wsgs, drop = TRUE, what = "ZM")
wsgs <- st_transform(wsgs, 4326)
cat("WSGs:", paste(wsgs$code, collapse = ", "), "\n")

DBI::dbDisconnect(conn)

# -- Ecoregions (BCDC) clipped to AOI -----------------------------------------
suppressPackageStartupMessages(library(bcdata))
ecoregions_bc <- bcdc_query_geodata("d00389e0-66da-4895-bd56-39a0dd64aa78") |>
  bcdata::filter(bcdata::INTERSECTS(aoi_3005)) |>
  collect()
ecoregions <- suppressWarnings(st_intersection(
  st_transform(ecoregions_bc, 3005), aoi_3005
))
ecoregions$area_km2 <- as.numeric(st_area(ecoregions)) / 1e6
# Smaller drop threshold than Peace (20 vs 50 km^2) — smaller AOI overall.
ecoregions <- ecoregions[ecoregions$area_km2 > 20, ]
ecoregions <- ecoregions[, c("ECOREGION_CODE", "ECOREGION_NAME", "area_km2")]
names(ecoregions)[1:2] <- c("code", "name")
ecoregions <- st_transform(ecoregions, 4326)
cat("Ecoregions inside AOI:", nrow(ecoregions), "\n")
cat("  ", paste(ecoregions$code, collapse = ", "), "\n")

# -- Simplify geometries -------------------------------------------------------
# Smaller AOI than Peace — tighter tolerance (50 m vs 200 m) preserves more
# shape on the regional map.
simplify_m <- 50
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
st_write(towns,      out_path, layer = "towns",      quiet = TRUE)
st_write(lakes,      out_path, layer = "lakes",      quiet = TRUE, append = TRUE)
st_write(rivers,     out_path, layer = "rivers",     quiet = TRUE, append = TRUE)
st_write(streams,    out_path, layer = "streams",    quiet = TRUE, append = TRUE)
st_write(highways,   out_path, layer = "highways",   quiet = TRUE, append = TRUE)
st_write(wsgs,       out_path, layer = "wsgs",       quiet = TRUE, append = TRUE)
st_write(ecoregions, out_path, layer = "ecoregions", quiet = TRUE, append = TRUE)

cat("\nWrote:", out_path, "\n")
cat("Layers:", paste(st_layers(out_path)$name, collapse = ", "), "\n")
cat("Size:", round(file.size(out_path) / 1e6, 1), "MB\n")
