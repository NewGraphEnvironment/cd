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

The bundled AOI is the FWCP Peace Region polygon (single multi-polygon,
EPSG:4326). Any `sf` polygon works. The watersheds within this region
all drain to the Mackenzie River — the Peace flows east into the Slave,
which flows into the Mackenzie, which empties into the Beaufort Sea on
the Arctic Ocean. This is the Arctic-draining side of British Columbia,
distinct from the Pacific-draining watersheds south and west of the
Continental Divide.

We also carry BC ecoregions through the analysis. Ecoregions partition
the province into broad climate-physiography zones based on latitude,
elevation, and dominant vegetation. Climate departure can vary across
them in ways the regional average hides, and we use them later as the
sub-region for the per-ecoregion breakdown.

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
British Columbia, coloured by BC ecoregion. Williston Reservoir
dominates the basin.](peace-fwcp_files/figure-html/map-location-1.png)

FWCP Peace Region area of interest (~73,000 km^2) in northeastern
British Columbia, coloured by BC ecoregion. Williston Reservoir
dominates the basin.

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
  knitr::kable(catalog, caption = NA),
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

  

## Extract Climate Time Series

[`cd_extract()`](https://newgraphenvironment.github.io/cd/reference/cd_extract.md)
crops each cloud-hosted COG to the AOI and computes the spatial mean per
year. For an AOI of this size, expect a few seconds per variable rather
than the sub-second extraction you get with a small watershed.

``` r

ts <- cd_extract(catalog, aoi)
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

trn <- cd_trend(ano, trend_start = c(1951, 1981))
kableExtra::kable_styling(
  knitr::kable(cd_summary(trn), caption = NA),
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

For the FWCP Peace Region, **overnight minimums are warming faster than
daytime maximums** — the textbook day-night asymmetry. Daytime maximums
warmed about +0.027 °C per year since 1951 (+2.0 °C cumulative), while
overnight minimums warmed about +0.032 °C per year (+2.4 °C cumulative).
The overnight side warmed roughly 0.4 °C more than the daytime side over
the full record, narrowing the diurnal temperature range by the same
amount.

## Recent vs Pre-warming

The tables below compare two windows directly — the recent decade
(2015–2025) against the pre-warming reference (1951–1980). Each row
includes the long-term Mann-Kendall p-value from the trend test (the
75-year window) so you can see whether the variable also has a
statistically significant monotonic trend. A small p-value (rule of
thumb: \< 0.05) means the trend is unlikely to be noise. The trend test
asks a slightly different question than “are these two windows
different” — it tests for a steady directional change — but it is the
closest available proxy for now.

``` r

cmp <- cd_compare(ts,
  window_a = 2015:2025,
  window_b = 1951:1980,
  method = "mean_diff"
)
cmp <- merge(cmp, trn_p, by = c("variable", "period"), all.x = TRUE)
kableExtra::kable_styling(
  knitr::kable(cmp, caption = NA, digits = 2),
  bootstrap_options = c("striped", "hover", "condensed")
) |>
  kableExtra::scroll_box(height = "320px")
```

| variable      | period | mean_a | mean_b | difference | method    | trend_p |
|:--------------|:-------|-------:|-------:|-----------:|:----------|--------:|
| prcp          | annual | 835.20 | 803.11 |      32.08 | mean_diff |    0.20 |
| prcp          | fall   | 239.18 | 230.76 |       8.42 | mean_diff |    0.49 |
| prcp          | spring | 155.72 | 150.62 |       5.10 | mean_diff |    0.16 |
| prcp          | summer | 266.04 | 242.15 |      23.89 | mean_diff |    0.18 |
| prcp          | winter | 174.26 | 179.59 |      -5.33 | mean_diff |    0.66 |
| rh            | annual |  74.08 |  74.08 |       0.00 | mean_diff |    0.86 |
| rh            | fall   |  79.38 |  80.16 |      -0.78 | mean_diff |    0.09 |
| rh            | spring |  68.43 |  69.49 |      -1.06 | mean_diff |    0.38 |
| rh            | summer |  67.25 |  67.63 |      -0.38 | mean_diff |    0.76 |
| rh            | winter |  81.25 |  79.05 |       2.20 | mean_diff |    0.00 |
| soil_moisture | annual |   0.32 |   0.32 |       0.00 | mean_diff |    0.90 |
| soil_moisture | fall   |   0.32 |   0.32 |       0.00 | mean_diff |    1.00 |
| soil_moisture | spring |   0.32 |   0.32 |       0.01 | mean_diff |    0.01 |
| soil_moisture | summer |   0.33 |   0.33 |      -0.01 | mean_diff |    0.17 |
| soil_moisture | winter |   0.31 |   0.31 |       0.00 | mean_diff |    0.50 |
| tmax          | annual |   3.66 |   1.99 |       1.67 | mean_diff |    0.00 |
| tmax          | fall   |   3.49 |   2.55 |       0.93 | mean_diff |    0.07 |
| tmax          | spring |   3.93 |   2.16 |       1.76 | mean_diff |    0.00 |
| tmax          | summer |  16.62 |  15.00 |       1.62 | mean_diff |    0.00 |
| tmax          | winter |  -9.40 | -11.77 |       2.37 | mean_diff |    0.00 |
| tmean         | annual |  -0.59 |  -2.41 |       1.82 | mean_diff |    0.00 |
| tmean         | fall   |  -0.32 |  -1.58 |       1.26 | mean_diff |    0.01 |
| tmean         | spring |  -0.75 |  -2.57 |       1.82 | mean_diff |    0.00 |
| tmean         | summer |  11.64 |   9.76 |       1.88 | mean_diff |    0.00 |
| tmean         | winter | -12.92 | -15.27 |       2.34 | mean_diff |    0.00 |
| tmin          | annual |  -4.12 |  -6.05 |       1.93 | mean_diff |    0.00 |
| tmin          | fall   |  -3.19 |  -4.71 |       1.52 | mean_diff |    0.00 |
| tmin          | spring |  -4.76 |  -6.49 |       1.74 | mean_diff |    0.00 |
| tmin          | summer |   6.93 |   4.81 |       2.12 | mean_diff |    0.00 |
| tmin          | winter | -15.47 | -17.81 |       2.33 | mean_diff |    0.00 |
| vpd           | annual |   2.14 |   1.86 |       0.28 | mean_diff |    0.00 |
| vpd           | fall   |   1.48 |   1.32 |       0.16 | mean_diff |    0.03 |
| vpd           | spring |   2.05 |   1.67 |       0.38 | mean_diff |    0.00 |
| vpd           | summer |   4.62 |   4.06 |       0.55 | mean_diff |    0.03 |
| vpd           | winter |   0.43 |   0.40 |       0.03 | mean_diff |    0.00 |

  

``` r

cmp_pct <- cd_compare(
  ts[ts$variable %in% c("prcp", "soil_moisture"), ],
  window_a = 2015:2025,
  window_b = 1951:1980,
  method = "pct_change"
)
cmp_pct <- merge(cmp_pct, trn_p, by = c("variable", "period"), all.x = TRUE)
knitr::kable(cmp_pct, caption = NA, digits = 1)
```

| variable      | period | mean_a | mean_b | difference | method     | trend_p |
|:--------------|:-------|-------:|-------:|-----------:|:-----------|--------:|
| prcp          | annual |  835.2 |  803.1 |        4.0 | pct_change |     0.2 |
| prcp          | fall   |  239.2 |  230.8 |        3.7 | pct_change |     0.5 |
| prcp          | spring |  155.7 |  150.6 |        3.4 | pct_change |     0.2 |
| prcp          | summer |  266.0 |  242.1 |        9.9 | pct_change |     0.2 |
| prcp          | winter |  174.3 |  179.6 |       -3.0 | pct_change |     0.7 |
| soil_moisture | annual |    0.3 |    0.3 |       -0.3 | pct_change |     0.9 |
| soil_moisture | fall   |    0.3 |    0.3 |       -0.4 | pct_change |     1.0 |
| soil_moisture | spring |    0.3 |    0.3 |        1.9 | pct_change |     0.0 |
| soil_moisture | summer |    0.3 |    0.3 |       -2.5 | pct_change |     0.2 |
| soil_moisture | winter |    0.3 |    0.3 |       -0.2 | pct_change |     0.5 |

  

## Spatial Pattern

The zonal mean reduces a region this size to a single number; the
spatial pattern carries the rest of the story.

``` r

tmean_row <- catalog[catalog$variable == "tmean" & catalog$period == "annual", ]
r_tmean <- cd_crop(tmean_row$href, aoi)

years <- as.integer(names(r_tmean))
recent_idx     <- which(years >= 2015 & years <= 2025)
historical_idx <- which(years >= 1951 & years <= 1980)

departure <- mean(r_tmean[[recent_idx]]) - mean(r_tmean[[historical_idx]])
departure <- terra::mask(departure, aoi)
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
knitr::kable(rollup, row.names = FALSE, caption = NA)
```

| Ecoregion | tmean degC/dec | tmax degC/dec | tmin degC/dec | prcp mm/yr | prcp p | vpd hPa/dec | vpd p | prcp pct change | soil moisture pct change |
|:---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| FAB | 0.29 | 0.26 | 0.30 | 0.032 | 0.634 | 0.061 | 0.002 | 0.8 | -1.3 |
| CRM | 0.29 | 0.25 | 0.30 | 0.077 | 0.253 | 0.045 | 0.001 | 4.1 | -0.5 |
| OMM | 0.32 | 0.29 | 0.34 | 0.052 | 0.421 | 0.054 | 0.000 | 2.5 | -0.7 |
| BMP | 0.30 | 0.27 | 0.33 | 0.144 | 0.023 | 0.033 | 0.003 | 6.3 | 0.3 |
| NRM | 0.29 | 0.26 | 0.31 | 0.156 | 0.015 | 0.030 | 0.004 | 6.6 | 0.6 |

Ecoregion codes used in the table above: FAB — Fraser Basin; CRM —
Central Canadian Rocky Mountains; OMM — Omineca Mountains; BMP — Boreal
Mountains and Plateaus; NRM — Northern Canadian Rocky Mountains.

  

  

## Interpretation

Three findings emerge from the FWCP Peace Region trends.

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
