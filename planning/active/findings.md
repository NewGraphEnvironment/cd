# Findings — Backfillers fetch a full partial year (#84)

## Issue context

## What changes if we do it

The monthly live run stops downloading a full year of hourly ERA5-Land and throwing
it away. Roughly eleven runs a year currently do real work over a metered free tier
and produce nothing.

## What happens if we never do it

We keep spending the EDH free-tier quota every month for no output, and the quota
becomes a plausible cause of a future red run that has nothing to do with the code.
It also means the expensive path is exercised regularly in the one way that cannot
produce a useful artifact.

## The mechanism

Both backfillers compute first and check completeness second.

`scripts/backfill_edh_all.py` (same shape at lines 128/137/146/161/168/180/192):

```python
monthly_tmax = (daily_max.resample(valid_time="1MS").mean() - 273.15).compute()
if monthly_tmax.sizes["valid_time"] == 12:
    write_geotiff(monthly_tmax, out["tmax"])
```

`scripts/backfill_edh_snow.py` — `.compute()` at 182 and 197, the `== 12` guards at
212/221/229/237.

`.compute()` is where the lazy dask/xarray graph executes and the data is actually
fetched from the Zarr store. The only earlier exit is the idempotency check
(`if not needed: return`, line 105), which does not fire for a year whose outputs have
never been written.

The comment in `pipeline_update_edh.R` describes the intent accurately — "The Python
scripts skip incomplete years (n_months != 12)" — but they skip the *write*, not the
*fetch*.

## Suggested fix

Read the available months from the store's coordinate before computing anything:

```python
n = hourly_ds.valid_time.sel(valid_time=slice(f"{year}-01-01", f"{year}-12-31T23:00")) \
             .dt.month.to_series().nunique()
if n < 12:
    log(f"{year}: only {n} months on EDH, skipping (no fetch)")
    return
```

Coordinate access is metadata, not data, so this costs nothing. Do it once in
`process_year()` rather than per-variable.

## Observed

`2026-09-07`, run 34145055066 (dry run): `Latest year on S3: 2025`,
`Candidate years to fetch: 2026`. The 09-01 live run took the same path, fetched 2026,
and wrote nothing — correct behaviour, expensively arrived at.

## Related

Steps 4 and 5 of `pipeline_update_edh.R` (COG append, catalog publish) have therefore
still never run to completion in CI since #78. First real opportunity is whenever 2026
completes on EDH, ~March 2027. Worth a deliberate test before then rather than
discovering it live — but that is a separate issue from this one.

