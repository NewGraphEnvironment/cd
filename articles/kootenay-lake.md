# Climate Departure for the Kootenay Lake Region

The `cd` package builds on ERA5-Land hourly reanalysis (1950–present, ~9
km native grid) fetched from the DestinE Earth Data Hub, aggregated to
monthly, seasonal, and annual periods over British Columbia, and
published as Cloud-Optimized GeoTIFFs alongside a static STAC catalog in
a public S3 bucket. R consumer functions read those GeoTIFFs directly
via GDAL, crop to any area of interest, and compute baselines,
anomalies, and Mann-Kendall / Theil-Sen trend statistics.

This vignette runs the consumer pipeline on a four-watershed-group area
in the southern interior of British Columbia: Kootenay Lake (`KOTL`),
Lower Arrow Lake (`LARL`, which covers Trail / Rossland / Red Mountain
at its south end), Duncan Lake (`DUNC`, draining the north end of
Kootenay Lake including the Lardeau valley), and Slocan River (`SLOC`,
between the Selkirks and Monashees). The four watershed groups together
total ~24,000 km² and span the east-west precipitation gradient that
defines the snowpack story for the region — Selkirk Pacific spillover
west of Kootenay Lake, Purcell rain shadow east.

## Area of Interest

The bundled area of interest is the union of the four watershed groups
(single multi-polygon, EPSG:4326). Any `sf` polygon works. The
watersheds in this region all drain to the Columbia River — Kootenay
Lake feeds the Kootenay River which joins the Columbia at Castlegar; the
Slocan and Lower Arrow drain directly into the Columbia.

We also carry British Columbia ecoregions through the analysis.
Ecoregions partition the province into broad climate-physiography zones
based on latitude, elevation, and dominant vegetation. Climate departure
can vary across them in ways the regional average hides, and we use them
later as the sub-region for the per-ecoregion breakdown.

![Kootenay Lake Region area of interest (~24,000 km²) in southern
interior British Columbia, coloured by ecoregion. Kootenay Lake
dominates the basin; Lower Arrow Lake and the Slocan are visible to the
west.](kootenay-lake_files/figure-html/map-location-1.png)

Kootenay Lake Region area of interest (~24,000 km²) in southern interior
British Columbia, coloured by ecoregion. Kootenay Lake dominates the
basin; Lower Arrow Lake and the Slocan are visible to the west.

## Connect to the Data Catalog

The producer pipeline in this repository fetches ERA5-Land hourly
reanalysis data, derives variables (vapour pressure deficit, relative
humidity, soil moisture), aggregates to monthly / seasonal / annual, and
writes Cloud-Optimized GeoTIFFs to S3. Alongside the GeoTIFFs we publish
a static SpatioTemporal Asset Catalog (STAC) — a small set of JSON files
that index the assets. Both the GeoTIFFs and the catalog JSON live at
<https://stac-era5-land.s3.us-west-2.amazonaws.com/catalog.json>.

