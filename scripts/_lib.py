"""Shared helpers for the cd producer-side bulk-fetch scripts.

Borne out of #38 — each backfill script (currently `backfill_edh_all.py`
and `backfill_edh_tmax_tmin.py`, eventually a snow-vars script for #48)
needs the same safeguards against its own failure modes:

  - `preflight_single_instance(name)` — pgrep guard so two runs of the
    same script can't hammer EDH concurrently. Skipped on GHA.
  - `with_retry(fn, ...)` — exponential backoff around the network surface.
    EDH is chunk-based and rate-limit-free, so transient blips (DNS, TLS
    handshakes) are the dominant failure mode.
  - `write_geotiff(da, out_path, ...)` — atomic .tmp + os.replace, so a
    killed run never leaves a truncated file that fools the per-output
    idempotency check.
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
import time
from pathlib import Path
from typing import Callable, Iterable, Optional, Sequence, TypeVar

import rasterio
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


def with_retry(
    fn: Callable[[], T],
    *,
    attempts: int = 4,
    initial_delay: float = 10.0,
    what: str = "operation",
) -> T:
    """Run `fn()` with exponential backoff on transient errors.

    EDH is chunk-based (no job queue), so network blips are the main
    failure mode. Retry on OSError / ConnectionError / TimeoutError
    (covers fsspec/aiohttp transients). Let other errors (KeyError,
    ValueError, RuntimeError) propagate — those are bugs, not transient.
    """
    delay = initial_delay
    for i in range(1, attempts + 1):
        try:
            return fn()
        except (OSError, ConnectionError, TimeoutError) as e:
            if i == attempts:
                raise
            log(f"  {what} failed (attempt {i}/{attempts}): "
                f"{type(e).__name__}: {e}. Retrying in {delay:.0f}s...")
            time.sleep(delay)
            delay *= 2
    raise RuntimeError(f"with_retry: exhausted {attempts} attempts for {what}")


def write_geotiff(
    da: xr.DataArray,
    out_path: Path,
    band_names: Optional[Sequence[str]] = None,
) -> None:
    """Write a DataArray with (valid_time, latitude, longitude) dims as a
    multi-band EPSG:4326 GeoTIFF.

    `band_names` defaults to MONTH_NAMES (Jan..Dec). For annual outputs,
    pass e.g. a list of year strings; the band count must match
    `da.sizes["valid_time"]`.

    Atomic: writes to a `.tmp` suffix then renames, so a killed run
    never leaves a truncated file that passes the per-output existence
    check on restart.
    """
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
        os.replace(tmp_path, out_path)
    except Exception:
        if tmp_path.exists():
            tmp_path.unlink()
        raise


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
