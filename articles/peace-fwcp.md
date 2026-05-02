# Climate Departure for the FWCP Peace Region

The `cd` package builds on ERA5-Land hourly reanalysis (1950–present, ~9
km native grid) fetched from the DestinE Earth Data Hub, aggregated to
monthly, seasonal, and annual periods over British Columbia, and
published as Cloud-Optimized GeoTIFFs alongside a static STAC catalog in
a public S3 bucket. R consumer functions read those GeoTIFFs directly
via GDAL, crop to any area of interest, and compute baselines,
anomalies, and Mann-Kendall / Theil-Sen trend statistics.

This vignette runs the consumer pipeline on a regional administrative
boundary — the Fish & Wildlife Compensation Program (FWCP) Peace Region,
~73,000 km² in northeastern British Columbia covering Williston
Reservoir and surrounding watersheds.

## Area of Interest

The bundled area of interest is the FWCP Peace Region polygon (single
multi-polygon, EPSG:4326). Any `sf` polygon works. The watersheds within
this region all drain to the Mackenzie River — the Peace flows east into
the Slave, which flows into the Mackenzie, which empties into the
Beaufort Sea on the Arctic Ocean.

We also carry British Columbia ecoregions through the analysis.
Ecoregions partition the province into broad climate-physiography zones
based on latitude, elevation, and dominant vegetation. Climate departure
can vary across them in ways the regional average hides, and we use them
later as the sub-region for the per-ecoregion breakdown.

``` r

library(cd)
library(sf)

aoi <- st_read(
  system.file("extdata", "example_aoi_fwcp_peace.gpkg", package = "cd"),
  quiet = TRUE
)

area_km2 <- as.numeric(sum(st_area(st_transform(aoi, 3005)))) / 1e6
```

``` r

aoi_bb <- st_bbox(aoi)

ggplot() +
  geom_sf(data = ecoregions, aes(fill = name_tc), color = "grey45",
          linewidth = 0.3, alpha = 0.45) +
  geom_sf(data = aoi, fill = NA, color = "#2166ac", linewidth = 0.8) +
  geom_sf(data = lakes, fill = "#a6bddb", color = "#74a9cf", linewidth = 0.2) +
  geom_sf(data = rivers, fill = "#a6bddb", color = "#74a9cf", linewidth = 0.2) +
  geom_sf(data = streams, color = "#74a9cf", linewidth = 0.3, alpha = 0.6) +
  geom_sf(data = highways, color = "#333333", linewidth = 0.5) +
  geom_sf(data = towns, color = "black", size = 2.5) +
  ggrepel::geom_label_repel(
    data = towns,
    aes(label = name, geometry = geom),
    stat = "sf_coordinates",
    size = 3.2, fill = "white", alpha = 0.85,
    label.padding = unit(0.2, "lines"),
    min.segment.length = 0
  ) +
  scale_fill_brewer(palette = "Set3", name = "Ecoregion") +
  guides(fill = guide_legend(nrow = 2, byrow = TRUE)) +
  coord_sf(
    xlim = c(aoi_bb["xmin"] - 0.4, aoi_bb["xmax"] + 0.4),
    ylim = c(aoi_bb["ymin"] - 0.5, aoi_bb["ymax"] + 0.3)
  ) +
  labs(title = "FWCP Peace Region",
       subtitle = paste0(round(area_km2), " km^2 — ", nrow(ecoregions), " ecoregions")) +
  theme_minimal(base_size = 12) +
  theme(axis.title = element_blank(),
        legend.position = "bottom",
        legend.text = element_text(size = 8),
        legend.title = element_text(size = 9),
        legend.key.size = unit(0.4, "cm"))
```

![FWCP Peace Region area of interest (~73,000 km^2) in northeastern
British Columbia, coloured by ecoregion. Williston Reservoir dominates
the basin.](peace-fwcp_files/figure-html/map-location-1.png)

FWCP Peace Region area of interest (~73,000 km^2) in northeastern
British Columbia, coloured by ecoregion. Williston Reservoir dominates
the basin.

## Connect to the Data Catalog

The producer pipeline in this repository fetches ERA5-Land hourly
reanalysis data, derives variables (vapour pressure deficit, relative
humidity, soil moisture), aggregates to monthly / seasonal / annual, and
writes Cloud-Optimized GeoTIFFs to S3. Alongside the GeoTIFFs we publish
a static SpatioTemporal Asset Catalog (STAC) — a small set of JSON files
that index the assets. Both the GeoTIFFs and the catalog JSON live at
<https://stac-era5-land.s3.us-west-2.amazonaws.com/catalog.json>.

