# Review: Phase 2, round 3 (#123): cd_extract_daily() off-grid points

## Clean

No bugs, security issues or data-loss paths. Mechanism reviewed: an abort became a value
(NA rows plus a warning), so every reader of the output and of the old error contract was
enumerated, and every place an NA cell could reach terra or an integer coercion was traced.

`devtools::test(filter = "cd_extract_daily$")`: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 75 ]`.

## Consumers of the output and of the error/warning contract (this repo)

Found by `grep -rn "extract_daily|daily_cells|daily_read|Outside the daily"` over R/, tests/,
vignettes/, data-raw/, scripts/, inst/ (planning/ and docs/ excluded).

| site | reads what | handles NA rows? | OK? |
|---|---|---|---|
| `R/cd_extract_daily.R` roxygen example (l.71-87) | `value` by `id`, `tapply(pmax(value - 5, 0), id, sum)` | both points are inside the bundled 5 x 5 crop, so no NA rows arise; an outside point would give `NA` for its sum (correct propagation, not a wrong number) | yes |
| `tests/testthat/test-cd_extract_daily.R` (all blocks) | shape, values, cell columns, warnings | the old "aborts naming it" test is replaced; three new blocks pin NA values, NA cell/cell_x/cell_y (NA, not NaN), FALSE cell_moved, integer `cell` type, input order, warning count | yes |
| `tests/testthat/test-cd_extract_daily_live.R` | `anyNA(value)`, `cell_y`, `expect_no_warning` | asserts no NA and no warning, i.e. it now fails loudly (as a warning + NA) rather than via abort if 10DA001 is outside; fails until the rebuilt cube is published (accepted) | yes |
| `tests/testthat/helper-daily.R` | builds fixture only | n/a | yes |
| `data-raw/example_daily.R` | producer of the example crop, not a caller | n/a | yes |
| `scripts/backfill_edh_daily.py:31` | comment only | n/a | yes |
| `R/cd_variables.R:12`, `NEWS.md`, `CLAUDE.md`, `research/` | prose mentions | n/a | yes |
| vignettes, `inst/`, other `R/` functions, `scripts/*.R` | no call to `cd_extract_daily()` / `daily_cells()` | n/a | yes |
| text "Outside the daily cube's extent" | no other matcher in the repo (wet#40's retry is external, accepted) | n/a | yes |

## NA cell reaching terra or a coercion in R/cd_extract_daily.R

| site | can an NA cell reach it? | result |
|---|---|---|
| `has_data(cell[inside])` l.290 | no: `inside <- which(!outside)` | OK |
| `terra::adjacent(template, cell[i])` l.292 | no: loop is over `dry`, a subset of `inside` | OK |
| `has_data(nb)` l.294 | no: `nb[!is.na(nb)]` first | OK |
| `terra::xyFromCell(template, nb)` l.300 | no: `nb` filtered | OK |
| `terra::xyFromCell(template, cell[inside])` l.314 | no; outside rows stay `NA_real_` (not NaN) | OK |
| `as.integer(cell)` l.317 | NA double -> `NA_integer_`; cell numbers are small (< 2^31) | OK |
| `ucell <- sort(unique(cells$cell))` l.128 | `sort()` drops NA | OK |
| `terra::extract(r, ucell)` l.154 | no: NA dropped; empty `ucell` guarded with a 0-row matrix | OK |
| `match(cells$cell, ucell)` l.159 | NA matches nothing since `ucell` has no NA (the `match(NA, ...)` trap does not apply) | NA row index -> NA values |
| `vals[rows, , drop = FALSE]` l.165 | NA integer index on a 0-row or n-row matrix gives an all-NA row | OK |

## Probes run (read-only, `load_all` + fixture in tempdir)

- Moved + stranded + two outside points (one at exactly xmax = -123.4 and above ymax),
  two variables across the 2003/2004 boundary: moved point reads cell 16 correctly, sea point
  keeps cell 8 with NA values, both outside points get NA cell/x/y/value and FALSE
  cell_moved; exactly two warnings, outside one lists `far, far2`.
- Single outside point with a factor id, one day: three NA rows, `cell` integer, id kept as factor.

## Observations, not findings

- The roxygen text states the cube box as 47.95-60.05 N; that is true only once the
  rebuilt cube (Phase 1) is published, same accepted tradeoff as the live 10DA001 test.
