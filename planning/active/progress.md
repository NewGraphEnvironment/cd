# Progress — cd_compare defaults + window-vs-window p-value (#20 + #43)

## Session 2026-05-09

- Plan-mode exploration — phases approved by user
- Created branch `20-43-cd-compare-defaults-pvalue` off main
  (post-v0.2.8 release commit `51aa556`)
- Confirmed the two issues are tightly coupled (#20 issue body
  explicitly says "should land together" with #43)
- Scaffolded PWF baseline with approved 4-phase plan
- Phase 1 done — defaults `window_a = 2015:2025`, `window_b = 1951:1980`
  on `cd_compare()`; roxygen documents cumulative-impact framing;
  defaults test passes; 16 PASS / 0 FAIL on the cd_compare suite
- Phase 2 done — `test = c("t", "wilcox", NULL)` argument added;
  default `"t"` so output gains `p_value` column by default;
  small-N guard (< 8 years either window) → NA + single batched
  warning naming affected variable/period rows; 6 new tests
  covering step-change, iid noise, wilcox, NULL, small-N guard,
  multi-variable; full suite 181 PASS / 0 FAIL
- Next: Phase 3 — vignette wire-up (drop synthesized trend_p
  proxy, surface real `Δ p (windows)` column)
