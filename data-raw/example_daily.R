# Bundled example of the daily air-temperature cube (#116), for the
# cd_extract_daily() examples.
#
# One year (2002) of tmean/tmax/tmin, cropped to a 5 x 5-cell window inside
# the bundled example AOI (inst/extdata/example_aoi.gpkg, near Burns Lake).
# Small on purpose: inst/extdata already ships several MB.
#
# Reads the cube built by scripts/backfill_edh_daily.py in
# data/backfill/daily/ (run `uv run scripts/backfill_edh_daily.py --year 2002`
# first) and writes inst/extdata/example_daily/{var}_daily_2002.tif.
#
# Run locally only (CLAUDE.md, "CI considerations").

library(terra)

src_dir <- "data/backfill/daily"
out_dir <- "inst/extdata/example_daily"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# Cell edges fall on x.x5 (cell centres on the 0.1 deg lines).
win <- ext(-126.45, -125.95, 54.25, 54.75)

for (v in c("tmean", "tmax", "tmin")) {
  r <- rast(file.path(src_dir, paste0(v, "_daily_2002.tif")))
  x <- crop(r, win, snap = "near")
  stopifnot(nrow(x) == 5, ncol(x) == 5, nlyr(x) == 365,
            identical(names(x), names(r)))
  out <- file.path(out_dir, paste0(v, "_daily_2002.tif"))
  writeRaster(x, out, datatype = "FLT4S", overwrite = TRUE,
              gdal = c("COMPRESS=DEFLATE", "PREDICTOR=3"))
  message(out, ": ", round(file.size(out) / 1024), " KB")
}
