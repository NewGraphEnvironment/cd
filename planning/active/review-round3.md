# Code check round 3: #138 (pct_change guard), branch vs main

Reviewed 2026-10-15. Diff: `scratchpad/branch.diff` (planning/ excluded). Tests run in a temp copy with
`NOT_CRAN=true`: test-cd_compare.R 94 expectations, 0 failed, no errors. test-cd_variables.R 0 failed.

## Clean

No issues found.

## Mechanism behind the round-1 defect

There were two definitions of "the same series" in one function. The guard (`meta_check(.by = c(variable, period))`)
certified one flag per series under column equality. The consumer then looked the flag up by a derived
string (`paste(variable, period)`), which has a weaker equality: it is lossy, because two distinct column
pairs can encode to the same string. So the lookup used an identity the guard had never validated. The sibling
shapes are: (a) any lookup or display keyed on a derived encoding of the key columns; (b) a join whose
row preservation depends on a uniqueness guard that keyed differently or ran on a different table.

## Where that mechanism, or a sibling, could reach in the changed code: checked

- `R/cd_compare.R:122-126`, the flag join. It now keys on the same columns as `meta_check` (line 98), on the
  same `x` (nothing modifies `x` between 97 and 124). Both use vctrs equality, so the uniqueness `meta_check`
  certifies is exactly the uniqueness the join needs. That makes the left join row-preserving, so `ok` aligns with
  `out`, and `ok` has no NA: `pct_change` is never NA after `meta_resolve`, and every `out` key comes from `x`.
  The restored pasted-key version would fail the "a b"/"c" test: both keys would match the first distinct row.
- `R/cd_compare.R:137`, the warning text `"%s/%s"`. This is a lossy encoding, but it is only displayed and selects
  nothing. Factor `variable` prints its label (`sprintf("%s", factor)` gave `"tmean"`, measured).
- `R/cd_anomaly.R:187`, the registry lookup `match(as.character(x$variable), vars$variable)`. It keys on the column
  value directly, with no derived key.
- `R/cd_anomaly.R:196-198`, carried flag. `x[["pct_change"]]` takes the exact name, with no `$` partial match. Line 90's
  `x$pct_change` is guarded by an exact `%in% names(x)`.
- `R/cd_variables.R`, the positional `pct_change` vector. Checked element by element against `variable`:
  F tmean, F tmax, F tmin, T prcp, T vpd, F rh, T soil_moisture, T swe, T snowfall, T snowmelt, F snow_cover,
  T swe_max, F snowfall_fraction, F snowmelt_doy_50, T snowmelt_rate_peak. Correct, and pinned by set in
  test-cd_variables.R.
- Other `meta_resolve()` callers (cd_trend, cd_summary, cd_plot_timeseries, cd_plot_comparison, cd_anomaly)
  never put `pct_change` in a `meta_check` column set, so a mixed or non-logical carried column cannot
  abort them.
- sf input errors under both methods with "y should not have class sf". This is pre-existing: the same error on
  main under `mean_diff`, from the `mean_a`/`mean_b` join. It is not introduced here.
- The data-raw callers of `method = "pct_change"` (kootenay, peace, northern_bc) pass only variables whose
  registry flag is TRUE (pct_normal vars; prcp, swe_max, vpd, soil_moisture), so a regen does not newly
  produce NA.

## Quantified claims, checked against code

- CLAUDE.md, cd_variables roxygen and test lists. The seven FALSE variables agree with the registry. The `vpd`,
  `swe_max` and `snowmelt_rate_peak` claim ("absolute, still take a percent") is correct.
- "−0.57 °C read as +343 %". This agrees with the `abs(mean_b)` denominator (mean_a ≈ 1.39, so it does mean warmer)
  and with issue #138 (+342.6 %).
- "one warning". There is one batched percent warning (the p_value warning is separate, as tested).
- "FALSE only for pct_point_diff" off the registry. This is correct: the coalesce reaches the type fallback only when
  the registry has no match, and NA type gives TRUE.
- "Read only by cd_compare()". This is correct: other consumers compute the flag and discard it.
- "Each variable and period must resolve to a single ... pct_change". Only cd_compare enforces this. cd_anomaly
  and cd_trend neither check nor keep the column, so it is harmless and not a failure.
- Test comments ("paste to the same `a b c`", "tibble() evaluates in order", "vignettes add a numeric
  pct_change") are all true.
