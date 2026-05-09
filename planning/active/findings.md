# Findings — cd_compare defaults + window-vs-window p-value (#20 + #43)

## Issue #20 — context

`cd_compare()` requires the user to specify both time windows
explicitly. There's no sensible default that helps a first-time
user understand what climate departure looks like for their AOI.

**Status (post-v0.2.1):** vignettes have settled on a de-facto
framing — recent **2015-2025** vs WMO-style **1951-1980**, paired
with both 75-yr and 45-yr Theil-Sen trends. Both `peace-fwcp` and
`kootenay-lake` use this consistently. The methodology lit review
from #54 (archived at
`planning/archive/2026-05-issue-53-snow-lit-review/findings.md`)
backs the choice — Mann-Kendall + Theil-Sen with no prewhitening
per Yue & Wang 2002 is correct for our 76-yr series with strong
trends.

**Remaining scope:** wire those windows in as `cd_compare()`
defaults so a first-time user gets a sensible answer without
having to supply both windows. Document the rationale (cumulative
impact framing — "2 °C warmer" punchline rather than per-year
rate) in roxygen + a brief note in the vignettes.

Tightly coupled with #43.

## Issue #43 — context

`cd_compare()` returns a window-vs-window difference (mean_diff /
pct_change) but no measure of statistical confidence. Readers of
the vignette want to know "is this window-shift real or noise?"

The Mann-Kendall p-value from `cd_trend()` is currently used as a
proxy in the FWCP Peace vignette but answers a different question
("is there a monotonic trend?") — not "do the two windows differ?"
Two windows can differ significantly without a monotonic trend
(step change, U-shape), and a non-significant trend doesn't always
mean the windows are statistically indistinguishable.

**Proposal:** add `test = c("t", "wilcox", NULL)` to `cd_compare()`.
Welch t-test (default) or Mann-Whitney U. Output gains `p_value`
column (NA when `test = NULL`). Small samples (< 8 in either
window) → return NA with a warning. Document the independence
assumption.

## Codebase exploration

### `R/cd_compare.R` (current)

```r
cd_compare <- function(x, window_a, window_b, method = "mean_diff") {
  method <- match.arg(method, c("mean_diff", "pct_change"))
  mean_a <- x |>
    dplyr::filter(.data$year %in% window_a) |>
    dplyr::summarise(mean_a = mean(.data$value, na.rm = TRUE), .by = c("variable", "period"))
  mean_b <- x |>
    dplyr::filter(.data$year %in% window_b) |>
    dplyr::summarise(mean_b = mean(.data$value, na.rm = TRUE), .by = c("variable", "period"))
  n_a <- length(unique(x$year[x$year %in% window_a]))
  n_b <- length(unique(x$year[x$year %in% window_b]))
  if (n_a < 2) warning("window_a has fewer than 2 years of data", call. = FALSE)
  if (n_b < 2) warning("window_b has fewer than 2 years of data", call. = FALSE)
  out <- dplyr::left_join(mean_a, mean_b, by = c("variable", "period"))
  out$difference <- switch(method,
    mean_diff = out$mean_a - out$mean_b,
    pct_change = (out$mean_a - out$mean_b) / abs(out$mean_b) * 100
  )
  out$method <- method
  out
}
```

Returns 6 cols: `variable, period, mean_a, mean_b, difference, method`.

### Existing tests (`tests/testthat/test-cd_compare.R`)

4 tests covering mean_diff, pct_change, small-window warning, and
multi-variable handling. All use `1956:1960 / 1951:1955` explicit
windows on a 1951:1960 toy series — independent of the new
defaults.

### Vignette callsites

- `peace-fwcp.Rmd:534` — `cmp <- cd::cd_compare(ts, 2015:2025, 1951:1980)`
- `peace-fwcp.Rmd:656` — same in per-ecoregion loop
- `kootenay-lake.Rmd:561` — same
- `kootenay-lake.Rmd:688` — same in per-ecoregion loop
- `R/cd_plot_comparison.R:18` — example; same windows

The `cd_plot_comparison()` example windows can stay explicit
since it shows a synthetic series (`1956:1960` vs `1951:1955`) —
or can drop to defaults. Decision to make in Phase 1.

### Reused patterns

- `cd_trend()` uses `match.arg` + per-row dispatch and rounds
  p-values to 4 decimals (`round(mk$sl[1], 4)`) — Phase 2 should
  mirror.
- Existing `n_a < 2` + `n_b < 2` warnings already use
  `call. = FALSE` and a clean message — pattern reused for the
  `< 8` test guard.

## Reference periods

The 1951–1980 window is the WMO-style reference. ERA5-Land
catalogues run 1950 → present (~9 km). Recent 2015–2025 is 11
years. Both far exceed the n=8 guard, so per-ecoregion + per-WSG
loops in vignettes will all return real p-values, not NA.

## Open question parked

The issue (#43) suggests `test = "t"` as the default for the next
minor release — explicit in the issue body. Going with that.
Plan calls a minor bump (v0.2.8 → v0.3.0) since the schema gains
a column by default.
