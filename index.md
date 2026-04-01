Compute climate anomalies from ERA5-Land reanalysis data for custom
areas of interest. Producer functions download ERA5-Land monthly means,
derive variables (VPD, RH, soil moisture), and publish Cloud-Optimized
GeoTIFFs with a static STAC catalog. Consumer functions query the
catalog, crop to AOI, compute baselines and anomalies for arbitrary
reference periods, and run trend analysis (Mann-Kendall and Theil-Sen).
