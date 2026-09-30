## Outcome

`cd_trend()` dropped every combination with fewer than 3 years and returned
`bind_rows()` of all-`NULL`, a 0 x 0 tibble, so `cd_summary()` died on
`Column 'period' not found` and `cd_plot_timeseries()` warned about uninitialised
columns. Rows are now bound under a zero-row template, so an empty trend carries every
column and flows through both consumers unchanged. The first version of the template
restated column types independently of the row builder, and the plan review and
code-check round 1 both caught what that cost: a factor `variable`/`period` came back
character on *every* result, and `trend_start = NULL` dropped its column. The key
columns now take their types from the same `combos` the rows are built from, and
`slope`/`intercept` are unnamed so empty and full results share one ptype. Round 3
enumerated all 11 template columns against the row builder and found them in agreement.
The existing test for short series asserted only `nrow == 0`, which the 0 x 0 satisfied,
which is why this was never caught. Each new guard was shown to fail against its own
restored defect.

Closed by: commit 8892556 / PR (see branch `101-cd-trend-no-series-long-enough-gives-a-0`)
