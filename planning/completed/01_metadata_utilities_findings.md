# Findings

## Variable metadata

Source of truth from `bc_climate_anomaly/app.R` and `extract_aoi_anomaly.R`:

| variable | long_name | unit | anomaly_type | era5_name |
|----------|-----------|------|-------------|-----------|
| tmean | Mean temperature | °C | absolute | 2m_temperature |
| tmax | Maximum temperature | °C | absolute | — (derived from hourly max) |
| tmin | Minimum temperature | °C | absolute | — (derived from hourly min) |
| prcp | Precipitation | % | pct_normal | total_precipitation |
| vpd | Vapour pressure deficit | Pa | absolute | — (derived from temp + dewpoint) |
| rh | Relative humidity | % | absolute | — (derived from temp + dewpoint) |
| soil_moisture | Soil moisture | % | pct_normal | volumetric_soil_water_layer_1-4 |

Note: `era5_name` for derived variables will be populated when `cd_fetch()` is built. For now, store the raw ERA5-Land variable names for the direct ones and NA for derived.

## Periods

From app.R: annual, winter (DJF), spring (MAM), summer (JJA), fall (SON). Monthly available but not default.

## Cache pattern

drift uses `rappdirs::user_cache_dir("drift")` — we follow the same pattern with `"cd"`.
