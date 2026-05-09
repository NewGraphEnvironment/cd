# Task: cd_compare defaults + window-vs-window p-value (#20 + #43)

`cd_compare()` requires both `window_a` / `window_b` (no defaults)
and emits no measure of statistical confidence. Issue #20 settles
the framing — recent **2015–2025** vs WMO-style **1951–1980** —
based on what both regional vignettes (`peace-fwcp`, `kootenay-lake`)
already use consistently and the methodology lit review at
`planning/archive/2026-05-issue-53-snow-lit-review/findings.md`.
Issue #43 closes the second gap: a real window-vs-window p-value
column so `cd_compare()` stops borrowing `cd_trend()`'s
Mann-Kendall p-value as a proxy. The MK test answers a different
question (monotonic trend vs window-vs-window difference). Issue
#20 explicitly says "Tightly coupled with #43; both should land
together" — single branch, single PR.

## Phase 1 — Add defaults (#20)

- [x] Edit `R/cd_compare.R` signature: `window_a = 2015:2025`,
      `window_b = 1951:1980` defaults; update roxygen with the
      framing rationale (cumulative-impact vs rate-of-change)
- [x] Update existing tests in `tests/testthat/test-cd_compare.R` —
      keep explicit-window tests, add a new test exercising the
      defaults
- [x] `devtools::document()` to refresh `man/cd_compare.Rd`
- [x] `devtools::test()` — green
- [x] Atomic commit: "Add cd_compare() defaults: 2015:2025 vs 1951:1980 (#20)"

## Phase 2 — Window-vs-window p-value (#43)

- [ ] Edit `R/cd_compare.R` body — add `test = "t"` argument,
      window-extraction + Welch t / Wilcoxon dispatch, < 8-year
      small-N guard with batched warning, `p_value` column emitted
      only when `test != NULL` (default `"t"` so column is present
      by default)
- [ ] Add tests covering: clean step-change → tiny p; iid noise →
      large p; `test = "wilcox"`; `test = NULL` → original 6-col
      schema; small-N guard fires once with warning; multi-variable
      input gets per-row p-values
- [ ] `devtools::document()` to refresh `man/cd_compare.Rd`
- [ ] `devtools::test()` — green
- [ ] `lintr::lint_package()` — clean
- [ ] Atomic commit: "Add window-vs-window p-value to cd_compare() (#43)"

## Phase 3 — Vignette updates

- [ ] `vignettes/peace-fwcp.Rmd` — bare default-driven
      `cd::cd_compare(ts)` recipe call; comparison table swaps
      synthesized `trend_p` proxy for new `Δ p (windows)` column
      (keep `Trend p (75-yr)` alongside — different question);
      add one-paragraph narrative on the two p-values
- [ ] `vignettes/kootenay-lake.Rmd` — same edits
- [ ] Local render of both vignettes — clean
- [ ] Atomic commit: "Use cd_compare() defaults + window-vs-window p-value in regional vignettes"

## Phase 4 — Release

- [ ] Update `NEWS.md` — single section bullet covering both
- [ ] Bump `DESCRIPTION` Version: `0.2.8` → `0.3.0` (minor — new
      arg with default value, output schema gains `p_value` column
      by default)
- [ ] PR via `/gh-pr-push`; merge via `/gh-pr-merge`
- [ ] `/planning-archive` after merge

## Validation

- [ ] Tests pass
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
