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

from _lib import (  # noqa: E402
    local_daily,
    local_year_complete,
    local_year_window,
    months_available,
    with_retry,
    write_cog,
)


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


def hourly_year(year: int, base_k: float = 283.15, spikes: dict = None) -> xr.DataArray:
    """One local year of hourly t2m (K) at a single point, as local_daily() gets it.

    `spikes` maps a UTC timestamp string to a value, to place a known extreme
    at a known hour and see which local day it lands on.
    """
    start, end = local_year_window(year)
    t = pd.date_range(start, end, freq="1h")
    v = np.full(len(t), base_k)
    for ts, val in (spikes or {}).items():
        v[t.get_loc(pd.Timestamp(ts))] = val
    return xr.DataArray(v, coords={"valid_time": t}, dims="valid_time")


def raises(exc, thunk) -> bool:
    try:
        thunk()
    except exc:
        return True
    return False


def daily_at(da: xr.DataArray, day: str) -> float:
    return float(da.sel(valid_time=day).values)


# (name, thunk) — each thunk returns True when the behaviour holds. Every
# local_year_complete case has a sibling that flips the answer, so a helper
# stuck on one value cannot pass the set.
LOCAL_CASES = [
    ("window 2024 is 08:00 UTC to 07:00 UTC next year",
     lambda: local_year_window(2024) == (pd.Timestamp("2024-01-01T08:00"),
                                         pd.Timestamp("2025-01-01T07:00"))),
    ("complete: store spans the local year (leap)",
     lambda: local_year_complete(ds_for("2023-12-31", "2025-01-02"), 2024)),
    ("complete: store ends exactly at 1 Jan 07:00 UTC",
     lambda: local_year_complete(ds_for("2024-01-01", "2025-01-01T07:00"), 2024)),
    # The case that matters for the monthly cron: EDH publishes whole UTC
    # months, so a store ending 31 Dec 23:00 holds every UTC hour of the year
    # and still lacks the last 8 hours of local 31 Dec.
    ("incomplete: store ends 31 Dec 23:00 UTC",
     lambda: not local_year_complete(ds_for("2024-01-01", "2024-12-31T23:00"), 2024)),
    ("incomplete: one hour missing mid-year",
     lambda: not local_year_complete(
         ds_for("2024-01-01", "2025-01-02").drop_sel(
             valid_time=pd.Timestamp("2024-07-01T12:00")), 2024)),
    ("complete: first year of the store (1950)",
     lambda: local_year_complete(ds_for("1950-01-01", "1951-02-01"), 1950)),
    ("incomplete: year absent",
     lambda: not local_year_complete(ds_for("2024-01-01", "2024-12-31"), 2030)),
    ("366 local days in 2024, labelled 1 Jan .. 31 Dec",
     lambda: (lambda d: d.sizes["valid_time"] == 366
              and str(d.valid_time.values[0])[:10] == "2024-01-01"
              and str(d.valid_time.values[-1])[:10] == "2024-12-31")(
                  local_daily(hourly_year(2024))["tmean"])),
    ("365 local days in 2023",
     lambda: local_daily(hourly_year(2023))["tmax"].sizes["valid_time"] == 365),
    ("constant 283.15 K is 10 C mean",
     lambda: abs(daily_at(local_daily(hourly_year(2023))["tmean"], "2023-06-01") - 10) < 1e-9),
    # 02:00 UTC on 11 Mar is 18:00 PST on 10 Mar. A UTC day would credit the
    # peak to the 11th; a local day must credit it to the 10th. This is #37.
    ("afternoon peak lands on its local day, not the UTC one",
     lambda: (lambda d: daily_at(d, "2024-03-10") == 30.0
              and daily_at(d, "2024-03-11") == 10.0)(
                  local_daily(hourly_year(2024, spikes={"2024-03-11T02:00": 303.15}))["tmax"])),
    # 07:00 UTC on 1 Jun is 23:00 PST on 31 May.
    ("late-evening low lands on its local day",
     lambda: (lambda d: abs(daily_at(d, "2024-05-31") - -10.0) < 1e-9
              and abs(daily_at(d, "2024-06-01") - 10.0) < 1e-9)(
                  local_daily(hourly_year(2024, spikes={"2024-06-01T07:00": 263.15}))["tmin"])),
    # Guard on the input: an unsliced UTC year starts at 16:00 local and would
    # resample into a short first day without complaint.
    ("refuses input not sliced to local days",
     lambda: raises(ValueError, lambda: local_daily(
         hourly_year(2024).sel(valid_time=slice("2024-01-01T09:00", None))))),
    ("refuses input with a missing hour",
     lambda: raises(ValueError, lambda: local_daily(
         hourly_year(2024).drop_sel(valid_time=pd.Timestamp("2024-07-01T12:00"))))),
    # 08:00 UTC on 1 Jun is midnight PST, the first hour of 1 Jun.
    ("08:00 UTC opens the local day",
     lambda: (lambda d: daily_at(d, "2024-06-01") == 30.0
              and daily_at(d, "2024-05-31") == 10.0)(
                  local_daily(hourly_year(2024, spikes={"2024-06-01T08:00": 303.15}))["tmax"])),
]


