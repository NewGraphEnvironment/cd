# Plan review — #97 (Plan agent, 2026-09-29)

Read-only agent; findings returned as reply text and recorded here with their disposition.

## Q1 parity

126 combinations checked (variable prcp/tmean/snow_cover/q_mean × `anomaly_type`
absent/NA/absolute/pct_normal/pct_point_diff/bogus × `unit` absent/NA/"mm" × value/anomaly):
**0 disagreements** between `cd_summary()$Unit` and the `cd_plot_timeseries()` label on
fresh `cd_trend()` output. They diverge only if a column is dropped after `cd_trend()`:
- `trend_on` dropped: raw pct_normal series go back to `%` (the #97 bug). → A1, accepted:
  a missing `trend_on` must read as anomaly for the committed rds.
- `anomaly_type` dropped but `unit` kept: type falls back to the registry. → A2, accepted
  (user edit, not the design).

## Q2 double resolution

Idempotent on fresh output. Side effects of `meta_check()` now running on raw metadata:
(a) raw input with a partly-NA or conflicting `anomaly_type`/`unit` within a series now
aborts in `cd_trend()` (the plot already does) → G3, test added; (b) masked values are
checked after masking, so `unit = c("%", "pct")` on a raw pct_normal series passes (the
plot behaves the same) → A4, accepted.

## Findings and disposition

| id | finding | disposition |
|---|---|---|
| G1 | NEWS needs the behaviour changes | listed in the PR body for `/gh-pr-merge` |
| G2 | stale `R/cd_compare.R:78` comment; "for anomalies" qualifier in `R/cd_plot_timeseries.R:6-9` | fixed |
| G3 / AC3 | no test for the new raw-input abort | test added |
| AC2 | no test that an old registered pct_normal table without `trend_on` keeps `%` | test added |
| A1 | masked vs unmasked carry of `unit` on raw trends | kept masked: the issue asked for `raw = TRUE`, and on a trend table `unit` then describes the slope; documented in `@return` |
| A3 | snow_cover raw values are percent; vpd's Pa vs hPa is #96 | no change |
| O1 | `meta_resolve()` vector `raw` and `cd_summary()` must land together | same commit |
| O2 | mutants | run: 3/3 red (findings.md) |
| S1 | plot `trend =` overlay ignores `trend_on`, draws raw line on anomaly plot | filed #103 |
| S2 | vignettes label anomaly prcp slope `prcp mm/yr` | verified against rds (slope 0.0521, pct_normal); filed #102 |
| S3 | mixed raw+anomaly rows in `cd_summary()` distinguished only by Unit | noted on #98 |
| AC1 | parity test covers plumbing, not the rule (rule pinned in test-cd_plot_timeseries) | accepted |
