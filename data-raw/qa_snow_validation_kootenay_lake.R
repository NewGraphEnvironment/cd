# QA cross-check: ERA5-Land swe_max vs BC ground-truth snow data
# for the Kootenay Lake region.
#
# Companion to data-raw/qa_snow_validation.R (which covered the FWCP
# Peace AOI). Same comparison shape, different sites — five active
# ASWS stations spanning the elevation gradient inside the
# Kootenay Lake AOI:
#
#   Redfish Creek (2D14P)       2100 m  Selkirks alpine
#   Moyie Mountain (2C10P)      1835 m  Purcells alpine, east shore
#   Gray Creek Lower (2D05P)    1650 m  east shore mid-elevation
#   Farron (2B02AP)             1230 m  Selkirks mid-elevation
#   New Denver East (2D16P)      653 m  Slocan valley bottom
#
# Filed against #56 Phase 5.
#
# Prerequisites:
#   - bcgov/bcsnowdata installed locally:
#       pak::pak("bcgov/bcsnowdata")
#     (also requires `reshape` as a transitive dep)
#   - cd package installed
#   - Network for ASWS data + S3 reads
#
# Usage:
#   Rscript data-raw/qa_snow_validation_kootenay_lake.R
#
# Output:
#   planning/active/qa_snow_validation_kootenay_lake_results.md
#   planning/active/qa_snow_validation_kootenay_lake_scatter.png

suppressMessages({
  library(bcsnowdata)
  library(sf)
  library(dplyr)
  library(ggplot2)
  library(terra)
  library(cd)
})

sites <- tibble::tribble(
  ~location_id, ~name,                ~elevation,
  "2D14P",      "Redfish Creek",      2100,
  "2C10P",      "Moyie Mountain",     1835,
  "2D05P",      "Gray Creek Lower",   1650,
  "2B02AP",     "Farron",             1230,
  "2D16P",      "New Denver East",     653
)

asws_loc <- snow_auto_location()
sites_geo <- merge(sites, asws_loc[, c("LOCATION_ID", "LATITUDE", "LONGITUDE")],
                   by.x = "location_id", by.y = "LOCATION_ID")

message("Pulling ASWS daily SWE for ", nrow(sites_geo), " sites...")
asws_data <- get_aswe_databc(
  station_id = sites_geo$location_id,
  get_year = "All",
  parameter = "swe",
  timestep = "daily"
)

asws_annual <- asws_data |>
  dplyr::mutate(
    year = as.integer(format(as.Date(date_utc), "%Y")),
    swe_mm = as.numeric(value)
  ) |>
  dplyr::filter(!is.na(swe_mm), swe_mm >= 0) |>
  dplyr::group_by(id, year) |>
  dplyr::summarise(asws_swe_max = max(swe_mm, na.rm = TRUE),
                   n_obs = dplyr::n(), .groups = "drop") |>
  dplyr::filter(n_obs >= 90)

message("ASWS site-years with peak SWE: ", nrow(asws_annual))

message("Fetching ERA5-Land swe_max from S3...")
catalog <- cd_catalog()
swe_row <- catalog[catalog$variable == "swe_max" & catalog$period == "annual", ]
r_swe <- terra::rast(paste0("/vsicurl/", swe_row$href))
years <- as.integer(names(r_swe))

site_pts <- sf::st_as_sf(sites_geo, coords = c("LONGITUDE", "LATITUDE"),
                         crs = 4326)
era5_at_sites <- terra::extract(r_swe, terra::vect(site_pts), ID = FALSE)
era5_long <- tibble::tibble(
  location_id = sites_geo$location_id,
  era5_at_sites
) |>
  tidyr::pivot_longer(-location_id, names_to = "year_str",
                      values_to = "era5_swe_max") |>
  dplyr::mutate(year = as.integer(year_str)) |>
  dplyr::select(location_id, year, era5_swe_max)

qa <- asws_annual |>
  dplyr::rename(location_id = id) |>
  dplyr::inner_join(era5_long, by = c("location_id", "year")) |>
  dplyr::left_join(sites[, c("location_id", "name", "elevation")],
                   by = "location_id")

message("Paired site-years: ", nrow(qa))
if (nrow(qa) == 0) stop("No paired ASWS / ERA5-Land observations.")

