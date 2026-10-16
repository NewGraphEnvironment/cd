# Code-check round 2: #146 branch (d4fcda8)

Reviewer: round 2, over `main...HEAD`. Method: ran the claims block offline on the
committed rds (all 18 claims TRUE), computed every inline expression the diff adds
(rendered values below), and mutated the inputs in a scratch session (the repo was
not edited) to test whether the new direction checks fire.

## Findings

- **[fragile]** data-raw/kootenay_lake_vignette_data.R:222 — `snow_summer_largest_losses`
  checks only which two rows sort lowest. It never checks that they are negative. The
  caption (vignettes/kootenay-lake.Rmd:470) says they "carry the largest losses". This is
  the same gap round 1 fixed elsewhere, a direction word with no sign check. Mutation:
  adding +200 to every seasonal snow pct (so no season lost snow, order unchanged)
  leaves the claim TRUE and `all(claims %in% TRUE)` TRUE. Fix: also require
  `all(snow_season_pct[c("swe summer", "snowmelt summer")] < 0)`.

- **[fragile]** vignettes/kootenay-lake.Rmd:1014-1016 vs data-raw/kootenay_lake_vignette_data.R:201
  — "The three ecoregions shown were between `r rng(er_num$delta, ...)` °C **warmer** in
  2015–2025 than in 1951–1980" is a window difference (`cd_compare` on each ecoregion's
  `ts`). No claim reads a per-ecoregion window difference: `temperature_p_below_0.001_every_shown`
  checks the 1951 trend slopes and p-values only. The regional twin of this sentence got
  `all(temp_window$difference > 0)` in d4fcda8, but this one did not. Mutation: lowering
  NCM's 2015+ annual tmean by 3 °C gives a window difference of -1.40 and every claim
  still TRUE. A negative value would show in the rendered range, so this is a gap in the
  guard, not a false page today. Fix: add a claim that each shown ecoregion's annual
  tmean `cd_compare()` difference is > 0, or compute it in the script beside `er_p`.

Everything else checks out:
- Each new claim reads the right table, column, period and trend_start: `sm51`/`sm81` from
  the regional trn (1951/1981); the window p from regional `cmp`, which equals the
  vignette's recomputed `sm_cmp` (0.0617); the soil pct from `cmp_pct` (-2.13, same sign
  as the vignette's `sm_pct`); temperature window and 1951 trend; ecoregion 1981 soil
  p and slope over `shown`; WSG 1951 prcp. Every NA path fails closed.
- Rendered values: temp "1.6 and 1.7"; soil "down 2.1 %, p ≈ 0.062, trend p ≈ 0.04 /
  0.0037"; ecoregion rates "+0.23 and +0.30", deltas "1.5 and 1.9", prcp "6.4 and 7.0";
  KOTL "0.015", others "0.051 and 0.094"; snow caption -73 / -61 / +138 / +12. Each
  matches the rds and the static words around it.
- "Four findings" is right in both articles (four bold findings in each Interpretation).
  "nearly two weeks" matches 12.6 days, and "about a quarter" matches summer SWE at 27 %
  of the reference. TOP (26 km²) is under one ~80 km² cell, and the overlap table lists it.
