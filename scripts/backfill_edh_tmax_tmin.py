#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "xarray",
#   "zarr",
#   "fsspec",
#   "aiohttp",
#   "requests",
#   "dask",
#   "numpy",
#   "rioxarray",
#   "rasterio",
# ]
# ///
"""
Full-backfill EDH pipeline for tmax/tmin over BC (1950-2025).

Replaces the CDS-based pipeline_tmax_tmin_hourly.R stages 1 and 2:
  1. Pull hourly 2m_temperature from DestinE Earth Data Hub (Zarr)
  2. Compute daily max/min, then monthly mean of daily max/min
  3. Write per-year GeoTIFFs with 12 month-layers each, °C

Output drop-in replacement for data/backfill/monthly/:
  tmax_YYYY.tif (12 layers: Jan..Dec, degrees C, EPSG:4326, BC bbox)
  tmin_YYYY.tif (same)

The existing R script's Stage 3 (COG aggregation, STAC catalog, S3 push)
can then run unchanged from these outputs.

KNOWN LIMITATION: daily max/min is computed over UTC-day windows. For BC
(UTC-8 winter, UTC-7 summer) the local-afternoon tmax peak can straddle
UTC day boundaries, producing a small systematic bias vs. a local-time
daily aggregation. This matches the behaviour of the existing R pipeline
(scripts/pipeline_tmax_tmin_hourly.R) so outputs are comparable. CDS's
derived-era5-land-daily-statistics product accepts a time_zone parameter
to fix this, but we abandoned it due to rate limits (see #33).

Idempotent — skips years whose tmax_YYYY.tif and tmin_YYYY.tif already exist.
Partial years (in-progress current year) are caught by the `n_months != 12`
guard and skipped with a warning.

Usage:
  uv run scripts/backfill_edh_tmax_tmin.py              # full backfill
  uv run scripts/backfill_edh_tmax_tmin.py --year 1950  # single year test
"""
import argparse
import os
import sys
import time
from pathlib import Path

import numpy as np
import rasterio
import xarray as xr

# -- Config --------------------------------------------------------------------
# BC bbox, matches scripts/pipeline_tmax_tmin_hourly.R
LAT_N, LAT_S = 60.0, 48.0
LON_W, LON_E = -140.0, -114.0  # will translate to 0-360 for EDH

YEARS_DEFAULT = range(1950, 2026)

REPO_ROOT = Path(__file__).resolve().parent.parent
MONTHLY_DIR = REPO_ROOT / "data" / "backfill" / "monthly"

MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
               "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]


# -- Token ---------------------------------------------------------------------
def get_token() -> str:
    token = os.environ.get("EDH_TOKEN")
    if token:
        return token
    renviron = Path.home() / ".Renviron"
    if renviron.exists():
        for line in renviron.read_text().splitlines():
            if line.strip().startswith("EDH_TOKEN="):
                return line.strip().split("=", 1)[1]
    sys.exit("EDH_TOKEN not found in env or ~/.Renviron")


# -- Main ----------------------------------------------------------------------
def main(years):
    MONTHLY_DIR.mkdir(parents=True, exist_ok=True)

    token = get_token()
    zarr_url = (
        f"https://edh:{token}@data.earthdatahub.destine.eu/era5/"
        "reanalysis-era5-land-no-antartica-v0.zarr"
    )

    print(f"[{time.strftime('%H:%M:%S')}] Opening EDH Zarr store...")
    t0 = time.time()
    ds = xr.open_dataset(zarr_url, chunks={}, engine="zarr")
    print(f"  Opened in {time.time() - t0:.1f}s")

    # Longitude convention
    lon_min = float(ds.longitude.min())
    if lon_min >= 0:
        bc_west, bc_east = LON_W + 360, LON_E + 360
    else:
        bc_west, bc_east = LON_W, LON_E

    for year in years:
        tmax_out = MONTHLY_DIR / f"tmax_{year}.tif"
        tmin_out = MONTHLY_DIR / f"tmin_{year}.tif"

        if tmax_out.exists() and tmin_out.exists():
            print(f"[{time.strftime('%H:%M:%S')}] {year}: exists, skipping")
            continue

        print(f"[{time.strftime('%H:%M:%S')}] {year}: fetching...")
        t_year = time.time()

        # Pull entire year of hourly t2m for BC
        hourly = ds["t2m"].sel(
            valid_time=slice(f"{year}-01-01", f"{year}-12-31T23:00"),
            latitude=slice(LAT_N, LAT_S),
            longitude=slice(bc_west, bc_east),
        )

        # Daily max/min, then monthly mean of each → 12 layers per year
        # resample labels: '1D' → daily, '1MS' → month start
        daily_max = hourly.resample(valid_time="1D").max()
        daily_min = hourly.resample(valid_time="1D").min()
        monthly_tmax = daily_max.resample(valid_time="1MS").mean() - 273.15
        monthly_tmin = daily_min.resample(valid_time="1MS").mean() - 273.15

        # Materialize
        monthly_tmax = monthly_tmax.compute()
        monthly_tmin = monthly_tmin.compute()

        n_months = monthly_tmax.sizes["valid_time"]
        if n_months != 12:
            print(f"  WARNING: {year} has {n_months} months, expected 12 — skipping")
            continue

        # Name layers Jan..Dec, translate longitude back to -180..180 for GeoTIFF
        def to_geotiff_raster(da, out_path):
            da = da.rename({"valid_time": "band"})
            da = da.assign_coords(band=MONTH_NAMES)
            # Translate longitude back if needed
            if float(da.longitude.max()) > 180:
                new_lon = da.longitude.where(da.longitude <= 180, da.longitude - 360)
                da = da.assign_coords(longitude=new_lon).sortby("longitude")
            # rioxarray expects 'x' and 'y' dim names
            da = da.rename({"longitude": "x", "latitude": "y"})
            da.rio.write_crs("EPSG:4326", inplace=True)
            da.rio.to_raster(out_path)
            # Set per-band descriptions so terra::rast() picks up Jan..Dec names
            # (required by cd_aggregate() for seasonal grouping)
            with rasterio.open(out_path, "r+") as dst:
                dst.descriptions = tuple(MONTH_NAMES)

        import rioxarray  # noqa: F401 — registers `.rio` accessor

        to_geotiff_raster(monthly_tmax, tmax_out)
        to_geotiff_raster(monthly_tmin, tmin_out)

        elapsed = time.time() - t_year
        print(f"  Wrote {tmax_out.name} and {tmin_out.name} in {elapsed:.1f}s")

    print(f"[{time.strftime('%H:%M:%S')}] DONE")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--year", type=int, help="Single year to backfill (for testing)")
    args = parser.parse_args()
    years = [args.year] if args.year else YEARS_DEFAULT
    main(years)
