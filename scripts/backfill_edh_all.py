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
Unified EDH backfill for all cd package variables (1950-2025).

Produces data/backfill/monthly/*.tif in a single consistent grid (EPSG:4326,
BC bbox, 120x260) with proper CRS tagging, so cd_extract() returns aligned
pixels across variables.

Output (per year):
  tmax_YYYY.tif, tmin_YYYY.tif              °C    (hourly t2m → daily max/min → monthly mean)
  tmean_YYYY.tif                            °C    (hourly t2m → monthly mean)
  vpd_YYYY.tif                              hPa   (Tetens from tmean + dewpoint)
  rh_YYYY.tif                               %     (from tmean + dewpoint)
  prcp_YYYY.tif                             mm    (DAILY product tp → monthly sum × 1000)
  soil_moisture_YYYY.tif                    m3/m3 (hourly swvl1..4 → monthly mean → 4-depth mean)

Idempotent per (variable, year): skips outputs that already exist.

Uses TWO EDH Zarr stores:
  - Hourly `reanalysis-era5-land-no-antartica-v0.zarr` for all state variables
  - Daily  `era5-land-daily-utc-v1.zarr`               for precipitation only
    (because ERA5-Land hourly `tp` has GRIB_stepType=accum and naive summing
    produces wildly wrong results — the daily product handles the reset).

Usage:
  uv run scripts/backfill_edh_all.py              # full backfill
  uv run scripts/backfill_edh_all.py --year 2000  # single year test
"""
import argparse
import os
import sys
import time
from pathlib import Path

import numpy as np
import rasterio
import rioxarray  # noqa: F401 — registers .rio accessor
import xarray as xr

# -- Config --------------------------------------------------------------------
LAT_N, LAT_S = 60.0, 48.0
LON_W, LON_E = -140.0, -114.0

YEARS_DEFAULT = range(1950, 2026)

REPO_ROOT = Path(__file__).resolve().parent.parent
MONTHLY_DIR = REPO_ROOT / "data" / "backfill" / "monthly"

MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
               "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]


# -- Helpers -------------------------------------------------------------------
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


def open_zarr(url_path: str, token: str) -> xr.Dataset:
    url = f"https://edh:{token}@data.earthdatahub.destine.eu/{url_path}"
    return xr.open_dataset(url, chunks={}, engine="zarr")


def bc_slice(ds: xr.Dataset, start: str, end: str) -> dict:
    lon_min = float(ds.longitude.min())
    if lon_min >= 0:
        bc_west, bc_east = LON_W + 360, LON_E + 360
    else:
        bc_west, bc_east = LON_W, LON_E
    return dict(
        valid_time=slice(start, end),
        latitude=slice(LAT_N, LAT_S),
        longitude=slice(bc_west, bc_east),
    )


def tetens_es(t_c):
    """Saturation vapour pressure (hPa) given temperature in °C (Tetens)."""
    return 6.1078 * np.exp(17.27 * t_c / (t_c + 237.3))


def write_geotiff(da: xr.DataArray, out_path: Path):
    """Write an xarray DataArray with (valid_time, latitude, longitude) dims
    as a multi-band EPSG:4326 GeoTIFF with Jan..Dec band descriptions.

    Atomic: writes to a .tmp suffix then renames, so a killed run never
    leaves a truncated file that passes the existence check on restart.
    """
    da = da.rename({"valid_time": "band"}).assign_coords(band=MONTH_NAMES)
    # Translate longitude back to -180..180 if needed
    if float(da.longitude.max()) > 180:
        new_lon = da.longitude.where(da.longitude <= 180, da.longitude - 360)
        da = da.assign_coords(longitude=new_lon).sortby("longitude")
    da = da.rename({"longitude": "x", "latitude": "y"})
    da.rio.write_crs("EPSG:4326", inplace=True)

    tmp_path = out_path.with_suffix(out_path.suffix + ".tmp")
    try:
        da.rio.to_raster(tmp_path, driver="GTiff")
        # Per-band descriptions so terra::rast() picks up Jan..Dec names
        with rasterio.open(tmp_path, "r+") as dst:
            dst.descriptions = tuple(MONTH_NAMES)
        os.replace(tmp_path, out_path)
    except Exception:
        if tmp_path.exists():
            tmp_path.unlink()
        raise


def log(msg: str):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


# -- Per-year processing -------------------------------------------------------
def outputs_for_year(year: int) -> dict:
    """Map output variable name to Path."""
    return {v: MONTHLY_DIR / f"{v}_{year}.tif" for v in (
        "tmax", "tmin", "tmean", "vpd", "rh", "prcp", "soil_moisture")}


def process_year(year: int, hourly_ds: xr.Dataset, daily_ds: xr.Dataset):
    out = outputs_for_year(year)

    # Which outputs are missing?
    needed = {v: p for v, p in out.items() if not p.exists()}
    if not needed:
        log(f"{year}: all outputs exist, skipping")
        return

    log(f"{year}: needed = {sorted(needed)}")
    t_year = time.time()

    # Hourly subset for the full year (all the state variables we need)
    hourly_box = bc_slice(hourly_ds, f"{year}-01-01", f"{year}-12-31T23:00")
    needed_hourly_vars = []
    if any(v in needed for v in ("tmax", "tmin", "tmean", "vpd", "rh")):
        needed_hourly_vars.append("t2m")
    if any(v in needed for v in ("vpd", "rh")):
        needed_hourly_vars.append("d2m")
    if "soil_moisture" in needed:
        needed_hourly_vars.extend(["swvl1", "swvl2", "swvl3", "swvl4"])

    hourly_sub = hourly_ds[needed_hourly_vars].sel(**hourly_box) if needed_hourly_vars else None

    # -- tmax / tmin (daily max/min → monthly mean of daily stat) ------------
    if "tmax" in needed or "tmin" in needed:
        t2m = hourly_sub["t2m"]
        if "tmax" in needed:
            daily_max = t2m.resample(valid_time="1D").max()
            monthly_tmax = (daily_max.resample(valid_time="1MS").mean() - 273.15).compute()
            if monthly_tmax.sizes["valid_time"] == 12:
                write_geotiff(monthly_tmax, out["tmax"])
                log(f"  wrote {out['tmax'].name}")
            else:
                log(f"  SKIP tmax: got {monthly_tmax.sizes['valid_time']} months, expected 12")
        if "tmin" in needed:
            daily_min = t2m.resample(valid_time="1D").min()
            monthly_tmin = (daily_min.resample(valid_time="1MS").mean() - 273.15).compute()
            if monthly_tmin.sizes["valid_time"] == 12:
                write_geotiff(monthly_tmin, out["tmin"])
                log(f"  wrote {out['tmin'].name}")
            else:
                log(f"  SKIP tmin: got {monthly_tmin.sizes['valid_time']} months, expected 12")

    # -- tmean (hourly t2m → monthly mean) -----------------------------------
    if "tmean" in needed:
        monthly_tmean = (hourly_sub["t2m"].resample(valid_time="1MS").mean() - 273.15).compute()
        if monthly_tmean.sizes["valid_time"] == 12:
            write_geotiff(monthly_tmean, out["tmean"])
            log(f"  wrote {out['tmean'].name}")
        else:
            log(f"  SKIP tmean: got {monthly_tmean.sizes['valid_time']} months, expected 12")

    # -- vpd / rh (Tetens from monthly mean of tmean + dewpoint) -------------
    # Use monthly-mean tmean and dewpoint as inputs (same as R cd_derive path)
    if "vpd" in needed or "rh" in needed:
        monthly_t_c = (hourly_sub["t2m"].resample(valid_time="1MS").mean() - 273.15).compute()
        monthly_td_c = (hourly_sub["d2m"].resample(valid_time="1MS").mean() - 273.15).compute()
        es = tetens_es(monthly_t_c)
        ea = tetens_es(monthly_td_c)
        n = monthly_t_c.sizes["valid_time"]
        if "vpd" in needed:
            if n == 12:
                vpd = (es - ea).clip(min=0)
                write_geotiff(vpd, out["vpd"])
                log(f"  wrote {out['vpd'].name}")
            else:
                log(f"  SKIP vpd: got {n} months, expected 12")
        if "rh" in needed:
            if n == 12:
                rh = (100 * ea / es).clip(min=0, max=100)
                write_geotiff(rh, out["rh"])
                log(f"  wrote {out['rh'].name}")
            else:
                log(f"  SKIP rh: got {n} months, expected 12")

    # -- soil_moisture (hourly swvl1..4 → monthly mean → 4-depth mean) -------
    if "soil_moisture" in needed:
        depths = [hourly_sub[f"swvl{d}"].resample(valid_time="1MS").mean()
                  for d in (1, 2, 3, 4)]
        monthly_sm = xr.concat(depths, dim="depth").mean(dim="depth").compute()
        if monthly_sm.sizes["valid_time"] == 12:
            write_geotiff(monthly_sm, out["soil_moisture"])
            log(f"  wrote {out['soil_moisture'].name}")
        else:
            log(f"  SKIP soil_moisture: got {monthly_sm.sizes['valid_time']} months, expected 12")

    # -- prcp (DAILY product tp → monthly sum × 1000) ------------------------
    if "prcp" in needed:
        daily_box = bc_slice(daily_ds, f"{year}-01-01", f"{year}-12-31")
        tp_daily = daily_ds["tp"].sel(**daily_box)
        monthly_prcp_m = tp_daily.resample(valid_time="1MS").sum()
        monthly_prcp_mm = (monthly_prcp_m * 1000).compute()
        if monthly_prcp_mm.sizes["valid_time"] == 12:
            write_geotiff(monthly_prcp_mm, out["prcp"])
            log(f"  wrote {out['prcp'].name}")
        else:
            log(f"  SKIP prcp: got {monthly_prcp_mm.sizes['valid_time']} months, expected 12")

    log(f"{year}: done in {time.time() - t_year:.1f}s")


# -- Main ----------------------------------------------------------------------
def main(years):
    MONTHLY_DIR.mkdir(parents=True, exist_ok=True)
    token = get_token()

    log("Opening hourly Zarr (reanalysis-era5-land-no-antartica-v0)...")
    hourly_ds = open_zarr("era5/reanalysis-era5-land-no-antartica-v0.zarr", token)
    log("Opening daily Zarr (era5-land-daily-utc-v1)...")
    daily_ds = open_zarr("era5/era5-land-daily-utc-v1.zarr", token)

    for year in years:
        process_year(year, hourly_ds, daily_ds)

    log("ALL DONE")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--year", type=int, help="Single year to backfill (for testing)")
    args = parser.parse_args()
    years = [args.year] if args.year else YEARS_DEFAULT
    main(years)
