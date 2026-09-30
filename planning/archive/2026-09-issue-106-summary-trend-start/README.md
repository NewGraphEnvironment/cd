## Outcome

`cd_summary()` now names the trend window (#106). A trend table holding more than one `trend_start`, such as `cd_trend(x, trend_start = c(1951, 1981))`, gains a `Start` column holding the start year asked of `cd_trend()`. It follows `Period`, or `Trend on` when that is present. The rule is the one #98 used for `Trend on`: the column is decided over the whole table, and only when the table needs it, so single-window tables keep their shape. Both vignettes had shown this defect on the published site: their trend tables gave 59 pairs of rows that differed only by `Years`. They now carry `Start`, and the hidden `trend-table` chunk orders rows so each 1951/1981 pair sits together. The plan review and three code-check rounds (vignettes and docs, then an adversarial search for row collisions) found no defects. The review's scope notes are in `findings.md`. They include rows that still collide for reasons outside this issue (baselines not stored, AOIs bound before summarising) and the pre-existing 0x0 `cd_trend()` failure, which was already filed as #101.

## Measurement

On the committed vignette data (`inst/vignette-data/{peace_fwcp,kootenay_lake}.rds`), each summary has 118 rows. Before the change, 59 of those rows duplicated another row on `Parameter`/`Period`. After it, 0 duplicate on `Parameter`/`Period`/`Start`. Final suite: 410 pass, 0 fail.

## Evidence

`review-round*.md` in this directory.

Closed by: PR (see `gh pr list --search 106`)
