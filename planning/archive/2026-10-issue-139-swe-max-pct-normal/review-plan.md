# Plan review — #139 (Plan agent, 2026-10-16 UTC)

Returned as reply text (Plan agents cannot write); recorded here.

- **B1** `test-cd_fetch.R:6-13` hardcodes the pct_normal list without swe_max — failing. *Confirmed by the full suite; fixed.*
- **G1** `R/cd_anomaly.R:3-8` lists swe_max among "annual snow scalars" (absolute). *Fix.*
- **G2** `R/cd_variables.R:22` `unit` doc lists `mm`, which no row has now; the column is the anomaly's unit. *Fix.*
- **G3** kootenay-lake.Rmd has a second swe_max facet (`facet-wsg-swe-max`, :808/:819) besides :476/:724/:736; peace :470/:710/:722. *Fix all.*
- **G4** data-raw `pct_normal_vars` comment ("vars with pct_normal anomaly type") is false after the change. *Reword; list unchanged (it is the cmp_pct set the vignettes read).*
- **G5** `test-cd_compare.R:271` uses swe_max as the absolute-but-takes-a-percent example; swap to snowmelt_rate_peak. *Fix.*
- **A1** `peace-fwcp.Rmd:912` says "peak SWE … 135 → 122 mm" but those are annual mean `swe` (swe_max is 348 → 334). Pre-existing. *Confirmed from regional$cmp; fix by dropping "peak".*
- **A2** CLAUDE.md Units column is the data unit; keep swe_max `mm`; only the #138 paragraph changes. *Agreed.* (`snowmelt_rate_peak` mm/day vs registry mm/wk: out of scope, noted.)
- **A3** Patch guard reproduces all 15 groups `identical()`; cmp/cmp_pct type-free. Suggests MK-p and slope-scaling assertions. *Checked externally (all 15 groups: p identical, slope = old × 100/bl); not added to the script, whose patching branch no longer runs.*
- **A4** Patched files: everything but swe_max ano/trn rows identical to HEAD. *Agreed.*
- **O1** Commit registry, tests and patched rds together so no commit is red. *Done that way.*
- Bundled-data test: no table overrides a type; `northern_bc.rds` tables lack `anomaly_type` and must stay excluded — comment it. *Fix.*
- **S1** other "recent decade" wording (vignettes, cd_plot_comparison) — out of the decided scope.
- **S2** NEWS: raw swe_max series lose the "mm" unit via meta_resolve(raw = TRUE), like swe; anomalies now % capped ±200. *Into the PR body for /gh-pr-merge.*
- **AC1** render against current source (`pkgdown::build_article()` or install first).
