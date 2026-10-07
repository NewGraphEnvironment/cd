# Review round 1: Phase 1 (#89), `cog_expected()` / `publish_problems()`

## Findings

- **[severity: fragile]** scripts/_lib.R:101-114 (`publish_problems`): the guard never checks
  that every expected COG is actually in `on_disk`, and `on_disk` is what gets published.
  The checks are expected ⊆ written, written ⊆ expected, and on_disk ⊆ written. Together
  they prove `written == expected` and `on_disk ⊆ expected`, but not `on_disk ⊇ expected`.
  `cd_stac_catalog()` builds the catalog from `list.files(cog_dir, "\\.tif$")`, and the helper's
  own doc comment calls that "what cd_stac_catalog() will list", so a COG recorded in `written`
  but missing from the directory still gets a short catalog published. That is the #89 failure,
  reached through the proxy (`written`) instead of the property (the directory). Reproduced:

  ```r
  e <- cog_expected(c(a="mean", b="sum"), list(winter = c(12,1,2)), "x")
  w <- setNames(rep(list(as.character(2000:2002)), length(e)), e)
  publish_problems(w, e, on_disk = e[-1], live_keys = sub(".tif$", "", e),
                   required_years = 2000:2002)
  #> character(0)        # publish allowed with one COG absent from cog_dir
  ```

  Phase 2 creates exactly this risk: `append_to_cog()` will record `written[[cog_name]]`, and it
  only takes one bad line to record it before `cd_cog_write()`, under the wrong name, or against
  a different directory, and the guard passes. The fix is one more branch:
  `setdiff(expected, on_disk)`. Equivalently, require `setequal(on_disk, expected)`.

## Checked and not a problem

- Contract fits both callers. The live catalog (fetched 2026-10-07) has 59 items, and every one
  spans `1950-01-01` to `2025-12-31`, including the tmax/tmin items republished in #37. So "one
  span across all 59" holds for the live data, and the update pipeline's `existing + new`
  COGs will share a span. Live period names are `annual/winter/spring/summer/fall`, which match
  `names(cd_seasons())`, so `live_keys` and `cog_expected()` share a vocabulary in both scripts.
- `identical(yrs, seq(min(yrs), max(yrs)))` compares like types: integer `from`/`to` give an
  integer `seq`, and `as.integer()` drops attributes. Duplicate band years (e.g. a year appended
  twice) also fail it, which is the right result.
- Non-integer or `NA` values in `required_years` show up as `short` and refuse.
- The `paste0()` zero-length trap in `cog_expected()`: `annual_vars = character(0)` yields a
  phantom `"_annual.tif"`. It can never be written, so this fails toward refusal. Both callers
  hardcode four vars, so it is not live.
- `required_years = integer(0)` passes the required-years check vacuously. Neither planned caller
  can produce it: the update pipeline's live years come from a COG with ≥1 band, and stage 3
  stops if it cannot read the live COG.
- When spans differ, the required-years check is skipped, but by then the guard has already
  refused.
- Tests: `Rscript scripts/test_lib.R` gives 43/43.

## Note (not a defect)

The fixture `seas` in scripts/test_lib.R uses `DJF/MAM/JJA/SON`, and findings.md says "DJF".
Production `cd_seasons()` is `winter/spring/summer/fall`. The count (59) and the logic do not
depend on the names, so nothing breaks. But the test comment calls the fixture "the production
config, restated", which is not quite true.
