# Task: cd_summary(): stations sharing a long_name give indistinguishable rows (#98)


`series_check()` tells callers that series from several sites need distinct `variable` names. The natural next step for streamflow is one `long_name` ("Mean discharge") on every station. `cd_summary()` (`R/cd_summary.R`) replaces `variable` with `Parameter = long_name` and drops `variable`, so those rows become indistinguishable. Measured in #93's review with `q_site1` / `q_site2`.

#93 handled the same case in `cd_plot_comparison()`: a label shared by several variables gets ` (variable)` appended, and facets key on variable + label so nothing can merge.

## Phase 1: Lift the shared-label rule into one helper
- [x] Add `label_disambiguate(variable, label)` to `R/cd_anomaly.R` beside the other series
      helpers (`@noRd`): a label shared by more than one distinct variable gets
      ` (variable)` appended. Repeat (bounded by the number of distinct variables) until no
      label is shared by two variables, so a contrived collision (`long_name = c("Q", "Q",
      "Q (a)")`) still ends distinct — a table has no hidden facet key to fall back on.
- [x] `cd_plot_comparison()` calls the helper in place of its inline three lines; facet key
      logic unchanged. Existing plot tests stay green (the collision test asserts facets only).
- [x] Unit tests for the helper in `tests/testthat/test-cd_anomaly.R`: shared → suffixed,
      unique → untouched, one variable over several periods → no suffix, the collision case →
      one distinct label per variable, `NA` handling not reachable (callers coalesce first).

## Phase 2: cd_summary() disambiguates stations
- [ ] `cd_summary()` passes `labels_param` through `label_disambiguate()`.
- [ ] Tests in `test-cd_summary.R`: two stations, one `long_name` → `"Mean discharge (q_site1)"`,
      `"Mean discharge (q_site2)"`; registered ERA5 variables unchanged (registry long_names are
      unique — assert `anyDuplicated(cd_variables()$long_name) == 0` so the premise is pinned);
      one variable over several periods gets no suffix; labels match `cd_plot_comparison()`
      for the same variables.

## Phase 3: cd_summary() carries the scale when a table mixes them
- [ ] Scale = `coalesce(col_or_na(trend, "trend_on"), "anomaly")` (missing/NA read as anomaly,
      as `cd_summary()` already does for units). When it has more than one distinct value, add
      `Trend on` (`"Value"`/`"Anomaly"`) after `Period`; otherwise the output shape is unchanged.
- [ ] Tests: mixed table (`bind_rows(cd_trend(x), cd_trend(ano))` for tmean — identical Unit,
      the case the issue names) → `Trend on` present with `c("Value", "Anomaly")`; single-scale
      and no-`trend_on` tables → `expect_named()` unchanged; value + `NA` trend_on → column
      present, NA row reads `"Anomaly"`; `region_name` still last.
- [ ] Roxygen: `@return` and description name both the ` (variable)` suffix and the conditional
      `Trend on` column; `devtools::document()`.

## Phase 4: Docs
- [ ] `CLAUDE.md` consumer-chain paragraph: the helpers in `R/cd_anomaly.R` are now four
      (add `label_disambiguate`) — any new consumer that prints labels calls it.
- [ ] Full `devtools::test()`, `lintr::lint_package()`, `pkgdown::check_pkgdown()` (no new export).

NEWS + version bump are left to `/gh-pr-merge`, per the repo workflow (0.5.4, patch).

## Validation

- [ ] Tests pass
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
