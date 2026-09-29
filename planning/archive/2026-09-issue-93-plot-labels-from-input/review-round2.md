# Review round 2 — staged diff, cd_plot_timeseries (#93)

Scope: `R/cd_plot_timeseries.R`, its test file and Rd (staged). Probed in a copy
(`scratchpad/cdcopy2`), ggplot2 4.0.3. Test file: `[ FAIL 0 | PASS 15 ]`.

## Findings

- **[severity: fragile]** R/cd_plot_timeseries.R:52 (with :56, :67) — the subset
  `x[x$variable == variable & x$period == period, ]` keeps an all-`NA` row for every
  row of `x` whose `variable` or `period` is `NA` (logical-`NA` index). That line is
  pre-existing, but before this diff the stray rows were harmless: the label came from
  the `variable` argument and ggplot dropped the `NA`-year bars. The diff now reads
  metadata from those rows, with two new outcomes:
  1. **Wrong label, silently.** If the first such row precedes the series in `x`,
     `meta$long_name[1]` / `meta$unit[1]` are `NA` (variable `NA`, no registry match),
     so the label falls back to the column name. `meta_check()` cannot catch it: it
     groups by `variable`/`period`, so the `NA/NA` row is its own group.
     Repro: `tibble(variable = "tmean", period = c(NA, "annual", "annual", "annual"),
     year = 2000:2003, anomaly = c(9, 1, -1, 2))` → y label `"anomaly"` (HEAD gives
     `"Mean temperature (°C)"`).
  2. **Misleading abort.** Two or more such rows become duplicate `NA/NA/NA` keys, so
     `series_check()` aborts with "More than one row per variable, period and year
     ... need distinct `variable` names", which blames the wrong thing. HEAD plotted.
     Repro: `tibble(variable = "tmean", period = c("annual", "annual", NA, NA),
     year = c(2001, 2002, 2001, 2002), anomaly = 1:4)`.
  Also the `variable = NULL` default: if `x$variable[1]` is `NA`, every row
  subsets to `NA` and the same false duplicate error fires.
  Fix: subset with `which()` (or `%in%`), i.e.
  `x[which(x$variable == variable & x$period == period), ]`, so `NA` keys never enter `dat`.
  Only reachable with `NA` in `variable`/`period`, which `cd_extract()` never produces,
  but the contract now invites external long-format producers.

## Checked and fine

- `trend` overlay: `cd_trend()` output on anomaly input and on raw `value` input both
  build; labels unaffected by `trend`.
- `variable = NULL` on a multi-variable `x` whose variables carry different metadata:
  first variable's label, `meta_check()` sees only the filtered series.
- `NA` values in `anomaly` (some or all): builds, label correct (fill `NA` is pre-existing).
- tibble vs data.frame, grouped input, factor `variable`/`period`/`unit`/`long_name`,
  logical-`NA` metadata columns: all resolve correctly.
- `pct_point_diff` on raw `value`: `snow_cover` → `"Snow cover (%)"`; a carried unit
  `"pp"` is honoured. Unregistered `pct_normal` on `value` with no `long_name` → `"value"`.
- Vacuity: against HEAD's `cd_plot_timeseries.R` seven of the new label/guard tests fail;
  the two that pass on HEAD (`tmean` registry label, NA-carried fallback) are regression
  guards whose expected value HEAD also produced, as intended.
