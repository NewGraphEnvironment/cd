# Review round 2 — staged `scripts/` diff (#116)

## Clean

No issues found.

### What was checked

- **Fix 1 (units/GRIB tags).** `local_daily()` sets `attrs = {"units": "degC"}` on all three outputs. A probe in a temp copy fed a source with GRIB-style attrs, a zarr-style
  `encoding` (`int16`, `scale_factor`, `add_offset`, `_FillValue`) and a non-dim `expver` coord along `valid_time`. All three outputs came back with `encoding == {}` and
  `expver` gone. So no scale or offset reaches `rio.to_raster()`. Only the scalar `number` coord survives, and it is not written as a tag. The written COG reads back with
  tags `{'units': 'degC', 'AREA_OR_POINT': 'Area'}`, no band tags, float32, `LAYOUT=COG`, `INTERLEAVE=PIXEL`, `PREDICTOR=3`, 16x16 blocks, and NaN preserved.
- **Fix 2 (stage dir).** The stage is `out_path.parent.parent` (`data/backfill/`). Nothing syncs `data/backfill/` as a whole: grep across `R/`, `scripts/*.R` and
  `.github/` finds only the `monthly/`, `annual/` and `cogs/` subdirectories. `os.replace` stays on one filesystem. `mkdtemp`'s 0700 applies only to the directory.
  GDAL creates the COG at umask perms (0644), and that survives the replace.
- **Mutation check (temp copy).** With the `rmtree` removed, `cog_roundtrip` FAILs. With the attrs reset removed, it FAILs. `pathlib.rglob` does see dot-dirs.
  Moving the stage back inside the publish dir still passes. That is expected: a hard kill cannot be modelled in-process, so the test pins cleanup, not location.
  Not a defect.
- **`local_year_complete` / `local_daily` guards.** The count, uniqueness and endpoint checks together imply contiguity on an hourly grid. Leap years are handled.
  The 31 Dec 23:00 UTC store end is correctly incomplete.
- **Offline suite.** `uv run --quiet scripts/test_lib.py` gives 27/27.

### Note (not a finding, unverified)

`data/backfill/daily/*_2002.tif` were written at 14:16:26-29. That is before the in-progress run (pid 58031) started at 14:16:35, and after `_lib.py`'s last edit at
14:14:34. At about 90 s per year, the run that wrote them started after the edit, so they were very likely written by post-fix code. I could not confirm this by reading
their tags (the permission check denied it). If they came from pre-fix code, they carry `units=K` and GRIB tags, and the exists-skip will never rewrite them.
Before syncing, one read settles it: `gdalinfo data/backfill/daily/tmax_daily_2002.tif | grep -i units`.
