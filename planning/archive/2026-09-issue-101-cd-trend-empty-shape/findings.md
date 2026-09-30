# Findings — cd_trend(): no series long enough gives a 0x0 tibble, and cd_summary() errors on it (#101)

## Issue context

**If we do it:** `cd_summary()` on a trend with no rows returns an empty table. **If we never do:** a chain run on short series (every series under 3 years in its trend window) aborts inside `cd_summary()` with an error naming a missing column, which says nothing about the cause.

## Problem

`cd_trend()` returns `NULL` for every combination with fewer than 3 years, and `dplyr::bind_rows()` of all-`NULL` is a **0 x 0** tibble — no `variable`, `period` or `slope` columns. `cd_summary()` then fails:

```r
x <- tibble::tibble(variable = "tmean", period = "annual", year = 2000:2001, value = 1:2)
cd_summary(cd_trend(x, 2000))
#> Error in dplyr::mutate(...): Column `period` not found in `.data`.
#> Warning: Unknown or uninitialised column: `variable`.
```

Reproduced on main's code (v0.5.1) and on the #97 branch. Found by the `/code-check` review for #97.

## Proposed Solution

- `cd_trend()` returns a zero-row tibble with its full column set when no combination has enough years, so every consumer sees a typed empty table rather than a shapeless one.
- Test: `cd_summary(cd_trend(<2-year series>))` has 0 rows and the documented columns.


## Plan-mode probe (2026-09-30, v0.5.5)

- `cd_summary(cd_trend(<2-year series>, 2000))` reproduces the error on main.
- A hand-built typed zero-row trend (8 documented columns) through `cd_summary()` gives
  0 x 7; with `region_name` 0 x 8; with `anomaly_type`/`unit`/`long_name` also 0 x 7.
  `cd_plot_timeseries(trend = <typed empty>)` draws with no warning; with the 0x0 it
  warns `Unknown or uninitialised column: 'variable'` / `'period'`.
- `cd_trend(x[0, ], 2000)` is also 0x0 today.
- The existing test `cd_trend skips combos with < 3 years` asserts only `nrow == 0`,
  which the 0x0 satisfies — a fixture that could not reach the failure.

## Errors Encountered

| Error | Resolution |
|-------|------------|
| Mutation check reported "0 lines mutated" while tests went red | `diff` is a shell function in this profile; used `/usr/bin/diff` |
