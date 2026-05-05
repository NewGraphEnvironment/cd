# Task: Add snow-related variables for hydrology departure (#48)

## Problem

Climate departure analysis in `cd` covers seven variables today
(tmean, tmax, tmin, prcp, vpd, rh, soil_moisture) but none of the
snow / precipitation-phase variables that drive hydrology. For fish
passage and aquatic restoration reporting in northern BC, the
questions that matter are: rain vs snow ratio, freshet timing,
freshet flashiness, peak snowpack, and when snow accumulates /
melts. The climate-departure framing is the right tool for each.

Two architectural facts pinned during plan-mode exploration:

- **Snow vars are hourly-only on EDH** — daily UTC product has zero
  snow vars. Hourly product has all four targets (`sf`, `smlt`,
  `sde`, `rsn`) plus `snowc` (cover fraction) which we're including.
- **`sf` and `smlt` are `stepType=accum`** — daily total = value at
  00:00 UTC of next day. We have to write the accum handling
  ourselves; no daily-product fallback like `tp` had in #36.

Scope: 8 new variables in two layers.

| Layer | Vars | Schema | What it shows |
|---|---|---|---|
| Monthly natives | `snow_depth`, `snowfall`, `snowmelt`, `snow_cover` | 12-band/year COG | seasonal curve — when snow accumulates and melts |
| Annual derived | `swe_max`, `snowfall_fraction`, `snowmelt_doy_50`, `snowmelt_rate_peak` | 1-band/year COG | climate-departure signals — peak SWE, freshet timing, flashiness |

Single hourly fetch on producer side covers both layers. QA via ASWS
automated snow pillows (primary, daily resolution) + manual snow
surveys (secondary, monthly Jan–Jun, longer records), both via the
`bcgov/bcsnowdata` R package, at five Peace-region sites.

Target release: **v0.2.0** (minor bump — new variables and a new
`pct_point_diff` anomaly type, no breaking changes).

## Phase 1 — Producer: snow backfill script with hourly accum handling

- [x] Implement hourly-to-daily accum reduction in
      `scripts/backfill_edh_snow.py` via `hourly_accum_to_daily()`:
      select 00:00 UTC values, shift time coord back 1 day so labels
      match the day accumulated. Code comments reference #36.
- [x] For `sde`, `rsn`, `snowc` (state / fraction vars):
      `.resample(valid_time="1D").mean()`.
- [x] **Monthly natives** to `data/backfill/monthly/{var}_{year}.tif` (12-band):
      - `snow_depth_{year}.tif` — monthly mean of daily `sde × rsn` (mm SWE)
      - `snowfall_{year}.tif` — monthly sum of daily `sf` × 1000 (mm/month)
      - `snowmelt_{year}.tif` — monthly sum of daily `smlt` × 1000 (mm/month)
      - `snow_cover_{year}.tif` — monthly mean of daily `snowc` (% — native
        ERA5-Land unit; was originally documented as fraction 0–1, corrected
        to match data)
- [x] **Annual derived** to `data/backfill/annual/{var}_{year}.tif` (1-band):
      - `swe_max_{year}.tif` — annual max of daily `sde × rsn`
      - `snowfall_fraction_{year}.tif` — `100 * annual_sum_sf / annual_sum_tp`
        (% — converted from fraction for consistency with `snow_cover`;
        `tp` from daily product, `with_retry`-wrapped)
      - `snowmelt_doy_50_{year}.tif` — DOY when cumulative annual `smlt`
        first crosses 50% of annual sum (NaN where annual sum is zero)
      - `snowmelt_rate_peak_{year}.tif` — annual max of 7-day rolling sum
        of daily `smlt` (mm/week)
- [x] Import `preflight_single_instance("backfill_edh_snow")`,
      `with_retry`, `write_geotiff`, `log`, `get_token` from
      `scripts/_lib.py`.
- [x] One-year smoke test (`uv run scripts/backfill_edh_snow.py --year 2020`).
      All 8 outputs written; spatial sanity confirmed (median DOY-50 = 128
      ≈ May 8 freshet; median snowfall_fraction = 27%; median peak SWE
      = 276 mm; values span plausible BC ranges).
- [x] Benchmark: 228 s/year first run, 61 s/year for incremental
      single-output rerun (idempotent skip + dependency cache effects).
      Full 76-year backfill estimate: ~4–5 hours fresh, faster on rerun.

## Phase 2 — Producer: full backfill + Stage 3 aggregation + S3 push

- [x] Full 76-year backfill (1950–2025) — 2h52min wall clock; one transient
      EDH `ClientPayloadError` on year 2022, recovered via single-year
      retry (idempotent skip on the rest).
- [x] `mv data/backfill/monthly/snow_depth_*.tif → swe_*.tif` (75 files;
      year 2022 retry produced `swe_2022.tif` directly under the
      post-rename script).