[`cd::cd_catalog()`](https://newgraphenvironment.github.io/cd/reference/cd_catalog.md)
reads that URL by default. The Cloud-Optimized GeoTIFFs are also usable
directly outside R — for example, in QGIS via the STAC plugin, in
`gdalcubes`, or with any STAC-aware client.

``` r

catalog <- cd::cd_catalog()
kableExtra::kable_styling(
  knitr::kable(catalog, label = NA,
    caption = "Available climate variables and periods in the STAC catalog."),
  bootstrap_options = c("striped", "hover", "condensed")
) |>
  kableExtra::scroll_box(height = "320px")
```

| variable | period | href | checksum | size | cd_version | cd_sha | run_time | run_url |
|:---|:---|:---|:---|---:|:---|:---|:---|:---|
| prcp | annual | <https://stac-era5-land.s3.us-west-2.amazonaws.com/prcp_annual.tif> | 1220730c1dd528b251a472d0bf5be00a36e5b0c458f115547c4b23b4ca2f98229e35 | 5625182 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| prcp | fall | <https://stac-era5-land.s3.us-west-2.amazonaws.com/prcp_fall.tif> | 122013cdcc6f5dfafc3f78bf2413de23522860f277931466d3a50688039b5ec31f96 | 5677983 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| prcp | spring | <https://stac-era5-land.s3.us-west-2.amazonaws.com/prcp_spring.tif> | 12200c079fedd71cf072c20e2282cbaf1640be398e45412859cf5b52ed30ca225693 | 5682614 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| prcp | summer | <https://stac-era5-land.s3.us-west-2.amazonaws.com/prcp_summer.tif> | 122021712e164766de9bd28f3340638a25e0782500678ca8f69608ba4108f0d8441b | 5612241 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| prcp | winter | <https://stac-era5-land.s3.us-west-2.amazonaws.com/prcp_winter.tif> | 1220850bc3ef2145e795d7cfca1bbb0ad2eb991d44e9b924e8a6303ec6124fe2de4c | 5678272 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| rh | annual | <https://stac-era5-land.s3.us-west-2.amazonaws.com/rh_annual.tif> | 12207743767feb01fc5dc6a6478c8ebea7bbeee126327a14c992eb766ecca47f2088 | 5243520 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| rh | fall | <https://stac-era5-land.s3.us-west-2.amazonaws.com/rh_fall.tif> | 122026b2e8596ff7b70d1db40b8d03d00b27eeac73102404873afc294fcd028c81e5 | 5300345 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| rh | spring | <https://stac-era5-land.s3.us-west-2.amazonaws.com/rh_spring.tif> | 12207512907a87a299ed200c7fe488535f4911fc1cce32bfdbaed90c66813f551b77 | 5325493 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| rh | summer | <https://stac-era5-land.s3.us-west-2.amazonaws.com/rh_summer.tif> | 12208bed1d51fe1f7107953ed6378908e7e261557235ff7245488f5858125b0daf2b | 5386484 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| rh | winter | <https://stac-era5-land.s3.us-west-2.amazonaws.com/rh_winter.tif> | 1220e69676b861ed1241e5582491b9c4ce302ce5a8e272c47c23179dde7e56c6ed9a | 5250798 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| snow_cover | annual | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snow_cover_annual.tif> | 1220b0b30134a3faeed6acfb017a7b6b1c2baf128d3ce18c712bcd8c037706f70f40 | 5422007 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| snow_cover | fall | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snow_cover_fall.tif> | 1220d15167465f6772c69cd0c48ef427687215a271ee56bfcc991bc94786bf150988 | 5605503 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| snow_cover | spring | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snow_cover_spring.tif> | 12206ad837fe006631bcb51ad2d4dc4d11e33993efef33d06dfa7e43d1f00292fbeb | 3944891 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| snow_cover | summer | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snow_cover_summer.tif> | 122088166d64ad112646e0568a6e3a08e49e524c39c2b54eb266137d7adfb69d8735 | 4521903 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| snow_cover | winter | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snow_cover_winter.tif> | 122055bcfdfb98c278e351ea6519ec6c8ef2aedd3387322c0407c13ea3e7bd4c808b | 1732905 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| snowfall | annual | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snowfall_annual.tif> | 12209fb134f10c3a049d6b7c7360499ae03a12221a49b959d2b4abd1c440ce2b491d | 5700112 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| snowfall | fall | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snowfall_fall.tif> | 1220bbd5806820ae0c469fded5ad2f7cd3a3bb0a8bd4821fe3f4af5b5ac9f66409f4 | 5767075 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| snowfall_fraction | annual | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snowfall_fraction_annual.tif> | 1220be14c4eee562684ef99aec87af37395c2fc12cfab44296feb8ee2b67c3f42aeb | 5624936 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| snowfall | spring | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snowfall_spring.tif> | 12202089ce001d0f18522c24b949b5501b942e7fde1b5413d40ab502440b591a733f | 5748630 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| snowfall | summer | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snowfall_summer.tif> | 122057f16deffe3b1d6c114a300d3e83025fb2c0cd8b9d90699f7f49d0090b9f2baf | 4058121 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| snowfall | winter | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snowfall_winter.tif> | 122068b8ebd0fd10eab7a995af3560fd5f585db9e78b8a5641d9ffde9f4b6673a78f | 5691517 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| snowmelt | annual | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snowmelt_annual.tif> | 1220513a1f7799fcd01e95a4edc4b1b5ae0bbf05e3ef53db5eeebe6fff4f3df8d872 | 5723384 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| snowmelt_doy_50 | annual | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snowmelt_doy_50_annual.tif> | 12206afd27587054c214b68e323d0c86681510ad3a86a3d5bd6fea4f9bc4010d64df | 2070285 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| snowmelt | fall | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snowmelt_fall.tif> | 1220dc1ce028acfa3a789d460bd354bff5963e04df1c38722ab5bc42b31090b557e0 | 5804333 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| snowmelt_rate_peak | annual | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snowmelt_rate_peak_annual.tif> | 12203ddbaf20308dd64658409b647630ec71410e89fa42fd7fbe8e616c58916c795e | 5411977 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| snowmelt | spring | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snowmelt_spring.tif> | 1220a03a122839c80363acbd2d39726c2d8eb7a5adf0fa96fb2c8fa26c8f475007bb | 5726183 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| snowmelt | summer | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snowmelt_summer.tif> | 1220f6b38f4623781230443bac67dbf6979a9d5f8bedf87fbe06ee0aa7571d5e7488 | 5219813 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| snowmelt | winter | <https://stac-era5-land.s3.us-west-2.amazonaws.com/snowmelt_winter.tif> | 1220dded6569451df2fa7738a9bc59dbe5c3171513e15fafd6cd242e69b3c681eb56 | 3606366 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| soil_moisture | annual | <https://stac-era5-land.s3.us-west-2.amazonaws.com/soil_moisture_annual.tif> | 12207509e872c4cbf984a5fbb2ccd40265bd5bb3fd59de10eba88b8d2d827b7ab8ac | 5438873 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| soil_moisture | fall | <https://stac-era5-land.s3.us-west-2.amazonaws.com/soil_moisture_fall.tif> | 1220bf5b6a3c0fce86aa26ac675d0bbc5f057607cf3eef6b35417109211e32a8ebe0 | 5478515 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| soil_moisture | spring | <https://stac-era5-land.s3.us-west-2.amazonaws.com/soil_moisture_spring.tif> | 12205f2835191b27ac51d740893d1e1cd8f4cf1fc28e46575c66bb2776f1234f723b | 5433015 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| soil_moisture | summer | <https://stac-era5-land.s3.us-west-2.amazonaws.com/soil_moisture_summer.tif> | 12202a85d198eb45efabd0e7f0b58fba40439244df12a3232f9dbd27050302b4c46d | 5471863 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| soil_moisture | winter | <https://stac-era5-land.s3.us-west-2.amazonaws.com/soil_moisture_winter.tif> | 1220edea061f1beeee5a6260cbc2aa112d7edc1a02ce61306041024ede3d3b641983 | 5429617 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| swe | annual | <https://stac-era5-land.s3.us-west-2.amazonaws.com/swe_annual.tif> | 122074db0d5c61f04a1fef80d10b1deb8c216a869f6cb212f97b954bc482c814b1ba | 5734077 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| swe | fall | <https://stac-era5-land.s3.us-west-2.amazonaws.com/swe_fall.tif> | 1220cf70872194681fd93ab8c67b04da6442454dee61701543338c7d17d375703d02 | 5785044 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| swe_max | annual | <https://stac-era5-land.s3.us-west-2.amazonaws.com/swe_max_annual.tif> | 12207d8ba95f3052f1d36a2d2da7699035692c23f89e79989dc19f86c63f0c3b2309 | 5676384 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| swe | spring | <https://stac-era5-land.s3.us-west-2.amazonaws.com/swe_spring.tif> | 1220b7369a1e82a6b9f22eee4c2728e6898f26d731e6e73265039eef01e20b6e2933 | 5758804 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| swe | summer | <https://stac-era5-land.s3.us-west-2.amazonaws.com/swe_summer.tif> | 12203b7a3eb75eeff8d1ba058ce0143cc4d8004bd00682305d8d07798914a8ca97f6 | 5545877 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| swe | winter | <https://stac-era5-land.s3.us-west-2.amazonaws.com/swe_winter.tif> | 12206747d837fd634af197b0f94b827178eae7f7023e0f2ee281b33bfdee32ab67c1 | 5677866 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| tmax | annual | <https://stac-era5-land.s3.us-west-2.amazonaws.com/tmax_annual.tif> | 1220650998a1ada8b9344d6b031ee2564b2caba213d437df34386837073a16b7b09b | 5753431 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| tmax | fall | <https://stac-era5-land.s3.us-west-2.amazonaws.com/tmax_fall.tif> | 1220404422d8c5d4b0f6311028822392481c2cc4c32c06027af6500f19eaffde8267 | 5741968 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| tmax | spring | <https://stac-era5-land.s3.us-west-2.amazonaws.com/tmax_spring.tif> | 1220065617396c31fce6e39ef856df2687702980b716a886ffd5f19ad7de90e6011c | 5753355 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| tmax | summer | <https://stac-era5-land.s3.us-west-2.amazonaws.com/tmax_summer.tif> | 1220bf3c64800ad5ff9c14f5cd1489e9274745e68f004e95bd30267ba7f7a2b8bdf8 | 5388925 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| tmax | winter | <https://stac-era5-land.s3.us-west-2.amazonaws.com/tmax_winter.tif> | 1220c6d7a6126a6439933f890a30fc348b9b72ce926df24ed94946eb0ccb6c173ef7 | 5670937 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| tmean | annual | <https://stac-era5-land.s3.us-west-2.amazonaws.com/tmean_annual.tif> | 1220a34508b33ab7b7a857a2a861a89fc8d03709545ee53ff0ed33d0b0afb5775e5c | 5608951 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| tmean | fall | <https://stac-era5-land.s3.us-west-2.amazonaws.com/tmean_fall.tif> | 122007414537f538b5a2cc09a11d6c4459c1d8306201d6ea303c9a3736e04419eee6 | 5317964 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| tmean | spring | <https://stac-era5-land.s3.us-west-2.amazonaws.com/tmean_spring.tif> | 1220f8efb9f82c9dbf1bd3bbfd65f8710852a90856f683c371ca4973bdc3ebc721d1 | 5312672 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| tmean | summer | <https://stac-era5-land.s3.us-west-2.amazonaws.com/tmean_summer.tif> | 1220cceae64740902b13ec1847bc398b38cbfdc7811dc6a91ec7b25aa2c00f103025 | 5226582 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| tmean | winter | <https://stac-era5-land.s3.us-west-2.amazonaws.com/tmean_winter.tif> | 12200ca82f93457c7210f1d9537086a592a3af3ed961ac9f8bb9caffc67ab7622a54 | 5388268 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| tmin | annual | <https://stac-era5-land.s3.us-west-2.amazonaws.com/tmin_annual.tif> | 12204b319730790fb72f976dd7c05b2e72e3bc5656c079c995688eb90ff4b1eae9c1 | 5761205 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| tmin | fall | <https://stac-era5-land.s3.us-west-2.amazonaws.com/tmin_fall.tif> | 1220e5bf897bf5e5208b53248a38ea3b60836afbdfbd66a15dbef1e2538478386ba1 | 5839215 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| tmin | spring | <https://stac-era5-land.s3.us-west-2.amazonaws.com/tmin_spring.tif> | 12209141a9afdb7156a815c2f4357389d1dc7cd68ca9809b273256a9e7dadc21666c | 5707615 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| tmin | summer | <https://stac-era5-land.s3.us-west-2.amazonaws.com/tmin_summer.tif> | 1220efc7e01b8d0fcd54b5f238f1a767614fa5f1991fd68b368b0c16177195ce9242 | 5529805 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| tmin | winter | <https://stac-era5-land.s3.us-west-2.amazonaws.com/tmin_winter.tif> | 1220b4d88d94aa7fc266edc11e02762ac9cd5d81a3e095536bbffa1d8a23c299c5d5 | 5560354 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| vpd | annual | <https://stac-era5-land.s3.us-west-2.amazonaws.com/vpd_annual.tif> | 122077c9dbee6272472ff2396b9d27bbfbd90f053332d7ed973930c5a6769b55b737 | 5607999 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| vpd | fall | <https://stac-era5-land.s3.us-west-2.amazonaws.com/vpd_fall.tif> | 12203018a5ab47320d473f089b7815662291256081b8248a25af0c3a7fa495984b23 | 5643105 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| vpd | spring | <https://stac-era5-land.s3.us-west-2.amazonaws.com/vpd_spring.tif> | 12208112591028115f486b018ae0219b213d89edafd6fb912941e6a1e27fd64f4276 | 5636858 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| vpd | summer | <https://stac-era5-land.s3.us-west-2.amazonaws.com/vpd_summer.tif> | 122080671903e2ebd97ed397a1226a442a59447ba4277fa8156aa78ed0e5cc2771dd | 5602565 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |
| vpd | winter | <https://stac-era5-land.s3.us-west-2.amazonaws.com/vpd_winter.tif> | 1220141bda27d56726f5f221be5c69c74f19e8d831d4f0d1a49b47e3a4797218415c | 5586138 | 0.6.3 | 349f9d72e1687761ce98ebd62e6a086be30cc2a6 | 2026-10-10T22:36:36Z | NA |

Available climate variables and periods in the STAC catalog. {.table
.table .table-striped .table-hover .table-condensed
style="margin-left: auto; margin-right: auto;"}

  

## Extract Climate Time Series

[`cd::cd_extract()`](https://newgraphenvironment.github.io/cd/reference/cd_extract.md)
crops each cloud-hosted GeoTIFF to the area of interest and computes the
spatial mean per year. For an area of interest of this size a live
extraction takes a few seconds per variable. To keep the vignette fast
and reproducible we load a pre-computed result of exactly that call.

``` r

ts <- cd::cd_extract(catalog, aoi)
head(ts, 10)
```

| variable | period | year |     value |
|:---------|:-------|-----:|----------:|
| prcp     | annual | 1950 | 1097.1773 |
| prcp     | annual | 1951 | 1046.8338 |
| prcp     | annual | 1952 |  737.0764 |
| prcp     | annual | 1953 | 1222.3778 |
| prcp     | annual | 1954 | 1274.0266 |
| prcp     | annual | 1955 | 1124.7121 |
| prcp     | annual | 1956 | 1075.2880 |
| prcp     | annual | 1957 |  944.5439 |
| prcp     | annual | 1958 | 1094.4144 |
| prcp     | annual | 1959 | 1226.6316 |

First 10 rows of the extracted climate time series. {.table}

## Trends

An anomaly is the difference between a year’s value and the average
value over a reference period. Here the reference is **1951–1980** — the
three decades before climate change accelerated, the same baseline
Hansen et al. ([2012](#ref-hansen_etal2012Perceptionclimate)) used to
track global temperature outliers. Saying a year is “+1.5 °C” means it
was 1.5 °C warmer than the average year in 1951–1980.

The trend table shows two rows per variable, fit from two different
start years:

- **1951–present (75 years)** — the long view. How much has the variable
  changed since the pre-warming reference?
- **1981–present (45 years)** — the recent view. Starts at the beginning
  of the most recent WMO “climate normal” (1981–2010), the period used
  in IPCC reports, so the numbers are easy to compare against published
  summaries.

If the 45-year slope is **steeper** than the 75-year slope, change has
accelerated. **Shallower** means it has slowed. **Similar** means a
roughly steady rate across the full record. “Total Change” is the slope
times the number of years in the window — the cumulative shift.

``` r

bl_early <- cd::cd_baseline(ts, baseline_years = 1951:1980)
ano      <- cd::cd_anomaly(ts, bl_early)
trn      <- cd::cd_trend(ano, trend_start = c(1951, 1981))
cd::cd_summary(trn)
```

| Parameter | Period | Start | Slope | Years | Total Change | Unit | p-value |
|:---|:---|---:|---:|---:|---:|:---|---:|
| Precipitation | Annual | 1951 | -0.120 | 75 | -9.0 | % | 0.0206 |
| Precipitation | Annual | 1981 | -0.138 | 45 | -6.2 | % | 0.1866 |
| Precipitation | Fall | 1951 | 0.016 | 75 | 1.2 | % | 0.9126 |
| Precipitation | Fall | 1981 | 0.075 | 45 | 3.4 | % | 0.7617 |
| Precipitation | Spring | 1951 | 0.190 | 75 | 14.2 | % | 0.0854 |
| Precipitation | Spring | 1981 | -0.033 | 45 | -1.5 | % | 0.8679 |
| Precipitation | Summer | 1951 | -0.168 | 75 | -12.6 | % | 0.1458 |
| Precipitation | Summer | 1981 | -1.064 | 45 | -47.9 | % | 0.0004 |
| Precipitation | Winter | 1951 | -0.342 | 75 | -25.7 | % | 0.0053 |
| Precipitation | Winter | 1981 | 0.207 | 45 | 9.3 | % | 0.3630 |
| Relative humidity | Annual | 1951 | -0.040 | 75 | -3.0 | % | 0.0006 |
| Relative humidity | Annual | 1981 | -0.088 | 45 | -4.0 | % | 0.0000 |
| Relative humidity | Fall | 1951 | -0.042 | 75 | -3.2 | % | 0.0174 |
| Relative humidity | Fall | 1981 | -0.060 | 45 | -2.7 | % | 0.1153 |
| Relative humidity | Spring | 1951 | -0.019 | 75 | -1.4 | % | 0.1509 |
| Relative humidity | Spring | 1981 | -0.081 | 45 | -3.7 | % | 0.0067 |
| Relative humidity | Summer | 1951 | -0.075 | 75 | -5.6 | % | 0.0146 |
| Relative humidity | Summer | 1981 | -0.225 | 45 | -10.1 | % | 0.0004 |
| Relative humidity | Winter | 1951 | 0.002 | 75 | 0.1 | % | 0.9417 |
| Relative humidity | Winter | 1981 | 0.020 | 45 | 0.9 | % | 0.3527 |
| Snow cover | Annual | 1951 | -0.073 | 75 | -5.5 | % | 0.0004 |
| Snow cover | Annual | 1981 | -0.018 | 45 | -0.8 | % | 0.6740 |
| Snow cover | Fall | 1951 | -0.052 | 75 | -3.9 | % | 0.1971 |
| Snow cover | Fall | 1981 | 0.028 | 45 | 1.2 | % | 0.8068 |
| Snow cover | Spring | 1951 | -0.084 | 75 | -6.3 | % | 0.0000 |
| Snow cover | Spring | 1981 | -0.027 | 45 | -1.2 | % | 0.6740 |
| Snow cover | Summer | 1951 | -0.137 | 75 | -10.3 | % | 0.0008 |
| Snow cover | Summer | 1981 | -0.030 | 45 | -1.4 | % | 0.5906 |
| Snow cover | Winter | 1951 | 0.000 | 75 | 0.0 | % | 0.0304 |
| Snow cover | Winter | 1981 | 0.000 | 45 | 0.0 | % | 0.0087 |
| Snowfall | Annual | 1951 | -0.272 | 75 | -20.4 | % | 0.0057 |
| Snowfall | Annual | 1981 | 0.106 | 45 | 4.8 | % | 0.5507 |
| Snowfall | Fall | 1951 | -0.193 | 75 | -14.5 | % | 0.2237 |
| Snowfall | Fall | 1981 | -0.127 | 45 | -5.7 | % | 0.7468 |
| Snowfall | Spring | 1951 | -0.177 | 75 | -13.3 | % | 0.2453 |
| Snowfall | Spring | 1981 | -0.004 | 45 | -0.2 | % | 0.9922 |
| Snowfall | Summer | 1951 | -0.622 | 75 | -46.7 | % | 0.0334 |
| Snowfall | Summer | 1981 | -0.500 | 45 | -22.5 | % | 0.4002 |
| Snowfall | Winter | 1951 | -0.361 | 75 | -27.1 | % | 0.0043 |
| Snowfall | Winter | 1981 | 0.232 | 45 | 10.4 | % | 0.3630 |
| Snowfall fraction | Annual | 1951 | -0.102 | 75 | -7.7 | % | 0.0038 |
| Snowfall fraction | Annual | 1981 | 0.127 | 45 | 5.7 | % | 0.1345 |
| Snowmelt | Annual | 1951 | -0.254 | 75 | -19.0 | % | 0.0038 |
| Snowmelt | Annual | 1981 | -0.014 | 45 | -0.6 | % | 0.9454 |
| Snowmelt | Fall | 1951 | -0.081 | 75 | -6.1 | % | 0.7281 |
| Snowmelt | Fall | 1981 | 0.727 | 45 | 32.7 | % | 0.2000 |
| Snowmelt | Spring | 1951 | 0.126 | 75 | 9.5 | % | 0.2763 |
| Snowmelt | Spring | 1981 | 0.062 | 45 | 2.8 | % | 0.7917 |
| Snowmelt | Summer | 1951 | -0.861 | 75 | -64.5 | % | 0.0011 |
| Snowmelt | Summer | 1981 | -0.169 | 45 | -7.6 | % | 0.5906 |
| Snowmelt | Winter | 1951 | 0.592 | 75 | 44.4 | % | 0.0772 |
| Snowmelt | Winter | 1981 | 0.357 | 45 | 16.1 | % | 0.6382 |
| Day of 50% melt | Annual | 1951 | -0.200 | 75 | -15.0 | day | 0.0003 |
| Day of 50% melt | Annual | 1981 | -0.063 | 45 | -2.8 | day | 0.7767 |
| Peak weekly melt rate | Annual | 1951 | -0.225 | 75 | -16.9 | mm/wk | 0.0316 |
| Peak weekly melt rate | Annual | 1981 | -0.175 | 45 | -7.9 | mm/wk | 0.4513 |
| Soil moisture | Annual | 1951 | -0.029 | 75 | -2.2 | % | 0.0404 |
| Soil moisture | Annual | 1981 | -0.095 | 45 | -4.3 | % | 0.0037 |
| Soil moisture | Fall | 1951 | -0.069 | 75 | -5.2 | % | 0.0576 |
| Soil moisture | Fall | 1981 | -0.125 | 45 | -5.6 | % | 0.0906 |
| Soil moisture | Spring | 1951 | 0.029 | 75 | 2.2 | % | 0.0400 |
| Soil moisture | Spring | 1981 | -0.028 | 45 | -1.3 | % | 0.4281 |
| Soil moisture | Summer | 1951 | -0.090 | 75 | -6.8 | % | 0.0018 |
| Soil moisture | Summer | 1981 | -0.215 | 45 | -9.7 | % | 0.0000 |
| Soil moisture | Winter | 1951 | 0.008 | 75 | 0.6 | % | 0.6020 |
| Soil moisture | Winter | 1981 | 0.025 | 45 | 1.1 | % | 0.4572 |
| Snow water equivalent | Annual | 1951 | -0.376 | 75 | -28.2 | % | 0.0013 |
| Snow water equivalent | Annual | 1981 | 0.020 | 45 | 0.9 | % | 0.9143 |
| Snow water equivalent | Fall | 1951 | -0.066 | 75 | -4.9 | % | 0.8333 |
| Snow water equivalent | Fall | 1981 | 0.164 | 45 | 7.4 | % | 0.7321 |
| Snow water equivalent | Spring | 1951 | -0.377 | 75 | -28.3 | % | 0.0025 |
| Snow water equivalent | Spring | 1981 | 0.020 | 45 | 0.9 | % | 0.9143 |
| Snow water equivalent | Summer | 1951 | -0.838 | 75 | -62.8 | % | 0.0019 |
| Snow water equivalent | Summer | 1981 | -0.120 | 45 | -5.4 | % | 0.5906 |
| Snow water equivalent | Winter | 1951 | -0.307 | 75 | -23.0 | % | 0.0013 |
| Snow water equivalent | Winter | 1981 | 0.039 | 45 | 1.7 | % | 0.8988 |
| Annual peak snow water equivalent | Annual | 1951 | -0.293 | 75 | -22.0 | % | 0.0042 |
| Annual peak snow water equivalent | Annual | 1981 | 0.082 | 45 | 3.7 | % | 0.7468 |
| Maximum temperature | Annual | 1951 | 0.024 | 75 | 1.8 | °C | 0.0000 |
| Maximum temperature | Annual | 1981 | 0.030 | 45 | 1.4 | °C | 0.0012 |
| Maximum temperature | Fall | 1951 | 0.019 | 75 | 1.4 | °C | 0.0122 |
| Maximum temperature | Fall | 1981 | 0.027 | 45 | 1.2 | °C | 0.0215 |
| Maximum temperature | Spring | 1951 | 0.027 | 75 | 2.0 | °C | 0.0002 |
| Maximum temperature | Spring | 1981 | 0.006 | 45 | 0.3 | °C | 0.7617 |
| Maximum temperature | Summer | 1951 | 0.036 | 75 | 2.7 | °C | 0.0000 |
| Maximum temperature | Summer | 1981 | 0.055 | 45 | 2.5 | °C | 0.0001 |
| Maximum temperature | Winter | 1951 | 0.021 | 75 | 1.6 | °C | 0.0044 |
| Maximum temperature | Winter | 1981 | 0.016 | 45 | 0.7 | °C | 0.3328 |
| Mean temperature | Annual | 1951 | 0.026 | 75 | 2.0 | °C | 0.0000 |
| Mean temperature | Annual | 1981 | 0.034 | 45 | 1.5 | °C | 0.0009 |
| Mean temperature | Fall | 1951 | 0.025 | 75 | 1.8 | °C | 0.0004 |
| Mean temperature | Fall | 1981 | 0.036 | 45 | 1.6 | °C | 0.0007 |
| Mean temperature | Spring | 1951 | 0.028 | 75 | 2.1 | °C | 0.0000 |
| Mean temperature | Spring | 1981 | 0.008 | 45 | 0.3 | °C | 0.6041 |
| Mean temperature | Summer | 1951 | 0.039 | 75 | 2.9 | °C | 0.0000 |
| Mean temperature | Summer | 1981 | 0.054 | 45 | 2.4 | °C | 0.0000 |
| Mean temperature | Winter | 1951 | 0.017 | 75 | 1.3 | °C | 0.0275 |
| Mean temperature | Winter | 1981 | 0.021 | 45 | 1.0 | °C | 0.1932 |
| Minimum temperature | Annual | 1951 | 0.027 | 75 | 2.0 | °C | 0.0000 |
| Minimum temperature | Annual | 1981 | 0.032 | 45 | 1.4 | °C | 0.0011 |
| Minimum temperature | Fall | 1951 | 0.030 | 75 | 2.3 | °C | 0.0000 |
| Minimum temperature | Fall | 1981 | 0.046 | 45 | 2.1 | °C | 0.0001 |
| Minimum temperature | Spring | 1951 | 0.026 | 75 | 2.0 | °C | 0.0000 |
| Minimum temperature | Spring | 1981 | 0.004 | 45 | 0.2 | °C | 0.6598 |
| Minimum temperature | Summer | 1951 | 0.040 | 75 | 3.0 | °C | 0.0000 |
| Minimum temperature | Summer | 1981 | 0.046 | 45 | 2.1 | °C | 0.0002 |
| Minimum temperature | Winter | 1951 | 0.014 | 75 | 1.0 | °C | 0.0941 |
| Minimum temperature | Winter | 1981 | 0.022 | 45 | 1.0 | °C | 0.2000 |
| Vapour pressure deficit | Annual | 1951 | 0.012 | 75 | 0.9 | hPa | 0.0000 |
| Vapour pressure deficit | Annual | 1981 | 0.024 | 45 | 1.1 | hPa | 0.0000 |
| Vapour pressure deficit | Fall | 1951 | 0.008 | 75 | 0.6 | hPa | 0.0088 |
| Vapour pressure deficit | Fall | 1981 | 0.014 | 45 | 0.6 | hPa | 0.0617 |
| Vapour pressure deficit | Spring | 1951 | 0.008 | 75 | 0.6 | hPa | 0.0000 |
| Vapour pressure deficit | Spring | 1981 | 0.010 | 45 | 0.4 | hPa | 0.0264 |
| Vapour pressure deficit | Summer | 1951 | 0.028 | 75 | 2.1 | hPa | 0.0003 |
| Vapour pressure deficit | Summer | 1981 | 0.066 | 45 | 3.0 | hPa | 0.0001 |
| Vapour pressure deficit | Winter | 1951 | 0.001 | 75 | 0.1 | hPa | 0.0007 |
| Vapour pressure deficit | Winter | 1981 | 0.000 | 45 | 0.0 | hPa | 0.7767 |

Trend statistics for all variables and periods, Kootenay Lake Region.
{.table .table .table-striped .table-hover .table-condensed
style="margin-left: auto; margin-right: auto;"}

  

``` r

cd::cd_plot_timeseries(
  ano, variable = "prcp", period = "annual", trend = trn,
  title = "Annual Precipitation Anomaly — Kootenay Lake Region"
)
```

![Annual precipitation anomaly (% of 1951-1980 baseline) for the
Kootenay Lake Region. The per-ecoregion mean temperature panel is shown
later in the Per-Ecoregion
section.](kootenay-lake_files/figure-html/plot-prcp-1.png)

Annual precipitation anomaly (% of 1951-1980 baseline) for the Kootenay
Lake Region. The per-ecoregion mean temperature panel is shown later in
the Per-Ecoregion section.

## Recent Decade vs Pre-Warming Reference

The table below compares the recent decade (2015–2025) directly against
the pre-warming reference (1951–1980). **Δ absolute** is the difference
of the two means in the variable’s native units. **Δ %** is shown only
where percent change makes physical sense (precipitation, soil moisture,
VPD, relative humidity).

Two p-values appear side-by-side because they answer different
questions. **Δ p (windows)** asks whether the recent decade differs from
the pre-warming reference. **Trend p (75-yr)** asks whether the full
series ramps year-on-year. A sudden step change shows up as significant
Δ p but not trend p; a gradual ramp shows up as both.

The recent decade was between 1.6 and 1.7 °C warmer than the pre-warming
reference for annual mean, daytime maximum, and overnight minimum, with
both window and trend p-values below 0.001. Vapour pressure deficit is
up significantly on both tests. Annual precipitation was about 6 to 7 %
*lower* in the recent decade, and the long-term Mann-Kendall trend test
confirms a steady year-on-year decline (trend p ≈ 0.02). Soil moisture
is down 2.1 %, too small a step for the window test (p ≈ 0.062), but the
trend test finds a steady decline (trend p ≈ 0.04 from 1951 and ≈ 0.0037
from 1981). Relative humidity shows a small significant decline.

``` r

cmp <- cd::cd_compare(ts)   # defaults: 2015–2025 vs 1951–1980, Welch t-test
```

| Variable | Period | Recent (2015–2025) | Pre-warming (1951–1980) | Δ absolute | Δ % | Δ p (windows) | Trend p (75-yr) |
|:---|:---|---:|---:|---:|---:|---:|---:|
| prcp | annual | 1017.80 | 1088.75 | -70.96 | -6.5 | 0.033 | 0.021 |
| prcp | fall | 281.22 | 270.22 | 11.00 | 4.1 | 0.632 | 0.913 |
| prcp | spring | 258.29 | 251.19 | 7.10 | 2.8 | 0.679 | 0.085 |
| prcp | summer | 192.13 | 230.76 | -38.63 | -16.7 | 0.018 | 0.146 |
| prcp | winter | 286.15 | 336.58 | -50.43 | -15.0 | 0.008 | 0.005 |
| rh | annual | 68.89 | 71.45 | -2.56 | -3.6 | 0.000 | 0.001 |
| rh | fall | 73.51 | 75.36 | -1.85 | -2.5 | 0.161 | 0.017 |
| rh | spring | 67.54 | 69.97 | -2.42 | -3.5 | 0.023 | 0.151 |
| rh | summer | 53.26 | 59.25 | -5.99 | -10.1 | 0.003 | 0.015 |
| rh | winter | 81.25 | 81.24 | 0.01 | 0.0 | 0.987 | 0.942 |
| snow_cover | annual | 57.85 | 62.06 | -4.21 | NA | 0.001 | 0.000 |
| snow_cover | fall | 41.63 | 42.85 | -1.22 | NA | 0.603 | 0.197 |
| snow_cover | spring | 87.27 | 93.72 | -6.45 | NA | 0.002 | 0.000 |
| snow_cover | summer | 5.58 | 14.72 | -9.13 | NA | 0.000 | 0.001 |
| snow_cover | winter | 96.91 | 96.95 | -0.04 | NA | 0.408 | 0.030 |
| snowfall | annual | 553.85 | 648.93 | -95.08 | -14.7 | 0.004 | 0.006 |
| snowfall | fall | 141.39 | 149.97 | -8.58 | -5.7 | 0.469 | 0.224 |
| snowfall | spring | 137.58 | 165.63 | -28.06 | -16.9 | 0.063 | 0.245 |
| snowfall | summer | 4.31 | 7.25 | -2.94 | -40.5 | 0.028 | 0.033 |
| snowfall | winter | 270.57 | 326.08 | -55.51 | -17.0 | 0.004 | 0.004 |
| snowfall_fraction | annual | 54.06 | 59.13 | -5.08 | NA | 0.040 | 0.004 |
| snowmelt | annual | 557.71 | 660.80 | -103.09 | -15.6 | 0.003 | 0.004 |
| snowmelt | fall | 33.80 | 34.40 | -0.60 | -1.7 | 0.905 | 0.728 |
| snowmelt | spring | 421.38 | 376.06 | 45.33 | 12.1 | 0.158 | 0.276 |
| snowmelt | summer | 96.89 | 247.97 | -151.08 | -60.9 | 0.000 | 0.001 |
| snowmelt | winter | 5.63 | 2.37 | 3.27 | 138.0 | 0.122 | 0.077 |
| snowmelt_doy_50 | annual | 133.32 | 145.90 | -12.58 | NA | 0.001 | 0.000 |
| snowmelt_rate_peak | annual | 135.52 | 147.44 | -11.92 | -8.1 | 0.170 | 0.032 |
| soil_moisture | annual | 0.33 | 0.34 | -0.01 | -2.1 | 0.062 | 0.040 |
| soil_moisture | fall | 0.32 | 0.33 | -0.01 | -4.2 | 0.130 | 0.058 |
| soil_moisture | spring | 0.36 | 0.35 | 0.01 | 1.7 | 0.214 | 0.040 |
| soil_moisture | summer | 0.32 | 0.34 | -0.02 | -6.9 | 0.000 | 0.002 |
| soil_moisture | winter | 0.33 | 0.33 | 0.00 | 0.8 | 0.533 | 0.602 |
| swe | annual | 159.54 | 206.33 | -46.79 | -22.7 | 0.000 | 0.001 |
| swe | fall | 26.61 | 26.42 | 0.19 | 0.7 | 0.945 | 0.833 |
| swe | spring | 353.55 | 464.55 | -111.00 | -23.9 | 0.001 | 0.002 |
| swe | summer | 10.24 | 37.82 | -27.58 | -72.9 | 0.000 | 0.002 |
| swe | winter | 247.77 | 296.54 | -48.77 | -16.4 | 0.000 | 0.001 |
| swe_max | annual | 471.59 | 563.35 | -91.75 | -16.3 | 0.006 | 0.004 |
| tmax | annual | 7.33 | 5.78 | 1.56 | NA | 0.000 | 0.000 |
| tmax | fall | 7.30 | 6.30 | 1.00 | NA | 0.040 | 0.012 |
| tmax | spring | 6.30 | 4.51 | 1.79 | NA | 0.001 | 0.000 |
| tmax | summer | 20.37 | 17.92 | 2.44 | NA | 0.000 | 0.000 |
| tmax | winter | -4.64 | -5.63 | 0.99 | NA | 0.051 | 0.004 |
| tmean | annual | 3.29 | 1.63 | 1.65 | NA | 0.000 | 0.000 |
| tmean | fall | 3.49 | 2.07 | 1.42 | NA | 0.002 | 0.000 |
| tmean | spring | 2.05 | 0.28 | 1.77 | NA | 0.000 | 0.000 |
| tmean | summer | 15.27 | 12.75 | 2.52 | NA | 0.000 | 0.000 |
| tmean | winter | -7.65 | -8.56 | 0.91 | NA | 0.098 | 0.028 |
| tmin | annual | -0.97 | -2.63 | 1.66 | NA | 0.000 | 0.000 |
| tmin | fall | -0.40 | -2.25 | 1.85 | NA | 0.000 | 0.000 |
| tmin | spring | -2.27 | -3.83 | 1.55 | NA | 0.000 | 0.000 |
| tmin | summer | 9.33 | 6.87 | 2.45 | NA | 0.000 | 0.000 |
| tmin | winter | -10.52 | -11.32 | 0.79 | NA | 0.188 | 0.094 |
| vpd | annual | 3.63 | 2.81 | 0.81 | 28.8 | 0.000 | 0.000 |
| vpd | fall | 2.67 | 2.22 | 0.46 | 20.6 | 0.060 | 0.009 |
| vpd | spring | 2.52 | 1.98 | 0.54 | 27.5 | 0.000 | 0.000 |
| vpd | summer | 8.65 | 6.45 | 2.20 | 34.1 | 0.001 | 0.000 |
| vpd | winter | 0.65 | 0.61 | 0.04 | 7.4 | 0.012 | 0.001 |

Recent decade (2015-2025 mean) compared to pre-warming reference
(1951-1980 mean) for the Kootenay Lake Region. {.table .table
.table-striped .table-hover .table-condensed
style="margin-left: auto; margin-right: auto;"}

  

## Daytime Highs and Overnight Lows

Alongside the daily mean, the cd package ships **tmax** (daytime
maximum) and **tmin** (overnight minimum). When overnight minimums warm
faster than daytime maximums, that’s the “day-night asymmetry” — a
textbook fingerprint of greenhouse warming, first documented globally by
Karl et al. ([1993](#ref-karl_etal1993NewPerspective)) (overnight
minimums rose roughly three times faster than daytime maximums between
1951 and 1990). Whether a region shows the signal depends on local
geography (valley inversions, snow cover, slope-aspect mix).

**For the Kootenay Lake Region, overnight minimums are warming faster
than daytime maximums.** Daytime maximums warmed about +0.024 °C/year
since 1951 (+1.8 °C cumulative); overnight minimums warmed about +0.027
°C/year (+2.0 °C cumulative). The overnight side has gained roughly 0.2
°C more than the daytime side over the full record.

![Annual tmax (top) and tmin (bottom) anomalies for the Kootenay Lake
Region, relative to the 1951-1980 baseline. Dashed line is the 75-year
Theil-Sen trend (1951-present); solid line is the 45-year trend
(1981-present).](kootenay-lake_files/figure-html/plot-tmaxmin-1.png)

Annual tmax (top) and tmin (bottom) anomalies for the Kootenay Lake
Region, relative to the 1951-1980 baseline. Dashed line is the 75-year
Theil-Sen trend (1951-present); solid line is the 45-year trend
(1981-present).

## Snowpack

In BC, most of the year’s runoff starts as winter snow. The snowpack
stores it, then releases it as meltwater across spring and summer. That
delayed release is what keeps creeks flowing through late summer and
what drives the spring freshet — the annual flood pulse that shapes
channels, mobilizes spawning gravels, and refills off-channel rearing
habitat for resident salmonids.

Cordillera-wide, snowpack has been declining for decades ([Mote et al.
2018](#ref-mote_etal2018Dramaticdeclines); [Pederson et al.
2011](#ref-pederson_etal2011UnusualNature)). Najafi et al.
([2017](#ref-najafi_etal2017AttributionObserved)) attribute the observed
spring SWE decline in the Columbia basin — the parent system of the
Kootenays — to human-caused warming.

**The Kootenay Lake Region snowpack signal is sharp.** Annual snow water
equivalent (SWE) is down **23%** (206 → 160 mm) since the 1951–1980
reference. Annual snowfall and annual snowmelt both fell about 15%, and
the **snowmelt midpoint (DOY-50) shifted 12.6 days earlier** in the
year. Annual peak SWE — the seasonal maximum — dropped **92 mm** (-16%).
**Annual precipitation in the Kootenay Lake Region has declined ~7%**
since the reference period, with a long-term Mann-Kendall p of 0.02.
Together this is a “warmer *and* drier” story rather than a
“warmer-only” one.

A note on how to read the snow numbers below. ERA5-Land works on a
roughly 9 km grid: each cell is a single number averaging snow over
about 80 km² of mixed terrain. Cross-checking against three BC automated
snow stations inside the AOI (74 paired station-years, 1972–2025), the
model is **40–63% too low on absolute peak SWE**, but the **bias is
stable over time** — the gap between model and stations in 2020 is the
same size as in 1990 — and **year-to-year correlation is strong** (r =
0.90). So the *trends and changes* below are credible. The absolute mm
values are not ground truth.

### Seasonal snowpack curve

Three of the monthly-native snow variables — SWE, snowfall and snowmelt
— show *when* snow accumulates and melts (snow cover, already a
percentage, has no percent change to compare). Aggregated to the four
standard meteorological seasons — winter (December–February), spring
(March–May), summer (June–August), and fall (September–November) — the
table below compares the recent decade (2015-2025) against the
pre-warming reference (1951-1980) directly. The **summer** rows carry
the snow-free-summer finding below, and winter and spring snowmelt rose
as melt moved earlier.

| Variable      | Season | Pre-warming (1951–1980) | Recent (2015–2025) |   Δ % |
|:--------------|:-------|------------------------:|-------------------:|------:|
| SWE (mm)      | winter |                   296.5 |              247.8 | -16.4 |
| SWE (mm)      | spring |                   464.6 |              353.6 | -23.9 |
| SWE (mm)      | summer |                    37.8 |               10.2 | -72.9 |
| SWE (mm)      | fall   |                    26.4 |               26.6 |   0.7 |
| Snowfall (mm) | winter |                   326.1 |              270.6 | -17.0 |
| Snowfall (mm) | spring |                   165.6 |              137.6 | -16.9 |
| Snowfall (mm) | summer |                     7.2 |                4.3 | -40.5 |
| Snowfall (mm) | fall   |                   150.0 |              141.4 |  -5.7 |
| Snowmelt (mm) | winter |                     2.4 |                5.6 | 138.0 |
| Snowmelt (mm) | spring |                   376.1 |              421.4 |  12.1 |
| Snowmelt (mm) | summer |                   248.0 |               96.9 | -60.9 |
| Snowmelt (mm) | fall   |                    34.4 |               33.8 |  -1.7 |

Seasonal snowpack: recent decade compared to pre-warming reference for
the Kootenay Lake Region. Summer SWE (-73%) and summer snowmelt (-61%)
carry the largest losses; winter (+138%) and spring (+12%) snowmelt
rose. {.table .table .table-striped .table-hover .table-condensed
style="margin-left: auto; margin-right: auto;"}

  

### Annual snowpack signals

Three annual numbers capture how the snowpack is changing:

- **Peak SWE** — the year’s maximum snow water equivalent. How much snow
  is in the bank at the height of winter? ([Mote et al.
  2018](#ref-mote_etal2018Dramaticdeclines),
  [2005](#ref-mote_etal2005DECLININGMOUNTAIN))
- **Snowmelt 50% day-of-year (DOY-50)** — the day by which half the
  year’s melt has run off. Earlier = freshet shifting into spring.
  ([Stewart et al. 2005](#ref-stewart_etal2005ChangesEarlier); [Cayan et
  al. 2001](#ref-cayan_etal2001ChangesOnset))
- **Snowfall fraction** — the share of annual precipitation that falls
  as snow rather than rain. ([Knowles et al.
  2006](#ref-knowles_etal2006TrendsSnowfall))

![Annual snowpack signals for the Kootenay Lake Region, relative to the
1951-1980 baseline. Each panel uses its own y-axis. Dashed line is the
75-year Theil-Sen trend; solid line is the 45-year
trend.](kootenay-lake_files/figure-html/snow-annual-1.png)

Annual snowpack signals for the Kootenay Lake Region, relative to the
1951-1980 baseline. Each panel uses its own y-axis. Dashed line is the
75-year Theil-Sen trend; solid line is the 45-year trend.

### What this means for the Kootenay Lake Region

Three findings carry the snowpack story for the Kootenay Lake Region.

**Snow is leaving *and* falling less.** Annual snowfall is down 15% (649
→ 554 mm). The Kootenay Lake region is warm enough at the relevant
elevations that the snow-vs-rain threshold is being crossed in the
calendar — winter precipitation is falling more often as rain instead of
snow. This matches the threshold finding from Knowles et al.
([2006](#ref-knowles_etal2006TrendsSnowfall)): the strongest
snowfall-fraction declines in the western US occur where winter wet-day
minimum temperatures are warmer than -5 °C, which is the regime the
southern Kootenays sit in.

**The freshet is shifting into spring.** The day of year by which half
the year’s snowmelt has happened (DOY-50) shifted **12.6 days earlier**
between the 1951-1980 reference and the recent decade — in line with
Stewart et al.’s ([2005](#ref-stewart_etal2005ChangesEarlier)) 1-4 week
earlier streamflow timing across western North America, and with the
~10-day Fraser freshet advance documented by Kang et al.
([2016](#ref-kang_etal2016ImpactsRapidly)) for a basin whose southern
boundary is just north of the Kootenay Lake Region.

**Summer is becoming snow-free.** Summer SWE has collapsed by 73% and
summer snowmelt is down 61%. The high-elevation snowpack that
historically lingered into summer now holds about a quarter of what it
did. For aquatic ecosystems downstream, this is a loss of late-season
cold-water input to streams during the warmest, most thermally stressful
weeks of the year.

## Spatial Pattern

The zonal mean reduces a region this size to a single number; the
spatial pattern carries the rest of the story.

Warming is not spatially uniform across the region. Total departures
range from about +1.2 °C at the lowest-warming pixels to +2.2 °C at the
highest, with a regional mean near +1.7 °C. Higher-elevation pixels tend
to show stronger warming — consistent with the elevation-dependent
warming signal documented at mid-latitude mountain sites ([Pepin et al.
2015](#ref-pepin_etal2015Elevationdependentwarming)), though not every
mountain region shows the same pattern and the regional evidence base
remains heterogeneous ([Rangwala and Miller
2012](#ref-rangwala_miller2012Climatechange)). The gradient here is
mixed enough that no single axis (north-south or east-west) carries the
full pattern.

![Spatial pattern of annual mean temperature departure across the
Kootenay Lake Region (2015-2025 mean minus 1951-1980 mean, degrees
C).](kootenay-lake_files/figure-html/spatial-tmean-1.png)

Spatial pattern of annual mean temperature departure across the Kootenay
Lake Region (2015-2025 mean minus 1951-1980 mean, degrees C).

## Per-Ecoregion Variation

The regional zonal mean averages over four ecoregions with different
elevations and exposures: Northern Columbia Mountains (NCM, the dominant
zone covering most of the AOI including the Selkirks and Purcells),
Selkirk-Bitterroot Foothills (SBF, the western lower- elevation tier of
LARL), Thompson-Okanagan Plateau (TOP, a 26 km² sliver in LARL’s far
west), and Purcell Transitional Ranges (PTR, a small sliver on the
eastern edge). Ecoregions under 100 km² — here TOP, smaller than one
ERA5-Land cell — are left out of the maps, the per-ecoregion trend
figures and the roll-up table below, so they show three. To check
whether the regional story holds within each ecoregion — and where it
does not — we run the same pipeline on each ecoregion polygon
individually.

All three ecoregions shown warmed, at rates between +0.23 and +0.30 °C
per decade since 1951. Precipitation shows a region-wide decline; the
magnitude is consistent across ecoregions rather than concentrated in
any one zone. Vapour pressure deficit is up significantly across the
region.

``` r

# For each ecoregion polygon, run the same cd pipeline as the regional one:
results <- lapply(seq_len(nrow(ecoregions)), function(i) {
  poly  <- ecoregions[i, ]
  ts_i  <- cd::cd_extract(catalog, poly)
  bl_i  <- cd::cd_baseline(ts_i, baseline_years = 1951:1980)
  ano_i <- cd::cd_anomaly(ts_i, bl_i)
  trn_i <- cd::cd_trend(ano_i, trend_start = c(1951, 1981))
  cmp_i <- cd::cd_compare(ts_i, window_a = 2015:2025, window_b = 1951:1980,
                           method = "pct_change")
  list(ano = ano_i, trn = trn_i, cmp = cmp_i)
})
```

![Annual mean temperature anomaly relative to the 1951-1980 baseline, by
ecoregion. Dashed line is the 75-year Theil-Sen trend (1951-present);
solid line is the 45-year trend (1981-present). A solid line steeper
than the dashed line indicates accelerating
warming.](kootenay-lake_files/figure-html/facet-tmean-1.png)

Annual mean temperature anomaly relative to the 1951-1980 baseline, by
ecoregion. Dashed line is the 75-year Theil-Sen trend (1951-present);
solid line is the 45-year trend (1981-present). A solid line steeper
than the dashed line indicates accelerating warming.

![Annual precipitation anomaly (% of the 1951-1980 baseline) by
ecoregion. Dashed line is the 75-year trend (1951-present); solid line
is the 45-year trend (1981-present). Precipitation declines in all three
ecoregions shown over the full record; the decline is statistically
significant in Northern Columbia Mountains (NCM) and Purcell
Transitional Ranges (PTR), not in SBF. None of the 45-year trends is
significant.](kootenay-lake_files/figure-html/facet-prcp-1.png)

Annual precipitation anomaly (% of the 1951-1980 baseline) by ecoregion.
Dashed line is the 75-year trend (1951-present); solid line is the
45-year trend (1981-present). Precipitation declines in all three
ecoregions shown over the full record; the decline is statistically
significant in Northern Columbia Mountains (NCM) and Purcell
Transitional Ranges (PTR), not in SBF. None of the 45-year trends is
significant.

### Snow per ecoregion

Two snow metrics are worth viewing per-ecoregion: peak snow water
equivalent (annual snowpack magnitude) and DOY-50 (the day-of-year by
which half the year’s snowmelt has already happened — earlier values
mean an earlier freshet). The two figures below show how each varies
ecoregion to ecoregion. Pair them with the Watershed Groups Across
Ecoregions section below to read each watershed group’s dominant
ecoregion’s signal.

![Annual peak snow water equivalent (SWE) anomaly by ecoregion, relative
to the 1951-1980 baseline. Bars are the percent departure of peak
snowpack from its baseline mean. Dashed line is the 75-year Theil-Sen
trend (1951-present); solid line is the 45-year trend
(1981-present).](kootenay-lake_files/figure-html/facet-swe-max-1.png)

Annual peak snow water equivalent (SWE) anomaly by ecoregion, relative
to the 1951-1980 baseline. Bars are the percent departure of peak
snowpack from its baseline mean. Dashed line is the 75-year Theil-Sen
trend (1951-present); solid line is the 45-year trend (1981-present).

![Snowmelt 50% day-of-year (DOY-50) anomaly by ecoregion, relative to
the 1951-1980 baseline. Negative values (red) mean the freshet midpoint
shifted earlier in the year. Dashed line is the 75-year Theil-Sen trend;
solid line is the 45-year
trend.](kootenay-lake_files/figure-html/facet-doy-50-1.png)

Snowmelt 50% day-of-year (DOY-50) anomaly by ecoregion, relative to the
1951-1980 baseline. Negative values (red) mean the freshet midpoint
shifted earlier in the year. Dashed line is the 75-year Theil-Sen trend;
solid line is the 45-year trend.

### Snow per watershed group

The four watershed groups that make up the AOI map onto the FWCP
reporting unit directly. Per-WSG facet plots show the same two-metric
snow signal — peak SWE and DOY-50 — broken out by watershed group rather
than by ecoregion.

``` r

# Same cd pipeline applied per watershed group polygon:
wsg_results <- lapply(seq_len(nrow(wsgs)), function(i) {
  poly  <- wsgs[i, ]
  ts_i  <- cd::cd_extract(catalog, poly)
  bl_i  <- cd::cd_baseline(ts_i, baseline_years = 1951:1980)
  ano_i <- cd::cd_anomaly(ts_i, bl_i)
  trn_i <- cd::cd_trend(ano_i, trend_start = c(1951, 1981))
  list(ano = ano_i, trn = trn_i)
})
```

![Annual peak SWE anomaly by watershed group. Bars are the percent
departure of peak snowpack from its 1951-1980 mean. Dashed line is the
75-year Theil-Sen trend; solid line is the 45-year
trend.](kootenay-lake_files/figure-html/facet-wsg-swe-max-1.png)

Annual peak SWE anomaly by watershed group. Bars are the percent
departure of peak snowpack from its 1951-1980 mean. Dashed line is the
75-year Theil-Sen trend; solid line is the 45-year trend.

![Snowmelt DOY-50 anomaly by watershed group. Negative values (red) mean
the freshet midpoint shifted earlier in the
year.](kootenay-lake_files/figure-html/facet-wsg-doy-50-1.png)

Snowmelt DOY-50 anomaly by watershed group. Negative values (red) mean
the freshet midpoint shifted earlier in the year.

| Ecoregion | tmean degC/dec | tmax degC/dec | tmin degC/dec | prcp %/yr | prcp p | vpd hPa/dec | vpd p | prcp pct change | soil moisture pct change |
|:---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| SBF | 0.30 | 0.28 | 0.30 | -0.110 | 0.061 | 0.154 | 0 | -6.6 | -2.1 |
| NCM | 0.25 | 0.23 | 0.26 | -0.121 | 0.030 | 0.108 | 0 | -6.4 | -2.1 |
| PTR | 0.23 | 0.22 | 0.24 | -0.141 | 0.010 | 0.084 | 0 | -7.0 | -2.3 |

Per-ecoregion roll-up over the 75-year window (1951-present): annual
mean, daytime maximum, and overnight minimum temperature trends (degrees
C per decade); annual precipitation trend (percent of the 1951-1980
baseline mean per year) and Mann-Kendall p-value; annual vapour pressure
deficit trend (hPa per decade) and p-value; and recent (2015-2025) vs
pre-warming (1951-1980) percent change for precipitation and soil
moisture. All temperature p-values are below 0.001. A tmin slope greater
than the tmax slope indicates the textbook day-night asymmetry. {.table}

Ecoregion codes used in the table above: SBF — Selkirk-Bitterroot
Foothills; NCM — Northern Columbia Mountains; PTR — Purcell Transitional
Ranges.

  

## Watershed Groups Across Ecoregions

The Kootenay Lake Region is reported and managed at the watershed-group
scale — the British Columbia Freshwater Atlas hydrological reporting
unit, and the unit the Fish & Wildlife Compensation Program funds work
in. Four watershed groups make up the AOI for this list. They span the
four ecoregions in different ways (TOP, too small to draw, appears only
in the table). KOTL, DUNC, and SLOC sit almost entirely within Northern
Columbia Mountains (NCM); LARL is the most-mixed group, splitting across
NCM and the Selkirk-Bitterroot Foothills (SBF). The map below shows the
watershed groups labelled with their codes, on top of ecoregion fills.
The table that follows gives the share of each watershed group’s area
falling in each ecoregion.

![The four watershed groups making up the AOI (KOTL, LARL, DUNC, SLOC)
on top of ecoregion fills. Northern Columbia Mountains (NCM) covers most
of the area; Selkirk-Bitterroot Foothills (SBF) covers the western
portion of LARL; a small sliver on the eastern edge belongs to Purcell
Transitional Ranges
(PTR).](kootenay-lake_files/figure-html/map-wsgs-1.png)

The four watershed groups making up the AOI (KOTL, LARL, DUNC, SLOC) on
top of ecoregion fills. Northern Columbia Mountains (NCM) covers most of
the area; Selkirk-Bitterroot Foothills (SBF) covers the western portion
of LARL; a small sliver on the eastern edge belongs to Purcell
Transitional Ranges (PTR).

| Code | Name             | NCM % | SBF % | TOP % | PTR % |
|:-----|:-----------------|------:|------:|------:|------:|
| DUNC | Duncan Lake      |  99.8 |   0.0 |   0.0 |   0.2 |
| KOTL | Kootenay Lake    |  93.8 |   1.0 |   0.0 |   5.2 |
| LARL | Lower Arrow Lake |  37.5 |  62.1 |   0.4 |   0.0 |
| SLOC | Slocan River     |  99.8 |   0.2 |   0.0 |   0.0 |

Watershed groups in the Kootenay Lake Region with the percent of each
group’s area falling in each ecoregion. KOTL, DUNC, and SLOC are
essentially within Northern Columbia Mountains; LARL is the only WSG
that meaningfully splits across two ecoregions (NCM + SBF), making it
the place where ecoregion-level findings can pull in two directions.
{.table .table .table-striped .table-hover .table-condensed
style="margin-left: auto; margin-right: auto;"}

  

## Interpretation

Four findings emerge from the climate departures shown above.

**Warming is broad and fast.** The three ecoregions shown were between
1.5 and 1.9 °C warmer in 2015–2025 than in 1951–1980, warming at rates
between +0.23 and +0.30 °C per decade since 1951, with Mann-Kendall
p-values below 0.001 in every ecoregion. The trend is statistically
significant beyond reasonable doubt of being random noise. Daily
maximum, daily minimum, and daily mean temperatures all tell the same
story. The whole region warmed; the ecoregions differ by a few tenths of
a degree, small beside the warming itself.

**Precipitation is declining and the decline is regionally consistent.**
Annual precipitation dropped **~7%** from the 1951-1980 reference to the
2015-2025 recent decade, with a long-term Mann-Kendall p of 0.02.
Spatially the decline is consistent across the three ecoregions shown,
down between 6.4 and 7.0 %. The watershed groups agree in direction more
than in strength: the precipitation trend since 1951 points down in all
four, but only in KOTL is it statistically significant (p 0.015); in
DUNC, LARL and SLOC it is not (p between 0.051 and 0.094).

**The atmosphere is drying.** Vapour pressure deficit — the gap between
how much water the air could hold and how much it actually does — is up
significantly across the region, mirroring the continental-scale drying
that Ficklin and Novick
([2017](#ref-ficklin_novick2017Historicprojected)) documented for the
United States as a whole, with the strongest historical VPD increases
concentrated in the western and southern portions, driven by combined
air-temperature increases and relative-humidity declines. Combined with
declining precipitation, this is a “double-dipping” signal: less water
arriving as precipitation, *and* warmer air pulling more water out of
soil and vegetation through evapotranspiration. Soil moisture is falling
too: down 2.1 % between the two windows, a step the window test cannot
separate from year-to-year noise (p ≈ 0.062), but part of a significant
long-term decline (trend p ≈ 0.04 from 1951 and ≈ 0.0037 from 1981).
From 1981 the decline is significant in every ecoregion shown.

**Snow is leaving *and* falling less.** Annual snowfall is **down 15%**
alongside the freshet shift — winter precipitation is falling more often
as rain instead of snow, matching the threshold finding from Knowles et
al. ([2006](#ref-knowles_etal2006TrendsSnowfall)) for sites with winter
wet-day minimum temperatures warmer than -5 °C. Annual snow water
equivalent (SWE) is down 23% (206 → 160 mm); summer SWE has collapsed by
73%; the snowmelt 50% day-of-year shifted **12.6 days earlier** between
the reference and recent windows. The per-WSG facet plot above shows the
freshet-timing shift clearly in all four watershed groups; the
per-ecoregion breakdown shows the signal is not concentrated in any one
ecoregion.

For the cold-water resident salmonids the Kootenay Lake region supports
— bull trout, Gerrard rainbow trout, mountain whitefish, kokanee — these
signals compound. Stream temperatures track ambient air temperatures, so
warmer air means warmer water. Cold-water fish lose thermal habitat
under that forcing more than warm-water fish do ([Eaton and Scheller
1996](#ref-eaton_scheller1996Effectsclimate)), and warming summer
streams combined with altered low flows reduce salmonid reproductive
success ([Mantua et al. 2010](#ref-mantua_etal2010Climatechange)). Three
knock-on effects matter here. **Late-summer low flows are not being
relieved by precipitation** — rain is falling, not rising. **The
cold-water input that high-elevation snowpack provides during the
warmest weeks of summer is dropping in parallel with summer SWE.** **The
spring freshet — the high-flow event that shapes channels, moves
spawning gravels, and refills off-channel rearing habitat — is arriving
nearly two weeks earlier.**

Lower Columbia River reaches below Hugh Keenleyside Dam are
dam-fragmented and not anadromous, so the framing is about resident
salmonids and their habitat rather than salmon migrations.

## References

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
