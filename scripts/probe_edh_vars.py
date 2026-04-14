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
Probe EDH to confirm each variable we need is what we expect, before
extending the backfill to all variables.

Strategy:
  1. For one sample month (Jan 2000), pull EDH hourly data for each
     candidate variable.
  2. Aggregate to monthly (mean for state variables, sum for precip).
  3. Compare against the existing CDS-derived monthly TIF in
     data/backfill/monthly/ for the same variable and month.
  4. Report: units, value ranges, correlation, mean abs diff.

If EDH output agrees with CDS to within expected rounding/grid-boundary
differences, we're safe to extend the backfill.

Variables probed:
  - t2m   → tmean (monthly mean of hourly)
  - d2m   → dewpoint (monthly mean of hourly)
  - tp    → prcp (monthly SUM of hourly, × 1000 m → mm)
  - swvl1..4 → soil_moisture (monthly mean of hourly, depth-weighted combine
               done in R cd_derive_soil — here we just report per-depth mean)

Usage:
  uv run scripts/probe_edh_vars.py
"""
import os
import sys
import time
from pathlib import Path

import numpy as np
import rasterio
import xarray as xr

LAT_N, LAT_S = 60.0, 48.0
LON_W, LON_E = -140.0, -114.0

YEAR = 2000
MONTH = 1  # January
MONTH_LABEL = "Jan"

REPO_ROOT = Path(__file__).resolve().parent.parent
MONTHLY_DIR = REPO_ROOT / "data" / "backfill" / "monthly"


def get_token() -> str:
    token = os.environ.get("EDH_TOKEN")
    if token:
        return token
    renviron = Path.home() / ".Renviron"
    if renviron.exists():
        for line in renviron.read_text().splitlines():
            if line.strip().startswith("EDH_TOKEN="):
                return line.strip().split("=", 1)[1]
    sys.exit("EDH_TOKEN not found")


def read_cds_layer(var_name: str, layer_label: str = MONTH_LABEL) -> np.ndarray | None:
    """Read one month-layer from an existing CDS-era TIF, if present."""
    path = MONTHLY_DIR / f"{var_name}_{YEAR}.tif"
    if not path.exists():
        return None
    with rasterio.open(path) as src:
        if src.descriptions:
            try:
                idx = src.descriptions.index(layer_label) + 1
            except ValueError:
                idx = 1  # fall back to first band if not labelled
        else:
            idx = 1
        return src.read(idx)


def summary(name: str, arr: np.ndarray, unit: str):
    print(f"  {name:30s}: {np.nanmin(arr):10.3f} {np.nanmax(arr):10.3f} "
          f"{np.nanmean(arr):10.3f} {unit}   (min, max, mean)")


def compare(name: str, edh: np.ndarray, cds: np.ndarray | None, unit: str):
    if cds is None:
        print(f"  {name}: no CDS file to compare — EDH only")
        summary(f"  EDH {name}", edh, unit)
        return

    # Dimensions may differ by 1 (121 vs 120 etc) — crop to min shape, which
    # is only informative if the grids line up at a reference point.
    min_rows = min(edh.shape[0], cds.shape[0])
    min_cols = min(edh.shape[1], cds.shape[1])
    e = edh[:min_rows, :min_cols]
    c = cds[:min_rows, :min_cols]

    # Mask where either is NaN
    mask = ~(np.isnan(e) | np.isnan(c))
    diff = e[mask] - c[mask]

    print(f"\n  {name}:")
    summary(f"  EDH {name}", edh, unit)
    summary(f"  CDS {name}", cds, unit)
    print(f"  overlap (min shape {min_rows}x{min_cols}, {mask.sum()} shared non-NaN cells):")
    print(f"    diff (EDH - CDS): min={diff.min():.3f}, max={diff.max():.3f}, "
          f"mean={diff.mean():.3f}, abs mean={np.abs(diff).mean():.3f} {unit}")
    if len(diff) > 100:
        corr = np.corrcoef(e[mask], c[mask])[0, 1]
        print(f"    correlation:     {corr:.4f}")


def main():
    token = get_token()
    zarr_url = (
        f"https://edh:{token}@data.earthdatahub.destine.eu/era5/"
        "reanalysis-era5-land-no-antartica-v0.zarr"
    )

    print(f"[{time.strftime('%H:%M:%S')}] Opening EDH Zarr...")
    ds = xr.open_dataset(zarr_url, chunks={}, engine="zarr")

    # Longitude translation
    lon_min = float(ds.longitude.min())
    if lon_min >= 0:
        bc_west, bc_east = LON_W + 360, LON_E + 360
    else:
        bc_west, bc_east = LON_W, LON_E

    # Time slice for one month
    n_days = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][MONTH - 1]  # 2000 was leap
    start = f"{YEAR}-{MONTH:02d}-01"
    end = f"{YEAR}-{MONTH:02d}-{n_days}T23:00"

    print(f"[{time.strftime('%H:%M:%S')}] Subsetting to BC, {start} to {end}")
    box = dict(
        valid_time=slice(start, end),
        latitude=slice(LAT_N, LAT_S),
        longitude=slice(bc_west, bc_east),
    )

    # -- t2m → tmean ----------------------------------------------------------
    print(f"\n[{time.strftime('%H:%M:%S')}] --- t2m (→ tmean) ---")
    t2m_hourly = ds["t2m"].sel(**box)
    t2m_monthly = (t2m_hourly.mean(dim="valid_time") - 273.15).compute().values
    cds_tmean_jan = read_cds_layer("tmean")
    compare("tmean (°C)", t2m_monthly, cds_tmean_jan, "°C")

    # -- d2m → dewpoint -------------------------------------------------------
    print(f"\n[{time.strftime('%H:%M:%S')}] --- d2m (→ dewpoint) ---")
    d2m_hourly = ds["d2m"].sel(**box)
    d2m_monthly = (d2m_hourly.mean(dim="valid_time") - 273.15).compute().values
    # CDS stored dewpoint in its raw pipeline stage; may not have a direct
    # monthly TIF since we derive VPD/RH from it. Just report EDH summary.
    summary("EDH dewpoint (°C)", d2m_monthly, "°C")

    # -- tp → prcp ------------------------------------------------------------
    # ERA5-Land tp is "total precipitation since start of forecast"; in the
    # hourly version it is accumulated from 00 UTC reset each day in the
    # most common convention. To get monthly precip (mm) we need to
    # understand the accumulation behaviour first.
    print(f"\n[{time.strftime('%H:%M:%S')}] --- tp (→ prcp) ---")
    tp_hourly = ds["tp"].sel(**box)
    # Probe: look at attributes and a single-cell time series to understand
    # accumulation behaviour.
    print(f"  tp attrs: {dict(tp_hourly.attrs)}")
    # Central-BC land cell: Prince George is ~53.9N, -122.75W → +237.25 in 0-360
    prince_george = tp_hourly.sel(latitude=53.9, longitude=237.25, method="nearest")
    pg_first_48h = prince_george.isel(valid_time=slice(0, 48)).compute().values
    print(f"  Prince George first 48h tp (m): min={pg_first_48h.min():.6f} "
          f"max={pg_first_48h.max():.6f} mean={pg_first_48h.mean():.6f}")
    print(f"  First 24 hours: {[f'{v:.6f}' for v in pg_first_48h[:24]]}")
    print(f"  Hours 24-48:    {[f'{v:.6f}' for v in pg_first_48h[24:48]]}")

    # Both interpretations below are intentionally wrong to demonstrate that
    # hourly tp accumulation cannot be naively summed.
    #
    # A: treat hourly as per-hour increment → 8× too high because tp is
    #    actually a running daily accumulation, not per-hour.
    # B: sum of daily max using calendar-day grouping → still biased because
    #    the 01:00 UTC reset means the "max" within a calendar day window
    #    is typically at 00:00 (the END of the previous accumulation cycle),
    #    which is yesterday's total, not today's.
    #
    # The correct answer is to use EDH's daily product which pre-computes
    # daily totals with the right semantics. Demonstrating the failure modes
    # here so the decision is self-documenting.
    tp_sum_mm = (tp_hourly.sum(dim="valid_time") * 1000).compute().values
    tp_daily_max = tp_hourly.resample(valid_time="1D").max()
    tp_daily_sum_mm = (tp_daily_max.sum(dim="valid_time") * 1000).compute().values

    cds_prcp_jan = read_cds_layer("prcp")
    print("\n  Interpretation A — hourly tp is per-hour increment (sum × 1000):")
    compare("prcp_A (mm)", tp_sum_mm, cds_prcp_jan, "mm")
    print("\n  Interpretation B — hourly tp is daily accumulation (sum of daily max × 1000):")
    compare("prcp_B (mm)", tp_daily_sum_mm, cds_prcp_jan, "mm")

    # -- swvl1..4 → soil_moisture ---------------------------------------------
    print(f"\n[{time.strftime('%H:%M:%S')}] --- swvl1..4 (→ soil_moisture) ---")
    for depth in (1, 2, 3, 4):
        v = f"swvl{depth}"
        sm = ds[v].sel(**box).mean(dim="valid_time").compute().values
        summary(f"EDH {v} (m³/m³)", sm, "m³/m³")
    # Existing CDS-derived soil_moisture is a single composite layer per month.
    cds_sm_jan = read_cds_layer("soil_moisture")
    if cds_sm_jan is not None:
        summary("CDS soil_moisture composite (m³/m³)", cds_sm_jan, "m³/m³")

    print(f"\n[{time.strftime('%H:%M:%S')}] DONE")


if __name__ == "__main__":
    main()
