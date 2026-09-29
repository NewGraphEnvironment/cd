# Review p2 round 3 — #93 Phase 2, the round-2 fixes

Reviewed the staged diff in a copy (`scratchpad/p2r3`); repo files untouched. Scripts:
`scratchpad/p2r3_probe.R`, `scratchpad/p2r3_order.R`.

## Findings

- **[fragile, low — contrived input]** R/cd_plot_comparison.R:37-45 — the variable+label key
  stops two variables sharing a facet (the r2 defect, now closed), but the **strip text** still
  collides. Measured on the test's own fixture, `variable = c("a","b","c")`,
  `long_name = c("Q","Q","Q (a)")`: three panels whose strips read `"Q (a)"`, `"Q (a)"`, `"Q (b)"`
  (panel keys `a\037Q (a)`, `c\037Q (a)`, `b\037Q (b)`). Nothing is merged any more, but a reader
  cannot tell which of the two "Q (a)" panels is `a` and which is `c`, which is what the comment
  at lines 34-35 ("so the facets can be told apart") and the `@param x` sentence promise. The test
  at test-cd_plot_comparison.R:72-84 checks panel count and facet/variable pairing, never strip
  text, so it passes while the labels stay ambiguous. Same root as r2 ("uniqueness checked before
  the rewrite, not after"), now reduced from wrong data to an ambiguous label. Needs a user
  `long_name` that is literally another label plus `" (variable)"`, so it's low priority. Fine to
  accept as-is if the doc claim is softened.

## Verified, no defect

- **Facet order matches the old behaviour.** For registry variables, mixed-case or underscore
  unregistered names, and multi-period input, old (`HEAD:R/cd_plot_comparison.R`, facet by label)
  and new panel label order are `identical()` under both `en_US.UTF-8` and `C` collation.
  `order()` on a character vector uses shell sort (locale collation), the same collation
  `factor()`/ggplot used on the label.
- **Strips show the label, not the key.** Read from `ggplotGrob()` strip grobs, sorted by
  layout position: "Mean temperature", "Minimum temperature", ... with no `\037` or variable
  prefix.
- **`as_labeller()` with repeated names** is harmless: a key repeats only across a variable's
  period rows, and it always maps to the same label (the label is part of the key), so
  `x[label]` taking the first match is correct.
- **factor `variable`**: same strips and levels as the character version; `paste`/`paste0`
  use the level labels.
- **NA `long_name`** falls back to the registry, then to the variable name. A carried label equal
  to another variable's registry label (`prcp` carrying "Mean temperature" next to `tmean`) gets
  both suffixed, which is correct. factor `long_name` works (`col_or_na` coerces).
- **`scales = "free_x"`** still applies per facet: panel x ranges `[1, 2]` and `[500, 600]`.
- **Separator**: a key collision needs a variable name containing `\u001f`. Punctuated names
  (`a.b`, `a b`, `a(b)`) key and label correctly.
- **Input columns named `param`/`facet`** are overwritten, not read. No effect.
- **One variable with different `long_name`s across periods** (allowed, since `meta_check` is per
  variable/period) splits into one facet per label. The old label-keyed code did the same.
- **Tests**: compare + plot_comparison, 56 expectations, 0 failed/skipped/error (`NOT_CRAN=true`);
  trend, summary, plot_timeseries files also green. Mutation: facet back on `param` makes
  "never puts two variables in one facet" fail, so the guard fires.
- **`cd_compare()`**: the `distinct()` join is one row per variable/period because `meta_check()`
  runs on the resolved column first. Joining factor-to-factor on `variable` works.

## Enumeration

Every grouping, join, facet, match and split key in R/ (`.by`, `_join(by=)`, `facet_*`,
`duplicated`, `match`, `expand.grid`, `==` filters) keys on `variable`/`period`/`year`,
except the one fixed site in `cd_plot_comparison()`. `long_name`/`param`/`Parameter` show up
only as output or display text: `cd_summary()` `Parameter` (cd#98), the `cd_plot_timeseries()`
y label, and the `cd_trend()`/`cd_compare()`/`cd_anomaly()` pass-through columns. None of them
is used as a key. The enumeration holds.

Checklist: skimmed for facet/labeller/ggplot/identity rules (510 KB). No rule applies beyond the
r2 mechanism.
