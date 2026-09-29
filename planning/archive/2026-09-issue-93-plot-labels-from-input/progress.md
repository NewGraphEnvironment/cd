# Progress — cd_plot_timeseries() and cd_plot_comparison(): use long_name/unit carried on the input (#93)

## Session 2026-09-28

- Plan-mode exploration — phases approved by user
- Created branch `93-cd-plot-timeseries-and-cd-plot-comparison` off main
- Scaffolded PWF baseline from issue #93 with approved phases
- Next: start Phase 1
- Plan review (Plan agent) landed during Phase 1: 11 findings, triaged in findings.md; filed cd#96 (vpd Pa/hPa) and cd#97 (cd_summary raw-value unit)
- Phase 1: cd_plot_timeseries() labels via series_check/meta_resolve/meta_check; raw-value unit rule moved into meta_resolve(raw = TRUE); which() subset. /code-check: 4 rounds (Clean, NA-subset, mechanism + NA-subset, Clean on fixes). Mutants of both fixes go red.
- Full suite at this point: FAIL 0 | PASS 313 (6 pre-existing rownames warnings in cd_plot_comparison)
- Phase 2: cd_compare() passes long_name (cd_trend's raw-value rule); cd_plot_comparison() facets by resolved long_name, keyed on variable + label so facets never merge. /code-check: 3 rounds + enumeration of label-as-key sites (1 found, fixed). Filed cd#98.
- Phase 3: full suite FAIL 0 | PASS 317; no new lints; both vignettes render.
