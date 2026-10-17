# NOTICE

cd's climate data are derived from ERA5-Land, produced by ECMWF for the Copernicus Climate Change Service and distributed under the [Creative Commons Attribution 4.0 International licence](https://creativecommons.org/licenses/by/4.0/) (CC BY 4.0).

> Contains modified Copernicus Climate Change Service information.

ERA5-Land: Muñoz-Sabater, J., et al. (2021). ERA5-Land: a state-of-the-art global reanalysis dataset for land applications. *Earth System Science Data*, 13, 4349–4383. <https://doi.org/10.5194/essd-13-4349-2021>

cd reads ERA5-Land from the [DestinE Earth Data Hub](https://earthdatahub.destine.eu/), aggregates and derives variables from it (seasonal and annual means and totals, vapour pressure deficit, relative humidity, soil moisture, snow metrics, and daily local-day air temperature), and publishes the results to `s3://stac-era5-land`.

## Redistributed data

This repository redistributes modified ERA5-Land data, under CC BY 4.0, in:

- `inst/extdata/example_daily/` (daily air temperature, 2002)
- `inst/vignette-data/` (the precomputed series and rasters the vignettes read)

It also redistributes, in `inst/extdata/example_aoi_*.gpkg` and `inst/extdata/context_*.gpkg`, watershed groups, lakes, rivers and streams from the BC Freshwater Atlas and ecoregions from the Ecoregion Ecosystem Classification of British Columbia, under the [Open Government Licence – British Columbia](https://www2.gov.bc.ca/gov/content/data/policy-standards/open-data/open-government-licence-bc).

> Contains information licensed under the Open Government Licence – British Columbia.
