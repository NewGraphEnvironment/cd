# Code-check Phase 2, round 2 (#123)

## Clean

No bugs, security issues or data-loss paths in the Phase 2 diff (`R/cd_extract_daily.R`, `man/cd_extract_daily.Rd`, both test files).
`devtools::test(filter = "cd_extract_daily$")`: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 75 ]`.

What was checked, beyond round 1:

- **NA rows through the extract loop.** `sort(unique())` drops the NA and `match(NA, ucell)` is NA, because `ucell` holds no NA. That makes `vals[rows, , drop = FALSE]` an NA row. The all-outside path was probed directly: `matrix(NA_real_, 0, 3)[c(NA, NA), , drop = FALSE]` returns a 2 x 3 NA matrix, so `t()`/`as.numeric()` give the right length. `keep` cannot be empty, because `years` comes from `from`/`to`.
- **compareGeom across years.** This is unchanged, and it still runs when every point is outside. A year on another grid aborts loudly. An outside point cannot get past it to read a wrong cell, because `cell` is fixed against the template.
- **`cache = FALSE` / `/vsicurl/`.** `has_data()` still extracts only the cells in question, and now only for `inside`. `terra::ext(template)` reads the header only, so it adds no reads.
- **`cache = TRUE` after the rebuild.** `cd_cache_fetch()` revalidates by ETag, so cached 120 x 260 files are replaced on the next call. A user who set `cd.cache_revalidate = FALSE` (or is offline) keeps the old grid. One year then gives the "outside" warning with the old extent printed. Mixed years hit the compareGeom abort. Both are loud, not silent. A NEWS line like 0.6.1's `cd_cache_clear()` advice would help (release bookkeeping, not a code defect).
- **Docs.** The `@return` and Cell choice text match the behaviour: NA `cell`/`cell_x`/`cell_y`, `cell_moved = FALSE`, other points unaffected. The stated 47.95–60.05 N / 140.05–113.95 W is true only once Phase 4 publishes. It ships in the same PR, so this is accepted.
- **Live test.**
  - `skip_on_ci()` + `skip_on_cran()` + `skip_if_offline(host =)` match the existing live test, and curl is in Imports.
  - `expect_no_warning(d <- ...)` evaluates its quosure in the test env, so `d` is assigned. testthat 3e is the mode already used in `test-cd_plot_timeseries.R:242`.
  - `cache = FALSE` needs no cache-dir isolation.
  - It fails until the rebuilt cube is published (accepted).

## Notes (not defects in this diff)

1. **Downstream wet behaviour change.** `wet/scripts/temp_fill_validate.R:38-51` (`wet_air_inside()`) catches only `error =` and regex-parses the abort to drop stations and retry. With this diff no error is raised, so the loop returns `p` unchanged. The warning surfaces at top level, and the outside stations go into `air_2002_2025.rds` as all-NA rows. Nothing in wet goes wrong silently. `wet_fill_prepare()` drops `NA` air rows (`wet_temp_fill.R:234`), and `score_one()` returns NULL for a station not in `fit_st`. The validate report's station and truth-year counts would include such stations, though. After the 121 x 261 rebuild 10DA001 is inside, so this probably affects nobody. The wet loop and its comment ("one point outside it aborts the call") are now dead or stale. NEWS should say the error became a warning plus NA rows, for any caller that catches the error.
2. **Phase 4 read-back (future work, not this diff).** `cd_s3_push()` is `--size-only`. A size read-back compares local to remote, so it passes even for a file the sync skipped because its old size happened to match. Only the extent check discriminates. Check the extent on all 228 files rather than a sample: it is a header read each. Also run that check, and the live 10DA001 checks, in a fresh R process. GDAL's `/vsicurl/` cache would otherwise serve a header read earlier in the session (CLAUDE.md, #119).