per_site <- qa |>
  dplyr::group_by(location_id, name, elevation) |>
  dplyr::summarise(
    n = dplyr::n(),
    yr_min = min(year), yr_max = max(year),
    asws_mean = round(mean(asws_swe_max), 1),
    era5_mean = round(mean(era5_swe_max), 1),
    bias_mm = round(mean(era5_swe_max - asws_swe_max), 1),
    bias_pct = round(100 * mean(era5_swe_max - asws_swe_max) /
                     mean(asws_swe_max), 1),
    cor = round(cor(era5_swe_max, asws_swe_max), 3),
    .groups = "drop"
  )

overall <- list(
  n_pairs = nrow(qa),
  cor_overall = round(cor(qa$era5_swe_max, qa$asws_swe_max), 3),
  mean_bias_mm = round(mean(qa$era5_swe_max - qa$asws_swe_max), 1),
  mean_bias_pct = round(100 * mean(qa$era5_swe_max - qa$asws_swe_max) /
                        mean(qa$asws_swe_max), 1)
)

bias_trends <- qa |>
  dplyr::mutate(diff = era5_swe_max - asws_swe_max) |>
  dplyr::group_by(location_id, name) |>
  dplyr::filter(dplyr::n() >= 8) |>
  dplyr::summarise(
    bias_slope = round(coef(lm(diff ~ year))[2], 2),
    bias_slope_p = round(summary(lm(diff ~ year))$coefficients[2, 4], 3),
    .groups = "drop"
  )

out_dir <- here::here("planning", "active")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
report_path <- file.path(out_dir, "qa_snow_validation_kootenay_lake_results.md")

md <- c(
  "# ASWS QA cross-check (Kootenay Lake AOI) — ERA5-Land swe_max vs station daily peak",
  "",
  paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  "",
  "Companion to the FWCP Peace QA from #48. Same questions:",
  "",
  "1. **Magnitude of the bias** at our 5 Kootenay-region sites?",
  "2. **Stability of the bias over time** — needed for the trend-",
  "   defensibility argument in vignettes/kootenay-lake.Rmd.",
  "",
  "## Per-site stats",
  ""
)
md <- c(md, knitr::kable(per_site, format = "pipe") |> paste(collapse = "\n"))
md <- c(md, "", "## Overall", "")
md <- c(md, sprintf("- Paired site-years: %d", overall$n_pairs))
md <- c(md, sprintf("- Correlation (ERA5 vs ASWS, all sites pooled): r = %.3f",
                    overall$cor_overall))
md <- c(md, sprintf("- Mean bias (ERA5 - ASWS): %.1f mm (%.1f%%)",
                    overall$mean_bias_mm, overall$mean_bias_pct))
md <- c(md, "", "## Bias-trend stability (per site)", "",
        "Regression of (ERA5 - ASWS) on year. A slope near zero with",
        "high p means the bias is stable — the trend-defensibility",
        "argument in the vignette holds.",
        "")
md <- c(md, knitr::kable(bias_trends, format = "pipe") |> paste(collapse = "\n"))

writeLines(md, report_path)
message("Wrote: ", report_path)

plot_path <- file.path(out_dir, "qa_snow_validation_kootenay_lake_scatter.png")
p <- ggplot(qa, aes(x = asws_swe_max, y = era5_swe_max, color = name)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "grey60") +
  geom_point(size = 1.5, alpha = 0.7) +
  geom_smooth(method = "lm", se = FALSE, linewidth = 0.6) +
  labs(
    title = "ERA5-Land swe_max vs ASWS daily peak SWE (Kootenay Lake AOI)",
    subtitle = sprintf("%d site-years; pooled r = %.2f, mean bias = %+.0f mm (%+.0f%%)",
                       overall$n_pairs, overall$cor_overall,
                       overall$mean_bias_mm, overall$mean_bias_pct),
    x = "ASWS station annual peak SWE (mm)",
    y = "ERA5-Land annual peak SWE at site (mm)",
    color = "Site"
  ) +
  theme_minimal(base_size = 11)
ggsave(plot_path, p, width = 8, height = 6, dpi = 150)
message("Wrote: ", plot_path)

cat("\n=== Summary ===\n")
print(per_site)
cat(sprintf("\nOverall: r = %.3f, mean bias = %+.1f mm (%+.1f%%)\n",
            overall$cor_overall, overall$mean_bias_mm,
            overall$mean_bias_pct))
