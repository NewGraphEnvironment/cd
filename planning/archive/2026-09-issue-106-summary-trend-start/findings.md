# Findings — cd_summary(): trends from several trend_start values differ only by Years (#106)

## Issue context

**If we do it:** a `cd_summary()` table over `cd_trend(x, trend_start = c(1951, 1981))` says which row is which window. **If we never do:** two rows read `Mean temperature / Annual` with different slopes, told apart only by `Years`, which a reader has to subtract from the current year to decode.

## Problem

`cd_trend()` accepts several `trend_start` values (`R/cd_trend.R`), and `cd_summary()` drops `trend_start`. The rows keep `Years` (`n_years`), which varies with the start, but nothing names the window. Same family as #98: #98 kept stations apart (` (variable)` suffix) and raw vs anomaly trends apart (a conditional `Trend on` column).

## Proposed Solution

Carry the start the way #98 carries the scale: a `Start` (or `Window`) column added only when the table holds more than one `trend_start`, so single-window tables keep their shape.

Found by the plan review for #98.

## Exploration (2026-09-30)

- Both vignettes render `cd_summary(trn)` over `cd_trend(ano, trend_start = c(1951, 1981))` (`peace-fwcp.Rmd:226`, `kootenay-lake.Rmd:234`) — the defect is live on the published site; the fix changes those tables (gains `Start`).
- `col_or_na()` (`R/cd_anomaly.R:136`) returns character; use it for detection only, copy values from `trend$trend_start`.
- Example data (`example_catalog.json` + `example_aoi.gpkg`): tmean only, years 1951–1960.

## Errors Encountered

| Error | Resolution |
|-------|------------|

## Plan review (Plan agent, 2026-09-30) — no blockers

Folded in: roxygen now says `Start` is the *requested* start year (not first data year) and is decided over the whole table (a 1991 trend of one station bound to a 2000 trend of another gains `Start`); grouped input with several starts tested.

Not acted on, with reasons:
- Factor/character `trend_start` is copied unchanged, so per-region summaries with mixed types fail in `bind_rows`. `cd_trend()` always emits numeric; a hand-built factor start is out of contract.
- Rows still collide for anomaly runs against different baselines (baseline not stored), for tables bound across AOIs before summarising, and for periods differing only in case. None is a `trend_start` problem.
- `cd_trend()` returning a 0x0 tibble breaks `cd_summary()` — already filed as #101.
- Vignette tables list all 1951 rows then all 1981 rows (grid order), so comparing windows means scrolling 59 rows. Handled in Phase 3 (hidden chunk only).

Pre-existing, not touched: 6 test warnings in `test-cd_plot_comparison.R` ("row names were found from a short variable"); `pkgdown::check_pkgdown()` aborts on main too (DESCRIPTION URL lacks the github.io url — custom domain); `object_usage_linter` flags `col_or_na` in `R/cd_summary.R` on main's line too.
