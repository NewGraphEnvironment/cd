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
BC bbox, 121x261 — `bc_slice()` in _lib.py, #123) with proper CRS tagging, so cd_extract() returns aligned
pixels across variables.

Output (per year):
  tmax_YYYY.tif, tmin_YYYY.tif              °C    (hourly t2m → local-day max/min → monthly mean)
  tmean_YYYY.tif                            °C    (hourly t2m → monthly mean)
  vpd_YYYY.tif                              hPa   (Tetens from tmean + dewpoint)
  rh_YYYY.tif                               %     (from tmean + dewpoint)
  prcp_YYYY.tif                             mm    (DAILY product tp → monthly sum × 1000)
  soil_moisture_YYYY.tif                    m3/m3 (hourly swvl1..4 → monthly mean → 4-depth mean)

Idempotent per (variable, year): skips outputs that already exist.

tmax/tmin use local days (fixed UTC-8, `local_daily()` in _lib.py), the same
days as the daily cube; a UTC day splits BC's afternoon peak across two days
(#37). A local year ends at 07:00 UTC on 1 Jan of the next year, so tmax/tmin
for year Y are written only once the store reaches that hour — about a month
after the other variables could be. The other variables keep UTC months.

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
import sys
import time
from pathlib import Path

import dask
import numpy as np
import xarray as xr

from _lib import (
    bc_files_check,
    bc_grid_check,
    bc_slice,
    get_token,
    local_daily,
    local_year_complete,
    local_year_window,
    log,
    monthly_from_daily,
    months_available,
    preflight_single_instance,
    with_retry,
    write_geotiff,
)

# -- Config --------------------------------------------------------------------
YEARS_DEFAULT = range(1950, 2026)

REPO_ROOT = Path(__file__).resolve().parent.parent
MONTHLY_DIR = REPO_ROOT / "data" / "backfill" / "monthly"


# -- Helpers -------------------------------------------------------------------
def open_zarr(url_path: str, token: str) -> xr.Dataset:
    url = f"https://edh:{token}@data.earthdatahub.destine.eu/{url_path}"
    return xr.open_dataset(url, chunks={}, engine="zarr")


def tetens_es(t_c):
    """Saturation vapour pressure (hPa) given temperature in °C (Tetens)."""
    return 6.1078 * np.exp(17.27 * t_c / (t_c + 237.3))


# -- Per-year processing -------------------------------------------------------
# Everything derived from the hourly store; prcp alone comes from the daily one.
# ALL_VARS derives from these two so the completeness guard and the output map
# cannot drift apart — a var added to one but not the other would otherwise be
# written without ever being completeness-checked.
HOURLY_VARS = ("tmax", "tmin", "tmean", "vpd", "rh", "soil_moisture")
DAILY_VARS = ("prcp",)
ALL_VARS = HOURLY_VARS + DAILY_VARS
# Hourly variables aggregated over local days, so gated on the local year
# rather than on 12 UTC months (#37).
LOCAL_DAY_VARS = ("tmax", "tmin")


def outputs_for_year(year: int) -> dict:
    """Map output variable name to Path."""
    return {v: MONTHLY_DIR / f"{v}_{year}.tif" for v in ALL_VARS}


def process_year(year: int, hourly_ds: xr.Dataset, daily_ds: xr.Dataset):
    out = outputs_for_year(year)
    # A file on disk counts as done below; refuse one on another grid.
    bc_files_check(out.values())

    # Which outputs are missing?
    needed = {v: p for v, p in out.items() if not p.exists()}
    if not needed:
        log(f"{year}: all outputs exist, skipping")
        return

    # Completeness before cost. Every .compute() below is where the lazy graph
    # actually pulls from EDH, so a variable that cannot be written has to be
    # dropped before we reach one — otherwise a partial year is downloaded in
    # full and thrown away, every month, against a metered quota (#84).
    #
    # Per store, not pooled: the hourly and daily stores advance independently,
    # and a hourly-complete/daily-short year must still write the six hourly
    # variables.
    #
    # NOTE the post-compute `== 12` checks below are NOT a backstop for this.
    # They count bins from `resample(valid_time="1MS")`, which builds a
    # contiguous grid from min to max and fills absent months with NaN — so a
    # year holding only Jan-Mar and Dec still yields 12 bins and passes.
    # months_available() is the only check that sees an interior gap.
    if any(v in needed for v in HOURLY_VARS):
        n_hourly = months_available(hourly_ds, year)
        if n_hourly < 12:
            for v in HOURLY_VARS:
                if v in needed:
                    log(f"  SKIP {v}: got {n_hourly} months, expected 12")
                    del needed[v]
    if any(v in needed for v in DAILY_VARS):
        n_daily = months_available(daily_ds, year)
        if n_daily < 12:
            for v in DAILY_VARS:
                if v in needed:
                    log(f"  SKIP {v}: got {n_daily} months, expected 12")
                    del needed[v]
    # A local year needs the first 8 hours of the next UTC year, which 12 UTC
    # months do not guarantee: EDH publishes whole UTC months.
    if (any(v in needed for v in LOCAL_DAY_VARS)
            and not local_year_complete(hourly_ds, year)):
        for v in LOCAL_DAY_VARS:
            if v in needed:
                log(f"  SKIP {v}: local year {year} not complete "
                    f"(needs {year + 1}-01-01T07:00 UTC)")
                del needed[v]
    if not needed:
        log(f"{year}: not complete on EDH yet — nothing fetched")
        return

    log(f"{year}: needed = {sorted(needed)}")
    t_year = time.time()

    # Hourly subset for the full year (all the state variables we need)
    hourly_box = bc_slice(hourly_ds, f"{year}-01-01", f"{year}-12-31T23:00")
    needed_hourly_vars = []
    if any(v in needed for v in ("tmean", "vpd", "rh")):
        needed_hourly_vars.append("t2m")
    if any(v in needed for v in ("vpd", "rh")):
        needed_hourly_vars.append("d2m")
    if "soil_moisture" in needed:
        needed_hourly_vars.extend(["swvl1", "swvl2", "swvl3", "swvl4"])

    hourly_sub = hourly_ds[needed_hourly_vars].sel(**hourly_box) if needed_hourly_vars else None
    if hourly_sub is not None:
        bc_grid_check(hourly_sub, what=f"hourly {year}")

    # -- tmax / tmin (local-day max/min → monthly mean, #37) -----------------
    # Own slice: the local year runs 08:00 UTC 1 Jan to 07:00 UTC 1 Jan next
    # year. monthly_from_daily() refuses anything but 12 whole local months,
    # so no post-compute month count is needed here.
    local_vars = [v for v in LOCAL_DAY_VARS if v in needed]
    if local_vars:
        start, end = local_year_window(year)
        t2m_local = hourly_ds["t2m"].sel(
            **bc_slice(hourly_ds, start.isoformat(), end.isoformat())
        )
        bc_grid_check(t2m_local, what=f"local-year t2m {year}")
        daily = local_daily(t2m_local)
        # One compute for both, so the year's hourly t2m is fetched once.
        monthly = dask.compute(*[monthly_from_daily(daily[v]) for v in local_vars])
        for v, da in zip(local_vars, monthly):
            write_geotiff(da, out[v])
            log(f"  wrote {out[v].name}")

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
        bc_grid_check(tp_daily, what=f"daily tp {year}")
        monthly_prcp_m = tp_daily.resample(valid_time="1MS").sum()
        monthly_prcp_mm = (monthly_prcp_m * 1000).compute()
        if monthly_prcp_mm.sizes["valid_time"] == 12:
            write_geotiff(monthly_prcp_mm, out["prcp"])
            log(f"  wrote {out['prcp'].name}")
        else:
            log(f"  SKIP prcp: got {monthly_prcp_mm.sizes['valid_time']} months, expected 12")

    bc_files_check(out.values())
    log(f"{year}: done in {time.time() - t_year:.1f}s")


# -- Main ----------------------------------------------------------------------
def main(years):
    preflight_single_instance("backfill_edh_all")
    MONTHLY_DIR.mkdir(parents=True, exist_ok=True)
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

    failed = []
    for year in years:
        try:
            with_retry(
                lambda y=year: process_year(y, hourly_ds, daily_ds),
                what=f"process year {year}",
            )
        except Exception as e:
            log(f"FAILED year {year} after retries: {type(e).__name__}: {e}")
            log("Continuing to next year (idempotent — restart to retry this one)")
            failed.append(year)

    if failed:
        # Non-zero, so pipeline_update_edh.R STEP 3 counts a failed fetch rather
        # than reading the missing files as EDH latency (#123 code-check).
        log(f"DONE with {len(failed)} failed year(s): {failed}")
        return 1
    log("ALL DONE")
    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--year", type=int, help="Single year to backfill (for testing)")
    args = parser.parse_args()
    years = [args.year] if args.year else YEARS_DEFAULT
    sys.exit(main(years))
