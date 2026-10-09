#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "xarray",
#   "numpy",
#   "pandas",
#   "rioxarray",
#   "rasterio",
# ]
# ///
"""
Monthly tmax/tmin for BC (1950-2025) from the local-day daily cube (#37).

Reads the daily air-temperature cube that backfill_edh_daily.py builds from
EDH hourly 2 m temperature, and averages each local month's daily max and min:

  data/backfill/daily/tmax_daily_YYYY.tif  (365/366 bands, local days, deg C)
    -> data/backfill/monthly/tmax_YYYY.tif (12 bands Jan..Dec, deg C)
  data/backfill/daily/tmin_daily_YYYY.tif
    -> data/backfill/monthly/tmin_YYYY.tif

Same output as backfill_edh_all.py writes for tmax/tmin, on the same grid,
for pipeline_stage3_edh.R or scripts/tmax_tmin_republish.R to aggregate.

Days are local at a fixed UTC-8 (`LOCAL_OFFSET_H` in _lib.py). Until #37 the
monthly layers used UTC days, which run from one afternoon peak (22-00 UTC)
to the next, so a hot afternoon counted toward two days: tmax read 0.5-0.8
degC high (research/tmax_tmin_day_boundary.md). Building the history from
the cube costs no EDH fetch, and the monthly and daily products then agree
by construction. New years in CI come from backfill_edh_all.py, which runs
the same hourly -> local_daily() -> monthly_from_daily() chain; the offline
suite (test_lib.py) pins that the two routes give the same values.

Needs the cube on disk: `uv run scripts/backfill_edh_daily.py` builds it
(about two hours from EDH for 76 years), or sync it down from
s3://stac-era5-land/daily/.

Idempotent — skips years whose tmax_YYYY.tif and tmin_YYYY.tif already exist.
A year whose cube files are missing is reported and skipped.

Usage:
  uv run scripts/backfill_edh_tmax_tmin.py              # 1950-2025
  uv run scripts/backfill_edh_tmax_tmin.py --year 1950  # one year
"""
import argparse
import sys
import time
from pathlib import Path

from _lib import (bc_file_check, bc_files_check, log, monthly_from_daily, read_cog_days,
                  write_geotiff)

YEARS_DEFAULT = range(1950, 2026)
VARS = ("tmax", "tmin")

REPO_ROOT = Path(__file__).resolve().parent.parent
DAILY_DIR = REPO_ROOT / "data" / "backfill" / "daily"
MONTHLY_DIR = REPO_ROOT / "data" / "backfill" / "monthly"


def main(years) -> int:
    MONTHLY_DIR.mkdir(parents=True, exist_ok=True)
    missing = []
    for year in years:
        t_year = time.time()
        wrote = []
        for var in VARS:
            out = MONTHLY_DIR / f"{var}_{year}.tif"
            if out.exists():
                bc_files_check([out])  # done only if on the BC grid (#123)
                continue
            src = DAILY_DIR / f"{var}_daily_{year}.tif"
            if not src.exists():
                missing.append(src.name)
                log(f"{year}: no {src.name}, skipping {var}")
                continue
            # A cube file from before #123 is 120 x 260; refuse it rather
            # than write a monthly layer on the old grid.
            bc_file_check(src)
            write_geotiff(monthly_from_daily(read_cog_days(src)), out)
            wrote.append(out.name)
        if wrote:
            log(f"{year}: wrote {', '.join(wrote)} in {time.time() - t_year:.1f}s")
        else:
            log(f"{year}: nothing to write")
    if missing:
        log(f"DONE with {len(missing)} cube file(s) missing — build them with "
            "backfill_edh_daily.py")
        return 1
    log("DONE")
    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--year", type=int, help="Single year (for testing)")
    args = parser.parse_args()
    sys.exit(main([args.year] if args.year else YEARS_DEFAULT))
