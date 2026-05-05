# Findings — Snow vars for hydrology departure (#48)

## Issue context (verbatim from #48)

`cd` currently ships seven climate variables (tmean, tmax, tmin, prcp,
vpd, rh, soil_moisture) but none of the snow-pack or
precipitation-phase variables that drive hydrology. For fish passage
and aquatic restoration reporting in northern BC, the climate-change
questions that actually matter for stream flow, thermal habitat, and
culvert sizing are:

- Is precipitation falling more as rain and less as snow? (winter
  precipitation phase)
- When is the seasonal snowpack melting — earlier, later, similar?
- How fast is melt happening — flashier (concentrated) or more spread
  out?
- Is peak snowpack getting smaller?

These belong in `cd` because the source data (ERA5-Land), architecture
(COG + STAC), consumer pipeline (cd_catalog → cd_extract → baselines →
trends), and scientific framing (departure analysis) are identical to
what the package already does for the seven existing variables.

## State found during plan-mode exploration

### Architecture

- **Snow vars are hourly-only on EDH.** Probe (now removed but
  documented in [issue comment 4368174544](https://github.com/NewGraphEnvironment/cd/issues/48#issuecomment-4368174544)):
  daily UTC product (`era5-land-daily-utc-v1.zarr`) ships 14 vars
  (`d2m, e, pev, ro, sp, ssr, ssrd, str, swvl1, swvl2, t2m, tp, u10,
  v10`) — zero snow. Hourly product
  (`reanalysis-era5-land-no-antartica-v0.zarr`) ships all four target
  source vars (`sf, smlt, sde, rsn`) plus three bonuses (`asn, tsn,
  snowc`).
- **`sf` and `smlt` are `stepType=accum`** — running accumulation
  from 01:00 UTC reset to 00:00 UTC next day. Same trap as `tp` in
  #36. For `tp` we punted to the daily product; for snow we have to
  write accum handling ourselves.
- **The 00:00 UTC reset trick** is documented in the #36 archive
  (`planning/archive/2026-04-issue-36-edh-migration/findings.md`)
  but never implemented in code. This issue is the first place it
  lands.

### Producer pipeline

- `scripts/backfill_edh_all.py` never does hourly accum handling —
  defers entirely to daily product for `tp`. Snow forces new code.
- `scripts/_lib.py` (just merged in #52) ships the safeguards we'll
  reuse: `preflight_single_instance(name)`, `with_retry`,
  `write_geotiff(da, out_path, band_names=...)` with `band_names`
  already supporting annual outputs (one band per year), `log`,
  `get_token`.
- `cd_stac_catalog` does directory scan + filename regex
  `{variable}_{period}.tif`. Adding new vars: just put them in
  `cd_variables()` registry and ensure filenames match.
- S3 layout is flat: `s3://stac-era5-land/{var}_{period}.tif`.
  Compatible with new vars.
- `.github/workflows/climate-update.yml` hardcodes the 7 existing
  vars. Needs extension or sibling workflow.

### Consumer pipeline

- `cd_aggregate()` strictly enforces 12-band input
  (`R/cd_aggregate.R:36`). Annual-only vars must be aggregated at
  producer side and bypass `cd_aggregate`. Decision: ship annual
  derived as 1-band/year COGs published directly.
- `cd_baseline()`, `cd_extract()`, `cd_trend()` are band-count
  agnostic — work for annual data without changes.
- `cd_anomaly()` needs a third branch for `pct_point_diff` (formula:
  `(value - baseline_mean) * 100`). Three lines.
- `cd_variables()` test asserts `nrow(vars) == 7` — bump to 15.

### QA cross-check

- BC Manual Snow Surveys via CSV at
  `https://www.env.gov.bc.ca/wsd/data_searches/snow/asws/data/allmss_archive.csv`
  (1950s+, monthly Jan–Jun). Site IDs use BC Snow Course codes.
- ASWS automated snow pillows give daily SWE, ~20-yr records. Better
  primary QA target — daily resolution lets us validate freshet
  timing, not just peak.
- `bcgov/bcsnowdata` R package wraps both. Already maintained,
  integrates with `bcdata`.
- Five representative Peace-region sites for QA scatter: Fort St.
  John Airport (4A25, 690 m), Summit Lake (4C02, 1280 m), Sikanni
  Lake (4C01, 1385 m), Fort St. James (1A07, 810 m), Kwadacha
  River (4A27, 1620 m). All ≥50 yr manual records overlapping
  ERA5-Land 1950–2025; subset have ASWS daily records too.

### Vignette

- `vignettes/peace-fwcp.Rmd` doesn't loop over variables — has manual
  per-section structure. New "Snowpack" section slots in between
  "Daytime Highs and Overnight Lows" and "Recent vs Pre-warming".
- The "Recent vs Pre-warming" table at lines 314–317 hardcodes which
  vars get pct columns. Needs parametrization for `pct_point_diff`
  vars (`snow_cover`, `snowfall_fraction`).

## Architecture decisions taken (user-confirmed)

1. **Both layers ship**: 4 monthly natives + 4 annual derived = 8 new
   vars. Single hourly fetch on producer side covers both. Vignette
   shows seasonal curve (when snow comes/melts) AND climate-departure
   trends (peak SWE, freshet timing).
2. **`snow_cover` (snowc) is in scope** despite originally being
   "out of scope bonus". User pushed back — snowc as monthly mean is
   the cleanest melt-timing visualization at regional scale ("70% of
   May had snow on the ground in 1950-1995 → 15% in 2015-2025"
   directly comparable). Complementary to `snow_depth`, not
   redundant.
3. **Annual derived aggregated at producer side** (1-band/year
   COGs). Avoids `cd_aggregate` extension.
4. **ASWS primary QA, manual surveys secondary**. Daily ASWS for
   freshet timing validation; manual surveys for peak-SWE long-record
   cross-check.
5. **New `pct_point_diff` anomaly type** for `snow_cover` and
   `snowfall_fraction` (both already fractions/ratios — departure in
   percentage points is the meaningful unit).
6. **`snowmelt_rate_peak`** uses 7-day rolling sum of daily `smlt`,
   annual max. Monthly aggregation would smear a one-week burst into
   a slow month — exactly the freshet flashiness signal we want to
   preserve.

## Anchors for downstream work

- This vignette is the template for the three reporting climate-
  departure appendices (cf #47 archive). Snow section will port
  directly to `fish_passage_peace_reporting_2025`.
- After v0.2.0 release, #49 (KOTL decision) revisits whether KOTL
  vignette stays dropped or returns as the snow-and-water story
  focused on Kootenay Lake (snow-fed reservoir dynamics).
- Companion future work: #43 (`cd_compare()` p-value) pairs
  naturally with snow but stays in a separate PR.