[`cd_catalog()`](https://newgraphenvironment.github.io/cd/reference/cd_catalog.md)
reads that URL by default. The Cloud-Optimized GeoTIFFs are also usable
directly outside R — for example, in QGIS via the STAC plugin, in
`gdalcubes`, or with any STAC-aware client.

``` r

catalog <- cd_catalog()
kableExtra::kable_styling(
  knitr::kable(catalog, label = NA,
    caption = "Available climate variables and periods in the STAC catalog."),
  bootstrap_options = c("striped", "hover", "condensed")
) |>
  kableExtra::scroll_box(height = "320px")
```

| variable | period | href |
|:---|:---|:---|
| prcp | annual | <https://stac-era5-land.s3.us-west-2.amazonaws.com/prcp_annual.tif> |
| prcp | fall | <https://stac-era5-land.s3.us-west-2.amazonaws.com/prcp_fall.tif> |
| prcp | spring | <https://stac-era5-land.s3.us-west-2.amazonaws.com/prcp_spring.tif> |
| prcp | summer | <https://stac-era5-land.s3.us-west-2.amazonaws.com/prcp_summer.tif> |
| prcp | winter | <https://stac-era5-land.s3.us-west-2.amazonaws.com/prcp_winter.tif> |
| rh | annual | <https://stac-era5-land.s3.us-west-2.amazonaws.com/rh_annual.tif> |
| rh | fall | <https://stac-era5-land.s3.us-west-2.amazonaws.com/rh_fall.tif> |
| rh | spring | <https://stac-era5-land.s3.us-west-2.amazonaws.com/rh_spring.tif> |
| rh | summer | <https://stac-era5-land.s3.us-west-2.amazonaws.com/rh_summer.tif> |
| rh | winter | <https://stac-era5-land.s3.us-west-2.amazonaws.com/rh_winter.tif> |
| soil_moisture | annual | <https://stac-era5-land.s3.us-west-2.amazonaws.com/soil_moisture_annual.tif> |
| soil_moisture | fall | <https://stac-era5-land.s3.us-west-2.amazonaws.com/soil_moisture_fall.tif> |
| soil_moisture | spring | <https://stac-era5-land.s3.us-west-2.amazonaws.com/soil_moisture_spring.tif> |
| soil_moisture | summer | <https://stac-era5-land.s3.us-west-2.amazonaws.com/soil_moisture_summer.tif> |
| soil_moisture | winter | <https://stac-era5-land.s3.us-west-2.amazonaws.com/soil_moisture_winter.tif> |
| tmax | annual | <https://stac-era5-land.s3.us-west-2.amazonaws.com/tmax_annual.tif> |
| tmax | fall | <https://stac-era5-land.s3.us-west-2.amazonaws.com/tmax_fall.tif> |
| tmax | spring | <https://stac-era5-land.s3.us-west-2.amazonaws.com/tmax_spring.tif> |
| tmax | summer | <https://stac-era5-land.s3.us-west-2.amazonaws.com/tmax_summer.tif> |
| tmax | winter | <https://stac-era5-land.s3.us-west-2.amazonaws.com/tmax_winter.tif> |
| tmean | annual | <https://stac-era5-land.s3.us-west-2.amazonaws.com/tmean_annual.tif> |
| tmean | fall | <https://stac-era5-land.s3.us-west-2.amazonaws.com/tmean_fall.tif> |
| tmean | spring | <https://stac-era5-land.s3.us-west-2.amazonaws.com/tmean_spring.tif> |
| tmean | summer | <https://stac-era5-land.s3.us-west-2.amazonaws.com/tmean_summer.tif> |
| tmean | winter | <https://stac-era5-land.s3.us-west-2.amazonaws.com/tmean_winter.tif> |
| tmin | annual | <https://stac-era5-land.s3.us-west-2.amazonaws.com/tmin_annual.tif> |
| tmin | fall | <https://stac-era5-land.s3.us-west-2.amazonaws.com/tmin_fall.tif> |
| tmin | spring | <https://stac-era5-land.s3.us-west-2.amazonaws.com/tmin_spring.tif> |
| tmin | summer | <https://stac-era5-land.s3.us-west-2.amazonaws.com/tmin_summer.tif> |
| tmin | winter | <https://stac-era5-land.s3.us-west-2.amazonaws.com/tmin_winter.tif> |
| vpd | annual | <https://stac-era5-land.s3.us-west-2.amazonaws.com/vpd_annual.tif> |
| vpd | fall | <https://stac-era5-land.s3.us-west-2.amazonaws.com/vpd_fall.tif> |
| vpd | spring | <https://stac-era5-land.s3.us-west-2.amazonaws.com/vpd_spring.tif> |
| vpd | summer | <https://stac-era5-land.s3.us-west-2.amazonaws.com/vpd_summer.tif> |
| vpd | winter | <https://stac-era5-land.s3.us-west-2.amazonaws.com/vpd_winter.tif> |

Available climate variables and periods in the STAC catalog. {.table
.table .table-striped .table-hover .table-condensed
style="margin-left: auto; margin-right: auto;"}

  

## Extract Climate Time Series

[`cd_extract()`](https://newgraphenvironment.github.io/cd/reference/cd_extract.md)
crops each cloud-hosted GeoTIFF to the area of interest and computes the
spatial mean per year. For an area of interest of this size a live
extraction takes a few seconds per variable. To keep the vignette fast
and reproducible we load a pre-computed result of exactly that call.

``` r

# In a fresh interactive session, you would compute this with:
#   ts <- cd_extract(catalog, aoi)
# Below we load the pre-computed equivalent so the vignette renders
# without hitting the network. ts is the time series tibble; bl_early,
# ano, trn, cmp, and cmp_pct are the downstream products.
vignette_data <- readRDS(system.file(
  "vignette-data", "peace_fwcp.rds", package = "cd"
))
ts       <- vignette_data$regional$ts
bl_early <- vignette_data$regional$bl
ano      <- vignette_data$regional$ano
trn      <- vignette_data$regional$trn
cmp      <- vignette_data$regional$cmp
cmp_pct  <- vignette_data$regional$cmp_pct

knitr::kable(head(ts, 10),
  caption = "First 10 rows of the extracted climate time series.")
```

| variable | period | year |    value |
|:---------|:-------|-----:|---------:|
| prcp     | annual | 1950 | 645.5450 |
| prcp     | annual | 1951 | 665.1381 |
| prcp     | annual | 1952 | 673.8270 |
| prcp     | annual | 1953 | 828.5204 |
| prcp     | annual | 1954 | 942.6607 |
| prcp     | annual | 1955 | 729.9778 |
| prcp     | annual | 1956 | 752.0231 |
| prcp     | annual | 1957 | 783.3298 |
| prcp     | annual | 1958 | 698.6779 |
| prcp     | annual | 1959 | 882.8473 |

First 10 rows of the extracted climate time series. {.table}

## Trends

Anomalies are computed against a pre-warming reference period —
1951–1980, the three decades before climate change accelerated. Saying a
year is “+1.5 °C” means it was 1.5 °C warmer than the average year
between 1951 and 1980.

The trend table that follows has two rows per variable. We compute
trends from two different start years:

- **1951–present (75 years)** — the long view. Captures the full
  magnitude of warming since the pre-warming reference.
- **1981–present (45 years)** — starts at the beginning of the World
  Meteorological Organization’s most recent 30-year “climate normal”
  (1981–2010). This is the reference period used in most published
  climate products, so it makes results easy to compare against
  Intergovernmental Panel on Climate Change reports and government
  climate summaries.

Comparing the two slopes is informative. If the 45-year slope is steeper
than the 75-year slope, warming has accelerated — recent decades are
heating faster than the long-term average. If the 45-year slope is
shallower, warming has slowed (though “slower” almost never means
“stopped”). When the two slopes are similar, the rate of change has been
roughly steady across the full record.

Total Change is the slope multiplied by the number of years — the
cumulative shift over the trend window.

``` r

# Equivalent to:
#   bl_early <- cd_baseline(ts, baseline_years = 1951:1980)
#   ano <- cd_anomaly(ts, bl_early)
#   trn <- cd_trend(ano, trend_start = c(1951, 1981))
kableExtra::kable_styling(
  knitr::kable(cd_summary(trn), label = NA,
    caption = "Trend statistics for all variables and periods, FWCP Peace Region."),
  bootstrap_options = c("striped", "hover", "condensed")
) |>
  kableExtra::scroll_box(height = "320px")
```

| Parameter               | Period |  Slope | Years | Total Change | Unit | p-value |
|:------------------------|:-------|-------:|------:|-------------:|:-----|--------:|
| Precipitation           | Annual |  0.085 |    75 |          6.4 | %    |  0.1971 |
| Relative humidity       | Annual |  0.001 |    75 |          0.1 | %    |  0.8620 |
| Soil moisture           | Annual | -0.002 |    75 |         -0.1 | %    |  0.8981 |
| Maximum temperature     | Annual |  0.027 |    75 |          2.0 | °C   |  0.0000 |
| Mean temperature        | Annual |  0.030 |    75 |          2.2 | °C   |  0.0000 |
| Minimum temperature     | Annual |  0.032 |    75 |          2.4 | °C   |  0.0000 |
| Vapour pressure deficit | Annual |  0.005 |    75 |          0.3 | Pa   |  0.0008 |
| Precipitation           | Fall   |  0.065 |    75 |          4.9 | %    |  0.4926 |
| Relative humidity       | Fall   | -0.016 |    75 |         -1.2 | %    |  0.0906 |
| Soil moisture           | Fall   |  0.000 |    75 |          0.0 | %    |  0.9964 |
| Maximum temperature     | Fall   |  0.013 |    75 |          1.0 | °C   |  0.0659 |
| Mean temperature        | Fall   |  0.020 |    75 |          1.5 | °C   |  0.0099 |
| Minimum temperature     | Fall   |  0.025 |    75 |          1.9 | °C   |  0.0027 |
| Vapour pressure deficit | Fall   |  0.002 |    75 |          0.2 | Pa   |  0.0323 |
| Precipitation           | Spring |  0.184 |    75 |         13.8 | %    |  0.1644 |
| Relative humidity       | Spring | -0.009 |    75 |         -0.7 | %    |  0.3848 |
| Soil moisture           | Spring |  0.032 |    75 |          2.4 | %    |  0.0151 |
| Maximum temperature     | Spring |  0.025 |    75 |          1.9 | °C   |  0.0007 |
| Mean temperature        | Spring |  0.028 |    75 |          2.1 | °C   |  0.0001 |
| Minimum temperature     | Spring |  0.027 |    75 |          2.0 | °C   |  0.0001 |
| Vapour pressure deficit | Spring |  0.005 |    75 |          0.4 | Pa   |  0.0001 |
| Precipitation           | Summer |  0.175 |    75 |         13.1 | %    |  0.1847 |
| Relative humidity       | Summer | -0.007 |    75 |         -0.6 | %    |  0.7558 |
| Soil moisture           | Summer | -0.036 |    75 |         -2.7 | %    |  0.1728 |
| Maximum temperature     | Summer |  0.026 |    75 |          2.0 | °C   |  0.0004 |
| Mean temperature        | Summer |  0.031 |    75 |          2.4 | °C   |  0.0000 |
| Minimum temperature     | Summer |  0.035 |    75 |          2.6 | °C   |  0.0000 |
| Vapour pressure deficit | Summer |  0.009 |    75 |          0.7 | Pa   |  0.0338 |
| Precipitation           | Winter | -0.050 |    75 |         -3.8 | %    |  0.6606 |
| Relative humidity       | Winter |  0.035 |    75 |          2.7 | %    |  0.0026 |
| Soil moisture           | Winter | -0.005 |    75 |         -0.4 | %    |  0.4983 |
| Maximum temperature     | Winter |  0.045 |    75 |          3.4 | °C   |  0.0000 |
| Mean temperature        | Winter |  0.044 |    75 |          3.3 | °C   |  0.0002 |
| Minimum temperature     | Winter |  0.043 |    75 |          3.3 | °C   |  0.0003 |
| Vapour pressure deficit | Winter |  0.001 |    75 |          0.1 | Pa   |  0.0007 |
| Precipitation           | Annual | -0.010 |    45 |         -0.4 | %    |  0.9298 |
| Relative humidity       | Annual | -0.016 |    45 |         -0.7 | %    |  0.3947 |
| Soil moisture           | Annual | -0.017 |    45 |         -0.7 | %    |  0.6041 |
| Maximum temperature     | Annual |  0.021 |    45 |          0.9 | °C   |  0.0449 |
| Mean temperature        | Annual |  0.023 |    45 |          1.0 | °C   |  0.0264 |
| Minimum temperature     | Annual |  0.024 |    45 |          1.1 | °C   |  0.0116 |
| Vapour pressure deficit | Annual |  0.005 |    45 |          0.2 | Pa   |  0.0963 |
| Precipitation           | Fall   |  0.083 |    45 |          3.7 | %    |  0.6884 |
| Relative humidity       | Fall   | -0.022 |    45 |         -1.0 | %    |  0.1678 |
| Soil moisture           | Fall   | -0.003 |    45 |         -0.2 | %    |  0.9376 |
| Maximum temperature     | Fall   |  0.029 |    45 |          1.3 | °C   |  0.0338 |
| Mean temperature        | Fall   |  0.038 |    45 |          1.7 | °C   |  0.0053 |
| Minimum temperature     | Fall   |  0.046 |    45 |          2.1 | °C   |  0.0014 |
| Vapour pressure deficit | Fall   |  0.005 |    45 |          0.2 | Pa   |  0.0834 |
| Precipitation           | Spring | -0.231 |    45 |        -10.4 | %    |  0.3044 |
| Relative humidity       | Spring | -0.054 |    45 |         -2.4 | %    |  0.0227 |
| Soil moisture           | Spring | -0.010 |    45 |         -0.5 | %    |  0.7100 |
| Maximum temperature     | Spring |  0.011 |    45 |          0.5 | °C   |  0.6179 |
| Mean temperature        | Spring |  0.006 |    45 |          0.3 | °C   |  0.7468 |
| Minimum temperature     | Spring |  0.003 |    45 |          0.1 | °C   |  0.7917 |
| Vapour pressure deficit | Spring |  0.008 |    45 |          0.4 | Pa   |  0.0141 |
| Precipitation           | Summer | -0.121 |    45 |         -5.4 | %    |  0.7468 |
| Relative humidity       | Summer |  0.001 |    45 |          0.0 | %    |  0.9922 |
| Soil moisture           | Summer | -0.069 |    45 |         -3.1 | %    |  0.2952 |
| Maximum temperature     | Summer |  0.030 |    45 |          1.3 | °C   |  0.0617 |
| Mean temperature        | Summer |  0.034 |    45 |          1.5 | °C   |  0.0113 |
| Minimum temperature     | Summer |  0.036 |    45 |          1.6 | °C   |  0.0015 |
| Vapour pressure deficit | Summer |  0.009 |    45 |          0.4 | Pa   |  0.4057 |
| Precipitation           | Winter |  0.187 |    45 |          8.4 | %    |  0.4281 |
| Relative humidity       | Winter |  0.021 |    45 |          1.0 | %    |  0.3527 |
| Soil moisture           | Winter | -0.003 |    45 |         -0.1 | %    |  0.8911 |
| Maximum temperature     | Winter |  0.015 |    45 |          0.7 | °C   |  0.4752 |
| Mean temperature        | Winter |  0.007 |    45 |          0.3 | °C   |  0.7321 |
| Minimum temperature     | Winter |  0.005 |    45 |          0.2 | °C   |  0.7917 |
| Vapour pressure deficit | Winter |  0.000 |    45 |          0.0 | Pa   |  0.8220 |

Trend statistics for all variables and periods, FWCP Peace Region.
{.table .table .table-striped .table-hover .table-condensed
style="margin-left: auto; margin-right: auto;"}

  

``` r

cd_plot_timeseries(
  ano, variable = "tmean", period = "annual", trend = trn,
  title = "Annual Mean Temperature Anomaly — FWCP Peace Region"
)
```

![Annual mean temperature anomaly for the FWCP Peace Region relative to
1951-1980 baseline.](peace-fwcp_files/figure-html/plot-tmean-1.png)

Annual mean temperature anomaly for the FWCP Peace Region relative to
1951-1980 baseline.

``` r

cd_plot_timeseries(
  ano, variable = "prcp", period = "annual", trend = trn,
  title = "Annual Precipitation Anomaly — FWCP Peace Region"
)
```

![Annual precipitation anomaly (% of 1951-1980 baseline) for the FWCP
Peace Region.](peace-fwcp_files/figure-html/plot-prcp-1.png)

Annual precipitation anomaly (% of 1951-1980 baseline) for the FWCP
Peace Region.

## Daytime Highs and Overnight Lows

The cd package ships daytime maximum (tmax) and overnight minimum (tmin)
temperatures alongside the daily mean. They carry distinct information.
Overnight minimums warming faster than daytime maximums — the “day-night
asymmetry” — is one of the textbook fingerprints of greenhouse warming
(Karl et al. 1993). Whether a watershed or region shows that signal
depends on local geography (valley inversions, snow cover, slope-aspect
mix).

For the FWCP Peace Region, **overnight minimums are warming faster than
daytime maximums** — the textbook day-night asymmetry. Daytime maximums
warmed about +0.027 °C per year since 1951 (+2.0 °C cumulative), while
overnight minimums warmed about +0.032 °C per year (+2.4 °C cumulative).
The overnight side warmed roughly 0.4 °C more than the daytime side over
the full record, narrowing the diurnal temperature range by the same
amount. The three figures below show the tmax, tmin and diurnal-range
time series that yield those numbers.

``` r

trn_tmax <- cd_trend(
  ano[ano$variable == "tmax" & ano$period == "annual", ],
  trend_start = c(1951, 1981)
)
cd_plot_timeseries(ano, variable = "tmax", period = "annual", trend = trn_tmax,
  title = "Daytime Maximum (tmax) — Annual Anomaly")
```

![Annual daytime maximum temperature (tmax) anomaly for the FWCP Peace
Region relative to the 1951-1980
baseline.](peace-fwcp_files/figure-html/plot-tmax-1.png)

Annual daytime maximum temperature (tmax) anomaly for the FWCP Peace
Region relative to the 1951-1980 baseline.

``` r

trn_tmin <- cd_trend(
  ano[ano$variable == "tmin" & ano$period == "annual", ],
  trend_start = c(1951, 1981)
)
cd_plot_timeseries(ano, variable = "tmin", period = "annual", trend = trn_tmin,
  title = "Overnight Minimum (tmin) — Annual Anomaly")
```

![Annual overnight minimum temperature (tmin) anomaly for the FWCP Peace
Region relative to the 1951-1980
baseline.](peace-fwcp_files/figure-html/plot-tmin-1.png)

Annual overnight minimum temperature (tmin) anomaly for the FWCP Peace
Region relative to the 1951-1980 baseline.

``` r

tmax_ts <- ts[ts$variable == "tmax" & ts$period == "annual", c("year", "value")]
tmin_ts <- ts[ts$variable == "tmin" & ts$period == "annual", c("year", "value")]
dtr <- merge(tmax_ts, tmin_ts, by = "year", suffixes = c("_max", "_min"))
dtr$dtr <- dtr$value_max - dtr$value_min

ggplot(dtr, aes(x = year, y = dtr)) +
  geom_line(color = "grey50") +
  geom_point(color = "grey30", size = 1) +
  geom_smooth(method = "lm", se = FALSE, color = "#b2182b", linewidth = 0.8) +
  labs(
    title = "Diurnal Temperature Range — FWCP Peace Region",
    x = NULL,
    y = expression("Daytime maximum minus overnight minimum (" * degree * "C)")
  ) +
  theme_minimal(base_size = 12)
```

![Diurnal temperature range (daytime maximum minus overnight minimum)
annual mean for the FWCP Peace Region. The downward trend indicates
overnight lows are warming faster than daytime highs — the textbook
day-night asymmetry shows up
here.](peace-fwcp_files/figure-html/plot-dtr-1.png)

Diurnal temperature range (daytime maximum minus overnight minimum)
annual mean for the FWCP Peace Region. The downward trend indicates
overnight lows are warming faster than daytime highs — the textbook
day-night asymmetry shows up here.

## Recent vs Pre-warming

The table below compares two windows directly — the recent decade
(2015–2025) against the pre-warming reference (1951–1980). Δ absolute is
the difference of the two means in the variable’s native units. Δ % is
shown only for variables where it is meaningful (precipitation, soil
moisture, vapour pressure deficit, relative humidity). The trend p
column is the Mann-Kendall p-value of the 75-year (1951–present) trend
on the same variable and period; it tests for a steady year-on-year
ramp, which is a related but distinct question from “do these two
windows differ”.

The recent decade was 1.7 to 2.4 °C warmer than the pre-warming
reference for annual mean, daytime maximum, and overnight minimum, with
Mann-Kendall trend p-values below 0.001. Vapour pressure deficit is up
significantly. Annual precipitation was about 3 to 4 % higher in the
recent decade; the long-term trend test does not confirm a steady
year-on-year ramp (p ≈ 0.20). Soil moisture and relative humidity show
no meaningful change.

``` r

trn_p <- trn[trn$trend_start == 1951, c("variable", "period", "mk_pvalue")]
names(trn_p)[3] <- "trend_p"
trn_p$trend_p <- round(trn_p$trend_p, 3)

cmp_combined <- cmp |>
  dplyr::mutate(
    pct_change = ifelse(
      variable %in% c("tmean", "tmax", "tmin"),
      NA_real_,
      round(100 * (mean_a - mean_b) / mean_b, 1)
    ),
    mean_a   = round(mean_a, 2),
    mean_b   = round(mean_b, 2),
    abs_diff = round(difference, 2)
  ) |>
  dplyr::select(variable, period, mean_a, mean_b, abs_diff, pct_change) |>
  merge(trn_p, by = c("variable", "period"), all.x = TRUE)

names(cmp_combined) <- c(
  "Variable", "Period",
  "Recent (2015–2025)", "Pre-warming (1951–1980)",
  "Δ absolute", "Δ %", "Trend p (75-yr)"
)

kableExtra::kable_styling(
  knitr::kable(cmp_combined, label = NA,
    caption = "Recent decade (2015-2025 mean) compared to pre-warming reference (1951-1980 mean) for the FWCP Peace Region.",
    row.names = FALSE),
  bootstrap_options = c("striped", "hover", "condensed")
) |>
  kableExtra::scroll_box(height = "360px")
```

| Variable | Period | Recent (2015–2025) | Pre-warming (1951–1980) | Δ absolute | Δ % | Trend p (75-yr) |
|:---|:---|---:|---:|---:|---:|---:|
| prcp | annual | 835.20 | 803.11 | 32.08 | 4.0 | 0.197 |
| prcp | fall | 239.18 | 230.76 | 8.42 | 3.7 | 0.493 |
| prcp | spring | 155.72 | 150.62 | 5.10 | 3.4 | 0.164 |
| prcp | summer | 266.04 | 242.15 | 23.89 | 9.9 | 0.185 |
| prcp | winter | 174.26 | 179.59 | -5.33 | -3.0 | 0.661 |
| rh | annual | 74.08 | 74.08 | 0.00 | 0.0 | 0.862 |
| rh | fall | 79.38 | 80.16 | -0.78 | -1.0 | 0.091 |
| rh | spring | 68.43 | 69.49 | -1.06 | -1.5 | 0.385 |
| rh | summer | 67.25 | 67.63 | -0.38 | -0.6 | 0.756 |
| rh | winter | 81.25 | 79.05 | 2.20 | 2.8 | 0.003 |
| soil_moisture | annual | 0.32 | 0.32 | 0.00 | -0.3 | 0.898 |
| soil_moisture | fall | 0.32 | 0.32 | 0.00 | -0.4 | 0.996 |
| soil_moisture | spring | 0.32 | 0.32 | 0.01 | 1.9 | 0.015 |
| soil_moisture | summer | 0.33 | 0.33 | -0.01 | -2.5 | 0.173 |
| soil_moisture | winter | 0.31 | 0.31 | 0.00 | -0.2 | 0.498 |
| tmax | annual | 3.66 | 1.99 | 1.67 | NA | 0.000 |
| tmax | fall | 3.49 | 2.55 | 0.93 | NA | 0.066 |
| tmax | spring | 3.93 | 2.16 | 1.76 | NA | 0.001 |
| tmax | summer | 16.62 | 15.00 | 1.62 | NA | 0.000 |
| tmax | winter | -9.40 | -11.77 | 2.37 | NA | 0.000 |
| tmean | annual | -0.59 | -2.41 | 1.82 | NA | 0.000 |
| tmean | fall | -0.32 | -1.58 | 1.26 | NA | 0.010 |
| tmean | spring | -0.75 | -2.57 | 1.82 | NA | 0.000 |
| tmean | summer | 11.64 | 9.76 | 1.88 | NA | 0.000 |
| tmean | winter | -12.92 | -15.27 | 2.34 | NA | 0.000 |
| tmin | annual | -4.12 | -6.05 | 1.93 | NA | 0.000 |
| tmin | fall | -3.19 | -4.71 | 1.52 | NA | 0.003 |
| tmin | spring | -4.76 | -6.49 | 1.74 | NA | 0.000 |
| tmin | summer | 6.93 | 4.81 | 2.12 | NA | 0.000 |
| tmin | winter | -15.47 | -17.81 | 2.33 | NA | 0.000 |
| vpd | annual | 2.14 | 1.86 | 0.28 | 15.1 | 0.001 |
| vpd | fall | 1.48 | 1.32 | 0.16 | 12.3 | 0.032 |
| vpd | spring | 2.05 | 1.67 | 0.38 | 22.8 | 0.000 |
| vpd | summer | 4.62 | 4.06 | 0.55 | 13.6 | 0.034 |
| vpd | winter | 0.43 | 0.40 | 0.03 | 6.5 | 0.001 |

Recent decade (2015-2025 mean) compared to pre-warming reference
(1951-1980 mean) for the FWCP Peace Region. {.table .table
.table-striped .table-hover .table-condensed
style="margin-left: auto; margin-right: auto;"}

  

## Spatial Pattern

The zonal mean reduces a region this size to a single number; the
spatial pattern carries the rest of the story.

Warming is not spatially uniform. Total departures range from about +1.5
°C in the southeast to over +2.1 °C in the west and centre. The dominant
gradient runs east-to-west — the western half of the region averages
roughly 0.2 °C more warming than the eastern half — with a smaller
south-to-north component. The west-of-Rockies pattern is consistent with
windward-slope amplification along the Continental Divide.

``` r

# Pre-computed by data-raw/peace_fwcp_vignette_data.R. Live equivalent:
#   r_tmean <- cd_crop(catalog$href[catalog$variable == "tmean"
#                                   & catalog$period == "annual"], aoi)
#   years <- as.integer(names(r_tmean))
#   departure <- mean(r_tmean[[which(years >= 2015 & years <= 2025)]]) -
#                mean(r_tmean[[which(years >= 1951 & years <= 1980)]])
#   departure <- terra::mask(departure, aoi)
departure <- terra::rast(system.file(
  "vignette-data", "peace_fwcp_departure_tmean.tif", package = "cd"
))
names(departure) <- "Temperature departure"

ggplot() +
  geom_spatraster(data = departure) +
  geom_sf(data = ecoregions, fill = NA, color = "grey25",
          linewidth = 0.4, linetype = "dashed") +
  geom_sf(data = aoi, fill = NA, color = "black", linewidth = 0.6) +
  geom_sf(data = lakes, fill = NA, color = "grey40", linewidth = 0.2) +
  geom_sf(data = highways, color = "#333333", linewidth = 0.4) +
  geom_sf(data = towns, color = "black", size = 2) +
  ggrepel::geom_label_repel(
    data = towns, aes(label = name, geometry = geom),
    stat = "sf_coordinates", size = 3, fill = "white", alpha = 0.8
  ) +
  scale_fill_distiller(
    palette = "RdBu", direction = -1,
    name = expression(Delta * degree * C)
  ) +
  coord_sf(
    xlim = c(aoi_bb["xmin"], aoi_bb["xmax"]),
    ylim = c(aoi_bb["ymin"], aoi_bb["ymax"])
  ) +
  labs(title = "Temperature Departure (2015-2025 vs 1951-1980)") +
  theme_minimal(base_size = 12) +
  theme(axis.title = element_blank())
```

![Spatial pattern of annual mean temperature departure across the FWCP
Peace Region (2015-2025 mean minus 1951-1980 mean, degrees
C).](peace-fwcp_files/figure-html/spatial-tmean-1.png)

Spatial pattern of annual mean temperature departure across the FWCP
Peace Region (2015-2025 mean minus 1951-1980 mean, degrees C).

## Per-Ecoregion Variation

The regional zonal mean averages over five ecoregions with different
elevations and exposures. To check whether the regional story holds
within each ecoregion — and where it does not — we run the same pipeline
on each ecoregion polygon individually.

All five ecoregions warmed at roughly the same rate — about +0.3 °C per
decade since 1951, with cumulative changes within 0.2 °C of each other.
Precipitation is the variable that diverges: the two northernmost
ecoregions (Boreal Mountains and Plateaus, Northern Canadian Rocky
Mountains) show statistically significant precipitation increases, while
the southern and central ecoregions do not. Vapour pressure deficit is
up significantly in all five.

``` r

ggplot(ano_all[ano_all$variable == "tmean" & ano_all$period == "annual", ],
       aes(x = year, y = anomaly)) +
  geom_col(aes(fill = anomaly >= 0), width = 0.85, show.legend = FALSE) +
  geom_segment(data = trn_segs_tmean,
               aes(x = x_start, xend = x_end, y = y_start, yend = y_end,
                   linetype = window),
               inherit.aes = FALSE, color = "black", linewidth = 0.6) +
  scale_fill_manual(values = c(`TRUE` = "#d73027", `FALSE` = "#4575b4")) +
  scale_linetype_manual(values = c("dashed", "solid"), name = "Trend window") +
  facet_wrap(~ ecoregion, ncol = 3,
             labeller = labeller(ecoregion = er_labels)) +
  labs(x = NULL, y = expression("Mean temperature anomaly (" * degree * C * ")")) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")
```

![Annual mean temperature anomaly relative to the 1951-1980 baseline, by
ecoregion. Dashed line is the 75-year Theil-Sen trend (1951-present);
solid line is the 45-year trend (1981-present). A solid line steeper
than the dashed line indicates accelerating
warming.](peace-fwcp_files/figure-html/facet-tmean-1.png)

Annual mean temperature anomaly relative to the 1951-1980 baseline, by
ecoregion. Dashed line is the 75-year Theil-Sen trend (1951-present);
solid line is the 45-year trend (1981-present). A solid line steeper
than the dashed line indicates accelerating warming.

``` r

ggplot(ano_all[ano_all$variable == "prcp" & ano_all$period == "annual", ],
       aes(x = year, y = anomaly)) +
  geom_col(aes(fill = anomaly >= 0), width = 0.85, show.legend = FALSE) +
  geom_segment(data = trn_segs_prcp,
               aes(x = x_start, xend = x_end, y = y_start, yend = y_end,
                   linetype = window),
               inherit.aes = FALSE, color = "black", linewidth = 0.6) +
  scale_fill_manual(values = c(`TRUE` = "#4575b4", `FALSE` = "#d73027")) +
  scale_linetype_manual(values = c("dashed", "solid"), name = "Trend window") +
  facet_wrap(~ ecoregion, ncol = 3,
             labeller = labeller(ecoregion = er_labels)) +
  labs(x = NULL, y = "Precipitation anomaly (% of baseline)") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")
```

![Annual precipitation anomaly (% of the 1951-1980 baseline) by
ecoregion. Dashed line is the 75-year trend (1951-present); solid line
is the 45-year trend (1981-present). The two northernmost ecoregions
(BMP, NRM) show statistically significant precipitation increases over
the full record; the others do
not.](peace-fwcp_files/figure-html/facet-prcp-1.png)

Annual precipitation anomaly (% of the 1951-1980 baseline) by ecoregion.
Dashed line is the 75-year trend (1951-present); solid line is the
45-year trend (1981-present). The two northernmost ecoregions (BMP, NRM)
show statistically significant precipitation increases over the full
record; the others do not.

``` r

get_75 <- function(trn, var) {
  trn[trn$variable == var & trn$period == "annual" & trn$trend_start == 1951, ]
}
rollup <- do.call(rbind, lapply(seq_along(results), function(i) {
  res <- results[[i]]
  cmp <- res$cmp
  tmean <- get_75(res$trn, "tmean")
  tmax  <- get_75(res$trn, "tmax")
  tmin  <- get_75(res$trn, "tmin")
  prcp  <- get_75(res$trn, "prcp")
  vpd   <- get_75(res$trn, "vpd")
  data.frame(
    Ecoregion = ecoregions$code[i],
    `tmean degC/dec` = round(10 * tmean$slope, 2),
    `tmax degC/dec`  = round(10 * tmax$slope, 2),
    `tmin degC/dec`  = round(10 * tmin$slope, 2),
    `prcp mm/yr` = round(prcp$slope, 3),
    `prcp p` = round(prcp$mk_pvalue, 3),
    `vpd hPa/dec` = round(10 * vpd$slope, 3),
    `vpd p` = round(vpd$mk_pvalue, 3),
    `prcp pct change` = round(
      cmp$difference[cmp$variable == "prcp" & cmp$period == "annual"], 1
    ),
    `soil moisture pct change` = round(
      cmp$difference[cmp$variable == "soil_moisture" & cmp$period == "annual"], 1
    ),
    check.names = FALSE
  )
}))
knitr::kable(rollup, row.names = FALSE,
  caption = "Per-ecoregion roll-up over the 75-year window (1951-present): annual mean, daytime maximum, and overnight minimum temperature trends (degrees C per decade); annual precipitation trend (mm per year) and Mann-Kendall p-value; annual vapour pressure deficit trend (hPa per decade) and p-value; and recent (2015-2025) vs pre-warming (1951-1980) percent change for precipitation and soil moisture. All temperature p-values are below 0.001. A tmin slope greater than the tmax slope indicates the textbook day-night asymmetry.")
```

| Ecoregion | tmean degC/dec | tmax degC/dec | tmin degC/dec | prcp mm/yr | prcp p | vpd hPa/dec | vpd p | prcp pct change | soil moisture pct change |
|:---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| FAB | 0.29 | 0.26 | 0.30 | 0.032 | 0.634 | 0.061 | 0.002 | 0.8 | -1.3 |
| CRM | 0.29 | 0.25 | 0.30 | 0.077 | 0.253 | 0.045 | 0.001 | 4.1 | -0.5 |
| OMM | 0.32 | 0.29 | 0.34 | 0.052 | 0.421 | 0.054 | 0.000 | 2.5 | -0.7 |
| BMP | 0.30 | 0.27 | 0.33 | 0.144 | 0.023 | 0.033 | 0.003 | 6.3 | 0.3 |
| NRM | 0.29 | 0.26 | 0.31 | 0.156 | 0.015 | 0.030 | 0.004 | 6.6 | 0.6 |

Per-ecoregion roll-up over the 75-year window (1951-present): annual
mean, daytime maximum, and overnight minimum temperature trends (degrees
C per decade); annual precipitation trend (mm per year) and Mann-Kendall
p-value; annual vapour pressure deficit trend (hPa per decade) and
p-value; and recent (2015-2025) vs pre-warming (1951-1980) percent
change for precipitation and soil moisture. All temperature p-values are
below 0.001. A tmin slope greater than the tmax slope indicates the
textbook day-night asymmetry. {.table}

Ecoregion codes used in the table above: FAB — Fraser Basin; CRM —
Central Canadian Rocky Mountains; OMM — Omineca Mountains; BMP — Boreal
Mountains and Plateaus; NRM — Northern Canadian Rocky Mountains.

  

## Watershed Groups Across Ecoregions

The FWCP Peace Region is reported and managed at the watershed-group
scale — the British Columbia Freshwater Atlas hydrological reporting
unit, and the unit the Fish & Wildlife Compensation Program funds work
in. Sixteen watershed groups make up the canonical FWCP Peace list. They
span the five ecoregions in different ways: some sit entirely within
one, others split across two or three. The map below shows the watershed
groups labelled with their codes, on top of the ecoregion fills. The
table that follows gives, for each watershed group, the share of its
area falling in each ecoregion.

The Upper Peace River watershed group is also intersected by the FWCP
boundary, but only at its upstream end — its main drainage runs east
beyond the region, so it is excluded here to keep the reporting unit
clean.

``` r

wsgs <- st_read(ctx, layer = "wsgs", quiet = TRUE)

wsg_centroids <- suppressWarnings(st_centroid(wsgs))

ggplot() +
  geom_sf(data = ecoregions, aes(fill = name_tc), color = "grey45",
          linewidth = 0.3, alpha = 0.45) +
  geom_sf(data = aoi, fill = NA, color = "#2166ac", linewidth = 0.8) +
  geom_sf(data = wsgs, fill = NA, color = "grey25", linewidth = 0.4) +
  ggrepel::geom_label_repel(
    data = wsg_centroids,
    aes(label = code, geometry = geom),
    stat = "sf_coordinates",
    size = 2.6, fill = "white", alpha = 0.85,
    label.padding = unit(0.15, "lines"),
    min.segment.length = 0
  ) +
  scale_fill_brewer(palette = "Set3", name = "Ecoregion") +
  guides(fill = guide_legend(nrow = 2, byrow = TRUE)) +
  coord_sf(
    xlim = c(aoi_bb["xmin"] - 0.4, aoi_bb["xmax"] + 0.4),
    ylim = c(aoi_bb["ymin"] - 0.5, aoi_bb["ymax"] + 0.3)
  ) +
  labs(title = "Watershed Groups on Ecoregion Backdrop") +
  theme_minimal(base_size = 12) +
  theme(axis.title = element_blank(),
        legend.position = "bottom",
        legend.text = element_text(size = 8),
        legend.title = element_text(size = 9),
        legend.key.size = unit(0.4, "cm"))
```

![Watershed groups intersecting the FWCP Peace Region (full extent,
including the parts spilling outside the FWCP boundary), labelled with
their codes, on top of ecoregion fills. The Fraser Basin, Central
Canadian Rockies, and Omineca Mountains ecoregions occupy the southern
and central portions; Boreal Mountains and Plateaus and Northern
Canadian Rocky Mountains sit in the
north.](peace-fwcp_files/figure-html/map-wsgs-1.png)

Watershed groups intersecting the FWCP Peace Region (full extent,
including the parts spilling outside the FWCP boundary), labelled with
their codes, on top of ecoregion fills. The Fraser Basin, Central
Canadian Rockies, and Omineca Mountains ecoregions occupy the southern
and central portions; Boreal Mountains and Plateaus and Northern
Canadian Rocky Mountains sit in the north.

``` r

wsg_xref <- read.csv(
  system.file("extdata", "peace_wsg_ecoregion_commentary.csv", package = "cd"),
  check.names = FALSE
)
wsg_xref$commentary <- NULL
names(wsg_xref) <- c("Code", "Name", "km² in FWCP",
                     "FAB %", "CRM %", "OMM %", "BMP %", "NRM %")
kableExtra::kable_styling(
  knitr::kable(wsg_xref, label = NA,
    caption = "Watershed groups in the FWCP Peace Region with the percent of each group's area falling in each of the five ecoregions. Rows where one ecoregion is at or near 100 percent indicate watershed groups contained within a single climatic-physiographic zone; rows split across two or more ecoregions indicate watershed groups whose climate departure can pull from more than one regional pattern. Codes match those in earlier figures. Source: data-raw/peace_wsg_ecoregion_commentary.R.",
    row.names = FALSE),
  bootstrap_options = c("striped", "hover", "condensed")
) |>
  kableExtra::scroll_box(height = "420px")
```

| Code | Name                | km² in FWCP | FAB % | CRM % | OMM % | BMP % | NRM % |
|:-----|:--------------------|------------:|------:|------:|------:|------:|------:|
| CARP | Carp Lake           |        1794 | 100.0 |   0.0 |   0.0 |   0.0 |   0.0 |
| CRKD | Crooked River       |        2172 | 100.0 |   0.0 |   0.0 |   0.0 |   0.0 |
| FINA | Finlay Arm          |        7383 |   0.3 |  20.2 |  61.8 |  10.3 |   7.4 |
| FINL | Finlay River        |        5479 |   0.0 |   0.0 |   0.0 |  30.4 |  69.6 |
| FIRE | Firesteel River     |        4376 |   0.0 |   0.0 |   1.0 |  99.0 |   0.0 |
| FOXR | Fox River           |        4279 |   0.0 |   0.0 |   0.0 |  16.8 |  83.2 |
| INGR | Ingenika River      |        5328 |   0.0 |   0.0 |   0.7 |  99.3 |   0.0 |
| LOMI | Lower Omineca River |        4013 |   0.0 |   0.0 | 100.0 |   0.0 |   0.0 |
| MESI | Mesilinka River     |        3294 |   0.0 |   0.0 |  94.8 |   5.2 |   0.0 |
| NATR | Nation River        |        6889 |  49.3 |   0.0 |  50.7 |   0.0 |   0.0 |
| OSPK | Ospika River        |        2973 |   0.0 |  60.5 |   0.0 |   0.0 |  39.5 |
| PARA | Parsnip Arm         |        3729 |  15.1 |  31.3 |  53.5 |   0.0 |   0.0 |
| PARS | Parsnip River       |        5583 |  28.6 |  71.4 |   0.0 |   0.0 |   0.0 |
| PCEA | Peace Arm           |        5861 |   0.0 |  98.8 |   1.2 |   0.0 |   0.0 |
| TOOD | Toodoggone River    |        4849 |   0.0 |   0.0 |   0.0 | 100.0 |   0.0 |
| UOMI | Upper Omineca River |        3905 |   0.0 |   0.0 | 100.0 |   0.0 |   0.0 |

Watershed groups in the FWCP Peace Region with the percent of each
group’s area falling in each of the five ecoregions. Rows where one
ecoregion is at or near 100 percent indicate watershed groups contained
within a single climatic-physiographic zone; rows split across two or
more ecoregions indicate watershed groups whose climate departure can
pull from more than one regional pattern. Codes match those in earlier
figures. Source: data-raw/peace_wsg_ecoregion_commentary.R. {.table
.table .table-striped .table-hover .table-condensed
style="margin-left: auto; margin-right: auto;"}

  

## Interpretation

Three findings emerge from the climate departures shown above.

**Warming is broad, fast, and uniform.** All five ecoregions warmed
between +1.7 °C and +1.9 °C cumulative since 1951, at a rate near +0.3
°C per decade, with Mann-Kendall p-values below 0.001 in every
ecoregion. The trend is statistically significant beyond reasonable
doubt of being random noise. Daily maximum, daily minimum, and daily
mean temperatures all tell the same story. There is no thermal hot spot.
The whole region has moved together. A subtle gradient does emerge — the
northern, higher-elevation ecoregions (Omineca Mountains, Boreal
Mountains and Plateaus) warmed about 0.2 °C more than the southern
Fraser Basin, consistent with the well-documented pattern of
high-latitude and high-elevation amplification — but it is small
relative to the regional signal.

**Precipitation is increasing significantly only in the two northernmost
ecoregions.** Across the FWCP Peace as a whole, the long-term trend in
annual precipitation is not statistically significant. Broken out by
ecoregion, Boreal Mountains and Plateaus and Northern Canadian Rocky
Mountains — both in the northern half of the region — show real
increases in annual precipitation (p = 0.02 and 0.01). The southern and
central ecoregions show no significant change. This is a
north-versus-south contrast that the regional average hides, and the
place where breaking the analysis down by ecoregion was worth doing.

Mapping that contrast onto the watershed-group reporting unit: five
watershed groups sit in or are dominated by the wetter ecoregions —
Toodoggone, Firesteel and Ingenika sit almost entirely within Boreal
Mountains and Plateaus, and Finlay and Fox are mostly in Northern
Canadian Rocky Mountains. For these, the small upward precipitation
trend is statistically defensible. The remaining 13 watershed groups sit
elsewhere — Fraser Basin, Central Canadian Rockies, Omineca Mountains —
where annual precipitation has not changed in a way distinguishable from
natural variability.

**The atmosphere is drying despite, in places, more precipitation.**
Vapour pressure deficit — the gap between how much water the air could
hold and how much it actually does — rose significantly in every
ecoregion (p \< 0.005 across all five). Warmer air holds more water
before saturating, and that pulls moisture out of soil and vegetation
through evaporation and transpiration. Soil moisture is essentially flat
in every ecoregion — even where precipitation increased — because the
warmer atmosphere is drinking the extra water back. This is the headline
ecological finding for the region: water inputs may be rising in places,
but soil and vegetation are not seeing more available moisture.

For the cold-water salmonids the FWCP supports — bull trout, Arctic
grayling, mountain whitefish, rainbow trout — these signals point in the
same direction. Stream temperatures are likely rising in step with
warmer ambient air temperatures, and the evapotranspiration imbalance
means low-flow conditions in late summer are not being relieved by the
precipitation increase that did occur.
