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
EDH backfill for snow-related variables over BC (1950-2025).

Produces two layers of outputs from a single hourly fetch per year:

Monthly natives (`data/backfill/monthly/{var}_{year}.tif`, 12 bands):
  swe_YYYY.tif    mm SWE  monthly mean of daily sde * rsn
  snowfall_YYYY.tif      mm      monthly sum  of daily sf (accum-handled)
  snowmelt_YYYY.tif      mm      monthly sum  of daily smlt (accum-handled)
  snow_cover_YYYY.tif    %       monthly mean of daily snowc (native ERA5-Land percent)

Annual derived (`data/backfill/annual/{var}_{year}.tif`, 1 band):
  swe_max_YYYY.tif              mm     annual max of daily sde * rsn
  snowfall_fraction_YYYY.tif    %      100 * annual_sum_sf / annual_sum_tp
  snowmelt_doy_50_YYYY.tif      day    DOY when cumsum(smlt) >= 0.5*annual_sum
  snowmelt_rate_peak_YYYY.tif   mm/wk  annual max of 7-day rolling sum of daily smlt

Idempotent per (variable, year): skips outputs that already exist.

Source: hourly EDH product `reanalysis-era5-land-no-antartica-v0.zarr`
(snow vars are NOT in the daily UTC product per probe results in #48).
Plus daily product `era5-land-daily-utc-v1.zarr` for `tp` (used in
snowfall_fraction; matches the existing prcp pipeline pattern).

ACCUMULATION HANDLING (sf, smlt):
  ECMWF ERA5-Land sf and smlt have GRIB stepType=accum — running
  accumulation from 01:00 UTC reset to 00:00 UTC next day. Naive
  hourly sum gives ~24x wrong values (same trap as `tp` in #36; for
  `tp` we punted to the daily product, but snow has no daily-product
  fallback). Daily total for day D = value at valid_time = D+1 00:00
  UTC. Implementation in `hourly_accum_to_daily()`.

POLITENESS:
  Imports `preflight_single_instance` and `with_retry` from
  `scripts/_lib.py` (#38/#52). pgrep guard prevents zombie-process
  hammering, with_retry handles transient EDH blips with exponential
  backoff. Idempotent per-output skipping means a killed-and-restarted
  run picks up where it left off without re-fetching.

Usage:
  uv run scripts/backfill_edh_snow.py              # full backfill
  uv run scripts/backfill_edh_snow.py --year 2020  # single year test
"""
import argparse
import time
from pathlib import Path

import numpy as np
import xarray as xr

from _lib import (
    get_token,
    log,
    preflight_single_instance,
    with_retry,
    write_geotiff,
)

# -- Config --------------------------------------------------------------------
LAT_N, LAT_S = 60.0, 48.0
LON_W, LON_E = -140.0, -114.0

YEARS_DEFAULT = range(1950, 2026)

REPO_ROOT = Path(__file__).resolve().parent.parent
MONTHLY_DIR = REPO_ROOT / "data" / "backfill" / "monthly"
ANNUAL_DIR = REPO_ROOT / "data" / "backfill" / "annual"

MONTHLY_VARS = ("swe", "snowfall", "snowmelt", "snow_cover")
ANNUAL_VARS = ("swe_max", "snowfall_fraction", "snowmelt_doy_50",
               "snowmelt_rate_peak")


# -- Helpers -------------------------------------------------------------------
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


def hourly_accum_to_daily(da_hourly: xr.DataArray) -> xr.DataArray:
    """Convert hourly ERA5-Land accumulation variable to daily totals.

    ERA5-Land stepType=accum convention: the value at valid_time = t
    (00:00 UTC) is the accumulation from t-24h to t. So daily total
    for day D = value at valid_time D+1 00:00 UTC.

    Caller fetches `valid_time` from year-01-02T00:00 through
    year+1-01-01T00:00 (one day past year end). This function:
      1. Selects 00:00 UTC values only
      2. Shifts the time coord back by 1 day so labels match the day
         actually accumulated
    """
    da_midnight = da_hourly.where(
        da_hourly.valid_time.dt.hour == 0, drop=True
    )
    return da_midnight.assign_coords(
        valid_time=da_midnight.valid_time - np.timedelta64(1, "D")
    )


def write_annual_geotiff(da_2d: xr.DataArray, out_path: Path, year: int) -> None:
    """Write a 2D (lat, lon) DataArray as a 1-band annual GeoTIFF.

    Adds a length-1 valid_time dim so write_geotiff's band-naming
    logic applies cleanly. Band name is the year string.
    """
    da_3d = da_2d.expand_dims(
        valid_time=[np.datetime64(f"{year}-01-01")]
    )
    write_geotiff(da_3d, out_path, band_names=[str(year)])


# -- Per-year processing -------------------------------------------------------
def outputs_for_year(year: int) -> dict:
    out = {}
    for v in MONTHLY_VARS:
        out[v] = MONTHLY_DIR / f"{v}_{year}.tif"
    for v in ANNUAL_VARS:
        out[v] = ANNUAL_DIR / f"{v}_{year}.tif"
    return out


def process_year(year: int, hourly_ds: xr.Dataset, daily_ds: xr.Dataset) -> None:
    out = outputs_for_year(year)
    needed = {v: p for v, p in out.items() if not p.exists()}
    if not needed:
        log(f"{year}: all outputs exist, skipping")
        return

    log(f"{year}: needed = {sorted(needed)}")
    t_year = time.time()

    # Which source variables do we need?
    needed_hourly = set()
    if any(v in needed for v in ("swe", "swe_max")):
        needed_hourly.update({"sde", "rsn"})
    if any(v in needed for v in ("snowfall", "snowfall_fraction")):
        needed_hourly.add("sf")
    if any(v in needed for v in ("snowmelt", "snowmelt_doy_50",
                                  "snowmelt_rate_peak")):
        needed_hourly.add("smlt")
    if "snow_cover" in needed:
        needed_hourly.add("snowc")

    # State vars (sde, rsn, snowc): daily mean over the calendar year
    daily_vars: dict[str, xr.DataArray] = {}
    state_box = bc_slice(hourly_ds,
                         f"{year}-01-01T00:00",
                         f"{year}-12-31T23:00")
    for v in ("sde", "rsn", "snowc"):
        if v in needed_hourly:
            hourly = hourly_ds[v].sel(**state_box)
            daily_vars[v] = with_retry(
                lambda h=hourly: h.resample(valid_time="1D").mean().compute(),
                what=f"compute daily {v} {year}",
            )

    # Accum vars (sf, smlt): need one extra day past year-end for the
    # 00:00 UTC reset trick, then hourly_accum_to_daily reduces.
    if "sf" in needed_hourly or "smlt" in needed_hourly:
        accum_box = bc_slice(hourly_ds,
                             f"{year}-01-02T00:00",
                             f"{year + 1}-01-01T00:00")
        for v in ("sf", "smlt"):
            if v in needed_hourly:
                hourly = hourly_ds[v].sel(**accum_box)
                daily_lazy = hourly_accum_to_daily(hourly)
                daily_vars[v] = with_retry(
                    lambda d=daily_lazy: d.compute(),
                    what=f"compute daily {v} {year}",
                )

    # Sanity check: all daily series should have ~365-366 days
    for v, da in daily_vars.items():
        n_days = da.sizes["valid_time"]
        if n_days < 365:
            log(f"  WARN {v}: got {n_days} days, expected 365-366 (incomplete year?)")

    # ---------------- monthly natives ----------------
    if "swe" in needed:
        # SWE in mm: sde (m) * rsn (kg/m^3) = kg/m^2 = mm of water
        daily_swe = daily_vars["sde"] * daily_vars["rsn"]
        monthly = daily_swe.resample(valid_time="1MS").mean()
        if monthly.sizes["valid_time"] == 12:
            write_geotiff(monthly, out["swe"])
            log(f"  wrote {out['swe'].name}")
        else:
            log(f"  SKIP swe: got {monthly.sizes['valid_time']} months")

    if "snowfall" in needed:
        # daily sf in m water-equiv -> monthly sum * 1000 = mm/month
        monthly = daily_vars["sf"].resample(valid_time="1MS").sum() * 1000
        if monthly.sizes["valid_time"] == 12:
            write_geotiff(monthly, out["snowfall"])
            log(f"  wrote {out['snowfall'].name}")
        else:
            log(f"  SKIP snowfall: got {monthly.sizes['valid_time']} months")

    if "snowmelt" in needed:
        monthly = daily_vars["smlt"].resample(valid_time="1MS").sum() * 1000
        if monthly.sizes["valid_time"] == 12:
            write_geotiff(monthly, out["snowmelt"])
            log(f"  wrote {out['snowmelt'].name}")
        else:
            log(f"  SKIP snowmelt: got {monthly.sizes['valid_time']} months")

    if "snow_cover" in needed:
        monthly = daily_vars["snowc"].resample(valid_time="1MS").mean()
        if monthly.sizes["valid_time"] == 12:
            write_geotiff(monthly, out["snow_cover"])
            log(f"  wrote {out['snow_cover'].name}")
        else:
            log(f"  SKIP snow_cover: got {monthly.sizes['valid_time']} months")

    # ---------------- annual derived ----------------
    if "swe_max" in needed:
        daily_swe = daily_vars["sde"] * daily_vars["rsn"]
        annual_max = daily_swe.max(dim="valid_time")
        write_annual_geotiff(annual_max, out["swe_max"], year)
        log(f"  wrote {out['swe_max'].name}")

    if "snowfall_fraction" in needed:
        annual_sf = daily_vars["sf"].sum(dim="valid_time")  # m
        daily_box_tp = bc_slice(daily_ds, f"{year}-01-01", f"{year}-12-31")
        tp_daily = daily_ds["tp"].sel(**daily_box_tp)
        annual_tp = with_retry(
            lambda: tp_daily.sum(dim="valid_time").compute(),
            what=f"compute annual tp {year}",
        )
        sf_pct = (100 * annual_sf / annual_tp).where(annual_tp > 0, 0).clip(0, 100)
        write_annual_geotiff(sf_pct, out["snowfall_fraction"], year)
        log(f"  wrote {out['snowfall_fraction'].name}")

    if "snowmelt_doy_50" in needed:
        smlt = daily_vars["smlt"]
        annual_sum = smlt.sum(dim="valid_time")
        cumsum = smlt.cumsum(dim="valid_time")
        threshold = 0.5 * annual_sum
        crossed = cumsum >= threshold
        # First True along time axis; +1 for 1-based DOY
        doy = (crossed.argmax(dim="valid_time") + 1).where(annual_sum > 0)
        write_annual_geotiff(doy, out["snowmelt_doy_50"], year)
        log(f"  wrote {out['snowmelt_doy_50'].name}")

    if "snowmelt_rate_peak" in needed:
        # 7-day rolling sum of daily smlt -> annual max, in mm/week
        smlt = daily_vars["smlt"]
        rolling7 = smlt.rolling(valid_time=7, min_periods=1).sum() * 1000
        peak = rolling7.max(dim="valid_time")
        write_annual_geotiff(peak, out["snowmelt_rate_peak"], year)
        log(f"  wrote {out['snowmelt_rate_peak'].name}")

    log(f"{year}: done in {time.time() - t_year:.1f}s")


# -- Main ----------------------------------------------------------------------
def main(years):
    preflight_single_instance("backfill_edh_snow")
    MONTHLY_DIR.mkdir(parents=True, exist_ok=True)
    ANNUAL_DIR.mkdir(parents=True, exist_ok=True)
    token = get_token()

    log("Opening hourly Zarr (reanalysis-era5-land-no-antartica-v0)...")
    hourly_ds = with_retry(
        lambda: open_zarr("era5/reanalysis-era5-land-no-antartica-v0.zarr", token),
        what="open hourly zarr",
    )
    log("Opening daily Zarr (era5-land-daily-utc-v1)...")
    daily_ds = with_retry(
        lambda: open_zarr("era5/era5-land-daily-utc-v1.zarr", token),
        what="open daily zarr",
    )

    for year in years:
        try:
            with_retry(
                lambda y=year: process_year(y, hourly_ds, daily_ds),
                what=f"process year {year}",
            )
        except Exception as e:
            log(f"FAILED year {year} after retries: {type(e).__name__}: {e}")
            log("Continuing to next year (idempotent — restart to retry this one)")

    log("ALL DONE")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--year", type=int,
                        help="Single year to backfill (for testing)")
    args = parser.parse_args()
    years = [args.year] if args.year else YEARS_DEFAULT
    main(years)
