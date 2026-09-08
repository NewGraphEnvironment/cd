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
"""Offline tests for scripts/_lib.py helpers.

No network and no EDH token — every case is built from a synthetic
xarray Dataset, so this is safe to run anywhere and costs no quota.

Usage:
  uv run scripts/test_lib.py
"""
import sys
from pathlib import Path

import numpy as np
import pandas as pd
import xarray as xr

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _lib import months_available  # noqa: E402


def ds_for(start: str, end: str, freq: str = "1h") -> xr.Dataset:
    """Minimal Dataset carrying only the time coordinate that matters here."""
    t = pd.date_range(start, end, freq=freq)
    return xr.Dataset(
        {"t2m": ("valid_time", np.zeros(len(t)))},
        coords={"valid_time": t},
    )


def ds_gap(year: int, spans: list) -> xr.Dataset:
    """A year whose coverage has a hole — e.g. [(1, 3), (7, 12)] is Jan-Mar + Jul-Dec.

    Non-contiguous coverage is what separates counting distinct months from
    reading the last month's index; without it the suite cannot tell them apart.
    """
    idx = None
    for first, last in spans:
        end = pd.Timestamp(year=year, month=last, day=1) + pd.offsets.MonthEnd(1)
        part = pd.date_range(f"{year}-{first:02d}-01", end, freq="1h")
        idx = part if idx is None else idx.append(part)
    return xr.Dataset(
        {"t2m": ("valid_time", np.zeros(len(idx)))},
        coords={"valid_time": idx},
    )


# (name, dataset, year, expected)
CASES = [
    # Both branches of every guard this helper fronts: a complete year must
    # return 12 and an incomplete one must not. A fixture set that only ever
    # returned 12 could not distinguish a working guard from a broken one.
    ("full year, hourly store", ds_for("2024-01-01", "2024-12-31T23:00"), 2024, 12),
    # These three are the ones that matter, and the suite did not have them.
    # Every other fixture's year starts on 1 Jan and is contiguous, and for that
    # shape "count of distinct months" and "index of the last month" are the same
    # number -- so an implementation returning `vt.dt.month.values.max()` passed
    # the whole set. A guard that over-counts lets a partial year through and
    # writes it, which is the exact failure #84 exists to prevent.
    ("starts mid-year (Jul-Dec)", ds_for("2024-07-01", "2024-12-31T23:00"), 2024, 6),
    ("interior gap (no Apr-Jun)", ds_gap(2024, [(1, 3), (7, 12)]), 2024, 9),
    ("December only", ds_for("2024-12-01", "2024-12-31T23:00"), 2024, 1),
    # Missing January, with the store continuing past year-end. This is the only
    # shape that catches a slice whose upper bound leaks into the next year: the
    # leak pulls in the following January, whose month number is 1, restoring the
    # count to 12 for a year that only has 11 months of data.
    ("no January, store runs on", ds_for("2024-02-01", "2025-03-31T23:00"), 2024, 11),
    ("full year, daily store", ds_for("2024-01-01", "2024-12-31", "1D"), 2024, 12),
    ("partial year, through Aug", ds_for("2024-01-01", "2026-08-31T23:00"), 2026, 8),
    ("single month only", ds_for("2026-01-01", "2026-01-31"), 2026, 1),
    ("year absent from store", ds_for("2024-01-01", "2024-12-31"), 2030, 0),
    ("year before store starts", ds_for("2024-01-01", "2024-12-31"), 1999, 0),
    # Documented limitation, pinned deliberately: the helper counts months
    # that hold *any* data, matching the post-compute guards it fronts. A
    # December holding 15 days still reads as 12 months. If EDH is ever
    # observed exposing a partial trailing month, this is the line that has
    # to change, and it should change in both places at once.
    ("partial trailing month still counts", ds_for("2025-01-01", "2025-12-15"), 2025, 12),
]


def main() -> int:
    failures = 0
    for name, ds, year, expected in CASES:
        got = months_available(ds, year)
        ok = got == expected
        failures += not ok
        print(f"  {'ok  ' if ok else 'FAIL'}  {name:38s} year={year}  "
              f"got={got} expected={expected}")
    print(f"\n{len(CASES) - failures}/{len(CASES)} passed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
