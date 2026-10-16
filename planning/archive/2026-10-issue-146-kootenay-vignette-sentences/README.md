## Outcome

The Kootenay Lake article had sentences it inherited from the Peace template that its own data contradicts. Soil moisture was called flat, and it is declining. The warming range left out PTR. "Three findings" introduced four. The watershed groups were said to share one drying signal, and only KOTL's is significant. The prose counted four ecoregions where the article draws three. Each is rewritten: its numbers are computed inline from the bundled rds, and the words around them ("significant", "every", "only KOTL", "about a quarter") are asserted by the `claims` block in `data-raw/kootenay_lake_vignette_data.R`, so a regen that falsifies one stops before it saves. Kootenay's ecoregion filter moved to Peace's 100 km². That draws the same three ecoregions, gives both articles one rule, and the claims check the prose states it. A sweep and the plan review found more inherited or wrong text: the seasonal snow caption still carried Peace's −75 % / +37 %, the temperature range said 1.8 where the data says 1.7, and "weeks earlier" was 12.6 days. Peace's own "cumulative since 1951" mislabel was reproduced and filed as #148. The lesson came from code-check, four rounds and each finding its defects inside the previous fix. A claim tested a proxy for its sentence: first significance without the sign, then rank without the sign, then loose number-word bounds, then the raw value where the page prints a rounded one. A raw p of 0.0496 passes `< 0.05` and prints "0.050" beside "significant". What ended it was making the rule structural (helpers named for the Rmd's print formats) and checking all 23 claims, parsed from the script, against it.

## Measurement

- Measured against the committed `kootenay_lake.rds` (v0.6.10 data). Soil moisture: regional trend p 0.040 (from 1951) and 0.0037 (from 1981); window −2.1 %, window p 0.062.
- Ecoregion tmean window Δ: NCM 1.60, SBF 1.88, PTR 1.49 °C (TOP 1.71, not shown); rates 0.23–0.30 °C/decade.
- WSG prcp trend p from 1951: KOTL 0.015, DUNC 0.094, LARL 0.054, SLOC 0.051.
- Seasonal snow: summer SWE −72.9 %, summer snowmelt −60.9 %, spring snowmelt +12.1 %, winter snowmelt +138 %.
- Offline claims harness: the claims block evaluated against the rds with in-memory perturbations. 43 perturbations; 40 fire on the claim they target; 3 pass correctly (TOP is not shown; SBF and SLOC p near 0.05 print 0.050, which reads not significant). Setting the filter back to 50 against prose saying 100 fires `prose_states_filter`.
- Tests: `devtools::test()` FAIL 0, PASS 768. Both changed articles render with the branch installed.

Review: plan review (`review-plan.md`, 3 blockers adopted); `/code-check branch` 4 rounds (`review-round{1,2,3,4}.md`), ended by enumerating all 23 claims against the printed-value rule (`findings.md`).

Closed by: PR (see `/gh-pr-push`)
