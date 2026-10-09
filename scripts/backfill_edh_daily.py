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
#   "pandas",
#   "rioxarray",
#   "rasterio",
# ]
# ///
"""
Daily BC air-temperature cube from EDH hourly 2 m temperature (#116).

For each year:
  1. Pull hourly t2m for the BC bbox over the year's local-time window
     (UTC-8: Y-01-01T08:00 to Y+1-01-01T07:00 UTC)
  2. Aggregate to local-day mean, max and min (deg C)
  3. Write one COG per variable, one band per day, bands named YYYY-MM-DD:
       data/backfill/daily/tmean_daily_YYYY.tif
       data/backfill/daily/tmax_daily_YYYY.tif
       data/backfill/daily/tmin_daily_YYYY.tif

These are the published files: `Rscript scripts/daily_publish.R` puts them
at s3://stac-era5-land/daily/ with daily/manifest.json, their sizes and
checksums (#124), and cd_extract_daily() reads them there. No R conversion step — the COG is written
here (`write_cog()`), in a layout chosen for point reads.

Why local days: a UTC day splits BC's afternoon peak (22-00 UTC) across two
days, biasing daily max low and min high (#37). That bias does not cancel
for absolute thresholds such as degree-days, which is what the cube is for.
The offset is fixed at UTC-8 (`LOCAL_OFFSET_H` in _lib.py): no daylight
time, and the MST corner of eastern BC is an hour off.

Why a cube at all: the EDH store is chunked [2880 h, 64, 64], so reading one
point for 20 years took 201 s through xarray (measured 2026-10-06); R through
terra/GDAL 3.13 is slower still (39 s for 48 hours of one point), and GDAL
3.8.5 cannot decode the store's bitround filter at all.

The monthly tmax/tmin COGs average these same local days (#37):
backfill_edh_tmax_tmin.py rebuilds their history from this cube, and
backfill_edh_all.py computes each new year by the same chain from hourly.

Idempotent — skips years whose three outputs already exist. A year whose
local window is not fully in the store (its last local day needs the first
8 hours of the next UTC year) is skipped before anything is fetched.

Every COG carries the run's provenance as file tags (`run_provenance()` in
_lib.py, #124). `--rewrite` re-writes years already on disk with fresh
provenance and the same values, with no EDH fetch: the way to tag a cube
built before #124.

Usage:
  uv run scripts/backfill_edh_daily.py --check              # latest complete year, no fetch
  uv run scripts/backfill_edh_daily.py --rewrite            # re-tag 1950-2025 on disk
  uv run scripts/backfill_edh_daily.py                      # 1950-2025
  uv run scripts/backfill_edh_daily.py --year 2002          # one year
  uv run scripts/backfill_edh_daily.py --from 2002 --to 2025
"""
import argparse
import os
import shutil
import tempfile
import time
from pathlib import Path

import numpy as np
import rasterio
import xarray as xr

from _lib import (
    bc_file_check,
    bc_files_check,
    bc_grid_check,
    bc_slice,
    get_token,
    local_daily,
    local_year_complete,
    local_year_window,
    log,
    preflight_single_instance,
    read_cog_days,
    run_provenance,
    with_retry,
    write_cog,
)

# -- Config --------------------------------------------------------------------
# The BC box is `bc_slice()` in _lib.py, shared with the monthly backfillers
# so the cube and the monthly layers sit on one 121 x 261 grid (#123).
YEAR_FROM, YEAR_TO = 1950, 2025
VARIABLES = ("tmean", "tmax", "tmin")

REPO_ROOT = Path(__file__).resolve().parent.parent
DAILY_DIR = REPO_ROOT / "data" / "backfill" / "daily"


def out_path(var: str, year: int) -> Path:
    return DAILY_DIR / f"{var}_daily_{year}.tif"


def latest_complete_year(ds: xr.Dataset) -> int:
    """Latest year whose local-day window is fully in the store, or 0.

    Coordinate-only. Starts from the year of the store's last stamp and steps
    back; the last year is usually short by its final local day.
    """
    year = int(str(ds.valid_time.values[-1])[:4])
    first = int(str(ds.valid_time.values[0])[:4])
    while year >= first:
        if local_year_complete(ds, year):
            return year
        year -= 1
    return 0


def open_store() -> xr.Dataset:
    token = get_token()
    zarr_url = (
        f"https://edh:{token}@data.earthdatahub.destine.eu/era5/"
        "reanalysis-era5-land-no-antartica-v0.zarr"
    )

    log("Opening EDH Zarr store...")
    t0 = time.time()
    ds = with_retry(
        lambda: xr.open_dataset(zarr_url, chunks={}, engine="zarr"),
        what="open hourly zarr",
    )
    log(f"  Opened in {time.time() - t0:.1f}s")
    return ds


# -- Main ----------------------------------------------------------------------
def check():
    """Print the latest complete local year as `latest_complete=YYYY`.

    For pipeline_update_edh.R, which cannot call local_year_complete()
    itself. Reads the time coordinate only.
    """
    print(f"latest_complete={latest_complete_year(open_store())}", flush=True)


