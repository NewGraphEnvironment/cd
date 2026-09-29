# Review round 3 — cd#92 (mechanism + new helpers)

Reviewer: subagent, 2026-09-28. Probes ran in a scratch copy of the repo
(`$SCRATCHPAD/cdcopy3`, staged tree, `pkgload::load_all()`), with main's `R/` in a second copy
(`$SCRATCHPAD/cdmain`) for before/after. The repo itself is unchanged apart from this file.

## Mechanism

Every consumer function is its own entry point, and each one re-derives its assumptions about
the input on its own. Those assumptions are: the frame is ungrouped, a series is keyed by
`(variable, period)`, there is one row per `(variable, period, year)`, and metadata is resolved
before it is judged. The rules now live in shared helpers (`meta_resolve()`, `meta_check()`).
The order they run in (ungroup, then resolve, then check, then consume) does not live in a
helper; it is typed out again in each caller. The rounds kept finding the same three things:

- Two lists that agree only by coincidence. The registry's `unit` is valid only together with
  the registry's `anomaly_type` (R1, R2).
- One caller that composes the steps in a different order from the others (R2: cd_summary
  skipped the guard; R2 again: cd_trend skipped the check).
- An input-shape assumption that one caller enforces and the next does not (grouping in R1 and
  R2).

The documented contract says "`value`: one value per variable, period and year". That is a
fourth instance of the third kind, and nothing enforces it anywhere.

Where the mechanism reaches, across every exported function in `R/`:

| function | shape (grouping / one row per key) | metadata (resolve then check) | status |
|---|---|---|---|
| `cd_anomaly` | ungroup; duplicate `(variable, period, year)` rows pass | resolve, then check | metadata handled; duplicate-key rows not handled (F2) |
| `cd_baseline` | ungroup; pools any extra key silently | none needed | **not handled** (F2): grouped extra key was an error on main and is now pooled |
| `cd_compare` | ungroup; pools any extra key silently | none needed | **not handled** (F2), same as `cd_baseline` |
| `cd_trend` | ungroup; duplicate years become one series (`n_years` inflated) | **checks raw, no resolve** | **not handled** (F1, F2) |
| `cd_summary` | ungroup; works row by row | resolve, and needs no check | handled |
| `cd_plot_timeseries` | base indexing | registry only, so the R1 unit class is still here | out of scope (cd#93) |
| `cd_plot_comparison` | base indexing | registry only | out of scope (cd#93) |
| `cd_extract` | producer: one row per key per AOI | none | not affected |
| `cd_stac_catalog`, `cd_fetch` | producer side, use only `cd_variables()$variable` | none | not affected |
| `cd_aggregate`, `cd_seasons`, `cd_periods`, `cd_cache*`, `cd_catalog`, `cd_crop`, `cd_cog_write`, `cd_derive`, `cd_s3_push`, `cd_variables` | no series identity or metadata logic | none | not affected |

## Findings

- **[fragile] R/cd_trend.R:43-47,79**: `cd_trend()` runs `meta_check()` on the raw columns
  without resolving them first. `cd_anomaly()` does the reverse (it resolves at line 87 and
  checks at line 107). That is R2's partly-NA finding, fixed in `cd_anomaly()` and reappearing
  in its other caller. `cd_trend()`'s docs point at the `cd_anomaly()` input contract ("where
  absent or `NA` they fall back to `cd_variables()`"), yet it rejects input that contract says
  is valid. Measured:
  - A raw tmean series with `long_name = c("Mean temperature", NA, ...)`: `cd_anomaly()`
    accepts it and fills the label. `cd_trend(x)` aborts with "`long_name` in tmean/annual".
  - An anomaly tibble built by hand for tmean, with `unit = c("°C", NA, ...)`: `cd_trend()`
    aborts with "`unit` in tmean/annual".

  It fails loudly, not silently. Fix: check the resolved values. Replace `x[cols_meta]` with
  `meta_resolve(x)[cols_meta]` before `meta_check()`, and carry the resolved value at line 79.
  Then the two callers compose the steps the same way.

- **[bug] R/cd_baseline.R:44, R/cd_compare.R:75** (and `cd_trend`/`cd_anomaly` downstream):
  the new `ungroup()` turns what used to be a loud error into silent pooling across series when
  the frame is grouped by a key outside `(variable, period)`. On main, `cd_baseline()` and
  `cd_compare()` on `group_by(q, station)` both aborted ("Can't supply `.by` when `.data` is a
  grouped data frame"), which I measured against main's `R/`. Now they return one pooled row.
  Measured with two stations × 10 years (values 1:10 and 101:110):
  - `cd_baseline()` gives one row, `baseline_mean = 53`.
  - `cd_compare()` gives one row, `difference = 5`.
  - `cd_trend(cd_anomaly(...))` gives one row, `n_years = 20` for a 10-year record. Every
    number in it is wrong, so `cd_summary()`'s `Total Change` (slope × n_years) is wrong too.

  This matters now because the consumer that motivated #92 (wet#25) produces flow at
  *hydrometric stations*. A multi-station long frame with a `station` column is its natural
  output, and grouping it by station is the natural thing to do before calling cd. The
  ungrouped form of the same input was already pooled on main, which is pre-existing. The diff
  removes the one signal that caught the grouped form. The contract's "one value per variable,
  period and year" is the invariant that would close both forms, and nothing checks it. A
  shared `series_check()` that aborts on duplicated `(variable, period, year)` would do it,
  called where `meta_check()`'s callers already sit plus in `cd_baseline()`/`cd_compare()`. At
  minimum, `ungroup()` only when `dplyr::group_vars(x)` is a subset of
  `c("variable", "period")`, and abort otherwise.

## Helpers checked, no defect

- `meta_resolve()`: NA and unregistered variables resolve to NA. `if_else(missing = NA)`
  covers an NA type. Factor `variable`/`anomaly_type` go through `as.character`. Zero-row
  input returns length-0 vectors. A carried `unit` with the registry type passes through as
  given, per the design (prcp/pct_normal with `unit = "mm"` gives `"mm"`).
- `meta_check()`: runs after resolution in `cd_anomaly()`. NA is counted as distinct by design.
  It returns early on zero rows or no columns. The message names the offending column and
  series.
- `cd_summary()`: factor `variable` and `anomaly_type`, NA variable, and carried NA `unit`
  under an overriding type all give the expected labels and units (measured).
- `cd_anomaly()` with NA `period`: `summarise(.by)` and `left_join` both match NA to NA, and
  the result is correct.
