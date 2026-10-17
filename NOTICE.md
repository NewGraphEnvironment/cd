# NOTICE

cd's climate data are derived from ERA5-Land, produced by ECMWF for the Copernicus Climate Change Service and distributed under the [Creative Commons Attribution 4.0 International licence](https://creativecommons.org/licenses/by/4.0/) (CC BY 4.0).

> Contains modified Copernicus Climate Change Service information.

ERA5-Land: Muñoz-Sabater, J., et al. (2021). ERA5-Land: a state-of-the-art global reanalysis dataset for land applications. *Earth System Science Data*, 13, 4349–4383. <https://doi.org/10.5194/essd-13-4349-2021>

cd reads ERA5-Land from the [DestinE Earth Data Hub](https://earthdatahub.destine.eu/), aggregates and derives variables from it (seasonal and annual means and totals, vapour pressure deficit, relative humidity, soil moisture, snow metrics, and daily local-day air temperature), and publishes the results to `s3://stac-era5-land`.

## Redistributed data

The example and vignette data in `inst/` are built from these sources (scripts in `data-raw/`):

| Source | Licence |
|---|---|
| ERA5-Land, as processed by cd | CC BY 4.0 (above) |
| BC Freshwater Atlas: watershed groups, lakes, rivers, streams | [Open Government Licence – British Columbia](https://www2.gov.bc.ca/gov/content/data/policy-standards/open-data/open-government-licence-bc) |
| Ecoregion Ecosystem Classification of British Columbia | Open Government Licence – British Columbia |
| BC Geographical Names (town points) | Not yet confirmed ([#151](https://github.com/NewGraphEnvironment/cd/issues/151)) |
| Digital Road Atlas (highways) | Not yet confirmed ([#151](https://github.com/NewGraphEnvironment/cd/issues/151)) |
| Fish & Wildlife Compensation Program Peace Region boundary, and the Peace layers clipped or masked to it | Not yet confirmed ([#151](https://github.com/NewGraphEnvironment/cd/issues/151)) |
| `bcgov/bc_climate_anomaly` (`inst/extdata/example_climate.tif`) | Not yet confirmed ([#151](https://github.com/NewGraphEnvironment/cd/issues/151)) |

> Contains information licensed under the Open Government Licence – British Columbia.
