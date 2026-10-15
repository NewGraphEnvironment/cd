# Task: cd_compare(method = "pct_change") returns a percent for temperature (#138)

**If we do it:** `cd_compare(method = "pct_change")` can no longer return a meaningless percent for a variable measured as a difference. **If we never do:** every caller has to remember which variables can take a percent, and a table that misses one publishes something like "+343 % warmer".

## Context

`cd_compare(ts, method = "pct_change")` computes `(mean_a - mean_b) / |mean_b| * 100` for every
variable. A variable with no real zero gets a meaningless percent: BULK annual tmean came out at
+342.6 % because its 1951–1980 mean is −0.57 °C. Day of year (`snowmelt_doy_50`) and variables
that are already percentages (`snow_cover`, `snowfall_fraction`) have the same problem.

**Exploration changed the key.** The issue suggests keying a guard on
`cd_variables()$anomaly_type`. That is the wrong proxy. `data-raw/northern_bc_vignette_data.R:36-41`
calls `pct_change` on `vpd` and `swe_max`, both `absolute`, and those percents are meaningful
because the values have a real zero. The variables that cannot take a percent are exactly the six
the two regional vignettes already exclude by hand (`no_pct_vars`, `vignettes/peace-fwcp.Rmd:280`):
tmean, tmax, tmin, snow_cover, snowfall_fraction, snowmelt_doy_50.

**Corrected during the build:** `rh` is blocked too. Its values are already in percent, the
same reason as snow_cover and snowfall_fraction, and the list at the gate missed it. That makes
seven, one more than the vignettes' `no_pct_vars`.

**Decisions taken at the gate:** a new logical registry column decides it, and blocked rows get
`difference = NA` with one batched warning. There is no `method = "auto"`. The swe_max
registry-vs-CLAUDE.md question is [#139](https://github.com/NewGraphEnvironment/cd/issues/139)
and stays there: swe_max can take a percent whichever anomaly type it ends up with.

## Phase 1: Tests first

`tests/testthat/test-cd_compare.R`, `tests/testthat/test-cd_variables.R`
- [x] `cd_variables()` has a logical `pct_change` column, FALSE for exactly tmean, tmax, tmin, rh, snow_cover, snowfall_fraction, snowmelt_doy_50; update the `expect_named()` at `test-cd_variables.R:5`
- [x] Change the existing "computes pct_change" test (`test-cd_compare.R:18`) from `tmean` to a ratio-scale variable (`prcp`) so it keeps testing the arithmetic
- [x] tmean with `pct_change` gives `difference = NA` and one warning naming `tmean/annual`; `mean_a` and `mean_b` are still returned
- [x] Mixed input (tmean + prcp) gives a number for prcp, NA for tmean, and exactly one warning
- [x] `mean_diff` on tmean gives no warning and no NA (the guard is pct_change-only)
- [x] Carried column: a non-registry series with `pct_change = FALSE` is blocked; `pct_change = TRUE` on tmean overrides the registry
- [x] Fallback for a non-registry series with no `pct_change` column: `anomaly_type = "pct_point_diff"` is blocked; `absolute`, `pct_normal` or no anomaly_type at all is computed as today (wet's streamflow keeps working)
- [x] A carried `pct_change` that is not logical, or varies within a series, aborts (via `meta_check()`)
- [x] Restore-the-bug check: with the guard removed, the tmean and mixed tests go red (testthat counting `failed | error`)

## Phase 2: Registry + resolver

`R/cd_variables.R`, `R/cd_anomaly.R`
- [x] Add a `pct_change` column to `cd_variables()` and its roxygen `@return` (`\item{pct_change}`: TRUE where the values have a real zero, so a percent change means something)
- [x] Resolve it in `meta_resolve()` (`R/cd_anomaly.R:166`), the one place the rules live: carried column, then registry, then `anomaly_type != "pct_point_diff"` (NA type → TRUE)
- [x] Document the optional `pct_change` input column in `?cd_anomaly`'s input contract, next to `anomaly_type`/`unit`/`long_name`

## Phase 3: Guard in cd_compare()

`R/cd_compare.R`
- [x] After `series_check()`, validate a carried `pct_change` is logical and run `meta_check(x, "pct_change")`
- [x] For `method = "pct_change"`, set `difference = NA` on rows whose resolved `pct_change` is FALSE, and emit one warning listing them as `variable/period` (same shape as the p_value warning at `cd_compare.R:122`)
- [x] Roxygen: `@param method` says which variables get NA and why; keep the example's `pct_change` call warning-free (the toy catalog is tmean only, so the example uses a hand-built prcp series)
- [x] `devtools::document()`, `lintr::lint_package()`, `devtools::test()`

## Phase 4: Docs and callers

- [x] CLAUDE.md: one sentence in the consumer-chain notes naming the `pct_change` column and the NA + warning behaviour
- [x] Grep vignettes and `data-raw/` for `pct_change` calls that now hit the guard. Expected: none, since northern-bc passes only prcp/swe_max/vpd/soil_moisture and peace/kootenay pass only pct_normal vars. Record it in findings either way; regen nothing unless a call changes
- [x] Note in findings (not done here): the hand-kept `no_pct_vars` vectors in `peace-fwcp.Rmd` / `kootenay-lake.Rmd` could read `cd_variables()$pct_change`
- [ ] Edit #138's body to record the decision (registry column, not anomaly_type, and why)

## Validation

- [ ] Tests pass
- [ ] `/code-check` clean (each commit, or once over the branch with `/code-check branch`)
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion

