# Task: Kootenay vignette: five sentences inherited from Peace contradict the Kootenay data (#146)

The Kootenay Lake vignette was templated from the Peace one, and several sentences that are true for Peace are false for Kootenay. Goal: every sentence in the Kootenay Lake article agrees with the numbers it renders.

## Plan context

`vignettes/kootenay-lake.Rmd` was templated from Peace and keeps sentences that are false for
Kootenay. Re-measured today against the committed `inst/vignette-data/kootenay_lake.rds`; every
number in the issue holds:

| item | sentence | data |
|---|---|---|
| 1 soil | `:273` "roughly flat", `:992` "essentially flat … keeps the topsoil roughly even" | regional trend −0.029 %/yr p 0.040 (1951), p 0.004 (1981); window Δ −2.1 %, window p 0.062; 1981 trend significant in all four ecoregions (0.002–0.020) |
| 2 range | `:964` "between +1.6 °C and +1.9 °C" | window Δ NCM 1.60, SBF 1.88, PTR 1.49 (TOP 1.71, not shown); slopes 0.23–0.30 °C/dec, all p < 0.001 |
| 3 count | `:962` "Three findings" (and `peace-fwcp.Rmd:854`) | four bold findings follow in each |
| 4 WSG | `:976-979` "all four … same drying signal" | all four 1951 prcp slopes negative; only KOTL significant (p 0.015); DUNC 0.094, LARL 0.054, SLOC 0.051 |
| 5 four vs three | `:614`, `:964`, `:976` say four ecoregions | the article shows three (TOP is 26 km², filtered at `:98`) |

Ecoregion areas: Kootenay TOP 26, PTR 495, SBF 4201, NCM 19445 km²; Peace's smallest kept is
9,110, PRB (66) dropped at its 100 km² filter.

**Threshold decision (recommended):** both articles use **100 km²**. For Kootenay that changes
nothing drawn (TOP is out at 50 and at 100, PTR is in at both), so it costs one line and gives the
two articles, and the appendices ported from them, one rule. The data script reads the threshold
from the vignette (`vignette_min_km2()`), so its `shown_are_ncm_sbf_ptr` claim keeps guarding it.

**Approach:** numbers in the rewritten sentences are computed inline from `vignette_data` (as
`northern-bc.Rmd` does); the qualitative words they carry ("significant", "only KOTL", "every
ecoregion") are added to the existing `claims` block in `data-raw/kootenay_lake_vignette_data.R`
(#102's pattern), so a regen that falsifies one stops. No rds regen, no change under `R/`.

## Phase 1: One area threshold, three ecoregions in the prose (item 5)
- [x] `kootenay-lake.Rmd:98` filter 50 → 100 km², matching `peace-fwcp.Rmd:92`
- [x] Per-Ecoregion intro (`:603-611`): state the 100 km² rule once where TOP is named
- [x] `:614`, `:964`, `:976` "four ecoregions" → the three shown (`:886`, the overlap table intro, stays four: that table shows four)

## Phase 2: Soil moisture is declining, not flat (item 1)
- [x] `:273` rewrite from inline values: window Δ % and window p from `cmp_pct`/`cmp`, 1951 and 1981 trend p from `trn`
- [x] `:992-996` rewrite: drop the unsupported "keeps the topsoil roughly even … shows up in baseflow" mechanism; state the decline with inline numbers
- [x] `claims`: regional soil_moisture slope < 0 and p < 0.05 for both starts; window p ≥ 0.05 (if the sentence says the window test misses it); 1981 trend p < 0.05 in every shown ecoregion

## Phase 3: Warming range and rate from the shown ecoregions (item 2)
- [x] `:964-966` range of window differences and range of °C/decade slopes computed inline over the shown ecoregions
- [x] `:614` "roughly the same rate" carries the same inline slope range
- [x] `claims`: tmean 1951 trend p < 0.001 in every shown ecoregion

## Phase 4: Findings count (item 3)
- [x] `kootenay-lake.Rmd:962` and `peace-fwcp.Rmd:854` "Three findings" → "Four findings"

## Phase 5: WSG drying is consistent in direction, not strength (item 4)
- [x] `:976-979` rewrite: all four WSGs trend down since 1951; significant only in the WSG(s) computed inline from `vignette_data$wsg`, with the others' p range
- [x] `claims`: every WSG 1951 prcp slope < 0; significant set is exactly KOTL (the sentence names it)

## Phase 6: Sweep the article's remaining quantified sentences
- [ ] Walk every "all / every / each / both / none / no" and stated number in the Kootenay prose and captions (grep list in findings.md) against the rds; record a verdict per sentence in findings.md
- [ ] Fix any found false, with inline numbers or a `claims` entry, same pattern as above

## Validation

- [x] Offline claims harness passes on the committed rds, and each new claim fires when its input is perturbed
- [ ] Branch installed; both changed articles render; rewritten sentences present in the HTML with no `NA`
- [ ] Tests pass
- [ ] `/code-check` clean (once over the branch with `/code-check branch`)
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
