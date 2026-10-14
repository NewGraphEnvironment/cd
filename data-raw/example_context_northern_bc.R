# Fetch map context for vignettes/northern-bc.Rmd (#137)
#
# Same recipe as example_context_fwcp_peace.R, at the scale of three
# watershed groups across northern BC: the main stems of the six rivers the
# vignette names, the large lakes (Williston dominates), the towns used for
# orientation, and a BC outline for the keymap.
#
# Output:
#   inst/extdata/context_northern_bc.gpkg (layers: towns, rivers, lakes, bc)
#
# Prerequisites:
#   - docker container fresh-db running, PG_* env vars set
#   - network access to the BC WFS (towns, via bcdata)
#   - R packages: fresh, sf, DBI, bcdata
#
# The gns place-names table is not in fwapg, so towns come from the BC
# Geographical Names WFS.

library(fresh)
library(sf)
suppressPackageStartupMessages(library(bcdata))

conn <- frs_db_conn()

# Map window: the three watershed groups padded so the Peace below Williston
# (Hudson's Hope) and Prince George fall inside.
env <- "ST_Transform(ST_MakeEnvelope(-128.6, 53.2, -120.6, 56.4, 4326), 3005)"
env_sf <- st_as_sfc(st_bbox(c(xmin = -128.6, ymin = 53.2, xmax = -120.6,
                              ymax = 56.4), crs = 4326))
out_path <- "inst/extdata/context_northern_bc.gpkg"

# -- Rivers: named main stems, clipped to the window --------------------------
river_names <- c("Skeena River", "Bulkley River", "Fraser River",
                 "Nechako River", "Peace River", "Parsnip River")
river_sql <- paste0("'", river_names, "'", collapse = ", ")
rivers <- frs_db_query(conn, sprintf("
  SELECT gnis_name AS name,
         ST_Intersection(ST_LineMerge(ST_Union(geom)), %s) AS geom
  FROM whse_basemapping.fwa_stream_networks_sp
  WHERE gnis_name IN (%s)
  AND blue_line_key = watershed_key
  AND ST_Intersects(geom, %s)
  GROUP BY gnis_name
", env, river_sql, env))
rivers <- st_zm(rivers, drop = TRUE, what = "ZM")
stopifnot(setequal(rivers$name, river_names))

# -- Lakes over 10,000 ha -----------------------------------------------------
lakes <- frs_db_query(conn, sprintf("
  SELECT gnis_name_1 AS name, ST_Union(geom) AS geom
  FROM whse_basemapping.fwa_lakes_poly
  WHERE area_ha > 10000
  AND ST_Intersects(geom, %s)
  GROUP BY gnis_name_1
", env))
lakes <- st_zm(lakes, drop = TRUE, what = "ZM")
stopifnot("Williston Lake" %in% lakes$name)

# -- BC outline for the keymap ------------------------------------------------
# The union of all watershed groups is BC's land area to within half a
# percent and needs no second source.
bc <- frs_db_query(conn, "
  SELECT ST_Union(ST_SimplifyPreserveTopology(geom, 2000)) AS geom
  FROM whse_basemapping.fwa_watershed_groups_poly
")
DBI::dbDisconnect(conn)

# -- Towns --------------------------------------------------------------------
town_names <- c("Smithers", "Houston", "Hazelton", "Vanderhoof",
                "Prince George", "Mackenzie")
towns <- bcdc_query_geodata("WHSE_BASEMAPPING.GNS_GEOGRAPHICAL_NAMES_SP") |>
  bcdata::filter(GEOGRAPHICAL_NAME %in% town_names) |>
  collect()
towns <- towns[!grepl("Indian Reserve|Regional District", towns$FEATURE_TYPE), ]
towns <- towns[!duplicated(towns$GEOGRAPHICAL_NAME), ]
towns <- st_sf(name = towns$GEOGRAPHICAL_NAME, geom = st_geometry(towns))
stopifnot(setequal(towns$name, town_names))

# -- Simplify (in BC Albers) and write ----------------------------------------
simplify_layer <- function(x, m) {
  st_transform(st_simplify(st_transform(x, 3005), dTolerance = m,
                           preserveTopology = TRUE), 4326)
}
rivers <- simplify_layer(rivers, 200)
lakes  <- simplify_layer(lakes, 200)
towns  <- st_transform(towns, 4326)

# The keymap is about an inch wide: drop islands under 500 km^2 and keep
# 5 km detail.
# Simplifying each group before the union leaves slivers along shared edges;
# a 2 km buffer out and back in closes them.
bc <- st_buffer(st_buffer(st_transform(bc, 3005), 2000), -2000)
bc <- st_cast(bc, "POLYGON")
bc <- bc[as.numeric(st_area(bc)) > 500e6, ]
bc <- st_sf(name = "British Columbia",
            geom = st_union(st_simplify(bc, dTolerance = 5000,
                                        preserveTopology = TRUE)))
bc <- st_transform(bc, 4326)

if (file.exists(out_path)) file.remove(out_path)
st_write(towns,  out_path, layer = "towns",  quiet = TRUE)
st_write(rivers, out_path, layer = "rivers", quiet = TRUE, append = TRUE)
st_write(lakes,  out_path, layer = "lakes",  quiet = TRUE, append = TRUE)
st_write(bc,     out_path, layer = "bc",     quiet = TRUE, append = TRUE)

cat("\nWrote:", out_path, "\n")
cat("Layers:", paste(st_layers(out_path)$name, collapse = ", "), "\n")
cat("Rivers:", paste(rivers$name, collapse = ", "), "\n")
cat("Lakes:", paste(lakes$name, collapse = ", "), "\n")
cat("Size:", round(file.size(out_path) / 1024), "KB\n")
