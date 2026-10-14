# Plan review — #96 (Plan agent, read-only; transcribed from its reply)

Reviewed task_plan/findings and commits 29fb834, 80620d3, ceda3f1. No blockers.

| # | Category | Finding | Verified | Action |
|---|----------|---------|----------|--------|
| 1 | Gap | A saved vpd table carrying "Pa" bound to new output carrying "hPa" aborts in `meta_check()` (`R/cd_anomaly.R:226-248`) from `cd_anomaly()`, `cd_trend()` and `cd_plot_timeseries()`; `cd_summary()` on bound trend tables prints both rows | Reproduced: `cd_trend()` aborts "More than one value within a series ... `unit` in vpd/annual, ..." | NEWS line says so |
| 2 | Acceptance | NEWS draft wrong: "re-run `cd_anomaly()`" cannot fix a saved anomaly table (no `value`, carried unit wins); `cd_trend()` should be named; "plot labels" is `cd_plot_timeseries()` only (`cd_plot_comparison()`/`cd_compare()` use `long_name` only) | Read against code | NEWS line rewritten: relabel, or recompute from the extracted series |
| 3 | Acceptance | `/gh-pr-merge` takes only the FIRST line of the PR body's `## Summary` as NEWS (`soul/skills/gh-pr-merge/SKILL.md` step 3) | Read the skill | NEWS text is one line, first in Summary |
| 4 | Scope | Downstream saved tables carry "Pa": fraser (3420 vpd rows), skeena (2660), peace (2280) 2025 reporting `.rds`, each printed through `cd::cd_summary(trn)`; restoration_wedzin_kwa_2024 hard-codes `vpd = "Pa"` (`2044-Appendix-climate-anomaly.Rmd:31`) | Counted rows; read the line | Filed fish_passage_fraser_2025_reporting#38, fish_passage_skeena_2025_reporting#19, fish_passage_peace_2025_reporting#48, restoration_wedzin_kwa_2024#162 |
| 5 | Assumption | "a future regen writes hPa on its own" holds only after a reinstall: generators run `library(cd)`, installed cd is 0.6.3 (still "Pa") | Same finding as code-check round 2 | Patch script header qualified; the agreement test catches a regen under an old cd |
| 6 | Acceptance | Vignette check used `load_all`, not the render path; pkgdown CI (installs `local::.`) is the real render; no R CMD check workflow, so run `devtools::check()` locally | — | `devtools::check()` run locally; pkgdown CI on the PR |
| 7 | Assumption | Issue cites stale line numbers (`:46`, `:13`; were `:55`, `:22`) | — | Cosmetic; none |

Checked sound: no unit string comparison anywhere; no other stored vpd unit (catalog, COG tags, extdata, snapshots); agreement test works under R CMD check and cannot pass vacuously; .rds patch changed only the unit column (round-trip `identical()`); commit order keeps every commit green.