def cog_roundtrip() -> bool:
    """Write a two-day cube the way the backfill does and read it back.

    Pins what review round 1 found: the source carries `units: K` and GRIB
    attrs, as EDH's t2m does, and none of that may reach the file; the bands
    keep their date names; nothing but the COG is left on disk.
    """
    import tempfile
    import rasterio

    t = pd.date_range(*local_year_window(2023), freq="1h")
    lat = np.array([54.05, 53.95])
    lon = np.array([237.0, 237.1])
    hourly = xr.DataArray(
        np.full((len(t), 2, 2), 283.15, dtype="float32"),
        coords={"valid_time": t, "latitude": lat, "longitude": lon},
        dims=("valid_time", "latitude", "longitude"),
        attrs={"units": "K", "GRIB_units": "K", "GRIB_Nx": 3600},
    )
    da = local_daily(hourly)["tmax"].isel(valid_time=slice(0, 2))
    with tempfile.TemporaryDirectory() as tmp:
        out_dir = Path(tmp) / "daily"
        out_dir.mkdir()
        out = out_dir / "tmax_daily_2023.tif"
        write_cog(da, out, band_names=["2023-01-01", "2023-01-02"])
        with rasterio.open(out) as d:
            tags = d.tags()
            ok = (tags.get("units") == "degC"
                  and not any(k.startswith("GRIB") for k in tags)
                  and d.descriptions == ("2023-01-01", "2023-01-02")
                  and abs(float(d.read(1)[0, 0]) - 10.0) < 1e-5
                  and d.tags(ns="IMAGE_STRUCTURE").get("LAYOUT") == "COG")
        left = sorted(p.relative_to(tmp).as_posix() for p in Path(tmp).rglob("*"))
        return ok and left == ["daily", "daily/tmax_daily_2023.tif"]


LOCAL_CASES.append(("COG: deg C tagged, no GRIB tags, dates kept, no leftovers",
                    cog_roundtrip))


def retry_aiohttp_payload() -> bool:
    """A truncated aiohttp payload is retried; a ValueError is not.

    Stands a fake `aiohttp` module in sys.modules, since test_lib.py does not
    install aiohttp -- with_retry() looks the class up there, not by import.
    """
    import types
    fake = types.ModuleType("aiohttp")

    class ClientError(Exception):
        pass

    class ClientPayloadError(ClientError):
        pass

    fake.ClientError = ClientError
    saved = sys.modules.get("aiohttp")
    sys.modules["aiohttp"] = fake
    try:
        calls = []

        def flaky():
            calls.append(1)
            if len(calls) < 3:
                raise ClientPayloadError("Response payload is not completed")
            return "ok"

        recovered = with_retry(flaky, initial_delay=0, what="test") == "ok" and len(calls) == 3
        bug_propagates = raises(ValueError, lambda: with_retry(
            lambda: (_ for _ in ()).throw(ValueError("bug")), initial_delay=0))
        return recovered and bug_propagates
    finally:
        if saved is None:
            sys.modules.pop("aiohttp", None)
        else:
            sys.modules["aiohttp"] = saved


LOCAL_CASES.append(("with_retry retries a truncated aiohttp payload, not a bug",
                    retry_aiohttp_payload))


def main() -> int:
    failures = 0
    for name, ds, year, expected in CASES:
        got = months_available(ds, year)
        ok = got == expected
        failures += not ok
        print(f"  {'ok  ' if ok else 'FAIL'}  {name:38s} year={year}  "
              f"got={got} expected={expected}")
    for name, check in LOCAL_CASES:
        # A case that raises is a failure to report, not a reason to abort
        # the rest of the suite.
        try:
            ok = bool(check())
        except Exception as e:  # noqa: BLE001
            print(f"        {name}: raised {type(e).__name__}: {e}")
            ok = False
        failures += not ok
        print(f"  {'ok  ' if ok else 'FAIL'}  {name}")
    n = len(CASES) + len(LOCAL_CASES)
    print(f"\n{n - failures}/{n} passed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
