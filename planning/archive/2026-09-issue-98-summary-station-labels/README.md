## Outcome

`cd_summary()` keeps rows distinguishable (#98). A `long_name` shared by several variables (one label on many stations) gets ` (variable)` appended, by a rule lifted out of `cd_plot_comparison()` into one internal helper, `label_disambiguate()` in `R/cd_anomaly.R`, which both now call. A table that mixes raw-value and anomaly trends gains a `Trend on` column (`Value`/`Anomaly`, the same `%in% "value"` rule as `Unit`); single-scale tables keep their shape, so the vignettes are unchanged. The user chose the conditional column at the plan gate over always adding it or suffixing `Parameter`. What was learned: the helper's repeat loop was bounded by reasoning three times and wrong twice — the plan review caught a silent residual collision, code-check round 1 a bound (variables) too small for one variable carrying different labels by period, round 2 a variable-name shape (`a) (a`) that never settles and so aborts. The shared mechanism, named in round 3, is assuming `variable` makes a printed thing unique; the loop ended on enumeration, not on a reviewer's say-so. A third source of look-alike rows (several `trend_start` values) is filed as #106.

## Measurement

Exhaustive enumeration of `label_disambiguate()` (`label_disambiguate_enum.R`): every set of 1–4 distinct (variable, label) pairs over variables `a`, `b`, `a) (b` and 12 chained-suffix labels — 66,711 sets, 0 aborts, 0 labels shared by two variables at the pair-count bound. At the first bound (`n_distinct(variable)`) the round-1 reviewer's 40,000-draw fuzz aborted 11 times; at the pair count, 0. 969 of the 66,711 sets merge two labels of one variable across periods (accepted: rows differ by `Period`, as on main). Round 2 and 3 stress runs (50,000 random inputs) never exceeded the bound. Final suite: 395 pass, 0 fail.

## Evidence

`review-plan.md`, `review-round*.md`, `label_disambiguate_enum.R` in this directory.

Closed by: PR (see `gh pr list --search 98`)
