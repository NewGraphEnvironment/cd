# Review: Phase 2, round 1 (#123): cd_extract_daily() off-grid points

## Clean

No real issues found in the unstaged diff (R/cd_extract_daily.R, man/cd_extract_daily.Rd,
tests/testthat/test-cd_extract_daily.R, tests/testthat/test-cd_extract_daily_live.R).

### What was checked

- `devtools::test(filter = "cd_extract_daily$")`: FAIL 0 | PASS 75.
- Edges: `terra::cellFromXY()` on the fixture puts xmax (-123.4) and ymin (53.8) inside,
  in the last column and the bottom row. So a point exactly on the right or bottom edge
  gets a real cell, not NA. Same as before the diff; no new abort or NA.
- Inf/-Inf coordinates: `cellFromXY` gives NA. Such a point gets NA rows and is named in
  the extent warning. NA/NaN coordinates still abort in `daily_points()` (`anyNA`).
- Every point outside (single integer id, a range spanning two years, all three
  variables): it returns 12 rows, all NA. `cell` is integer, `cell_x`/`cell_y` are
  NA_real_ (not NaN), `cell_moved` is FALSE, and the rows are ordered by point,
  variable, then date.
- Mixed calls (outside + inside, factor ids, a projected sf in EPSG:3005): the inside
  points keep their correct values and cells, and the outside point is named.
- An outside point plus a stranded sea point: two separate warnings, and the sea point
  keeps its own cell (8). Covered by the new test.
- Warning text with real-world extents: `format(round(v, 4))` turns -140.0500000000082
  etc. into "-140.05", "-113.95", "47.95", "60.05".
- Mutation proofs in a copy (`$TMPDIR/.../cdcopy`). Each guard was reverted on its own,
  and each revert reddens 2 tests:
  - M1: the `length(ucell) > 0L` guard around `terra::extract`
  - M2: the NA `centre` matrix, reverted to `xyFromCell(template, cell)`, which gives NaN
  - M3: the `length(inside) > 0L` guard on `dry`
- No other caller of `daily_cells()`, and no other reference to the old message text.

Not findings (stated by the caller): the live 60 N test fails until the rebuilt cube is
published. All-off-grid calls still download every file.