def same_layout(old: Path, new: Path) -> None:
    """Refuse a rewrite whose file differs from the original in anything but
    its tags: grid, dtype, nodata, tiling, compression, band names."""
    with rasterio.open(old) as a, rasterio.open(new) as b:
        keys = ("driver", "dtype", "nodata", "width", "height", "count", "crs",
                "transform", "blockxsize", "blockysize", "tiled", "compress",
                "interleave")
        pa = {k: a.profile.get(k) for k in keys}
        pb = {k: b.profile.get(k) for k in keys}
        if pa != pb or a.descriptions != b.descriptions:
            raise SystemExit(f"{old.name}: rewrite changed the layout "
                             f"({pa} -> {pb}); original kept")


def rewrite(years):
    """Re-write cube years already on disk, with this run's provenance.

    Values, band names, grid and layout are unchanged: the year is read back
    with `read_cog_days()` and written through `write_cog()` again, beside the
    original; it replaces the original only once its values, band names and
    layout are shown equal. Refuses a year with a file missing, rather than
    leaving it half-tagged.
    """
    preflight_single_instance("backfill_edh_daily")
    tags = run_provenance()
    log(f"Rewriting with {tags}")
    for year in years:
        outs = {v: out_path(v, year) for v in VARIABLES}
        missing = [p.name for p in outs.values() if not p.exists()]
        if missing:
            raise SystemExit(f"{year}: not on disk ({', '.join(missing)}); "
                             f"build it first")
        bc_files_check(outs.values())
        for var, path in outs.items():
            da = read_cog_days(path)
            # local_daily() writes units=degC, and read_cog_days() clears attrs.
            da.attrs = {"units": "degC"}
            dates = [str(d)[:10] for d in da.valid_time.values]
            # Written beside, compared, then moved over the original: these
            # files cannot be rebuilt as they were, since EDH has revised
            # published values since (research/edh_era5_land_store.md).
            stage = Path(tempfile.mkdtemp(prefix=".rewrite_", dir=DAILY_DIR.parent))
            try:
                (stage / "daily").mkdir()
                new = stage / "daily" / path.name
                write_cog(da, new, band_names=dates, tags=tags)
                bc_file_check(new)
                same_layout(path, new)
                back = read_cog_days(new)
                if not (np.array_equal(back.values, da.values, equal_nan=True)
                        and back.dtype == da.dtype
                        and list(back.valid_time.values) == list(da.valid_time.values)):
                    raise SystemExit(f"{path.name}: rewrite changed values; original kept")
                os.replace(new, path)
            finally:
                shutil.rmtree(stage, ignore_errors=True)
        log(f"{year}: rewritten")
    log("DONE")


def main(years):
    preflight_single_instance("backfill_edh_daily")
    DAILY_DIR.mkdir(parents=True, exist_ok=True)

    tags = run_provenance()
    ds = open_store()

    for year in years:
        outs = {v: out_path(v, year) for v in VARIABLES}
        # A file on disk counts as done; refuse one on another grid (#123).
        bc_files_check(outs.values())
        if all(p.exists() for p in outs.values()):
            log(f"{year}: exists, skipping")
            continue

        # Completeness before cost (#84): coordinate-only, no transfer.
        if not local_year_complete(ds, year):
            log(f"  SKIP {year}: local-day window not complete in the store "
                f"— nothing fetched")
            continue

        log(f"{year}: fetching...")
        t_year = time.time()

        start, end = local_year_window(year)
        hourly = ds["t2m"].sel(
            **bc_slice(ds, start.isoformat(), end.isoformat())
        )
        bc_grid_check(hourly, what=f"t2m {year}")
        # One fetch, three reductions: compute the hourly block once rather
        # than letting each .compute() below pull it from EDH again.
        hourly = with_retry(lambda da=hourly: da.compute(),
                            what=f"fetch t2m {year}")
        daily = local_daily(hourly)

        for var, da in daily.items():
            if outs[var].exists():
                continue
            da = da.compute()
            dates = [str(d)[:10] for d in da.valid_time.values]
            write_cog(da, outs[var], band_names=dates, tags=tags)
            try:
                bc_file_check(outs[var])
            except ValueError:
                # Off the grid is not a file to keep: the per-output skip
                # would otherwise publish it on the next run.
                outs[var].unlink()
                raise

        elapsed = time.time() - t_year
        n_days = daily["tmean"].sizes["valid_time"]
        log(f"  wrote {year} ({n_days} days) in {elapsed:.1f}s")

    log("DONE")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true",
                        help="Print the latest complete local year and exit")
    parser.add_argument("--rewrite", action="store_true",
                        help="Re-write years on disk with fresh provenance; no fetch")
    parser.add_argument("--year", type=int, help="Single year (for testing)")
    parser.add_argument("--from", dest="year_from", type=int, default=YEAR_FROM)
    parser.add_argument("--to", dest="year_to", type=int, default=YEAR_TO)
    args = parser.parse_args()
    if args.check:
        check()
        raise SystemExit(0)
    if args.year:
        years = [args.year]
    else:
        years = range(args.year_from, args.year_to + 1)
    if args.rewrite:
        rewrite(years)
    else:
        main(years)
