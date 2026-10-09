"""Shared helpers for the cd producer-side bulk-fetch scripts.

Borne out of #38 — each EDH backfill script (`backfill_edh_all.py`,
`backfill_edh_snow.py`, `backfill_edh_daily.py`) needs the same safeguards
against its own failure modes:

  - `preflight_single_instance(name)` — pgrep guard so two runs of the
    same script can't hammer EDH concurrently. Skipped on GHA.
  - `with_retry(fn, ...)` — exponential backoff around the network surface.
    EDH is chunk-based and rate-limit-free, so transient blips (DNS, TLS
    handshakes) are the dominant failure mode.
  - `write_geotiff(da, out_path, ...)` — atomic .tmp + os.replace, so a
    killed run never leaves a truncated file that fools the per-output
    idempotency check.
  - `months_available(ds, year)` — how many months of a year the store
    holds, from the time coordinate alone (no data transfer).
  - `bc_slice()`, `bc_grid_check()`, `bc_file_check()`, `bc_files_check()` —
    the BC box every product is cut to, and the guards that the cut and the
    files on disk are 121 x 261 (#123).
  - `local_year_window()`, `local_year_complete()`, `local_daily()` —
    local-day (UTC-8) aggregation for the daily cube (#116).
  - `monthly_from_daily()`, `read_cog_days()` — local days to local months,
    from hourly or from the cube, for the monthly tmax/tmin (#37).
  - `write_cog(da, out_path, band_names, tags=)` — atomic COG write,
    daily-cube layout, with the run's provenance as file tags (#124).
  - `run_provenance()` — CD_VERSION / CD_SHA / CD_RUN_TIME / CD_RUN_ID, the
    same keys and environment contract as `run_provenance()` in `_lib.R`.
  - `log(msg)` — timestamped print, flushed.
  - `get_token()` — EDH token from env or `~/.Renviron`.

Backup-before-delete pattern (third safeguard from #38) lives here as
`backup_before_delete(files)`. No call sites yet — both production
scripts are pure-write, protected by per-output idempotency. The first
real call site is expected with #48 if the snow-var aggregation method
forces a re-run of existing year files. The pattern is in operational
use on disk: `data/backfill/monthly/_cds_backup/` holds 375 CDS-era
TIFs hand-moved during the EDH migration before the new outputs
overwrote them.

This module imports `rasterio`, `rioxarray`, and `xarray`. Each script
that imports `_lib` already pulls these via its PEP 723 inline-deps
shebang, so no new runtime dependencies are introduced.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Callable, Iterable, Optional, Sequence, TypeVar

import pandas as pd
import rasterio
import rasterio.errors
import rasterio.shutil
import rioxarray  # noqa: F401 — registers .rio accessor on xarray DataArrays
import xarray as xr

T = TypeVar("T")

MONTH_NAMES: list[str] = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
]


def preflight_single_instance(name: str) -> None:
    """Refuse to start if another instance with `name` in the cmdline is running.

    `name` is the pgrep -f target — pass each script's own basename
    (e.g. "backfill_edh_all", "backfill_edh_tmax_tmin"). Filters out
    own pid and parent pid so the wrapping shell / uv invocation
    doesn't false-positive.

    Skipped on GHA: each runner is in a fresh container, no other
    instances are possible, and the pgrep check has unrelated false
    positives there (uv wrapper, shell ancestors, pgrep's own
    pre-exec cmdline) that aren't worth chasing.

    Born from the CDS-era hammering incident (#33) where zombie
    processes stacked up and we couldn't tell which "kill" actually
    killed which.
    """
    if os.environ.get("GITHUB_ACTIONS") == "true":
        return

    my_pid = os.getpid()
    my_ppid = os.getppid()
    try:
        out = subprocess.run(
            ["pgrep", "-f", name],
            capture_output=True, text=True, check=False,
        )
        pids = [int(p) for p in out.stdout.strip().splitlines()
                if p.strip() and int(p) not in (my_pid, my_ppid)]
    except (FileNotFoundError, ValueError):
        pids = []
    if pids:
        sys.exit(f"ABORT: another {name} is running (pids: {pids}). "
                 f"Kill them first: kill {' '.join(str(p) for p in pids)}")


def _transient_errors() -> tuple:
    """Exception types worth another attempt.

    aiohttp's errors (fsspec's HTTP transport) do not subclass OSError, so a
    truncated chunk -- `ClientPayloadError: Response payload is not
    completed` -- used to escape the retry and kill a whole backfill run
    (seen 2026-10-06 at year 1975 of the #116 daily cube). Looked up from
    sys.modules rather than imported, so this file still loads where aiohttp
    is not installed (test_lib.py).
    """
    errs = (OSError, ConnectionError, TimeoutError)
    aiohttp = sys.modules.get("aiohttp")
    client_error = getattr(aiohttp, "ClientError", None)
    if isinstance(client_error, type):
        errs = errs + (client_error,)
    return errs


def with_retry(
    fn: Callable[[], T],
    *,
    attempts: int = 4,
    initial_delay: float = 10.0,
    what: str = "operation",
) -> T:
    """Run `fn()` with exponential backoff on transient errors.

    EDH is chunk-based (no job queue), so network blips are the main
    failure mode. Retry on OSError / ConnectionError / TimeoutError and
    aiohttp.ClientError (see `_transient_errors()`). Let other errors (KeyError,
    ValueError, RuntimeError) propagate — those are bugs, not transient.
    """
    delay = initial_delay
    for i in range(1, attempts + 1):
        try:
            return fn()
        except _transient_errors() as e:
            if i == attempts:
                raise
            log(f"  {what} failed (attempt {i}/{attempts}): "
                f"{type(e).__name__}: {e}. Retrying in {delay:.0f}s...")
            time.sleep(delay)
            delay *= 2
    raise RuntimeError(f"with_retry: exhausted {attempts} attempts for {what}")


def months_available(ds: xr.Dataset, year: int) -> int:
    """Count distinct calendar months of `year` present in `ds.valid_time`.

    Reads the time coordinate only. Zarr materialises coordinates when the
    store is opened, so this triggers no data transfer — which is the whole
    point: callers use it to decide whether a year is worth fetching, and a
    check that fetched in order to answer would defeat itself (#84).

    Agrees with the post-compute guards it fronts on a contiguous year, but is
    strictly stronger. Those count month-start bins after
    `resample(valid_time="1MS")`, which builds a contiguous grid from min to max
    and fills absent months with NaN — so a year holding only Jan-Mar and Dec
    yields 12 bins and passes them. This counts months that actually hold data,
    so it returns 4. Do not treat those checks as a backstop for this one.

    A month present but incomplete counts as present in both.

    Returns 0 when the year is absent from the store entirely.
    """
    vt = ds.valid_time.sel(
        valid_time=slice(f"{year}-01-01", f"{year}-12-31T23:59:59")
    )
    if vt.size == 0:
        return 0
    return len(set(vt.dt.month.values.tolist()))


# The BC box, as cell centres on ERA5-Land's 0.1 deg grid: 121 x 261 cells,
# extent 47.95-60.05 N, 140.05-113.95 W. Every product (monthly, annual,
# daily) is cut by `bc_slice()` so they share one grid.
LAT_N, LAT_S = 60.0, 48.0
LON_W, LON_E = -140.0, -114.0
BC_NLAT, BC_NLON = 121, 261
# Half a cell. The store's coordinates are not exact multiples of 0.1: the
# hourly store holds latitude 60.00000000000142 and longitude
# 219.9999999999918, so a slice ending exactly on 60.0 / 220.0 drops the
# north row and west column. That cut is what #123 found in the published
# cube (and the monthly layers): 120 x 260, stopping at 59.95 N.
_BC_PAD = 0.05


def bc_slice(ds: xr.Dataset, start: str, end: str) -> dict:
    """`sel()` arguments cutting `ds` to the BC box over `start`..`end`.

    Pads each edge by half a cell so float drift in the store's coordinates
    cannot drop an edge row or column; pair with `bc_grid_check()` on the
    result. Handles a store in 0-360 or -180-180 longitudes.
    """
    if float(ds.longitude.min()) >= 0:
        west, east = LON_W + 360, LON_E + 360
    else:
        west, east = LON_W, LON_E
    # Latitude is stored north to south, so the slice runs high to low.
    return dict(
        valid_time=slice(start, end),
        latitude=slice(LAT_N + _BC_PAD, LAT_S - _BC_PAD),
        longitude=slice(west - _BC_PAD, east + _BC_PAD),
    )


def bc_grid_check(da: xr.DataArray, what: str = "slice") -> None:
    """Raise unless `da` covers the BC box cell for cell (121 x 261).

    Reads coordinates only, so call it on the lazy slice, before anything is
    fetched: a wrong cut then costs nothing rather than a year of transfer.
    """
    lat = da.latitude.values
    lon = da.longitude.values
    lon = (lon + 180) % 360 - 180
    got = (lat.size, lon.size)
    edges = (float(lat.max()), float(lat.min()), float(lon.min()), float(lon.max())) \
        if lat.size and lon.size else None
    want = (LAT_N, LAT_S, LON_W, LON_E)
    if got != (BC_NLAT, BC_NLON) or edges is None or any(
            abs(e - w) > 1e-6 for e, w in zip(edges, want)):
        raise ValueError(
            f"{what}: expected the BC grid, {BC_NLAT} x {BC_NLON} cell centres "
            f"from {LAT_N} to {LAT_S} N and {LON_W} to {LON_E} E; got "
            f"{got[0]} x {got[1]} with edges {edges}."
        )


def bc_file_check(path: Path) -> None:
    """Raise unless the raster at `path` is on the BC grid: 261 x 121 cells,
    bounds (-140.05, 47.95, -113.95, 60.05). Reads the header only.

    The written-extent half of `bc_grid_check()`: it would also catch a
    writer that shifted or cropped a correct slice.
    """
    want = (LON_W - _BC_PAD, LAT_S - _BC_PAD, LON_E + _BC_PAD, LAT_N + _BC_PAD)
    try:
        with rasterio.open(path) as src:
            got = tuple(src.bounds)
            size = (src.width, src.height)
    except rasterio.errors.RasterioIOError as e:
        # RasterioIOError subclasses OSError, which with_retry() treats as a
        # network blip; an unreadable local file is not one.
        raise ValueError(f"{path}: not readable as a raster ({e}).") from e
    if size != (BC_NLON, BC_NLAT) or any(
            abs(g - w) > 1e-6 for g, w in zip(got, want)):
        raise ValueError(
            f"{path}: expected the BC grid, {BC_NLON} x {BC_NLAT} cells with "
            f"bounds {want}; got {size[0]} x {size[1]} with bounds {got}."
        )


def bc_files_check(paths: Iterable[Path]) -> None:
    """`bc_file_check()` on every path that exists.

    For the per-output skip: an output already on disk counts as done, so a
    file left from before #123 (120 x 260) would otherwise ride along into
    the publish beside the rebuilt ones. Raise rather than delete, so the
    operator sees which file it was.
    """
    for p in paths:
        if Path(p).exists():
            bc_file_check(Path(p))


# Pacific standard time. A fixed offset, not a zone: it ignores daylight time
# and the MST corner of eastern BC, which is #37's Option A and enough for
# degree-day work (#116) and the monthly tmax/tmin (#37). Every caller that
# builds local days uses this one value, so the published cube, the monthly
# layers and their completeness checks cannot disagree.
LOCAL_OFFSET_H: int = -8


def local_year_window(year: int, offset_h: int = LOCAL_OFFSET_H) -> tuple:
    """First and last UTC hour of a local-time calendar year.

    With offset -8, local 1 Jan 00:00 is 08:00 UTC, so the year runs from
    `Y-01-01T08:00` to `Y+1-01-01T07:00` inclusive. The last local day
    therefore needs the first hours of the following UTC year.
    """
    start = pd.Timestamp(f"{year}-01-01") - pd.Timedelta(hours=offset_h)
    end = pd.Timestamp(f"{year + 1}-01-01") - pd.Timedelta(hours=offset_h + 1)
    return start, end


def local_year_complete(
    ds: xr.Dataset, year: int, offset_h: int = LOCAL_OFFSET_H
) -> bool:
    """Whether the store holds every hour of `year`'s local days.

    Reads the time coordinate only, so it costs no data transfer (#84): call
    it before anything that computes. Complete means the window from
    `local_year_window()` is present at exactly 24 distinct hours per day,
    so a store ending on 31 Dec 23:00 UTC is NOT complete for that year:
    local 31 Dec runs until 1 Jan 07:00 UTC.
    """
    start, end = local_year_window(year, offset_h)
    vt = ds.valid_time.sel(valid_time=slice(start, end)).values
    n_days = 366 if pd.Timestamp(f"{year}-12-31").dayofyear == 366 else 365
    if len(vt) != 24 * n_days or len(set(vt.tolist())) != len(vt):
        return False
    return pd.Timestamp(vt.min()) == start and pd.Timestamp(vt.max()) == end


def local_daily(
    hourly: xr.DataArray, offset_h: int = LOCAL_OFFSET_H
) -> dict:
    """Hourly 2 m temperature (K) to local-day mean, max and min (deg C).

    `hourly` is one local year of `t2m`, sliced to `local_year_window()`.
    Shifting the time coordinate by the offset before resampling makes each
    `1D` bin a local day, which is the whole fix #37 describes: a UTC day
    splits BC's afternoon peak (22-00 UTC) across two days.

    Returns a dict of lazy DataArrays keyed `tmean`, `tmax`, `tmin`, each
    labelled by local date.
    """
    local = hourly.assign_coords(
        valid_time=hourly.valid_time + pd.Timedelta(hours=offset_h)
    )
    # resample() builds a contiguous grid from first to last stamp, so input
    # that starts mid-day or has a hole yields short or NaN days without a
    # word. Refuse anything but whole local days of 24 hours each.
    vt = pd.DatetimeIndex(local.valid_time.values)
    n_days = len(vt) // 24
    if (len(vt) == 0 or len(vt) % 24 or vt[0] != vt[0].normalize()
            or vt[-1] != vt[0] + pd.Timedelta(hours=24 * n_days - 1)
            or not vt.is_unique):
        raise ValueError(
            "local_daily() needs whole local days of 24 hourly steps; slice "
            "the input to local_year_window() first."
        )
    days = local.resample(valid_time="1D")
    out = {
        "tmean": days.mean() - 273.15,
        "tmax": days.max() - 273.15,
        "tmin": days.min() - 273.15,
    }
    # xarray keeps the source attrs through resample and arithmetic, and
    # rio.to_raster() writes every attr as a file tag: without this the cube
    # says `units=K` over values in deg C, plus GRIB tags for the global grid.
    for da in out.values():
        da.attrs = {"units": "degC"}
    return out


def monthly_from_daily(daily: xr.DataArray) -> xr.DataArray:
    """Local-day values for one calendar year to their 12 monthly means.

    `daily` is labelled by local date, as `local_daily()` returns it and as the
    daily cube stores it (`read_cog_days()`), so each month is a local month:
    the monthly tmax/tmin COGs are this applied to the cube's days (#37).

    Refuses anything but every day of one calendar year. `resample("1MS")`
    builds a contiguous grid from first to last date, so a short year would
    come back as fewer months, or as 12 with a mean over the days present.
    """
    vt = pd.DatetimeIndex(daily.valid_time.values)
    if len(vt) == 0:
        raise ValueError("monthly_from_daily() got no days.")
    year = vt[0].year
    want = pd.date_range(f"{year}-01-01", f"{year}-12-31", freq="1D")
    if not vt.equals(want):
        raise ValueError(
            f"monthly_from_daily() needs every day of {year} once, in order; "
            f"got {len(vt)} days from {vt.min().date()} to {vt.max().date()}."
        )
    out = daily.resample(valid_time="1MS").mean()
    out.attrs = {"units": "degC"}
    return out


def read_cog_days(path: Path) -> xr.DataArray:
    """Read a daily-cube COG back as (valid_time, latitude, longitude).

    The inverse of `write_cog()` for the cube's layout: band descriptions
    (`YYYY-MM-DD`) become the time coordinate, so the result feeds
    `monthly_from_daily()` exactly as `local_daily()` output does.
    """
    # Loaded and closed here: one cube year is ~45 MB, and a handle left open
    # is torn down at interpreter exit, which prints an excepthook error.
    with rioxarray.open_rasterio(path, masked=True) as src:
        da = src.load()
    names = da.attrs.get("long_name")
    if isinstance(names, str):
        names = (names,)
    if names is None or len(names) != da.sizes["band"]:
        raise ValueError(f"{path}: band descriptions missing or short.")
    da = da.assign_coords(band=pd.DatetimeIndex(list(names)))
    da = da.rename({"band": "valid_time", "y": "latitude", "x": "longitude"})
    da.attrs = {}
    return da.drop_vars("spatial_ref", errors="ignore")


def run_provenance() -> dict:
    """The provenance a published COG carries as GDAL tags (#124).

    The same keys and the same environment contract as `run_provenance()` in
    `scripts/_lib.R`, so one pipeline run stamps the monthly COGs and the daily
    cube alike: `pipeline_update_edh.R` sets CD_RUN_TIME before it calls this
    script, and the child inherits it.

      CD_VERSION   Version: in the repo's DESCRIPTION.
      CD_SHA       GITHUB_SHA in CI; locally `git rev-parse HEAD`, with
                   "-dirty" on an unclean tree; "unknown" without either.
      CD_RUN_TIME  CD_RUN_TIME from the environment, else now (ISO, UTC).
      CD_RUN_ID    GITHUB_RUN_ID in CI, else "local".

    Keys carry no ':' — GDAL reads one as a metadata domain separator.
    """
    root = Path(__file__).resolve().parent.parent
    version = next(
        line.split(":", 1)[1].strip()
        for line in (root / "DESCRIPTION").read_text().splitlines()
        if line.startswith("Version:")
    )
    sha = os.environ.get("GITHUB_SHA") or ""
    if not sha:
        try:
            head = subprocess.run(
                ["git", "rev-parse", "HEAD"], cwd=root, capture_output=True,
                text=True, check=True,
            ).stdout.strip()
            dirty = subprocess.run(
                ["git", "status", "--porcelain"], cwd=root, capture_output=True,
                text=True, check=True,
            ).stdout.strip()
            sha = head + ("-dirty" if dirty else "")
        except (OSError, subprocess.CalledProcessError):
            sha = "unknown"
    run_time = os.environ.get("CD_RUN_TIME") or time.strftime(
        "%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    return {
        "CD_VERSION": version,
        "CD_SHA": sha,
        "CD_RUN_TIME": run_time,
        "CD_RUN_ID": os.environ.get("GITHUB_RUN_ID") or "local",
    }


def write_geotiff(
    da: xr.DataArray,
    out_path: Path,
    band_names: Optional[Sequence[str]] = None,
    tags: Optional[dict] = None,
) -> None:
    """Write a DataArray with (valid_time, latitude, longitude) dims as a
    multi-band EPSG:4326 GeoTIFF.

    `band_names` defaults to MONTH_NAMES (Jan..Dec). For annual outputs,
    pass e.g. a list of year strings; the band count must match
    `da.sizes["valid_time"]`.

    Atomic: writes to a `.tmp` suffix then renames, so a killed run
    never leaves a truncated file that passes the per-output existence
    check on restart.

    `tags` are written as dataset metadata alongside the descriptions.
    """
    if tags and any(":" in k for k in tags):
        raise ValueError(f"tag keys may not contain ':': {sorted(tags)}")
    band_names = list(band_names) if band_names is not None else MONTH_NAMES
    da = da.rename({"valid_time": "band"}).assign_coords(band=band_names)
    if float(da.longitude.max()) > 180:
        new_lon = da.longitude.where(da.longitude <= 180, da.longitude - 360)
        da = da.assign_coords(longitude=new_lon).sortby("longitude")
    da = da.rename({"longitude": "x", "latitude": "y"})
    da.rio.write_crs("EPSG:4326", inplace=True)

    tmp_path = out_path.with_suffix(out_path.suffix + ".tmp")
    try:
        da.rio.to_raster(tmp_path, driver="GTiff")
        with rasterio.open(tmp_path, "r+") as dst:
            dst.descriptions = tuple(band_names)
            if tags:
                dst.update_tags(**tags)
        os.replace(tmp_path, out_path)
    except Exception:
        if tmp_path.exists():
            tmp_path.unlink()
        raise


def write_cog(
    da: xr.DataArray,
    out_path: Path,
    band_names: Sequence[str],
    blocksize: int = 16,
    tags: Optional[dict] = None,
) -> None:
    """Write a (valid_time, latitude, longitude) DataArray as a COG.

    Goes through `write_geotiff()` (which sets the CRS, the -180..180
    longitudes and the band descriptions) to a temporary GeoTIFF, then copies
    that to the COG driver, so the descriptions carry over. Atomic like
    `write_geotiff()`: the COG appears under its final name only when whole.

    Layout chosen by measurement for the daily cube (#116): 16 px tiles,
    pixel-interleaved, so one point's 365 days sit in one ~125 KB tile and a
    remote point read fetches only that. DEFLATE with the floating-point
    predictor; no overviews, since nothing reads this grid zoomed out.

    `tags` (the run's provenance, #124) go on the staging GeoTIFF, and the
    COG copy carries them over: the copy is the last step to touch a published
    byte, so a checksum taken afterwards covers them.
    """
    # Stage beside, not inside, the output directory: that directory is what
    # gets synced to S3, and a run killed hard (SIGKILL, OOM) skips `finally`.
    # Same filesystem, so the final os.replace() stays atomic.
    stage = Path(tempfile.mkdtemp(prefix=".cog_stage_", dir=out_path.parent.parent))
    tmp_tif = stage / "src.tif"
    tmp_cog = stage / "cog.tif"
    try:
        write_geotiff(da, tmp_tif, band_names=band_names, tags=tags)
        rasterio.shutil.copy(
            tmp_tif, tmp_cog, driver="COG", compress="DEFLATE",
            predictor="YES", blocksize=blocksize, overviews="NONE",
        )
        os.replace(tmp_cog, out_path)
    finally:
        shutil.rmtree(stage, ignore_errors=True)


def log(msg: str) -> None:
    """Timestamped print, flushed for tail-the-log workflows."""
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def get_token() -> str:
    """Read EDH_TOKEN from env, falling back to ~/.Renviron."""
    token = os.environ.get("EDH_TOKEN")
    if token:
        return token
    renviron = Path.home() / ".Renviron"
    if renviron.exists():
        for line in renviron.read_text().splitlines():
            if line.strip().startswith("EDH_TOKEN="):
                return line.strip().split("=", 1)[1]
    sys.exit("EDH_TOKEN not found in env or ~/.Renviron")


def backup_before_delete(
    files: Iterable[Path],
    backup_subdir: str = "_backup",
) -> None:
    """Move `files` to `<file.parent>/<backup_subdir>/<file.name>` before a regen.

    Pattern lifted from `data/backfill/monthly/_cds_backup/` (375 files
    hand-moved during the #36 EDH migration before the new EDH-produced
    outputs overwrote the CDS-era TIFs). Codified here so future regens
    don't have to reinvent it.

    No overwrite: if the backup target already exists, log a warning
    and skip that file. Caller decides whether that's fatal.
    """
    for src in files:
        if not src.exists():
            continue
        backup_dir = src.parent / backup_subdir
        backup_dir.mkdir(parents=True, exist_ok=True)
        dst = backup_dir / src.name
        if dst.exists():
            log(f"  backup target exists, skipping: {dst}")
            continue
        shutil.move(str(src), str(dst))
        log(f"  backed up {src.name} -> {backup_subdir}/")
