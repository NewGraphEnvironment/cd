# Findings — cd_compare(method = "pct_change") returns a percent for temperature (#138)

## Issue context

**If we do it:** `cd_compare(method = "pct_change")` can no longer return a meaningless percent for a variable measured as a difference. **If we never do:** every caller has to remember which variables can take a percent, and a table that misses one publishes something like "+343 % warmer".

Found while probing for #137 (2026-10-14). On a full `cd_extract()` series, `cd_compare(ts, method = "pct_change")` computes a percent change for every variable, `tmean` included. BULK annual tmean over 2016–2025 against 1951–1980 came out at +342.6 %, because the base mean is −0.57 °C. A temperature near 0 °C makes the percent unbounded and its sign arbitrary. Days of year (`snowmelt_doy_50`) and percentage-point variables have the same problem in milder form.

Options: warn or refuse `pct_change` where `cd_variables()$anomaly_type` is `absolute` or `pct_point_diff`, or add a `method = "auto"` that picks per variable. Note the registry's own entries first: `swe_max` is `absolute` there, but CLAUDE.md lists it as `pct_normal`, and the vignettes report it as a percent. Settle which is right before keying any guard on it.


## Exploration (2026-10-15)

- `anomaly_type` is the wrong key for the guard. `data-raw/northern_bc_vignette_data.R:36-41` calls `pct_change` on `vpd` and `swe_max`, both `absolute` in the registry, and those percents are meaningful (real zero). What breaks a percent is a value with no real zero (interval scale: °C, day of year) or one already in percent (`pct_point_diff`).
- The six variables that cannot take a percent are exactly the hand-kept `no_pct_vars` in `vignettes/peace-fwcp.Rmd:280` and `vignettes/kootenay-lake.Rmd`: tmean, tmax, tmin, snow_cover, snowfall_fraction, snowmelt_doy_50.
- `swe_max`'s type (registry `absolute`, CLAUDE.md `pct_normal`) is #139, left there. It can take a percent either way.
- Gate decisions (user, 2026-10-15): new logical `pct_change` column in `cd_variables()`, resolved in `meta_resolve()`; blocked rows get `difference = NA` plus one batched warning; no `method = "auto"`.
- `cd_compare()` must keep working on a non-registry series with no `anomaly_type` (meta_resolve gives NA type there), so the fallback treats NA type as allowed.

## Errors Encountered

| Error | Resolution |
|-------|------------|
| Test helper `pct_series(variable, ...)` built a 10-row column then failed `length(variable)` inside `tibble()` | `tibble()` evaluates arguments in order, so a later argument sees the column, not the function argument; renamed it `vars` |
