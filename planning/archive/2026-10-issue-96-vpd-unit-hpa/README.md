## Outcome

`cd_variables()` now gives `vpd` the unit `"hPa"`. It said `"Pa"`, but `cd_derive_vpd()` and the EDH backfiller have always produced hPa (Tetens), so every vpd `Unit` in `cd_anomaly()`, `cd_trend()`, `cd_summary()` and the `cd_plot_timeseries()` axis was off by 100×. Fixing the registry was one string; the real work was the **written data**. A carried `unit` column wins over the registry in `meta_resolve()`, so both vignettes' precomputed `ano`/`trn` tables would have kept printing "Pa". By user decision they were relabelled in place by `data-raw/vignette_data_vpd_unit_patch.R` rather than regenerated from S3. The regen is still owed for #123's grid and #126's columns. A new test holds every unit in the bundled vignette data to the registry. The plan review then found the same baked-in "Pa" in three downstream reporting repos' saved tables and a hard-coded lookup in a fourth; issues were filed there. It also found that a saved "Pa" table bound to new "hPa" output now aborts in `meta_check()`, so the NEWS line says how to relabel. The lesson from review: a sentence about what a script does can depend on **which copy of the package runs**. `library(cd)` gives the installed copy in a fresh session but the source tree after `load_all()`. Code-check round 2 caught the first wrong claim, and round 3 caught the fix's wrong claim. The loop ended by enumerating all 26 added prose lines.

## Measurement

- Relabelled vpd rows: 3510 in `kootenay_lake.rds` (9 AOIs × 390: 380 `ano` + 10 `trn`) and 2340 in `peace_fwcp.rds` (6 × 390). An independent element-wise diff against the pre-patch blobs showed that only those `unit` cells changed, and each patched file reverses to an `identical()` copy of the original.
- The downstream saved tables still carrying "Pa": fraser 3420 vpd rows, skeena 2660, peace 2280 (2025 reporting repos).
- Agreement test: it fails 18 expectations on the pre-patch `kootenay_lake.rds` and passes on the patched one. Local `devtools::check()`: 0 errors, 0 warnings, 1 note (a local `.ruff_cache` directory).

Review: plan review (`review-plan.md`, 7 findings, no blockers); `/code-check branch` 3 rounds (`review-round{1,2,3}.md`), ended by enumeration.

Closed by: PR (see `/gh-pr-push`), commits 29fb834, 80620d3, 183be9f
