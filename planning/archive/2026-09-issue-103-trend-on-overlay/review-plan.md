# Plan review — #103 (Plan agent, 2026-09-29; relayed and triaged by the parent session)

No blockers. Probes: factor / grouped / logical-NA `trend_on` all filter correctly via `col_or_na()`;
0x0 trend unchanged; `val_col` rule is shared with `cd_trend()` so both-columns frames agree.

| # | Category | Finding | Disposition |
|---|----------|---------|-------------|
| 1 | Gap | Behaviour changes need a NEWS line | PR body lists them; `/gh-pr-merge` writes NEWS |
| 2 | Gap | Trend entirely on the other scale is now dropped silently | Fix: warn when rows match variable/period but none match `trend_on` |
| 2b | Gap | Trend missing `variable`/`period` column: old tibble error, now silent no-op | Accepted — a data.frame was already silent before; not a `cd_trend()` shape |
| 3 | Gap | No test for `which()` | Already added (NA-variable test; mutation FAIL 1) |
| 4 | Scope | Line style follows row order, not `trend_start`; captions say dashed = 1951 | Fix: order rows by `trend_start` before the loop (issue names row-order styling) |
| 5 | Acceptance | NA `trend_on` means "either scale" here, "anomaly" in `cd_summary()` | Fix: say so in roxygen |
| 6 | Ordering | Red run not recorded | Recorded in progress.md (FAIL 5 against unfixed code) |
| 7 | Acceptance | Mixed legacy (no `trend_on`) + new table still mixes scales | Inherent — no marker to filter on; PR body says so |
| 8 | Scope | Other trend consumers (vignettes, cd_summary) unaffected | Noted |
| 9 | Minor | Comment "predates #97" — also hand-built tables | Fix wording |
