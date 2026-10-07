# Code-check round 4 — #116 (review of round-3 fixes)

## Clean
No issues found.

### What was checked (terra 1.9.50, in a scratch copy; repo untouched)

- **Fix 2, `has_data()`** — `terra::extract(r[[1]], cells)[, 1]`:
  - length-1 cell vector: 1-row, 1-column data.frame (no ID column), so `[, 1]` is the value.
  - repeated cells `c(8, 8, 16, 16, 8)`: one row per input, order kept -> `FALSE FALSE TRUE TRUE FALSE`.
  - length-2 numeric is treated as cells, not as an x/y pair (2 rows returned).
  - 0 cells: returns `logical(0)` with a "[extract] nothing to extract" warning, no error. Only reachable
    when every queen neighbour is off-grid (a 1 x 1 grid), so not reachable on the cube.
  - `adjacent()` returns a 1 x 8 matrix with `NaN` for off-grid neighbours; `nb[!is.na(nb)]` flattens it
    to a plain vector, so `extract()` never sees a 2-column matrix (which it would read as coordinates).
  - `which(!has_data(cell))` indexes points correctly; NA cells cannot reach it (aborted earlier).
  - Fixture suite: 51 pass, 0 fail, including the move / edge-ring / stranded tests.
- **Fix 1** — `tidyr_free_wide` now defined before use; the variable order of appearance is
  tmean, tmax, tmin (the result's order), so the `setNames()` mapping is right. Live test skips
  ("daily cube not published"), as expected pre-publication. `R_USER_CACHE_DIR` does isolate the cache
  (rappdirs honours it: `/tmp/x/cd`).
- **Fix 3** — `curl::new_handle(nobody = TRUE, timeout = 30L)` is accepted; status mapping unchanged.
- **Fix 4** — `sfc` abort precedes the `sf` branch; an `sf` object does not inherit `sfc`, so sf input
  is unaffected; test matches "geometry column".
- **Fix 5** — prose only.
- Re-check of the rest: STEP D exits all route through `finish()` after STEP D; `cd_s3_push()` has
  `prefix`; `terra` attached for `nlyr()`/`rast()`; Python `test_lib.py` 27/27.
