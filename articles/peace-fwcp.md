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
| snow_cover | annual | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snow_cover_annual.tif> |
| snow_cover | fall | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snow_cover_fall.tif> |
| snow_cover | spring | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snow_cover_spring.tif> |
| snow_cover | summer | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snow_cover_summer.tif> |
| snow_cover | winter | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snow_cover_winter.tif> |
| snowfall | annual | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snowfall_annual.tif> |
| snowfall | fall | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snowfall_fall.tif> |
| snowfall_fraction | annual | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snowfall_fraction_annual.tif> |
| snowfall | spring | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snowfall_spring.tif> |
| snowfall | summer | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snowfall_summer.tif> |
| snowfall | winter | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snowfall_winter.tif> |
| snowmelt | annual | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snowmelt_annual.tif> |
| snowmelt_doy_50 | annual | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snowmelt_doy_50_annual.tif> |
| snowmelt | fall | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snowmelt_fall.tif> |
| snowmelt_rate_peak | annual | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snowmelt_rate_peak_annual.tif> |
| snowmelt | spring | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snowmelt_spring.tif> |
| snowmelt | summer | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snowmelt_summer.tif> |
| snowmelt | winter | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snowmelt_winter.tif> |
| soil_moisture | annual | <https://stac-era5-land.s3.us-west-2.amazonaws.com/soil_moisture_annual.tif> |
| soil_moisture | fall | <https://stac-era5-land.s3.us-west-2.amazonaws.com/soil_moisture_fall.tif> |
| soil_moisture | spring | <https://stac-era5-land.s3.us-west-2.amazonaws.com/soil_moisture_spring.tif> |
| soil_moisture | summer | <https://stac-era5-land.s3.us-west-2.amazonaws.com/soil_moisture_summer.tif> |
| soil_moisture | winter | <https://stac-era5-land.s3.us-west-2.amazonaws.com/soil_moisture_winter.tif> |
| swe | annual | <https://stac-era5-land.s3.us-west-2.amazonaws.com/swe_annual.tif> |
| swe | fall | <https://stac-era5-land.s3.us-west-2.amazonaws.com/swe_fall.tif> |
| swe_max | annual | <https://stac-era5-land.s3.us-west-2.amazonaws.com/swe_max_annual.tif> |
| swe | spring | <https://stac-era5-land.s3.us-west-2.amazonaws.com/swe_spring.tif> |
| swe | summer | <https://stac-era5-land.s3.us-west-2.amazonaws.com/swe_summer.tif> |
| swe | winter | <https://stac-era5-land.s3.us-west-2.amazonaws.com/swe_winter.tif> |
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
1951–1980, the three decades before climate change accelerated. This is
the same base period Hansen et al.
([2012](#ref-hansen_etal2012Perceptionclimate)) use to detect the
emergence of 3-sigma summertime-temperature outliers globally. Saying a
year is “+1.5 °C” means it was 1.5 °C warmer than the average year
between 1951 and 1980.

The trend table that follows has two rows per variable. We compute
trends from two different start years:

- **1951–present (75 years)** — the long view. Captures the full
  magnitude of warming since the pre-warming reference.
- **1981–present (45 years)** — starts at the beginning of the World
  Meteorological Organization’s most recent 30-year “climate normal”
  (1981–2010) ([Arguez and Vose
  2011](#ref-arguez_vose2011DefinitionStandard)). This is the reference
  period used in most published climate products, so it makes results
  easy to compare against Intergovernmental Panel on Climate Change
  reports and government climate summaries.

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

| Parameter | Period | Slope | Years | Total Change | Unit | p-value |
|:---|:---|---:|---:|---:|:---|---:|
| Precipitation | Annual | 0.085 | 75 | 6.4 | % | 0.1971 |
| Relative humidity | Annual | 0.001 | 75 | 0.1 | % | 0.8620 |
| Snow cover | Annual | -0.053 | 75 | -4.0 | % | 0.0026 |
| Snowfall | Annual | -0.088 | 75 | -6.6 | % | 0.2528 |
| Snowfall fraction | Annual | -0.079 | 75 | -5.9 | % | 0.0078 |
| Snowmelt | Annual | -0.039 | 75 | -2.9 | % | 0.5279 |
| Day of 50% melt | Annual | -0.150 | 75 | -11.3 | day | 0.0018 |
| Peak weekly melt rate | Annual | 0.101 | 75 | 7.6 | mm/wk | 0.3848 |
| Soil moisture | Annual | -0.002 | 75 | -0.1 | % | 0.8981 |
| Snow water equivalent | Annual | -0.098 | 75 | -7.3 | % | 0.2644 |
| Annual peak snow water equivalent | Annual | -0.075 | 75 | -5.7 | mm | 0.7697 |
| Maximum temperature | Annual | 0.027 | 75 | 2.0 | °C | 0.0000 |
| Mean temperature | Annual | 0.030 | 75 | 2.2 | °C | 0.0000 |
| Minimum temperature | Annual | 0.032 | 75 | 2.4 | °C | 0.0000 |
| Vapour pressure deficit | Annual | 0.005 | 75 | 0.3 | Pa | 0.0008 |
| Precipitation | Fall | 0.065 | 75 | 4.9 | % | 0.4926 |
| Relative humidity | Fall | -0.016 | 75 | -1.2 | % | 0.0906 |
| Snow cover | Fall | -0.032 | 75 | -2.4 | % | 0.4051 |
| Snowfall | Fall | 0.019 | 75 | 1.4 | % | 0.9344 |
| Snowmelt | Fall | -0.149 | 75 | -11.2 | % | 0.4208 |
| Soil moisture | Fall | 0.000 | 75 | 0.0 | % | 0.9964 |
| Snow water equivalent | Fall | 0.006 | 75 | 0.4 | % | 0.9854 |
| Maximum temperature | Fall | 0.013 | 75 | 1.0 | °C | 0.0659 |
| Mean temperature | Fall | 0.020 | 75 | 1.5 | °C | 0.0099 |
| Minimum temperature | Fall | 0.025 | 75 | 1.9 | °C | 0.0027 |
| Vapour pressure deficit | Fall | 0.002 | 75 | 0.2 | Pa | 0.0323 |
| Precipitation | Spring | 0.184 | 75 | 13.8 | % | 0.1644 |
| Relative humidity | Spring | -0.009 | 75 | -0.7 | % | 0.3848 |
| Snow cover | Spring | -0.047 | 75 | -3.5 | % | 0.0014 |
| Snowfall | Spring | -0.102 | 75 | -7.6 | % | 0.4587 |
| Snowmelt | Spring | 0.559 | 75 | 41.9 | % | 0.0006 |
| Soil moisture | Spring | 0.032 | 75 | 2.4 | % | 0.0151 |
| Snow water equivalent | Spring | -0.119 | 75 | -8.9 | % | 0.2723 |
| Maximum temperature | Spring | 0.025 | 75 | 1.9 | °C | 0.0007 |
| Mean temperature | Spring | 0.028 | 75 | 2.1 | °C | 0.0001 |
| Minimum temperature | Spring | 0.027 | 75 | 2.0 | °C | 0.0001 |
| Vapour pressure deficit | Spring | 0.005 | 75 | 0.4 | Pa | 0.0001 |
| Precipitation | Summer | 0.175 | 75 | 13.1 | % | 0.1847 |
| Relative humidity | Summer | -0.007 | 75 | -0.6 | % | 0.7558 |
| Snow cover | Summer | -0.121 | 75 | -9.1 | % | 0.0008 |
| Snowfall | Summer | -0.735 | 75 | -55.1 | % | 0.0015 |
| Snowmelt | Summer | -0.807 | 75 | -60.5 | % | 0.0066 |
| Soil moisture | Summer | -0.036 | 75 | -2.7 | % | 0.1728 |
| Snow water equivalent | Summer | -0.792 | 75 | -59.4 | % | 0.0029 |
| Maximum temperature | Summer | 0.026 | 75 | 2.0 | °C | 0.0004 |
| Mean temperature | Summer | 0.031 | 75 | 2.4 | °C | 0.0000 |
| Minimum temperature | Summer | 0.035 | 75 | 2.6 | °C | 0.0000 |
| Vapour pressure deficit | Summer | 0.009 | 75 | 0.7 | Pa | 0.0338 |
| Precipitation | Winter | -0.050 | 75 | -3.8 | % | 0.6606 |
| Relative humidity | Winter | 0.035 | 75 | 2.7 | % | 0.0026 |
| Snow cover | Winter | 0.000 | 75 | 0.0 | % | 0.2816 |
| Snowfall | Winter | -0.044 | 75 | -3.3 | % | 0.7076 |
| Snowmelt | Winter | 0.056 | 75 | 4.2 | % | 0.5987 |
| Soil moisture | Winter | -0.005 | 75 | -0.4 | % | 0.4983 |
| Snow water equivalent | Winter | 0.009 | 75 | 0.7 | % | 0.9126 |
| Maximum temperature | Winter | 0.045 | 75 | 3.4 | °C | 0.0000 |
| Mean temperature | Winter | 0.044 | 75 | 3.3 | °C | 0.0002 |
| Minimum temperature | Winter | 0.043 | 75 | 3.3 | °C | 0.0003 |
| Vapour pressure deficit | Winter | 0.001 | 75 | 0.1 | Pa | 0.0007 |
| Precipitation | Annual | -0.010 | 45 | -0.4 | % | 0.9298 |
| Relative humidity | Annual | -0.016 | 45 | -0.7 | % | 0.3947 |
| Snow cover | Annual | -0.063 | 45 | -2.8 | % | 0.0516 |
| Snowfall | Annual | -0.073 | 45 | -3.3 | % | 0.6317 |
| Snowfall fraction | Annual | -0.003 | 45 | -0.1 | % | 0.9143 |
| Snowmelt | Annual | -0.107 | 45 | -4.8 | % | 0.3947 |
| Day of 50% melt | Annual | -0.119 | 45 | -5.4 | day | 0.2141 |
| Peak weekly melt rate | Annual | 0.090 | 45 | 4.1 | mm/wk | 0.6598 |
| Soil moisture | Annual | -0.017 | 45 | -0.7 | % | 0.6041 |
| Snow water equivalent | Annual | -0.116 | 45 | -5.2 | % | 0.6598 |
| Annual peak snow water equivalent | Annual | -0.251 | 45 | -11.3 | mm | 0.6884 |
| Maximum temperature | Annual | 0.021 | 45 | 0.9 | °C | 0.0449 |
| Mean temperature | Annual | 0.023 | 45 | 1.0 | °C | 0.0264 |
| Minimum temperature | Annual | 0.024 | 45 | 1.1 | °C | 0.0116 |
| Vapour pressure deficit | Annual | 0.005 | 45 | 0.2 | Pa | 0.0963 |
| Precipitation | Fall | 0.083 | 45 | 3.7 | % | 0.6884 |
| Relative humidity | Fall | -0.022 | 45 | -1.0 | % | 0.1678 |
| Snow cover | Fall | -0.078 | 45 | -3.5 | % | 0.3630 |
| Snowfall | Fall | -0.046 | 45 | -2.1 | % | 0.7767 |
| Snowmelt | Fall | 0.177 | 45 | 8.0 | % | 0.6740 |
| Soil moisture | Fall | -0.003 | 45 | -0.2 | % | 0.9376 |
| Snow water equivalent | Fall | -0.443 | 45 | -19.9 | % | 0.3328 |
| Maximum temperature | Fall | 0.029 | 45 | 1.3 | °C | 0.0338 |
| Mean temperature | Fall | 0.038 | 45 | 1.7 | °C | 0.0053 |
| Minimum temperature | Fall | 0.046 | 45 | 2.1 | °C | 0.0014 |
| Vapour pressure deficit | Fall | 0.005 | 45 | 0.2 | Pa | 0.0834 |
| Precipitation | Spring | -0.231 | 45 | -10.4 | % | 0.3044 |
| Relative humidity | Spring | -0.054 | 45 | -2.4 | % | 0.0227 |
| Snow cover | Spring | -0.047 | 45 | -2.1 | % | 0.2444 |
| Snowfall | Spring | -0.267 | 45 | -12.0 | % | 0.4631 |
| Snowmelt | Spring | 0.550 | 45 | 24.7 | % | 0.0944 |
| Soil moisture | Spring | -0.010 | 45 | -0.5 | % | 0.7100 |
| Snow water equivalent | Spring | -0.127 | 45 | -5.7 | % | 0.6041 |
| Maximum temperature | Spring | 0.011 | 45 | 0.5 | °C | 0.6179 |
| Mean temperature | Spring | 0.006 | 45 | 0.3 | °C | 0.7468 |
| Minimum temperature | Spring | 0.003 | 45 | 0.1 | °C | 0.7917 |
| Vapour pressure deficit | Spring | 0.008 | 45 | 0.4 | Pa | 0.0141 |
| Precipitation | Summer | -0.121 | 45 | -5.4 | % | 0.7468 |
| Relative humidity | Summer | 0.001 | 45 | 0.0 | % | 0.9922 |
| Snow cover | Summer | -0.118 | 45 | -5.3 | % | 0.0766 |
| Snowfall | Summer | -0.544 | 45 | -24.5 | % | 0.1295 |
| Snowmelt | Summer | -0.822 | 45 | -37.0 | % | 0.0944 |
| Soil moisture | Summer | -0.069 | 45 | -3.1 | % | 0.2952 |
| Snow water equivalent | Summer | -0.659 | 45 | -29.7 | % | 0.0799 |
| Maximum temperature | Summer | 0.030 | 45 | 1.3 | °C | 0.0617 |
| Mean temperature | Summer | 0.034 | 45 | 1.5 | °C | 0.0113 |
| Minimum temperature | Summer | 0.036 | 45 | 1.6 | °C | 0.0015 |
| Vapour pressure deficit | Summer | 0.009 | 45 | 0.4 | Pa | 0.4057 |
| Precipitation | Winter | 0.187 | 45 | 8.4 | % | 0.4281 |
| Relative humidity | Winter | 0.021 | 45 | 1.0 | % | 0.3527 |
| Snow cover | Winter | 0.000 | 45 | 0.0 | % | 0.3945 |
| Snowfall | Winter | 0.145 | 45 | 6.5 | % | 0.4631 |
| Snowmelt | Winter | 0.419 | 45 | 18.9 | % | 0.3376 |
| Soil moisture | Winter | -0.003 | 45 | -0.1 | % | 0.8911 |
| Snow water equivalent | Winter | 0.068 | 45 | 3.1 | % | 0.8220 |
| Maximum temperature | Winter | 0.015 | 45 | 0.7 | °C | 0.4752 |
| Mean temperature | Winter | 0.007 | 45 | 0.3 | °C | 0.7321 |
| Minimum temperature | Winter | 0.005 | 45 | 0.2 | °C | 0.7917 |
| Vapour pressure deficit | Winter | 0.000 | 45 | 0.0 | Pa | 0.8220 |

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
([Karl et al. 1993](#ref-karl_etal1993NewPerspective)). Whether a
watershed or region shows that signal depends on local geography (valley
inversions, snow cover, slope-aspect mix).

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

## Snowpack

Snowpack is the hinge of BC hydrology: winter precipitation falls as
snow, accumulates on the ground, and releases as meltwater across spring
and summer. That seasonal storage is the difference between a
late-summer creek that still flows and one that doesn’t. It also sets
the timing of the spring freshet — the annual flood pulse that salmonids
time their up-river migrations to. Cordillera-wide, snowpack has been
declining for decades ([Mote et al.
2018](#ref-mote_etal2018Dramaticdeclines); [Pederson et al.
2011](#ref-pederson_etal2011UnusualNature)). For four BC river basins
(Fraser, Peace, Columbia, Campbell), Najafi et al.
([2017](#ref-najafi_etal2017AttributionObserved)) attribute observed
spring SWE decline to anthropogenic forcing using formal
detection-attribution. For the Fraser specifically, Kang et al.
([2016](#ref-kang_etal2016ImpactsRapidly)) document a ~10-day advance of
the spring freshet over 1949-2006, with declining summer flows during
the salmon migration window.

**For the FWCP Peace Region, the snowpack signal in our data is
unambiguous and concentrated in the warm shoulders of the year.** Annual
snow water equivalent (SWE) declined ~10% (135 → 122 mm), but the
seasonal breakdown is sharper: **summer SWE collapsed by 75%** (21.5 →
5.3 mm) and **spring snowmelt rose 37%** (212 → 290 mm) as the freshet
shifted earlier into the calendar. Total annual snowfall barely changed
(-6%) — the SWE decline is mostly about warming removing snow earlier,
not less snow falling.

A few notes on how to read the snow numbers below.

ERA5-Land represents snow on a roughly 9 km grid — each grid cell is a
single number summarizing snow averaged over about 80 km² of mixed
terrain (saddles, slopes, valleys, forest, exposed alpine, all
combined). When we compare the model against a snow station inside that
cell, two distinct errors can stack: a **scale mismatch** (a single
point measurement isn’t the same thing as an 80 km² average, especially
in mountain terrain where snow accumulation varies sharply over short
distances), and a **cell-mean bias** that the model has at the Northern
Hemisphere scale (ERA5-Land overestimates mountain SWE by 150-200% even
when compared against area-averaged satellite estimates ([Kouki et al.
2023](#ref-kouki_etal2023Evaluationsnow)), traced to a simplified snow
layer in the underlying atmospheric model).

Our QA cross-check at four British Columbia automated snow stations
inside the FWCP Peace Region (1985-2025, 95 paired station-years) sees
both kinds of error stacked and cannot fully separate them. At Pine Pass
— a Coast Mountain saddle that catches orographic precip from systems
coming inland from the Pacific — the model is 61% too low at the
station, likely mostly scale mismatch: the station sits at a high-snow
microsite within an averaged cell. At Aiken Lake — a drier interior
valley basin — the model is 54% too high, likely a mix of scale mismatch
(averaging snowier surrounding terrain into the same cell) and the
Kouki-style cell-mean bias for interior-continental cells.

What does survive both kinds of error: **the gap between the model and
the stations is the same size in 2020 as it was in 1990.** The bias is
stable over time at every site (regression of model-minus-station on
year is non-significant, p \> 0.2). That means the *changes over time*
shown below — peak snowpack dropping, freshet shifting earlier — are
real even though the absolute mm numbers shouldn’t be quoted as ground
truth. For regional aggregates (the numbers in this section are spatial
means over hundreds of cells), random point-vs-cell mismatches partially
cancel, and stable cell-mean biases preserve the trend signal.

The trend tests below use raw Mann-Kendall plus Theil-Sen — no
pre-whitening — which is the right call for our 76-year series with
strong climate trends per Yue and Wang
([2002](#ref-yue_wang2002Applicabilityprewhitening)) (pre-whitening
underestimates slope when a real trend exists).

### Seasonal snowpack curve

The four monthly-native snow variables — SWE, snowfall, snowmelt, and
snow cover — show *when* snow accumulates and melts. Aggregated to the
four standard meteorological seasons — winter (December–February),
spring (March–May), summer (June–August), and fall (September–November)
— the table below compares the recent decade (2015-2025) against the
pre-warming reference (1951-1980) directly. The headline numbers above
(summer SWE collapse, spring snowmelt rise) are in the **summer** and
**spring** rows.

``` r

snow_monthly <- c("swe", "snowfall", "snowmelt", "snow_cover")
season_order <- c("winter", "spring", "summer", "fall")

snow_seasonal <- cmp_pct[cmp_pct$variable %in% snow_monthly &
                          cmp_pct$period %in% season_order, ]
snow_seasonal$period <- factor(snow_seasonal$period, levels = season_order)
snow_seasonal$variable <- factor(snow_seasonal$variable, levels = snow_monthly,
                                  labels = c("SWE (mm)", "Snowfall (mm)",
                                             "Snowmelt (mm)", "Snow cover (%)"))
snow_seasonal <- snow_seasonal[order(snow_seasonal$variable, snow_seasonal$period), ]
snow_seasonal$mean_a <- round(snow_seasonal$mean_a, 1)
snow_seasonal$mean_b <- round(snow_seasonal$mean_b, 1)
snow_seasonal$difference <- round(snow_seasonal$difference, 1)
snow_seasonal <- snow_seasonal[, c("variable", "period", "mean_b",
                                    "mean_a", "difference")]
names(snow_seasonal) <- c("Variable", "Season",
                          "Pre-warming (1951–1980)",
                          "Recent (2015–2025)", "Δ %")

kableExtra::kable_styling(
  knitr::kable(snow_seasonal, label = NA,
    caption = "Seasonal snowpack: recent decade compared to pre-warming reference for the FWCP Peace Region. Summer SWE collapse (-75%) and spring snowmelt rise (+37%) are the headline signals.",
    row.names = FALSE),
  bootstrap_options = c("striped", "hover", "condensed")
)
```

| Variable      | Season | Pre-warming (1951–1980) | Recent (2015–2025) |   Δ % |
|:--------------|:-------|------------------------:|-------------------:|------:|
| SWE (mm)      | winter |                   195.9 |              192.6 |  -1.7 |
| SWE (mm)      | spring |                   292.8 |              259.6 | -11.4 |
| SWE (mm)      | summer |                    21.5 |                5.3 | -75.5 |
| SWE (mm)      | fall   |                    30.2 |               29.1 |  -3.6 |
| Snowfall (mm) | winter |                   176.3 |              170.0 |  -3.6 |
| Snowfall (mm) | spring |                   109.0 |               94.1 | -13.7 |
| Snowfall (mm) | summer |                    12.0 |                4.9 | -59.5 |
| Snowfall (mm) | fall   |                   135.0 |              136.6 |   1.2 |
| Snowmelt (mm) | winter |                     1.1 |                1.4 |  37.2 |
| Snowmelt (mm) | spring |                   212.2 |              289.9 |  36.6 |
| Snowmelt (mm) | summer |                   165.0 |               63.8 | -61.3 |
| Snowmelt (mm) | fall   |                    30.9 |               25.9 | -16.2 |

Seasonal snowpack: recent decade compared to pre-warming reference for
the FWCP Peace Region. Summer SWE collapse (-75%) and spring snowmelt
rise (+37%) are the headline signals. {.table .table .table-striped
.table-hover .table-condensed
style="margin-left: auto; margin-right: auto;"}

  

### Annual climate-departure signals

Four derived annual scalars capture the climate-departure signals the
literature treats as headline metrics for snow hydrology: peak snowpack
([Mote et al. 2018](#ref-mote_etal2018Dramaticdeclines),
[2005](#ref-mote_etal2005DECLININGMOUNTAIN)), the date of melt midpoint
([Stewart et al. 2005](#ref-stewart_etal2005ChangesEarlier); [Cayan et
al. 2001](#ref-cayan_etal2001ChangesOnset)), freshet flashiness, and the
fraction of precipitation falling as snow ([Knowles et al.
2006](#ref-knowles_etal2006TrendsSnowfall)). Two notes on our specific
implementation. We use the actual annual maximum of daily SWE rather
than the April-1 SWE canon ([Pederson et al.
2011](#ref-pederson_etal2011UnusualNature)) — equivalent in effect for
BC pixels (peak is at or near April 1) but date-insensitive. And our
freshet-flashiness metric (annual maximum of 7-day rolling daily
snowmelt) is upstream of the streamflow-based flashiness measures in the
literature ([Stewart et al. 2005](#ref-stewart_etal2005ChangesEarlier);
[Kang et al. 2016](#ref-kang_etal2016ImpactsRapidly)) — diagnostic of
snowpack-side intensity before routing through soil and channel storage.

``` r

trn_swe_max <- cd_trend(
  ano[ano$variable == "swe_max" & ano$period == "annual", ],
  trend_start = c(1951, 1981)
)
cd_plot_timeseries(ano, variable = "swe_max", period = "annual",
                   trend = trn_swe_max,
                   title = "Annual peak SWE — Anomaly")
```

![Annual peak snow water equivalent (swe_max) for the FWCP Peace Region.
ERA5-Land mm SWE (regional spatial
mean).](peace-fwcp_files/figure-html/snow-swe-max-1.png)

Annual peak snow water equivalent (swe_max) for the FWCP Peace Region.
ERA5-Land mm SWE (regional spatial mean).

``` r

trn_doy <- cd_trend(
  ano[ano$variable == "snowmelt_doy_50" & ano$period == "annual", ],
  trend_start = c(1951, 1981)
)
cd_plot_timeseries(ano, variable = "snowmelt_doy_50", period = "annual",
                   trend = trn_doy,
                   title = "Snowmelt 50% DOY — Anomaly")
```

![Day of year when half the annual snowmelt has accumulated
(snowmelt_doy_50). Earlier dates indicate an earlier freshet
centroid.](peace-fwcp_files/figure-html/snow-doy-50-1.png)

Day of year when half the annual snowmelt has accumulated
(snowmelt_doy_50). Earlier dates indicate an earlier freshet centroid.

``` r

trn_rate <- cd_trend(
  ano[ano$variable == "snowmelt_rate_peak" & ano$period == "annual", ],
  trend_start = c(1951, 1981)
)
cd_plot_timeseries(ano, variable = "snowmelt_rate_peak", period = "annual",
                   trend = trn_rate,
                   title = "Peak weekly melt rate — Anomaly")
```

![Annual maximum of 7-day rolling daily snowmelt (snowmelt_rate_peak).
Higher values indicate more concentrated freshet
pulses.](peace-fwcp_files/figure-html/snow-rate-peak-1.png)

Annual maximum of 7-day rolling daily snowmelt (snowmelt_rate_peak).
Higher values indicate more concentrated freshet pulses.

``` r

trn_frac <- cd_trend(
  ano[ano$variable == "snowfall_fraction" & ano$period == "annual", ],
  trend_start = c(1951, 1981)
)
cd_plot_timeseries(ano, variable = "snowfall_fraction", period = "annual",
                   trend = trn_frac,
                   title = "Snowfall fraction — Anomaly")
```

![Annual snowfall fraction (snowfall_fraction): the percent of annual
precipitation that fell as snow. Anomaly is in percentage
points.](peace-fwcp_files/figure-html/snow-fraction-1.png)

Annual snowfall fraction (snowfall_fraction): the percent of annual
precipitation that fell as snow. Anomaly is in percentage points.

### What this means for the FWCP Peace Region

Three findings carry the snowpack story for the Peace.

**Snow is leaving the region earlier each year, not falling less.**
Total annual snowfall is roughly stable (-6%); the snowpack decline is
dominated by *earlier* melt, not by *less* snow. The seasonal data make
this concrete: spring snowmelt is up 37% while summer snowmelt is down
61% — same total melt, redistributed earlier into the year. This matches
the broader Pacific-Northwest signal documented since Mote et al.
([2005](#ref-mote_etal2005DECLININGMOUNTAIN)).

**The freshet is shifting into spring.** Spring snowmelt up 37% is
direct evidence of an earlier freshet centroid — consistent in direction
and rough magnitude with Stewart et al.’s
([2005](#ref-stewart_etal2005ChangesEarlier)) 1-4 week earlier
streamflow timing across western North America, and with the 10-day
Fraser freshet advance documented by Kang et al.
([2016](#ref-kang_etal2016ImpactsRapidly)) for a basin whose southern
boundary is just south of the FWCP Peace Region.

**Summer is becoming snow-free.** Summer SWE has collapsed by 75% and
summer snowmelt is down 61%. The high-elevation snowpack that
historically lingered into summer no longer does in the recent decade.
For aquatic ecosystems downstream, this is a loss of late- season
cold-water input to streams during the warmest part of the year.

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

no_pct_vars <- c(
  "tmean", "tmax", "tmin",
  # snow_cover and snowfall_fraction are already in % (pct_point_diff
  # anomaly type) — pct-of-baseline mixes units. snowmelt_doy_50 is a
  # day-of-year — pct-change of a date is meaningless.
  "snow_cover", "snowfall_fraction", "snowmelt_doy_50"
)
cmp_combined <- cmp |>
  dplyr::mutate(
    pct_change = ifelse(
      variable %in% no_pct_vars,
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
| snow_cover | annual | 59.89 | 63.84 | -3.95 | NA | 0.003 |
| snow_cover | fall | 49.76 | 52.03 | -2.27 | NA | 0.405 |
| snow_cover | spring | 88.85 | 93.80 | -4.95 | NA | 0.001 |
| snow_cover | summer | 4.22 | 12.80 | -8.58 | NA | 0.001 |
| snow_cover | winter | 96.73 | 96.71 | 0.02 | NA | 0.282 |
| snowfall | annual | 405.53 | 432.37 | -26.84 | -6.2 | 0.253 |
| snowfall | fall | 136.62 | 135.00 | 1.61 | 1.2 | 0.934 |
| snowfall | spring | 94.08 | 109.02 | -14.94 | -13.7 | 0.459 |
| snowfall | summer | 4.87 | 12.02 | -7.15 | -59.5 | 0.002 |
| snowfall | winter | 169.96 | 176.32 | -6.36 | -3.6 | 0.708 |
| snowfall_fraction | annual | 48.45 | 53.56 | -5.10 | NA | 0.008 |
| snowmelt | annual | 381.07 | 409.27 | -28.20 | -6.9 | 0.528 |
| snowmelt | fall | 25.92 | 30.93 | -5.02 | -16.2 | 0.421 |
| snowmelt | spring | 289.89 | 212.24 | 77.65 | 36.6 | 0.001 |
| snowmelt | summer | 63.82 | 165.05 | -101.23 | -61.3 | 0.007 |
| snowmelt | winter | 1.44 | 1.05 | 0.39 | 37.2 | 0.599 |
| snowmelt_doy_50 | annual | 137.74 | 148.50 | -10.75 | NA | 0.002 |
| snowmelt_rate_peak | annual | 118.44 | 116.52 | 1.93 | 1.7 | 0.385 |
| soil_moisture | annual | 0.32 | 0.32 | 0.00 | -0.3 | 0.898 |
| soil_moisture | fall | 0.32 | 0.32 | 0.00 | -0.4 | 0.996 |
| soil_moisture | spring | 0.32 | 0.32 | 0.01 | 1.9 | 0.015 |
| soil_moisture | summer | 0.33 | 0.33 | -0.01 | -2.5 | 0.173 |
| soil_moisture | winter | 0.31 | 0.31 | 0.00 | -0.2 | 0.498 |
| swe | annual | 121.65 | 135.11 | -13.46 | -10.0 | 0.264 |
| swe | fall | 29.15 | 30.24 | -1.09 | -3.6 | 0.985 |
| swe | spring | 259.56 | 292.80 | -33.24 | -11.4 | 0.272 |
| swe | summer | 5.27 | 21.50 | -16.23 | -75.5 | 0.003 |
| swe | winter | 192.64 | 195.91 | -3.27 | -1.7 | 0.913 |
| swe_max | annual | 333.64 | 348.42 | -14.79 | -4.2 | 0.770 |
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

### Snow per ecoregion

Two snow metrics are worth viewing per-ecoregion: peak snow water
equivalent (annual snowpack magnitude) and DOY-50 (the day-of-year by
which half the year’s snowmelt has already happened — earlier values
mean an earlier freshet). The two figures below show how each varies
ecoregion to ecoregion. Pair them with the Watershed Groups Across
Ecoregions section below to read each watershed group’s dominant
ecoregion’s signal.

``` r

ggplot(ano_all[ano_all$variable == "swe_max" & ano_all$period == "annual", ],
       aes(x = year, y = anomaly)) +
  geom_col(aes(fill = anomaly >= 0), width = 0.85, show.legend = FALSE) +
  geom_segment(data = trn_segs_swe_max,
               aes(x = x_start, xend = x_end, y = y_start, yend = y_end,
                   linetype = window),
               inherit.aes = FALSE, color = "black", linewidth = 0.6) +
  scale_fill_manual(values = c(`TRUE` = "#4575b4", `FALSE` = "#d73027")) +
  scale_linetype_manual(values = c("dashed", "solid"), name = "Trend window") +
  facet_wrap(~ ecoregion, ncol = 3,
             labeller = labeller(ecoregion = er_labels)) +
  labs(x = NULL, y = "Peak SWE anomaly (mm)") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")
```

![Annual peak snow water equivalent (SWE) anomaly by ecoregion, relative
to the 1951-1980 baseline. Bars are mm of water-equivalent snowpack
departure from baseline. Dashed line is the 75-year Theil-Sen trend
(1951-present); solid line is the 45-year trend
(1981-present).](peace-fwcp_files/figure-html/facet-swe-max-1.png)

Annual peak snow water equivalent (SWE) anomaly by ecoregion, relative
to the 1951-1980 baseline. Bars are mm of water-equivalent snowpack
departure from baseline. Dashed line is the 75-year Theil-Sen trend
(1951-present); solid line is the 45-year trend (1981-present).

``` r

ggplot(ano_all[ano_all$variable == "snowmelt_doy_50" & ano_all$period == "annual", ],
       aes(x = year, y = anomaly)) +
  geom_col(aes(fill = anomaly >= 0), width = 0.85, show.legend = FALSE) +
  geom_segment(data = trn_segs_doy_50,
               aes(x = x_start, xend = x_end, y = y_start, yend = y_end,
                   linetype = window),
               inherit.aes = FALSE, color = "black", linewidth = 0.6) +
  scale_fill_manual(values = c(`TRUE` = "#d73027", `FALSE` = "#4575b4")) +
  scale_linetype_manual(values = c("dashed", "solid"), name = "Trend window") +
  facet_wrap(~ ecoregion, ncol = 3,
             labeller = labeller(ecoregion = er_labels)) +
  labs(x = NULL, y = "DOY-50 anomaly (days; negative = earlier melt)") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")
```

![Snowmelt 50% day-of-year (DOY-50) anomaly by ecoregion, relative to
the 1951-1980 baseline. Negative values (red) mean the freshet midpoint
shifted earlier in the year. Dashed line is the 75-year Theil-Sen trend;
solid line is the 45-year
trend.](peace-fwcp_files/figure-html/facet-doy-50-1.png)

Snowmelt 50% day-of-year (DOY-50) anomaly by ecoregion, relative to the
1951-1980 baseline. Negative values (red) mean the freshet midpoint
shifted earlier in the year. Dashed line is the 75-year Theil-Sen trend;
solid line is the 45-year trend.

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
Fraser Basin, consistent with the elevation-dependent warming signal
documented at mid-latitude mountain sites ([Pepin et al.
2015](#ref-pepin_etal2015Elevationdependentwarming)), though the
regional evidence base remains heterogeneous and not every mountain
region shows the same pattern ([Rangwala and Miller
2012](#ref-rangwala_miller2012Climatechange)). The gradient is small
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
ecoregion (p \< 0.005 across all five), mirroring the continental-scale
drying that Ficklin and Novick
([2017](#ref-ficklin_novick2017Historicprojected)) documented for the
United States as a whole, driven by combined air-temperature increases
and relative-humidity changes. Warmer air holds more water before
saturating, and that pulls moisture out of soil and vegetation through
evaporation and transpiration. Soil moisture is essentially flat in
every ecoregion — even where precipitation increased — because the
warmer atmosphere is drinking the extra water back. This is the headline
ecological finding for the region: water inputs may be rising in places,
but soil and vegetation are not seeing more available moisture.

**Snow is leaving the region earlier, not falling less.** Annual
snowfall across the FWCP Peace is essentially unchanged (-6%); the
snowpack story is about *timing*, not *quantity*. Spring snowmelt rose
37% (212 → 290 mm) and summer snowmelt fell 61% (165 → 64 mm) — same
total annual melt, redistributed earlier in the calendar. Annual peak
snow water equivalent (SWE) is down about 10% (135 → 122 mm), and most
strikingly, **summer SWE has collapsed by 75%**: the high-elevation
snowpack that historically lingered into June and July no longer does.
This is the direct mechanism behind the freshet shift described in the
snow-trend literature: warmer winters and springs do not stop snow from
falling — they shorten how long it stays on the ground.

The freshet-timing signal is *broadly uniform across the region* —
DOY-50 (day-of-year by which half the year’s snowmelt has happened) is
shifting earlier at roughly 1 day per decade in every one of the five
ecoregions, with Mann-Kendall p-values below 0.01 in each (median p ≈
0.005). All sixteen FWCP Peace watershed groups, regardless of which
ecoregion they sit in, are seeing the same order-of-magnitude earlier
melt. The peak-SWE signal is noisier — small recent-decade declines show
up in every ecoregion, but the year-to-year variability is large enough
that the long-term Theil-Sen slopes do not reach statistical
significance at the ecoregion scale. The 75% summer-SWE collapse is
detectable in the regional aggregate because spatial averaging
suppresses that variability.

For the cold-water resident salmonids the FWCP Peace supports — bull
trout, Arctic grayling, mountain whitefish, rainbow trout, kokanee —
these signals compound. Stream temperatures are likely rising in step
with warmer ambient air temperatures, with the combined effects of
warming summer stream temperatures and altered low flows likely reducing
thermally-suitable habitat for cold-water species ([Mantua et al.
2010](#ref-mantua_etal2010Climatechange); [Eaton and Scheller
1996](#ref-eaton_scheller1996Effectsclimate)). The evapotranspiration
imbalance means low-flow conditions in late summer are not being
relieved by the precipitation increase that did occur; and the
cold-water input that high-elevation snowpack provides to streams during
the warmest, most thermally stressful weeks of summer is dropping in
parallel with summer SWE. The spring freshet — the dominant high-flow
event that shapes channel morphology, mobilizes spawning gravels, and
refills off-channel rearing habitat — is shifting weeks earlier; the
neighbouring Fraser Basin documents the same kind of freshet advance
([Kang et al. 2016](#ref-kang_etal2016ImpactsRapidly)) at comparable
magnitude.

## References

Arguez, Anthony, and Russell S. Vose. 2011. “The Definition of the
Standard WMO Climate Normal: The Key to Deriving Alternative Climate
Normals.” *Bulletin of the American Meteorological Society* 92 (6):
699–704. <https://doi.org/10.1175/2010BAMS2955.1>.

Cayan, Daniel R., Michael D. Dettinger, Susan A. Kammerdiener, Joseph M.
Caprio, and David H. Peterson. 2001. “Changes in the Onset of Spring in
the Western United States.” *Bulletin of the American Meteorological
Society* 82 (3): 399–415.
<https://doi.org/10.1175/1520-0477(2001)082%3C0399:citoos%3E2.3.co;2>.

Eaton, John G., and Robert M. Scheller. 1996. “Effects of Climate
Warming on Fish Thermal Habitat in Streams of the United States.”
*Limnology and Oceanography* 41 (5): 1109–15.
<https://doi.org/10.4319/lo.1996.41.5.1109>.

Ficklin, Darren L., and Kimberly A. Novick. 2017. “Historic and
Projected Changes in Vapor Pressure Deficit Suggest a Continental‐scale
Drying of the United States Atmosphere.” *Journal of Geophysical
Research: Atmospheres* 122 (4): 2061–79.
<https://doi.org/10.1002/2016JD025855>.

Hansen, James, Makiko Sato, and Reto Ruedy. 2012. “Perception of Climate
Change.” *Proceedings of the National Academy of Sciences* 109 (37).
<https://doi.org/10.1073/pnas.1205276109>.

Kang, Do Hyuk, Huilin Gao, Xiaogang Shi, Siraj ul Islam, and Stephen J.
Déry. 2016. “Impacts of a Rapidly Declining Mountain Snowpack on
Streamflow Timing in Canada’s Fraser River Basin.” *Scientific Reports*
6 (1). <https://doi.org/10.1038/srep19299>.

Karl, Thomas R., Richard W. Knight, Kevin P. Gallo, et al. 1993. “A New
Perspective on Recent Global Warming: Asymmetric Trends of Daily Maximum
and Minimum Temperature.” *Bulletin of the American Meteorological
Society* 74 (6): 1007–23.
<https://doi.org/10.1175/1520-0477(1993)074%3C1007:ANPORG%3E2.0.CO;2>.

Knowles, Noah, Michael D. Dettinger, and Daniel R. Cayan. 2006. “Trends
in Snowfall Versus Rainfall in the Western United States.” *Journal of
Climate* 19 (18): 4545–59. <https://doi.org/10.1175/jcli3850.1>.

Kouki, Kerttu, Kari Luojus, and Aku Riihelä. 2023. “Evaluation of Snow
Cover Properties in ERA5 and ERA5-Land with Several Satellite-Based
Datasets in the Northern Hemisphere in Spring 1982–2018.” *The
Cryosphere* 17 (12): 5007–26. <https://doi.org/10.5194/tc-17-5007-2023>.

Mantua, Nathan, Ingrid Tohver, and Alan Hamlet. 2010. “Climate Change
Impacts on Streamflow Extremes and Summertime Stream Temperature and
Their Possible Consequences for Freshwater Salmon Habitat in Washington
State.” *Climatic Change* 102 (1–2): 187–223.
<https://doi.org/10.1007/s10584-010-9845-2>.

Mote, Philip W., Alan F. Hamlet, Martyn P. Clark, and Dennis P.
Lettenmaier. 2005. “DECLINING MOUNTAIN SNOWPACK IN WESTERN NORTH
AMERICA\*.” *Bulletin of the American Meteorological Society* 86 (1):
39–50. <https://doi.org/10.1175/bams-86-1-39>.

Mote, Philip W., Sihan Li, Dennis P. Lettenmaier, Mu Xiao, and Ruth
Engel. 2018. “Dramatic Declines in Snowpack in the Western US.” *Npj
Climate and Atmospheric Science* 1 (1).
<https://doi.org/10.1038/s41612-018-0012-1>.

Najafi, Mohammad Reza, Francis Zwiers, and Nathan Gillett. 2017.
“Attribution of the Observed Spring Snowpack Decline in British Columbia
to Anthropogenic Climate Change.” *Journal of Climate* 30 (11): 4113–30.
<https://doi.org/10.1175/jcli-d-16-0189.1>.

Pederson, Gregory T., Stephen T. Gray, Connie A. Woodhouse, et al. 2011.
“The Unusual Nature of Recent Snowpack Declines in the North American
Cordillera.” *Science* 333 (6040): 332–35.
<https://doi.org/10.1126/science.1201570>.

Pepin, N., R. S. Bradley, H. F. Diaz, et al. 2015. “Elevation-Dependent
Warming in Mountain Regions of the World.” *Nature Climate Change* 5
(5): 424–30. <https://doi.org/10.1038/nclimate2563>.

Rangwala, Imtiaz, and James R. Miller. 2012. “Climate Change in
Mountains: A Review of Elevation-Dependent Warming and Its Possible
Causes.” *Climatic Change* 114 (3–4): 527–47.
<https://doi.org/10.1007/s10584-012-0419-3>.

Stewart, Iris T., Daniel R. Cayan, and Michael D. Dettinger. 2005.
“Changes Toward Earlier Streamflow Timing Across Western North America.”
*Journal of Climate* 18 (8): 1136–55.
<https://doi.org/10.1175/jcli3321.1>.

Yue, Sheng, and Chun Yuan Wang. 2002. “Applicability of Prewhitening to
Eliminate the Influence of Serial Correlation on the Mann‐Kendall Test.”
*Water Resources Research* 38 (6).
<https://doi.org/10.1029/2001wr000861>.
