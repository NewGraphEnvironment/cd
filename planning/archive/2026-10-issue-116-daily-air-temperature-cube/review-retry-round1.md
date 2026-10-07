# Review round 1: with_retry() + aiohttp.ClientError (staged diff)

Reviewed 2026-10-06. Files: scripts/_lib.py:97-140, scripts/test_lib.py:225-284.
Probed with uv-resolved aiohttp 3.14.4, fsspec 2026.9.0, zarr 3.4.0, dask, Python 3.12.13
(the version `uv run` picks for these scripts). All probes ran in the scratchpad, against a
local socket server; no repo files touched, no backfill script run.

## Verdict: Clean

No real defects. The questions asked, with the evidence:

### 1. Is aiohttp guaranteed in sys.modules when with_retry needs it? Yes, by construction.
`except _transient_errors() as e:` (_lib.py:133) is evaluated when an exception is being
matched, not when with_retry is entered (probed: the tuple-building function ran once, after
the raise). An aiohttp exception instance cannot exist unless aiohttp has been imported, so
whenever the thing being matched is an aiohttp error, `sys.modules["aiohttp"]` is populated.
(fsspec.implementations.http also imports aiohttp at module top, so it is loaded as soon as
the HTTP filesystem is touched — but the lazy evaluation makes that irrelevant.)

### 2. Does zarr / dask wrap the error before `.compute()` sees it? No.
- fsspec `HTTPFileSystem.cat_file` on a server that sends 3 of 1000 promised bytes raises
  `aiohttp.client_exceptions.ClientPayloadError` unwrapped through fsspec's `sync()`.
- A dask array whose block raises `ClientPayloadError` re-raises the same type under both the
  `threads` and `synchronous` schedulers.
- zarr 3's `FsspecStore.allowed_exceptions` only converts FileNotFoundError /
  IsADirectoryError / NotADirectoryError to missing keys; others propagate. Consistent with
  the reported traceback.
- Real hierarchy confirmed: `ClientPayloadError -> ClientError -> Exception`, and
  `aiohttp.ClientError is aiohttp.client_exceptions.ClientError`, so the fake module in the
  test matches the real one on the point that matters.

### 3. Non-transient ClientErrors are now retried. Real, but not worth blocking on.
`ClientResponseError` (any non-404 4xx/5xx via fsspec's `raise_for_status()`), `InvalidURL`
and certificate errors are all `ClientError` subclasses, so a 401/403 now costs 4 attempts and
10+20+40 = 70 s before the original exception propagates. Impact by call site:
- `backfill_edh_daily.py` / `_tmax_tmin.py` / the `open zarr` calls: +70 s, then the same
  failure. Harmless.
- `backfill_edh_snow.py:334` and `backfill_edh_all.py:261` wrap `process_year` in with_retry,
  and snow's `process_year` has inner with_retry calls (211, 226, 284), so retries nest:
  a persistent 403 mid-run costs about 4 x 70 + 70 = 350 s per year in snow (70 s in all),
  and the year loop then `continue`s to the next year and pays it again. Before this change
  a 403 escaped both layers at once. Only matters for a long multi-year local backfill whose
  credential or quota dies partway (CLAUDE.md notes free-tier quota); the monthly GH Action
  processes one year and its STEP 0 auth probe catches a bad token before any Python runs.
  Nothing is lost in either case — outputs are idempotent and the error still surfaces.
- Optional refinement if fail-fast matters: retry a `ClientResponseError` only when
  `status >= 500 or status == 429`. Note 429 *is* worth retrying, so catching the whole class
  is defensible as is.

No secret leak from the new log line: `str(ClientResponseError)` prints the URL with the
userinfo stripped (probed with `edh:SECRETTOKEN@` in the URL; token absent), and
`ClientPayloadError`'s message carries no URL.

### 4. Is the test sound? Yes.
- Mutation check: running the staged test_lib.py against HEAD's `_lib.py` gives
  `FAIL  with_retry retries a truncated aiohttp payload, not a bug` (27/28); against the
  staged `_lib.py`, 28/28. The test discriminates the fix.
- The `main()` try/except change works as intended: under the old lib the raising case is
  reported as FAIL and the remaining cases still run.
- Covers both branches that matter (ClientError subclass retried to success on attempt 3;
  ValueError propagates on first call). The sys.modules save/restore is correct.
- Uncovered but trivial: the no-aiohttp branch (`getattr(None, ...)` -> None), exercised
  implicitly by every other case since test_lib.py never imports aiohttp.

## Non-blocking observation (pre-existing, not introduced here)
A retry of `hourly.compute()` in backfill_edh_daily.py:167 re-fetches the whole year from
scratch, so each retry re-spends the bytes already transferred. If payload truncations turn
out to be frequent on a year-sized fetch, per-chunk retry (e.g. fsspec/aiohttp client
retry options on the store) would be the more efficient layer. Not a defect in this diff.
