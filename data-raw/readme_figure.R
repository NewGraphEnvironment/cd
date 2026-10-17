# Build the README figure and the output its example shows (#142)
#
# Generates:
#   man/figures/readme-kotl-tmean.png  (annual mean air temperature departure
#                                       for the Kootenay Lake watershed group,
#                                       with its trend)
# and prints the cd_summary() table pasted under the README example.
#
# The code between the two `README example` markers is the README's example,
# so the figure and the pasted output come from the same run. Run from the
# package root when the catalog gains a year.
#
# Prerequisites: network access to the live catalog.

Sys.setenv(
  GDAL_HTTP_MAX_RETRY = "3",
  GDAL_HTTP_RETRY_DELAY = "2"
)

# The checkout's cd, not an installed one (#135).
pkgload::load_all(export_all = FALSE, quiet = TRUE)

# --- README example ---------------------------------------------------------
catalog <- cd_catalog()
aoi <- sf::st_read(
  system.file("extdata", "example_aoi_kotl.gpkg", package = "cd"),
  quiet = TRUE
)

ts <- cd_extract(catalog, aoi, variables = "tmean", periods = "annual")
bl <- cd_baseline(ts, baseline_years = 1951:1980)
ano <- cd_anomaly(ts, bl)
trn <- cd_trend(ano, trend_start = 1951)

cd_summary(trn)
# --- end README example -----------------------------------------------------

print(cd_summary(trn))

p <- cd_plot_timeseries(ano, trend = trn) +
  ggplot2::theme_minimal(base_size = 15) +
  ggplot2::theme(legend.position = "none")

out <- "man/figures/readme-kotl-tmean.png"
# png() gives an opaque white background, which survives a dark web page.
grDevices::png(out, width = 7, height = 3.5, units = "in", res = 150,
               bg = "white")
print(p)
grDevices::dev.off()
message("Wrote ", out)