- [x] Adapt `scripts/pipeline_stage3_edh.R` for annual-only vars:
      monthly natives flow through `cd_aggregate` (Step 1); annual
      derived skip `cd_aggregate` and stack 1-band-per-year files into
      multi-band COGs in a new Step 1b. Extended `agg_methods` for the
      4 new monthly vars (sum for snowfall/snowmelt, mean for
      swe/snow_cover).
- [x] Bug fix in `cd_stac_item()` caught during dry-run: substring
      `grepl(v, name_parts)` mis-routed `swe_max_annual.tif` under
      `swe`. Replaced with strict `{var}_{period}` exact-match against
      both registries.
- [x] Generate updated `catalog.json` via `cd_stac_catalog` (59 items).
- [x] Push to `s3://stac-era5-land` (24 new COGs + updated catalog,
      ~114 MB, ~5s sync).
- [x] Verify catalog readable from `cd_catalog()` (default S3 URL):
      4 monthly natives × 5 periods + 4 annual derived × 1 period = 24
      new entries returned correctly.

## Phase 3 — Producer-side QA cross-check vs ASWS / manual snow surveys

- [x] Added `bcsnowdata` to Suggests in DESCRIPTION (also requires
      `reshape` as a transitive dep, installed locally).
- [x] New `data-raw/qa_snow_validation.R`. Site selection pivoted from
      the explore-agent's original list (Fort St. John Airport et al.,
      lat/lon coords were inaccurate) to active ASWS sites verified
      via `bcsnowdata::snow_auto_location()` spatially intersected
      with the FWCP Peace AOI: Ware Upper (4A03P, 1565 m), Mount
      Sheba (4A18P, 1490 m), Pine Pass (4A02P, 1400 m), Aiken Lake
      (4A30P, 1050 m), Germansen Landing (4A35P, 766 m). Germansen
      ended up with no usable SWE record so the QA is on 4 sites,
      95 paired site-years.
- [x] Skipped manual-survey secondary cross-check — the ASWS bias
      stability is clearly stable across all 4 sites with usable
      records, so the secondary check isn't needed to support the
      vignette claim. Documented as deferred in findings.md.
- [x] Extracted ERA5-Land `swe_max` at each site's point lat/lon
      via `terra::extract` on the 76-band annual COG from S3.
- [x] Scatter, correlation, mean bias, bias-trend regression all
      computed. Outputs at
      `planning/active/qa_snow_validation_results.md` (text report)
      and `qa_snow_validation_scatter.png` (plot).
- [x] **Findings**: bias is direction-variable (Pine Pass −61%,
      Aiken Lake +54%) rather than uniformly high as Kouki's NH
      average suggests. **Bias is stable over time** at all 4 sites
      (regression p > 0.2 everywhere), supporting the "trends still
      defensible" vignette claim. Updated the vignette methodology
      footnote with these specific BC numbers replacing the earlier
      quote of Kouki's 150–200% NH-wide figure.

## Phase 4 — Consumer: registry + anomaly branch + tests

- [x] Add 8 rows to `cd_variables()`:
      - `swe`, `snowfall`, `snowmelt`: monthly, `pct_normal` (renamed
        `snow_depth` → `swe` since the value is mm SWE, not vertical
        snow depth — `sde × rsn` = kg/m² = mm of water)
      - `snow_cover`: monthly, **new** `pct_point_diff` (already in %)
      - `swe_max`: annual, `absolute` (mm)
      - `snowfall_fraction`: annual, `pct_point_diff` (already in %)
      - `snowmelt_doy_50`: annual, `absolute` (day)
      - `snowmelt_rate_peak`: annual, `absolute` (mm/wk)
- [x] Add `pct_point_diff` branch to `cd_anomaly()`'s `case_when`.
      Formula identical to `absolute` (`value - baseline_mean`) — the
      distinction is unit semantics for downstream display. Combined
      with `absolute` via `%in%`. `cap_pct` does NOT apply to
      `pct_point_diff` (covered by new test).
- [x] Update `test-cd_variables.R` count assertion 7 → 15. Added two
      new tests for `pct_point_diff` membership.
- [x] Update `test-cd_fetch.R` pct_normal list — now includes
      `swe`, `snowfall`, `snowmelt` alongside `prcp`, `soil_moisture`.
- [x] Add two `test-cd_anomaly.R` cases: pct_point_diff arithmetic
      and confirmation that `cap_pct` is NOT applied to
      `pct_point_diff`.
- [x] `devtools::test()` clean (166 PASS, 0 FAIL).
- [ ] After backfill completes, `mv data/backfill/monthly/snow_depth_*.tif
      data/backfill/monthly/swe_*.tif` (the running fetch is using
      pre-rename code; reload is unnecessary, just rename outputs).

## Phase 5 — Vignette: new "Snowpack" section

- [x] Extended `data-raw/peace_fwcp_vignette_data.R` — extracted
      `pct_normal_vars` list to include `swe`, `snowfall`, `snowmelt`
      alongside `prcp`, `soil_moisture` for the regional and
      per-ecoregion `cd_compare(method = "pct_change")` calls.
      Re-ran precompute: `peace_fwcp.rds` is now 270 KB (was 160 KB)
      with all 15 vars.
