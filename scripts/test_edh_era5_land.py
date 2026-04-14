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
# ]
# ///
"""
Benchmark test: pull one month of ERA5-Land hourly 2m_temperature for BC
bbox from DestinE Earth Data Hub (Zarr) and compare to CDS throughput.

Reference: CDS takes ~80s per month (download + polite sleep). If EDH Zarr
can do the same in <30s, we have a clear winner.

Portable — uses PEP 723 inline deps. Run with:
  uv run scripts/test_edh_era5_land.py

Token lookup order: EDH_TOKEN env var, then ~/.Renviron.
"""
import os
import time
import xarray as xr
import numpy as np

# -- Config --------------------------------------------------------------------
# BC bbox (matches scripts/pipeline_tmax_tmin_hourly.R)
# area format in ecmwfr: c(N, W, S, E) = c(60, -140, 48, -114)
LAT_N, LAT_S = 60.0, 48.0
LON_W, LON_E = -140.0, -114.0

# One test month to benchmark against CDS
YEAR = 1960
MONTH = 1

# -- Token ---------------------------------------------------------------------
token = os.environ.get("EDH_TOKEN")
if not token:
    # Fallback: try reading from ~/.Renviron
    renviron = os.path.expanduser("~/.Renviron")
    if os.path.exists(renviron):
        with open(renviron) as f:
            for line in f:
                if line.strip().startswith("EDH_TOKEN="):
                    token = line.strip().split("=", 1)[1]
                    break
if not token:
    raise SystemExit("EDH_TOKEN not found in env or ~/.Renviron")

# -- Open Zarr -----------------------------------------------------------------
zarr_url = (
    f"https://edh:{token}@data.earthdatahub.destine.eu/era5/"
    "reanalysis-era5-land-no-antartica-v0.zarr"
)

print(f"Opening Zarr store for ERA5-Land hourly...")
t0 = time.time()
ds = xr.open_dataset(zarr_url, chunks={}, engine="zarr")
print(f"  Opened in {time.time() - t0:.1f}s")
print(f"  Variables: {list(ds.data_vars)}")
print(f"  Full extent: {dict(ds.sizes)}")
print(f"  Time range: {ds.valid_time.values.min()} to {ds.valid_time.values.max()}")

# -- Subset to BC + one month --------------------------------------------------
print(f"\nSubsetting to BC bbox, {YEAR}-{MONTH:02d} ...")
t0 = time.time()

# EDH uses longitude 0-360 or -180-180? Check coord convention
lon_min, lon_max = float(ds.longitude.min()), float(ds.longitude.max())
print(f"  Longitude convention: {lon_min} to {lon_max}")

# Translate BC bbox if EDH uses 0-360
if lon_min >= 0:
    bc_west = LON_W + 360
    bc_east = LON_E + 360
else:
    bc_west, bc_east = LON_W, LON_E

start = f"{YEAR}-{MONTH:02d}-01"
end = f"{YEAR}-{MONTH:02d}-28" if MONTH == 2 else f"{YEAR}-{MONTH:02d}-{[31,28,31,30,31,30,31,31,30,31,30,31][MONTH-1]}"

subset = ds["t2m"].sel(
    valid_time=slice(start, end),
    latitude=slice(LAT_N, LAT_S),  # EDH typically has lat descending
    longitude=slice(bc_west, bc_east),
)
print(f"  Subset shape: {dict(subset.sizes)}")
assert all(v > 0 for v in subset.sizes.values()), (
    f"Empty subset {dict(subset.sizes)} — check lat direction / lon convention"
)

# Force compute (download chunks)
values = subset.values
elapsed = time.time() - t0
size_mb = values.nbytes / 1e6
print(f"  Downloaded and materialized in {elapsed:.1f}s")
print(f"  In-memory size: {size_mb:.1f} MB")
n_total = values.size
n_nan = np.isnan(values).sum()
print(f"  NaN cells (ocean): {n_nan} / {n_total} ({100 * n_nan / n_total:.1f}%)")
print(f"  Values (land only): {np.nanmin(values):.1f} to {np.nanmax(values):.1f} K")
print(f"  Values (land only, C): {np.nanmin(values) - 273.15:.1f} to {np.nanmax(values) - 273.15:.1f} C")

# -- Verdict -------------------------------------------------------------------
print("\n=== BENCHMARK VS CDS ===")
print(f"EDH:  {elapsed:.1f}s for one month BC hourly t2m")
print(f"CDS:  ~80s per month (download + polite sleep)")
if elapsed < 60:
    print(f"EDH is {80 / elapsed:.1f}x faster — clear winner")
elif elapsed < 120:
    print(f"EDH is comparable to CDS but without quota issues")
else:
    print(f"EDH is slower than CDS — not worth switching on speed alone")
