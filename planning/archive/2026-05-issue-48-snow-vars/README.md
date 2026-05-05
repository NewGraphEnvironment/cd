# Archive: Snow-related variables for hydrology departure (#48)

## Outcome

Added 8 snow-related variables to the cd package — the **v0.2.0
release**, the snow chapter the package was missing for hydrology
reporting in the FWCP Peace context.

  * 4 monthly natives: `swe`, `snowfall`, `snowmelt`, `snow_cover`
  * 4 annual derived: `swe_max`, `snowfall_fraction`,
    `snowmelt_doy_50`, `snowmelt_rate_peak`

Single hourly EDH fetch on the producer side covers both layers.
24 new multi-year COGs on `s3://stac-era5-land`; catalog now serves
59 items. New `pct_point_diff` anomaly type in `cd_anomaly()` for
`snow_cover` and `snowfall_fraction` (already-percentage variables
where percentage-of-baseline is meaningless).

## Headline scientific findings (Peace Region)

  1. Annual SWE down ~10% (135 → 122 mm); **summer SWE collapsed
     by 75%** (21.5 → 5.3 mm); spring snowmelt rose 37%; annual
     snowfall roughly flat (-6%). The story is about *timing*,
     not *quantity*.
  2. Freshet-timing shift is uniform across all 5 ecoregions —
     ~1 day/decade earlier melt, p < 0.01 in every ecoregion.
     Peak SWE shows in regional aggregate but washes out at
     ecoregion scale due to inter-annual variability.
  3. ASWS QA at 4 BC sites: bias direction varies (Pine Pass -61%,
     Aiken Lake +54%) but is stable over time at every site
     (p > 0.2 everywhere). Trend defensibility holds.

## Key methodological findings worth remembering

  * **`cd_trend()` raw Mann-Kendall + Theil-Sen (no prewhitening) is
    methodologically correct** for our 76-year series with strong
    trends per Yue and Wang 2002. Prewhitening would
    underestimate slope when a real trend exists.
  * **`snowmelt_rate_peak` (annual max of 7-day rolling daily smlt)
    is novel** — closest precedent is streamflow-based freshet
    flashiness, ours is upstream of that on the snowmelt flux
    directly. Documented as deviation from literature canon in the
    vignette.
  * **ERA5-Land snow bias has two components**: scale mismatch
    (point vs 80 km² cell average) AND cell-mean bias (Kouki 2023
    NH-wide). Our QA at 4 points sees both stacked and can't
    fully separate them. Pine Pass underestimate is mostly scale
    mismatch (high-snow microsite); Aiken Lake overestimate is a
    mix.
  * **`snow_depth` was renamed to `swe`** during registry design —
    `sde × rsn` evaluates to mm SWE not vertical snow depth. The
    original name was a unit mismatch.
  * **`cd_stac_item()` substring-match bug fix**: `grepl(v, name_parts)`
    was mis-routing `swe_max_annual.tif` under `swe`. Replaced
    with strict `{var}_{period}` exact-match. Latent bug — only
    surfaced when registry got vars whose names were substrings
    of other vars.

## Per-FWCP-Peace context worth remembering for future work

  * **No anadromous salmon in FWCP Peace** — Bennett Dam blocks
    salmon access to the Williston watershed. FWCP supports
    resident salmonids only (bull trout, Arctic grayling, mountain
    whitefish, rainbow trout, kokanee). Vignette text and any
    future ecological framing should not invoke salmon migrations.
  * The Fraser comparison (Kang et al. 2016) is valid for snow-trend
    *magnitude* even though Fraser is anadromous — but the framing
    has to focus on freshet hydrology, not salmon-life-history
    impact.

## Reproducing the rag store / methodology citations

Citations come from the companion #53 archive (snow methodology lit
review, merged as v0.1.7). 11 papers in `NewGraphEnvironment/hydrology`
Zotero collection (X29BX4U8). `vignettes/references.bib` was generated
once via `rbbt::bbt_write_bib()` and committed; vignette renders on
CI without needing Zotero/BBT live.

## Closing ref

  * Issue: NewGraphEnvironment/cd#48
  * PR: NewGraphEnvironment/cd#55 (merged 2026-05-04, squash 81d96bf)
  * Companion lit review: NewGraphEnvironment/cd#53 / #54 (v0.1.7)
  * Followup decision: NewGraphEnvironment/cd#49 (KOTL — drop or
    repurpose for snow story now that snow lives in peace-fwcp)