- [x] Wired bibliography — added `bibliography: references.bib` and
      `link-citations: true` to vignette YAML; generated
      `vignettes/references.bib` (22 KB) via `rbbt::bbt_write_bib()`
      from BBT keys for the 11 papers in the
      `NewGraphEnvironment/hydrology` Zotero collection.
- [x] New `## Snowpack` section in `vignettes/peace-fwcp.Rmd`
      between "Daytime Highs and Overnight Lows" and "Recent vs
      Pre-warming". Pivoted seasonal-curve sub-story to a SEASONAL
      table (winter/spring/summer/fall) instead of a monthly faceted
      plot — monthly aggregations aren't on S3 (the COG schema is
      annual + 4 seasons), and the seasonal level still tells the
      "when does snow accumulate / melt" story cleanly. Annual
      derived sub-story = 4 `cd_plot_timeseries` panels for
      `swe_max`, `snowmelt_doy_50`, `snowmelt_rate_peak`,
      `snowfall_fraction`.
- [x] Extended "Recent vs Pre-warming" table — added `no_pct_vars`
      list (`snow_cover`, `snowfall_fraction`, `snowmelt_doy_50`)
      to NA-out the Δ % column for vars where it's not meaningful.
      All 8 new vars appear in the table with appropriate columns.
- [x] Three-finding interpretation paragraph closes the Snowpack
      section: snow leaving earlier (not falling less), freshet
      shifting into spring, summers becoming snow-free. Each
      finding ties to a specific cited paper from the citation
      map in #53's findings.md.
- [x] 11 citations resolve in the rendered References section.
- [x] Render time 8.7 s (well under 30 s target). 166 tests pass.

## Phase 6 — Monthly GHA + docs

- [x] Extended `scripts/pipeline_update_edh.R` (the script the GHA
      calls) rather than touching the workflow YAML directly:
      - Added `annual_dir` config alongside `monthly_dir`.
      - Extended `agg_methods` with the 4 monthly snow natives
        (matches `pipeline_stage3_edh.R`).
      - Added `annual_vars` list for the 4 annual snow scalars.
      - Step 3 now calls both `backfill_edh_all.py` AND
        `backfill_edh_snow.py` for each candidate year, and
        verifies all 15 outputs (7 core + 4 monthly snow + 4
        annual snow) wrote.
      - Step 4 split into a monthly path (cd_aggregate) and an
        annual path (read 1-band annual TIFs, stack onto S3 COG).
        Refactored the per-(var, period) append logic into an
        `append_to_cog()` helper to avoid duplication between the
        two paths.
- [x] No changes needed to `.github/workflows/climate-update.yml` —
      the workflow just calls `pipeline_update_edh.R`, all
      snow-specific logic lives in the R script.
- [x] README: variable inventory updated to list all 15 vars
      grouped as core / snow monthly natives / snow annual derived,
      with periods note clarifying that annual-derived vars only
      have an "annual" period.
- [x] `parse()` clean on `pipeline_update_edh.R`. 166 tests pass.

## Phase 7 — Release v0.2.0

- [ ] `/code-check` clean on each commit.
- [ ] Atomic commits — Phase 1 producer script, Phase 2 Stage 3 + S3,
      Phase 3 QA, Phase 4 registry/anomaly, Phase 5 vignette, Phase 6
      GHA/docs.
- [ ] PR with `Fixes #48`, SRED ref
      (`Relates to NewGraphEnvironment/sred-2025-2026#23`).
- [ ] Bump DESCRIPTION 0.1.6 → 0.2.0; NEWS entry; tag `v0.2.0`.

## Phase 8 — KOTL decision (#49)

- [ ] Once snow section is live in `peace-fwcp.Rmd`, evaluate
      whether KOTL stays dropped or gets resurrected as a
      snow-and-water vignette focused on Kootenay Lake.
- [ ] Close or update #49 with the decision.

## Validation

- [ ] Single-year smoke test produces all 8 output families with
      expected band counts.
- [ ] Spatial sanity: more snow in mountains; melt timing later
      at higher elevations.
- [ ] ASWS QA: r ≥ 0.6 typical and stable bias over time.
- [ ] `devtools::test()` clean.
- [ ] `lintr::lint_package()` clean.
- [ ] Vignette renders in <30 s.
- [ ] PWF checkboxes match landed work.
- [ ] `/planning-archive` on completion.

## Out of scope

- Daily-resolution SWE published to S3. Daily lives producer-internal
  only.
- Streamflow modelling.
- Glacier dynamics.
- Bonus snow vars `asn` (albedo), `tsn` (snow temperature). Follow-up
  if motivated.
- `cd_compare()` p-value (#43). Separate PR.
- tmax/tmin local-time aggregation (#37).
