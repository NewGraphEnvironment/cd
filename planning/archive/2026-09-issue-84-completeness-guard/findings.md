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


## Measurements — 2026-09-07

### EDH store coverage (metadata only, no data fetched)

| store | coverage ends | months in 2026 | 2023-2025 |
|---|---|---|---|
| hourly `reanalysis-era5-land-no-antartica-v0` | 2026-05-31T23:00 | 5 | 12 each |
| daily `era5-land-daily-utc-v1` | 2026-07-31T00:00 | 7 | 12 each |

**The two stores are two months apart.** This is the evidence for guarding per
store rather than pooling: a pooled check would have to pick one answer for a
year where the right answer differs by variable, and would have regressed the
existing hourly-complete/daily-short behaviour. Visible in the run output as
`SKIP rh: got 5 months` beside `SKIP prcp: got 7 months` in the same year.

Hourly latency is ~3.2 months as measured here, so 2026 will not be complete on
the hourly store until roughly March-April 2027. That is when steps 4 and 5 of
`pipeline_update_edh.R` (COG append, catalog publish) get their first real
exercise since #78.

### Both known answers, on real data

Complete years (2023, 2024, 2025) return 12 on both stores and would fetch.
2026 returns 5 and 7 and is skipped. A fixture set that only ever produced one
of these could not distinguish a working guard from a broken one.

### After the change

| script | `--year 2026` | wrote |
|---|---|---|
| `backfill_edh_all.py` | 23.5 s | nothing |
| `backfill_edh_snow.py` | 23.4 s | nothing |
| `backfill_edh_tmax_tmin.py` | 22.0 s | nothing |

~5 s of each is opening the Zarr store(s); the guard itself is a coordinate
read. `find data/backfill -newermt '-10 minutes'` returned nothing.

The pre-change wall clock was deliberately **not** measured: doing so requires
the full partial-year download this change exists to prevent, and the quota is
the thing being protected.

### Offline unit test

`uv run scripts/test_lib.py` — 7/7. Confirmed it can fail: with
`months_available()` stubbed to always return 12 it reports 5/7 and exits 1.

## Out-of-scope question, now measured and closed

**Does a partial trailing month pass the 12-month check?** It would — both the
old guards and `months_available()` count months holding *any* data. Measured:
the trailing month of 2026 is complete on both stores (month 5, 31 days
present; month 7, 31 days present). EDH appears to publish whole months, so
the hazard is not currently realised. **No issue filed.** If EDH ever exposes a
partial trailing month this becomes real, and the fix has to land in both
`months_available()` and the post-compute backstops at once — the case is
pinned in `scripts/test_lib.py` so the behaviour is documented rather than
accidental.

## Still open, untouched by this work

`accum_box` in `backfill_edh_snow.py` runs to `{year+1}-01-01T00:00` for the
06:00-UTC accumulation reset, but nothing verifies that extra day exists. A
year can pass a 12-month check with a 364-day accumulation series. Pre-existing;
not filed.
