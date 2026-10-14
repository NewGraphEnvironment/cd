# Bundle the areas of interest for vignettes/northern-bc.Rmd (#137)
#
# Three FWA watershed groups, one per major river system, plus the Bulkley
# split at Houston into its upper (Neexdzii Kwa) and lower halves:
#
#   BULK        Bulkley River       Skeena            -> Pacific
#   NECR        Nechako River       Fraser            -> Pacific
#   PARS        Parsnip River       Peace -> Mackenzie -> Arctic (Beaufort Sea)
#   BULK_UPPER  Upper Bulkley (Neexdzii Kwa): the Bulkley above the Morice
#               confluence at Houston
#   BULK_LOWER  Lower Bulkley: BULK minus the upper Bulkley, Houston to the
#               Skeena at Hazelton
#
# The Morice is its own watershed group (MORR), so the watershed upstream of
# the Bulkley just above the Morice mouth lies wholly inside BULK.
#
# Output:
#   inst/extdata/example_aoi_northern_bc.gpkg (layer "aoi", EPSG:4326)
#
# Prerequisites:
#   - docker container fresh-db running, PG_* env vars set
#   - R packages: fresh, sf, DBI

library(fresh)
library(sf)

conn <- frs_db_conn()
q <- function(sql) DBI::dbGetQuery(conn, sql)

blk_bulkley <- 360873822  # Bulkley River main stem
blk_morice  <- 360885316  # Morice River main stem

# -- Watershed groups ---------------------------------------------------------
wsgs <- frs_db_query(conn, "
  SELECT watershed_group_code AS code, watershed_group_name AS name, geom
  FROM whse_basemapping.fwa_watershed_groups_poly
  WHERE watershed_group_code IN ('BULK', 'NECR', 'PARS')
  ORDER BY watershed_group_code
")
wsgs <- st_zm(wsgs, drop = TRUE, what = "ZM")

# -- Upper Bulkley ------------------------------------------------------------
# The Morice main stem's downstream end lies on the Bulkley centreline, and
# FWA breaks the Bulkley into segments at the confluence. Locate that point on
# the Bulkley as a route measure, then take the watershed 100 m upstream of it
# so the Morice is excluded.
confluence <- q(sprintf("
  WITH mouth AS (
    SELECT ST_StartPoint(ST_GeometryN(geom, 1)) AS pt
    FROM whse_basemapping.fwa_stream_networks_sp
    WHERE blue_line_key = %s AND downstream_route_measure = 0
  )
  SELECT s.downstream_route_measure +
           ST_LineLocatePoint(ST_LineMerge(s.geom), mouth.pt) *
           (s.upstream_route_measure - s.downstream_route_measure) AS measure,
         ST_Distance(s.geom, mouth.pt) AS dist_m
  FROM whse_basemapping.fwa_stream_networks_sp s, mouth
  WHERE s.blue_line_key = %s
  ORDER BY ST_Distance(s.geom, mouth.pt)
  LIMIT 1
", blk_morice, blk_bulkley))
stopifnot(nrow(confluence) == 1, confluence$dist_m < 1)
cat("Morice confluence on the Bulkley: measure", round(confluence$measure), "m\n")

upper <- frs_watershed_at_measure(conn, blk_bulkley, confluence$measure + 100)
upper <- st_zm(st_union(upper), drop = TRUE, what = "ZM")

# The Morice main stem must fall outside the upper Bulkley.
morice <- frs_db_query(conn, sprintf("
  SELECT ST_Union(geom) AS geom FROM whse_basemapping.fwa_stream_networks_sp
  WHERE blue_line_key = %s AND downstream_route_measure > 1000
", blk_morice))
stopifnot(!any(st_intersects(st_zm(morice, drop = TRUE, what = "ZM"), upper,
                             sparse = FALSE)))
DBI::dbDisconnect(conn)

bulk <- st_geometry(wsgs[wsgs$code == "BULK", ])
# The upper Bulkley should already lie inside BULK: clipping it to BULK may
# trim boundary slivers, never a real piece of watershed.
area_unclipped <- as.numeric(st_area(upper))
upper <- st_intersection(upper, bulk)
stopifnot(abs(as.numeric(sum(st_area(upper))) / area_unclipped - 1) < 0.005)
lower <- st_difference(bulk, upper)
# An overlay can return a GEOMETRYCOLLECTION where the pieces touch along a
# line, which QGIS will not draw; keep only the polygons when it does.
polygons_only <- function(x) {
  if (any(st_is(x, "GEOMETRYCOLLECTION"))) st_collection_extract(x, "POLYGON") else x
}
upper <- polygons_only(upper)
lower <- polygons_only(lower)

parts <- st_sf(
  code = c("BULK_UPPER", "BULK_LOWER"),
  name = c("Upper Bulkley (Neexdzii Kwa)", "Lower Bulkley"),
  geom = c(st_union(upper), st_union(lower))
)

# -- Assemble -----------------------------------------------------------------
aoi <- rbind(wsgs[, c("code", "name")], parts)
aoi$river_system <- c(BULK = "Skeena", NECR = "Fraser", PARS = "Peace",
                      BULK_UPPER = "Skeena", BULK_LOWER = "Skeena")[aoi$code]
aoi$drains_to <- ifelse(aoi$code == "PARS", "Arctic", "Pacific")
aoi$role <- ifelse(startsWith(aoi$code, "BULK_"), "bulkley_part",
                   "watershed_group")

# Area before simplifying (BC Albers, units m).
aoi$area_km2 <- round(as.numeric(st_area(aoi)) / 1e6, 1)
area <- setNames(aoi$area_km2, aoi$code)
print(sf::st_drop_geometry(aoi))

# Areas from #137's table.
expected <- c(BULK = 7762, NECR = 4148, PARS = 5597)
stopifnot(all(abs(area[names(expected)] / expected - 1) < 0.01))

# A 50 m tolerance is nothing against the ~9 km ERA5-Land grid and cuts the
# vertex count several-fold.
aoi <- st_simplify(aoi, dTolerance = 50, preserveTopology = TRUE)
aoi <- st_transform(aoi, 4326)
aoi <- aoi[, c("code", "name", "river_system", "drains_to", "role", "area_km2")]

out <- "inst/extdata/example_aoi_northern_bc.gpkg"
st_write(aoi, out, layer = "aoi", delete_dsn = TRUE, quiet = TRUE)

cat("\nWrote:", out, "(", round(file.size(out) / 1024), "KB )\n")
cat("Bbox:", paste(round(st_bbox(aoi), 4), collapse = ", "), "\n")
