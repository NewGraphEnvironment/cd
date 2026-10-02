# Changelog

## cd 0.5.9 (2026-10-02)

- The installed package is 4.7 MB smaller, about 38%. It no longer ships
  `inst/extdata/context_kotl.gpkg`, a 4.9 MB layer set that nothing has
  read since the KOTL vignette was removed in 0.1.4. The Kootenay Lake
  vignette’s `context_kootenay_lake.gpkg` covers its layers and area.
  `example_aoi_kotl.gpkg`, which the README uses, stays.
  ([\#112](https://github.com/NewGraphEnvironment/cd/issues/112),
  [\#115](https://github.com/NewGraphEnvironment/cd/pull/115))

## cd 0.5.8 (2026-10-01)

- `sf` moves from Imports to Suggests, so installing cd no longer
  installs sf. No cd function calls sf:
  [`cd_crop()`](https://newgraphenvironment.github.io/cd/reference/cd_crop.md)
  and
  [`cd_extract()`](https://newgraphenvironment.github.io/cd/reference/cd_extract.md)
  still accept an `sf` AOI, which
  [`terra::vect()`](https://rspatial.github.io/terra/reference/vect.html)
  converts, loading sf itself. The examples, README and vignettes read
  AOIs with
  [`sf::st_read()`](https://r-spatial.github.io/sf/reference/st_read.html),
  so install sf to follow them. The `.data` and `.env` pronouns are now
  imported from rlang, and `R CMD check` reports no NOTEs.
  ([\#111](https://github.com/NewGraphEnvironment/cd/issues/111),
  [\#114](https://github.com/NewGraphEnvironment/cd/pull/114))

## cd 0.5.7 (2026-10-01)

- The package tarball now ships only the package. `.Rbuildignore` had
  held its six scaffold lines, so every build and every install from
  GitHub carried `planning/`, `scripts/`, `data-raw/`, `dev/`, `logs/`,
  `.claude/`, `CLAUDE.md`, `CITATION.cff` and `.lintr`: 307 files where
  92 belong. `R CMD check` drops the “hidden files”, “portable file
  names” and “CITATION file in a non-standard place” NOTEs.
  ([\#100](https://github.com/NewGraphEnvironment/cd/issues/100),
  [\#113](https://github.com/NewGraphEnvironment/cd/pull/113))

## cd 0.5.6 (2026-09-30)

- [`cd_trend()`](https://newgraphenvironment.github.io/cd/reference/cd_trend.md)
  returns a typed empty table when no series is long enough. A trend in
  which every variable and period had fewer than 3 years in its window
  came back as a 0 x 0 tibble, so
  [`cd_summary()`](https://newgraphenvironment.github.io/cd/reference/cd_summary.md)
  on it failed with `Column 'period' not found` and
  `cd_plot_timeseries(trend = )` warned about uninitialised columns. It
  is now a zero-row tibble with every column
  [`cd_trend()`](https://newgraphenvironment.github.io/cd/reference/cd_trend.md)
  documents, and
  [`cd_summary()`](https://newgraphenvironment.github.io/cd/reference/cd_summary.md)
  returns an empty table.

  Behaviour changes for existing callers:

  - `slope` and `intercept` no longer carry the names `"yr"` and
    `"Intercept"` that the Theil-Sen fit attached.

  ([\#101](https://github.com/NewGraphEnvironment/cd/issues/101),
  [\#110](https://github.com/NewGraphEnvironment/cd/pull/110))

## cd 0.5.5 (2026-09-30)

- [`cd_summary()`](https://newgraphenvironment.github.io/cd/reference/cd_summary.md)
  names the trend window. A trend table holding several `trend_start`
  values, such as `cd_trend(x, trend_start = c(1951, 1981))`, gave two
  rows per variable and period that differed only by `Years`. It now
  gains a `Start` column, holding the start year asked of
  [`cd_trend()`](https://newgraphenvironment.github.io/cd/reference/cd_trend.md),
  after `Period` (or after `Trend on`). Both vignettes’ trend tables had
  59 such row pairs. They now show `Start`, and each 1951/1981 pair sits
  on adjacent rows.

  Behaviour changes for existing callers:

  - [`cd_summary()`](https://newgraphenvironment.github.io/cd/reference/cd_summary.md)
    gains a `Start` column only when the table holds more than one
    `trend_start`, counted over the whole table, with an `NA` counting
    as one. A single-window table keeps its shape. As with `Trend on`,
    per-region summaries bound together can differ in having it, and it
    is `NA` for those that lack it.

  ([\#106](https://github.com/NewGraphEnvironment/cd/issues/106),
  [\#109](https://github.com/NewGraphEnvironment/cd/pull/109))

## cd 0.5.4 (2026-09-30)

- [`cd_summary()`](https://newgraphenvironment.github.io/cd/reference/cd_summary.md)
  keeps rows distinguishable. A `long_name` shared by several variables,
  such as one “Mean discharge” on many stations, now gets the variable
  appended: `Mean discharge (q_site1)`, `Mean discharge (q_site2)`. This
  is the rule
  [`cd_plot_comparison()`](https://newgraphenvironment.github.io/cd/reference/cd_plot_comparison.md)
  already used, now in one internal helper that both functions call. A
  trend table holding both raw-value and anomaly trends, such as
  `bind_rows(cd_trend(x), cd_trend(ano))`, gains a `Trend on` column
  (`Value` or `Anomaly`) after `Period`. It uses the same rule as
  `Unit`, so a missing or `NA` `trend_on` reads as `Anomaly`.

  Behaviour changes for existing callers:

  - [`cd_summary()`](https://newgraphenvironment.github.io/cd/reference/cd_summary.md)
    `Parameter` gains `(variable)` wherever several variables share a
    label. Registered ERA5 variables are unaffected, because their
    long_names are unique.
  - [`cd_summary()`](https://newgraphenvironment.github.io/cd/reference/cd_summary.md)
    gains a `Trend on` column only when the input mixes scales. A table
    on one scale keeps its shape.
  - [`cd_plot_comparison()`](https://newgraphenvironment.github.io/cd/reference/cd_plot_comparison.md):
    where a suffixed label equals another variable’s own label
    (`long_name = c("Q", "Q", "Q (a)")`), the facets now read
    `Q (a) (a)`, `Q (b)`, `Q (a) (c)`. Previously two of them both read
    `Q (a)`.
  - A variable name built to collide (`a) (a` beside `a`) gives labels
    that never settle.
    [`cd_summary()`](https://newgraphenvironment.github.io/cd/reference/cd_summary.md)
    and
    [`cd_plot_comparison()`](https://newgraphenvironment.github.io/cd/reference/cd_plot_comparison.md)
    now abort on it and ask for the variables to be renamed.
    [`cd_plot_comparison()`](https://newgraphenvironment.github.io/cd/reference/cd_plot_comparison.md)
    used to plot it.

  Follow-up filed:
  [\#106](https://github.com/NewGraphEnvironment/cd/issues/106).
  ([\#98](https://github.com/NewGraphEnvironment/cd/issues/98),
  [\#108](https://github.com/NewGraphEnvironment/cd/pull/108))

## cd 0.5.3 (2026-09-29)

- `cd_plot_timeseries(trend =)` now draws only trend lines on the
  plotted scale. A table holding both raw-value and anomaly trends of a
  series, such as `bind_rows(cd_trend(x), cd_trend(ano))`, drew the raw
  line (in mm, say) over the anomaly bars. The overlay now keeps rows
  whose `trend_on` names the plotted column. It warns when rows match
  the series but none is on that scale. It orders rows by `trend_start`,
  so the earliest start is always the dashed line, as the vignette
  captions say.

  Behaviour changes for existing callers:

  - A trend on the other scale is skipped with a warning. For example,
    `cd_plot_timeseries(ano, trend = cd_trend(ts))` now draws nothing,
    where it drew the raw line on the anomaly axis.
  - A trend table without `trend_on`, whether hand-built or saved before
    0.5.2, still draws, on either scale.
    [`cd_summary()`](https://newgraphenvironment.github.io/cd/reference/cd_summary.md)
    instead reads such rows as anomaly trends.
  - Trend rows whose `variable` or `period` is `NA` are no longer drawn
    as an empty line. They no longer take the dashed style either.
  - The earliest `trend_start` is dashed whatever the row order.

  ([\#103](https://github.com/NewGraphEnvironment/cd/issues/103),
  [\#105](https://github.com/NewGraphEnvironment/cd/pull/105))

## cd 0.5.2 (2026-09-29)

- [`cd_summary()`](https://newgraphenvironment.github.io/cd/reference/cd_summary.md)
  no longer labels a trend of raw values with the anomaly unit from
  [`cd_variables()`](https://newgraphenvironment.github.io/cd/reference/cd_variables.md).
  A raw precipitation slope in mm read `%`, and a unit carried on an
  `absolute` series (`m3/s`, say) was dropped.
  [`cd_trend()`](https://newgraphenvironment.github.io/cd/reference/cd_trend.md)
  now records what it ran on in a `trend_on` column (`"value"` or
  `"anomaly"`). On raw input it also carries `anomaly_type` and `unit`,
  keeping the unit only where it is also the unit of the values
  (`absolute`, `pct_point_diff`).
  [`cd_summary()`](https://newgraphenvironment.github.io/cd/reference/cd_summary.md)
  applies that rule row by row, so its `Unit` column now agrees with the
  [`cd_plot_timeseries()`](https://newgraphenvironment.github.io/cd/reference/cd_plot_timeseries.md)
  axis label for the same series. This replaces the 0.5.0 rule that
  `anomaly_type` and `unit` are carried only when trending anomalies.

  Behaviour changes for existing callers:

  - Every
    [`cd_trend()`](https://newgraphenvironment.github.io/cd/reference/cd_trend.md)
    result gains a `trend_on` column.
  - [`cd_summary()`](https://newgraphenvironment.github.io/cd/reference/cd_summary.md)
    `Unit` on raw-value trends: `pct_normal` series (prcp,
    soil_moisture, swe, snowfall, snowmelt) go from `%` to `NA`, and a
    unit carried on an `absolute` series is now shown.
  - [`cd_trend()`](https://newgraphenvironment.github.io/cd/reference/cd_trend.md)
    on raw input now errors when `anomaly_type` or `unit` varies within
    one series, as
    [`cd_plot_timeseries()`](https://newgraphenvironment.github.io/cd/reference/cd_plot_timeseries.md)
    already did.
  - A trend table without `trend_on`, such as one saved before this
    release, is read as an anomaly trend, as before.

  Follow-ups filed from review:
  [\#101](https://github.com/NewGraphEnvironment/cd/issues/101),
  [\#102](https://github.com/NewGraphEnvironment/cd/issues/102),
  [\#103](https://github.com/NewGraphEnvironment/cd/issues/103).
  ([\#104](https://github.com/NewGraphEnvironment/cd/pull/104))

## cd 0.5.1 (2026-09-29)

- [`cd_plot_timeseries()`](https://newgraphenvironment.github.io/cd/reference/cd_plot_timeseries.md)
  and
  [`cd_plot_comparison()`](https://newgraphenvironment.github.io/cd/reference/cd_plot_comparison.md)
  now label a series from the `long_name` and `unit` it carries, falling
  back to
  [`cd_variables()`](https://newgraphenvironment.github.io/cd/reference/cd_variables.md)
  by the rules of the 0.5.0 input contract, so a series from another
  package (streamflow, say) plots under the label
  [`cd_summary()`](https://newgraphenvironment.github.io/cd/reference/cd_summary.md)
  prints for it instead of `anomaly`.
  [`cd_compare()`](https://newgraphenvironment.github.io/cd/reference/cd_compare.md)
  carries a `long_name` column through when its input has one (no unit:
  it works on raw values). A `long_name` shared by several variables
  gets the variable name appended in the comparison plot, and each
  variable always gets its own facet.

  Behaviour changes for existing callers:

  - [`cd_plot_timeseries()`](https://newgraphenvironment.github.io/cd/reference/cd_plot_timeseries.md)
    on raw values no longer shows an anomaly unit that does not describe
    them: raw precipitation, which read “Precipitation (%)”, now reads
    “Precipitation”. Anomaly plots are unchanged.
  - [`cd_plot_timeseries()`](https://newgraphenvironment.github.io/cd/reference/cd_plot_timeseries.md)
    errors on duplicate years in the plotted series (they were stacked
    into one bar) and on conflicting metadata within it, and ignores
    rows whose `variable` or `period` is `NA`.
  - [`cd_compare()`](https://newgraphenvironment.github.io/cd/reference/cd_compare.md)
    gains a `long_name` column when the input carries one.

  Follow-ups filed from review:
  [\#96](https://github.com/NewGraphEnvironment/cd/issues/96),
  [\#97](https://github.com/NewGraphEnvironment/cd/issues/97),
  [\#98](https://github.com/NewGraphEnvironment/cd/issues/98).
  ([\#99](https://github.com/NewGraphEnvironment/cd/pull/99))

## cd 0.5.0 (2026-09-29)

- The consumer chain now works on any annual series in cd’s long format,
  not only the ERA5-Land variables in
  [`cd_variables()`](https://newgraphenvironment.github.io/cd/reference/cd_variables.md).
  Streamflow and stream temperature from other packages are included.
  [`cd_anomaly()`](https://newgraphenvironment.github.io/cd/reference/cd_anomaly.md)
  used to return a silent `NA` for any variable outside the registry. It
  now takes `anomaly_type`, `unit` and `long_name` from the input where
  present, falls back to
  [`cd_variables()`](https://newgraphenvironment.github.io/cd/reference/cd_variables.md)
  row by row, and raises an error naming any variable whose type it
  cannot resolve. `unit` means the anomaly’s unit, as it always has in
  [`cd_variables()`](https://newgraphenvironment.github.io/cd/reference/cd_variables.md).
  [`cd_trend()`](https://newgraphenvironment.github.io/cd/reference/cd_trend.md)
  carries the metadata through (`anomaly_type` and `unit` only when
  trending anomalies) and
  [`cd_summary()`](https://newgraphenvironment.github.io/cd/reference/cd_summary.md)
  uses it. The contract is documented under “Input contract” in
  [`?cd_anomaly`](https://newgraphenvironment.github.io/cd/reference/cd_anomaly.md).

  Behaviour changes for existing callers:

  - [`cd_trend()`](https://newgraphenvironment.github.io/cd/reference/cd_trend.md)
    on
    [`cd_anomaly()`](https://newgraphenvironment.github.io/cd/reference/cd_anomaly.md)
    output gains `anomaly_type` and `unit` columns.
  - Input with more than one row per variable, period and year is now an
    error in
    [`cd_baseline()`](https://newgraphenvironment.github.io/cd/reference/cd_baseline.md),
    [`cd_anomaly()`](https://newgraphenvironment.github.io/cd/reference/cd_anomaly.md),
    [`cd_compare()`](https://newgraphenvironment.github.io/cd/reference/cd_compare.md)
    and
    [`cd_trend()`](https://newgraphenvironment.github.io/cd/reference/cd_trend.md).
    Before, two stations stacked under one `variable` were silently
    averaged together.
  - Grouped input is accepted.

  ERA5 results are unchanged: the regional trend tables in both
  vignettes reproduce exactly.
  ([\#94](https://github.com/NewGraphEnvironment/cd/pull/94))

## cd 0.4.3 (2026-09-07)

- Producer-side only — no change to any exported function. Fixes what
  four independent review rounds found in the 0.4.1 and 0.4.2 changes,
  which had shipped on self-review alone.

  The offline test suites added in those releases were decorative for
  the distinction they existed to make: `months_available()` stubbed to
  return the *index of the last month* instead of the *count of distinct
  months* passed 7/7, because every fixture’s year began on 1 January
  and was contiguous, and for that shape the two are the same number. A
  guard that over-counts writes a partial year. The R suite never
  asserted the connection-failure diagnosis at all, so a message
  colliding with the 401 text would have sent an operator to rotate a
  healthy secret on a DNS timeout. Both suites now carry fixtures that
  reach those cases, and every previously surviving mutant is red.

  In the probe itself: `edh_err` was not reset between retry attempts,
  so one attempt’s connection error printed beneath another’s
  `rotate the secret` diagnosis; the error-text fetch never checked its
  own status, so a recovered server’s 200 body could be quoted as EDH’s
  explanation; and neither curl handle bounded the transfer, so a server
  that completed the handshake and stalled hung until the job was
  **cancelled** — which `if: failure()` skips, silencing the alarm in
  exactly the hang the probe exists to catch. The workflow now also
  fires on `cancelled()`.

  Three pre-existing defects the review surfaced are filed rather than
  fixed here:
  [\#88](https://github.com/NewGraphEnvironment/cd/issues/88),
  [\#89](https://github.com/NewGraphEnvironment/cd/issues/89),
  [\#90](https://github.com/NewGraphEnvironment/cd/issues/90).
  ([\#91](https://github.com/NewGraphEnvironment/cd/pull/91))

## cd 0.4.2 (2026-09-07)

- Producer-side only — no change to any exported function. The EDH
  credential probe in `scripts/pipeline_update_edh.R` STEP 0 collapsed
  every HTTP status `>= 400` into `EDH rejected the token`, so a 403
  sent the reader to rotate a secret that was in perfect health — which
  is exactly what happened on 2026-09-07. A 401, 403 and 404 now give
  three distinct diagnoses, and EDH’s own error text is quoted on the
  failure path. The probe also gains a bounded retry over the statuses
  that can clear on their own (connection failure, 408, 429, 5xx, and
  403 — observed transient), while 401 still fails immediately, since
  retrying a rejected credential only delays the report. Both decisions
  are pure functions in a new `scripts/_lib.R`, asserted offline by
  `scripts/test_lib.R`.
  ([\#87](https://github.com/NewGraphEnvironment/cd/pull/87))

## cd 0.4.1 (2026-09-07)

- Producer-side only — no change to any exported function. The three EDH
  backfillers now establish whether a year is complete **before**
  fetching it. `.compute()`, where the lazy xarray graph actually pulls
  from the Zarr store, previously ran ahead of the 12-month guard, so
  every monthly `climate-update` run downloaded a full partial year
  across 15 variables and discarded it — against a metered EDH free
  tier, roughly eleven times a year. A new `months_available()` helper
  answers the same question from the store’s time coordinate, which Zarr
  materialises on open and so costs no data transfer. The check is per
  store, since the hourly and daily stores advance independently
  (measured two months apart). Also closes an unguarded write: the four
  annual-derived snow variables had no completeness check at all, so a
  partial year produced rasters that the per-output idempotency check
  then preserved permanently.
  ([\#85](https://github.com/NewGraphEnvironment/cd/pull/85))

## cd 0.4.0 (2026-06-25)

- On-disk caching wired into the consumer read path, so repeated
  extractions, report renders, and vignette rebuilds pull each COG from
  S3 **once** and read locally thereafter — turning the dominant
  recurring S3 egress driver into a one-time cost. New exported
  [`cd_cache_fetch()`](https://newgraphenvironment.github.io/cd/reference/cd_cache_fetch.md)
  downloads a remote http(s) COG to the cd cache (keyed by URL hash,
  with a sidecar `.meta` recording the S3 ETag and size), validates
  freshness with a cheap HTTP HEAD (ETag, falling back to
  Content-Length), and serves the local copy on a hit. Downloads are
  size-validated and atomically renamed so a truncated file is never
  served; a failed HEAD with a cached copy present serves the cache, and
  `options(cd.cache_revalidate = FALSE)` skips revalidation entirely for
  offline work.
  [`cd_crop()`](https://newgraphenvironment.github.io/cd/reference/cd_crop.md)
  and
  [`cd_extract()`](https://newgraphenvironment.github.io/cd/reference/cd_extract.md)
  gain `cache = TRUE` (default), threading remote reads through the
  cache while local paths pass through unchanged. Live S3 confirmation:
  a repeat read drops from a full-COG download (megabytes) to a ~1 KB
  HEAD (or zero network with revalidation off). Adds `curl` to Imports.
  See the new README “Caching” section, which also documents the GDAL
  `/vsicurl/` env-var stopgap.
  ([\#76](https://github.com/NewGraphEnvironment/cd/pull/76))

## cd 0.3.2 (2026-06-06)

- Both regional vignettes (kootenay-lake, peace-fwcp) rewritten for new
  readers: plainer-language opener for the snowpack section (“In BC,
  most of the year’s runoff starts as winter snow…” instead of the
  “hinge of BC hydrology” metaphor), Trends / Recent-Decade / bias-notes
  preambles compressed and de-jargoned, Annual snowpack signals intro
  reduced to a 3-bullet plain-language list, salmonid Interpretation
  closer tightened to one paragraph with three bold knock-on effects.
  Figure trim: cut `plot-tmean` (covered by `facet-tmean`), `plot-dtr`
  (asymmetry numbers already in prose), and `snow-rate-peak` (not
  load-bearing); fold `plot-tmax` + `plot-tmin` into one 2-panel faceted
  `plot-tmaxmin`, and `snow-swe-max` + `snow-doy-50` + `snow-fraction`
  into one 3-panel faceted `snow-annual` (free y-scales). Net per
  vignette: 3 fewer standalone figures, same coverage. Bibliography:
  dropped `kouki_etal2023` and `yue_wang2002` (no longer cited); union
  now 15/15. ([\#75](https://github.com/NewGraphEnvironment/cd/pull/75))

## cd 0.3.1 (2026-06-06)

- Kootenay Lake vignette: drops cross-references to the Peace vignette
  so the regional narrative stands on its own — recent-decade table
  preamble, snowpack section header, ASWS QA cross-check,
  snowpack-meaning section, cordillera-wide background, and the
  precipitation / snow Interpretation bullets all rewritten to focus on
  Kootenay-only findings (what is happening and what it means).
  Institutional FWCP reference at the watershed-group section and
  maintainer-facing `peace-fwcp.Rmd` build comment retained.
  ([\#74](https://github.com/NewGraphEnvironment/cd/pull/74))

## cd 0.3.0 (2026-05-10)

- [`cd_compare()`](https://newgraphenvironment.github.io/cd/reference/cd_compare.md)
  API: adds defaults `window_a = 2015:2025`, `window_b = 1951:1980` (the
  WMO-style standard normal vs recent decade — the framing both regional
  vignettes had settled on) and a new `test = "t"` argument that adds a
  `p_value` column to the output. `test = "t"` runs Welch’s two-sample
  t-test on the annual values within each window; `test = "wilcox"` runs
  Mann-Whitney U; `test = NULL` skips and drops the column. Rows where
  either window has \< 8 non-NA years get `p_value = NA` and a single
  batched warning naming affected variable/period rows. The
  window-vs-window p-value answers a different question than
  [`cd_trend()`](https://newgraphenvironment.github.io/cd/reference/cd_trend.md)’s
  Mann-Kendall test — “do the two windows differ” vs “is there a
  monotonic trend” — and step changes / U-shapes can produce significant
  Δ p with non-significant trend p (and vice versa). Both regional
  vignettes now report both p-values side-by-side (`Δ p (windows)` +
  `Trend p (75-yr)`), and the visible `compare-recipe` chunk drops to
  `cd::cd_compare(ts)` letting defaults carry the call. Vignette
  structure tweak: the **Recent Decade vs Pre-Warming Reference**
  section (renamed from “Recent vs Pre-warming”) moves up directly after
  Trends so the headline cumulative-impact number lands before DTR /
  Snowpack / Spatial Pattern drill-down. Minor bump (output schema gains
  `p_value` column by default; new `test` argument).
  ([\#73](https://github.com/NewGraphEnvironment/cd/pull/73))

## cd 0.2.8 (2026-05-07)

- Vignette polish bundle covering both regional vignettes
  (kootenay-lake, peace-fwcp): (1) **citation prose tightening** —
  surfaces source-specific findings ([Karl et
  al. 1993](https://doi.org/10.1175/1520-0477(1993)074%3C1007:ANPORG%3E2.0.CO;2)’s
  3:1 min:max ratio, [Mantua et
  al. 2010](https://doi.org/10.1007/s10584-010-9845-2)’s
  Washington-State scope + [Eaton & Scheller
  1996](https://doi.org/10.4319/lo.1996.41.5.1109)’s 57-species
  comparative finding, [Kang et
  al. 2016](https://doi.org/10.1038/srep19299)’s ~10-day Fraser advance)
  instead of name-drop end-tags; drops `arguez_vose2011` as
  decorative-only attribution; references.bib regen 18 → 17 entries; (2)
  **km² superscript fix** + **highway symbology** lifted from
  `gq/inst/registry/reg_qgis_restoration.json` (grey casing under
  warm-yellow fill); (3) **kootenay town filter** to Rossland,
  Castlegar, Nelson, Cranbrook, Kaslo, Nakusp; (4) **chunk restructure**
  (Option B) — hide ~13 visualization/styling chunks per vignette via
  `echo = FALSE`, lift `cd_*()` recipes (`cd_extract`,
  `cd_baseline + cd_anomaly + cd_trend + cd_summary`, `cd_compare`,
  per-ecoregion + per-WSG cd loops) out of `# Equivalent to:` comment
  blocks into shown `eval = FALSE` companion chunks. Reader’s flow
  becomes: cd recipe (visible, copy-pasteable) → output (table/figure,
  source hidden) → narrative; (5) **`cd::` namespace prefix** on every
  cd function call in both vignettes (visible + hidden) for explicit
  package attribution. Independent Explore subagent re-verified each
  tightened citation against source archives + PDFs; both vignettes
  render cleanly post-restructure.
  ([\#72](https://github.com/NewGraphEnvironment/cd/pull/72))

## cd 0.2.7 (2026-05-06)

- Tooling. Adds `data-raw/regenerate_bib.R` — a one-line helper that
  regenerates `vignettes/references.bib` from the union of pandoc
  citation markers across both regional vignettes by pulling source
  records from Zotero via Better BibTeX (`rbbt::bbt_bib`). Run after
  editing cites: `Rscript data-raw/regenerate_bib.R`. Each vignette gets
  a top-of-file HTML comment pointing to the helper; CLAUDE.md Vignettes
  section documents the prerequisite (BBT 9.x for Zotero 8/9). The
  conservative option vs embedding the rbbt call in YAML at render time,
  which would break pkgdown CI (no Zotero on the runner).
  ([\#70](https://github.com/NewGraphEnvironment/cd/pull/70))

## cd 0.2.6 (2026-05-05)

- Wires up `vignettes/peace-fwcp.Rmd` interpretation paragraphs with
  citations from the climate-departure 3-split lit reviews — companion
  to v0.2.5’s kootenay-lake wire-up. Same 7-insertion pattern (8 unique
  new keys + 1 reuse), sparingly applied per the plain-language vignette
  philosophy. Two AOI-specific tweaks vs the kootenay PR: the
  `[@pepin_etal2015Elevationdependentwarming; `[`@rangwala_miller2012Climatechange`](https://github.com/rangwala_miller2012Climatechange)`]`
  cite lands at the **Interpretation paragraph** rather than the Spatial
  Pattern section (Peace’s dominant warming gradient is east-west /
  windward-of-Rockies, not pure elevation), and the
  \[@ficklin_novick2017Historicprojected\] VPD-drying cite is **stronger
  here** than in Kootenay because Peace’s precipitation is *up* 3-4% in
  2 ecoregions yet soil moisture is flat — pure VPD-driven
  evaporative-demand effect. Audit log at
  `planning/archive/2026-05-issue-67-peace-vignette-wireup/citation_audit.md`
  records the per-cite source quote, paraphrase, and visible-in-vignette
  warrant. An independent Explore subagent verified each row against
  source quote archives + PDFs and signed off all 7 cites with zero
  edits or removals required (stronger pass than the v0.2.5 review,
  which caught one minor scope nit). `vignettes/references.bib` regen
  produced no diff — both vignettes draw from the same 18-key union.
  Snow-section citations from
  [\#54](https://github.com/NewGraphEnvironment/cd/issues/54) untouched.
  ([\#68](https://github.com/NewGraphEnvironment/cd/pull/68))

## cd 0.2.5 (2026-05-05)

- Wires up `vignettes/kootenay-lake.Rmd` interpretation paragraphs with
  citations from the climate-departure 3-split lit reviews
  ([\#53](https://github.com/NewGraphEnvironment/cd/issues/53)/#58/#61/#63).
  8 new BBT-keyed citations + 1 reuse, sparingly applied per the
  plain-language vignette philosophy. Insertions span all four non-snow
  interp themes: Trends/baseline-window ([Hansen et
  al. 2012](https://doi.org/10.1073/pnas.1205276109), [Arguez & Vose
  2011](https://doi.org/10.1175/2010BAMS2955.1)), DTR asymmetry ([Karl
  et
  al. 1993](https://doi.org/10.1175/1520-0477(1993)074%3C1007:ANPORG%3E2.0.CO;2)),
  elevation-dependent warming ([Pepin et
  al. 2015](https://doi.org/10.1038/nclimate2563); [Rangwala & Miller
  2012](https://doi.org/10.1007/s10584-012-0419-3)), continental-scale
  VPD drying ([Ficklin & Novick
  2017](https://doi.org/10.1002/2016JD025855)), and the
  climate→stream-temperature→fish thermal-habitat bridge ([Mantua et
  al. 2010](https://doi.org/10.1007/s10584-010-9845-2); [Eaton &
  Scheller 1996](https://doi.org/10.4319/lo.1996.41.5.1109)). Audit log
  at
  `planning/archive/2026-05-issue-65-kootenay-vignette-wireup/citation_audit.md`
  records, per cite, the vignette excerpt, source quote, rag store +
  topic where retrieved, and paraphrase as written — the “what is where
  by who said what where” trail. An independent Explore subagent
  verified each row against source quote archives and PDFs before merge;
  one minor scope concern surfaced (Ficklin & Novick paraphrase narrowed
  continental-US scope to “western US”) and was fixed inline.
  `vignettes/references.bib` regenerated via `rbbt::bbt_update_bib()` —
  now 18 entries (was 11). Snow-section citations from
  [\#54](https://github.com/NewGraphEnvironment/cd/issues/54) untouched.
  ([\#66](https://github.com/NewGraphEnvironment/cd/pull/66))

## cd 0.2.4 (2026-05-05)

- Interpretation framing methodology literature review — wraps the
  climate-departure 3-split (snow done in v0.1.7, temperature in v0.2.2,
  precip+drying in v0.2.3, **interpretation framing here**). Adds
  `scripts/rag_interpretation_framing_build.R` and
  `scripts/rag_interpretation_framing_query.R`, builds a local ragnar
  DuckDB from 4 peer-reviewed papers (now in the
  `NewGraphEnvironment/climate` Zotero collection), and ships the
  methodology synthesis + 11-row “cite this for that” citation map at
  `planning/archive/2026-05-issue-63-interpretation-framing-lit-review/findings.md`.
  Coverage spans WMO climate normal definition + alternatives ([Arguez &
  Vose 2011](https://doi.org/10.1175/2010BAMS2955.1)), estimating
  normals when trends exist ([Livezey et
  al. 2007](https://doi.org/10.1175/2007JAMC1666.1)), time of emergence
  / signal-to-noise framing ([Hawkins & Sutton
  2012](https://doi.org/10.1029/2011GL050087)), and cumulative-impact /
  “loaded dice” framing ([Hansen et
  al. 2012](https://doi.org/10.1073/pnas.1205276109)). Headline finding:
  Hansen et al. (2012) explicitly use the **same 1951–1980 base period
  that cd uses**, providing the strongest direct precedent for cd’s
  baseline window choice across all three lit reviews; combined with
  Arguez & Vose (2011)’s framework, cd’s choice is a defensible
  “alternative climate normal” with cumulative-impact framing for FWCP
  fish-passage planner reporting. After this release, the citation
  backbone for the climate-departure 3-split is complete: 32
  peer-reviewed papers across 4 ragnar stores, with cite-this-for-that
  maps in 4 archived findings.md files ready for the downstream vignette
  wire-up branch.
  ([\#64](https://github.com/NewGraphEnvironment/cd/pull/64))

## cd 0.2.3 (2026-05-05)

- Precipitation + drying methodology literature review (2/3 of the
  climate-departure 3-split; temperature done in v0.2.2, interpretation
  framing forthcoming). Adds
  `scripts/rag_precip_drying_methodology_build.R` and
  `scripts/rag_precip_drying_methodology_query.R`, builds a local ragnar
  DuckDB from 7 peer-reviewed papers (now in the
  `NewGraphEnvironment/climate` Zotero collection), and ships the
  methodology synthesis + 15-row “cite this for that” citation map at
  `planning/archive/2026-05-issue-61-precip-drying-lit-review/findings.md`.
  Coverage spans anthropogenic precip-extremes attribution ([Min et
  al. 2011](https://doi.org/10.1038/nature09763)), Canadian / BC
  adjusted precip dataset methodology ([Mekis & Vincent
  2011](https://doi.org/10.1080/07055900.2011.583910)), VPD
  continental-scale drying ([Ficklin & Novick
  2017](https://doi.org/10.1002/2016JD025855)), VPD ecosystem responses
  ([Grossiord et al. 2020](https://doi.org/10.1111/nph.16485)), drought
  attribution ([Williams et
  al. 2020](https://doi.org/10.1126/science.aaz9600)), drought framework
  ([Trenberth et al. 2014](https://doi.org/10.1038/nclimate2067)), and
  20th-century hydroclimate signal ([Marvel et
  al. 2019](https://doi.org/10.1038/s41586-019-1149-8)). Headline
  finding: the v0.1.1 vignette claim that “soils dry from both ↓P and
  ↑ET” is now backed by Ficklin & Novick (2017) rising-VPD continental
  drying + Williams (2020) anthropogenic-warming attribution of NA
  megadrought + Trenberth (2014) Penman-Monteith drought framework.
  Macos Zotero auto-restart pattern (`osascript quit` + `open -a` + 30 s
  wait) automated the BBT key generation step end-to-end (added to
  `soul#43` for `/lit-search` + `/zotero-api`).
  ([\#62](https://github.com/NewGraphEnvironment/cd/pull/62))

## cd 0.2.2 (2026-05-05)

- Temperature-departure methodology literature review (1/3 of the
  climate-departure 3-split; precip+drying and interpretation framing
  follow as separate issues). Adds
  `scripts/rag_temp_methodology_build.R` and
  `scripts/rag_temp_methodology_query.R`, builds a local ragnar DuckDB
  from 10 peer-reviewed papers (now in the `NewGraphEnvironment/climate`
  Zotero collection), and ships the methodology synthesis + 18-row “cite
  this for that” citation map at
  `planning/archive/2026-05-issue-58-temperature-lit-review/findings.md`.
  Coverage spans DTR asymmetry methodology ([Karl et
  al. 1993](https://doi.org/10.1175/1520-0477(1993)074%3C1007:ANPORG%3E2.0.CO;2),
  [Easterling et
  al. 1997](https://doi.org/10.1126/science.277.5324.364), [Vose et
  al. 2005](https://doi.org/10.1029/2005GL024379)), Canadian/BC
  temperature trends ([Vincent et
  al. 2018](https://doi.org/10.1080/07055900.2018.1514579)),
  elevation-dependent warming ([Pepin et
  al. 2015](https://doi.org/10.1038/nclimate2563), [Rangwala & Miller
  2012](https://doi.org/10.1007/s10584-012-0419-3)), BC downscaling
  ([Wang et al. 2012](https://doi.org/10.1175/JAMC-D-11-043.1)), the
  climate-fish thermal-stress bridge ([Mantua et
  al. 2010](https://doi.org/10.1007/s10584-010-9845-2)), and salmonid
  thermal envelope ([Eaton & Scheller
  1996](https://doi.org/10.4319/lo.1996.41.5.1109), [Richter & Kolmes
  2005](https://doi.org/10.1080/10641260590885861)). Headline finding:
  [`cd_trend()`](https://newgraphenvironment.github.io/cd/reference/cd_trend.md)’s
  raw Mann-Kendall + Theil-Sen aligns with Vincent et al. 2018’s
  Canadian-temperature-trend methodology (Sen slope + Kendall’s τ); raw
  MK is the right call for our 76-year strong-trend series per [Yue &
  Wang 2002](https://doi.org/10.1029/2001WR000861) (cross-rag from snow
  methodology store). Also renames existing `rag_build_*.R` /
  `rag_query_*.R` scripts to `rag_*_build.R` / `rag_*_query.R`
  (`noun_verb` per cd convention).
  ([\#60](https://github.com/NewGraphEnvironment/cd/pull/60))

## cd 0.2.1 (2026-05-04)

- Adds a new `kootenay-lake` vignette covering the southern Kootenays —
  KOTL + LARL + DUNC + SLOC, ~24,200 km². Reads stand-alone alongside
  `peace-fwcp` and uses the v0.2.0 snow variables to tell a snow-pack
  story for a region with a sharp east-west precipitation gradient
  (Selkirks vs Purcells). Headline regional findings (2015-2025 vs
  1951-1980): annual SWE -23%, annual snowfall -15%, freshet shift -12.6
  days earlier, annual precipitation -7% (p = 0.02). Total annual
  snowfall is dropping, not just melt timing shifting — consistent with
  [Knowles et al. 2006](https://doi.org/10.1175/JCLI3850.1)’s threshold
  finding that significant snowfall-fraction declines occur where winter
  wet-day Tmin \> -5 °C. Adds a per-watershed-group facet view and
  `data-raw/qa_snow_validation_kootenay_lake.R` ASWS cross-check (5
  sites, 74 paired station-years, pooled r = 0.90, mean bias -54%,
  bias-stable). New bundled assets:
  `inst/extdata/example_aoi_kootenay_lake.gpkg`,
  `inst/extdata/context_kootenay_lake.gpkg`,
  `inst/vignette-data/kootenay_lake.rds`.
  ([\#57](https://github.com/NewGraphEnvironment/cd/pull/57))

## cd 0.2.0 (2026-05-04)

- Adds 8 snow-related variables for hydrology departure analysis. Four
  monthly natives (`swe`, `snowfall`, `snowmelt`, `snow_cover`) ship as
  12-band/year COGs alongside the existing 7 climate variables; four
  annual derived scalars (`swe_max`, `snowfall_fraction`,
  `snowmelt_doy_50`, `snowmelt_rate_peak`) ship as 1-band/year COGs. New
  `pct_point_diff` anomaly type in
  [`cd_anomaly()`](https://newgraphenvironment.github.io/cd/reference/cd_anomaly.md)
  for `snow_cover` and `snowfall_fraction` (already-percentage
  variables). New “Snowpack” section in the FWCP Peace vignette with
  seasonal-curve table, four annual time-series plots, per-ecoregion
  view, and citation-grounded interpretation; ASWS QA cross-check at 4
  BC stations confirms bias is stable over time even where absolute
  values are biased. Producer pipeline extends with
  `scripts/backfill_edh_snow.py` (first place ECMWF’s accumulation-reset
  trick lands in code). Also bug-fix in `cd_stac_item()` filename
  parsing (substring match was mis-routing variables whose names contain
  other variable names — `swe_max` was being filed under `swe`).
  Headline finding: regional summer SWE has collapsed by 75% over the
  record, freshet-timing shift is uniform across all 5 ecoregions at ~1
  day/decade earlier melt.
  ([\#55](https://github.com/NewGraphEnvironment/cd/pull/55))

## cd 0.1.7 (2026-05-04)

- Snow-methodology literature review for the upcoming “Snowpack”
  vignette section. Adds `scripts/rag_build_snow_methodology.R` and
  `scripts/rag_query_snow_methodology.R`, builds a local ragnar DuckDB
  from 11 peer-reviewed papers (now in the
  `NewGraphEnvironment/hydrology` Zotero collection), and ships the
  methodology synthesis + 15-row “cite this for that” citation map at
  `planning/archive/2026-05-issue-53-snow-lit-review/findings.md`.
  Headline finding:
  [`cd_trend()`](https://newgraphenvironment.github.io/cd/reference/cd_trend.md)’s
  raw Mann-Kendall + Theil-Sen (no prewhitening) is methodologically
  correct for our 76-year series with strong trends per [Yue & Wang
  2002](https://doi.org/10.1029/2001WR000861) — prewhitening would
  *underestimate* slope when a real trend exists.
  ([\#54](https://github.com/NewGraphEnvironment/cd/pull/54))

## cd 0.1.6 (2026-05-03)

- Producer-side refactor. Extracted shared safeguards (single-instance
  pgrep guard, exponential-backoff retry, atomic GeoTIFF write,
  timestamped logging, EDH token loader) from
  `scripts/backfill_edh_all.py` into a new `scripts/_lib.py`, and ported
  them to the sibling `scripts/backfill_edh_tmax_tmin.py` (which
  previously had none). Adds a `backup_before_delete()` helper codifying
  the on-disk pattern at `data/backfill/monthly/_cds_backup/`. No
  consumer-side changes; sets up the planned snow-variables backfill
  ([\#48](https://github.com/NewGraphEnvironment/cd/issues/48)) to
  inherit the safeguards via a single import.
  ([\#52](https://github.com/NewGraphEnvironment/cd/pull/52))

## cd 0.1.5 (2026-05-02)

- Adds a “Watershed Groups Across Ecoregions” section to the
  `peace-fwcp` vignette: a map of the 16 canonical FWCP Peace watershed
  groups labelled with codes on top of ecoregion fills, plus a table
  showing the percent of each watershed group’s area falling in each of
  the five ecoregions. Lets readers map per-ecoregion climate departure
  findings (precipitation up only in BMP and NRM) onto the
  watershed-group reporting unit. Canonical 16-WSG list (CARP, CRKD,
  FINA, FINL, FIRE, FOXR, INGR, LOMI, MESI, NATR, OSPK, PARA, PARS,
  PCEA, TOOD, UOMI) hardcoded in `data-raw/example_context_fwcp_peace.R`
  for reuse — UPCE and MURR dropped because they sit mostly outside the
  FWCP boundary. Recent vs Pre-warming consolidated into one table. All
  six vignette tables now render with single, clean bookdown captions
  (`label = NA` + `caption = "..."` pattern).
  ([\#47](https://github.com/NewGraphEnvironment/cd/issues/47))

## cd 0.1.4 (2026-05-01)

KOTL vignette removed. `peace-fwcp` is now the canonical worked example
— it covers everything KOTL did at higher fidelity (regional +
per-ecoregion + day-night asymmetry + plain-language explainers +
interpretation), and dropping the second live-S3 vignette saves ~60 s
per pkgdown render and removes the last `/vsicurl/` flake surface from
the doc build. KOTL polygon assets stay in `inst/extdata/` because the
README quick-start still uses them. Future direction (single-vignette
snowpack story or split vignettes by AOI scale) deferred until snow-pack
variables land — see
[\#49](https://github.com/NewGraphEnvironment/cd/issues/49).
([\#50](https://github.com/NewGraphEnvironment/cd/pull/50))

## cd 0.1.3 (2026-05-01)

CI fragility patch. The `peace-fwcp` vignette previously re-fetched ~144
`/vsicurl/` COG range requests on every pkgdown render; one transient
flake failed the whole build. Heavy data is now pre-computed by
`data-raw/peace_fwcp_vignette_data.R` and shipped under
`inst/vignette-data/` (160 KB rds + 6 KB tif). Vignette loads via
[`system.file()`](https://rdrr.io/r/base/system.file.html) and renders
in ~10 s instead of ~6 min. Live
[`cd_catalog()`](https://newgraphenvironment.github.io/cd/reference/cd_catalog.md)
read kept as the consumer entry-point demonstration.
([\#45](https://github.com/NewGraphEnvironment/cd/issues/45))

## cd 0.1.2 (2026-04-30)

Vignette and docs patch. New `peace-fwcp` vignette runs the consumer
pipeline on a regional administrative AOI (FWCP Peace Region, ~73,000
km², ~11x KOTL) — catalog → extract → trends → recent vs pre-warming →
spatial map → per-ecoregion breakdown across the five BC ecoregions
intersecting the region, with faceted time-series carrying both 75-yr
and 45-yr Theil-Sen trend lines, a wide roll-up table, day-night
asymmetry section (textbook signal does show up here, unlike KOTL), and
three-finding interpretation. Plain-language explainers for trend
windows, WMO climate normal, and “warming has accelerated/slowed”
framing. README gains a Data section with the catalog URL and the
`/vsicurl/` direct-read pattern so the COGs are usable outside R (QGIS,
gdalcubes, rasterio). Issue
[\#43](https://github.com/NewGraphEnvironment/cd/issues/43) filed for
[`cd_compare()`](https://newgraphenvironment.github.io/cd/reference/cd_compare.md)
to gain a proper window-vs-window p-value.
([\#42](https://github.com/NewGraphEnvironment/cd/issues/42))

## cd 0.1.1 (2026-04-15)

Vignette and docs patch. The `climate-departure` vignette gained a
“Daytime Highs and Overnight Lows” section using the tmax/tmin variables
now on STAC, with honest framing for the example watershed (the textbook
day-night asymmetry doesn’t show at Kootenay Lake — the dominant signal
is summer daytime maximum, the temperature envelope for salmonid thermal
stress in tributaries). Existing maps now clip context layers and mask
departure rasters to the watershed group polygon for tighter framing.
Interpretation section corrected: precipitation has declined ~10%
(statistically significant) and soils are drying due to both falling
precipitation and rising evapotranspiration. README quick-start fixed
(was referencing files that don’t exist) and now links to the live
pkgdown vignette.
([\#39](https://github.com/NewGraphEnvironment/cd/issues/39))

## cd 0.1.0 (2026-04-14)

CRAN release: 2020-10-22

First minor release. Producer pipeline migrated from Copernicus CDS to
DestinE Earth Data Hub (Zarr). Same ERA5-Land data at the same 9 km
native grid, no rate limiting, ~5x faster fetches. All 7 cd variables
(tmax, tmin, tmean, prcp, vpd, rh, soil_moisture) regenerated on a
single internally-consistent EPSG:4326 BC grid. Monthly GitHub Action
rewired to use EDH. Consumer API unchanged —
[`cd_catalog()`](https://newgraphenvironment.github.io/cd/reference/cd_catalog.md)
and friends work exactly as before against the refreshed STAC catalog on
`s3://stac-era5-land`. See [pkgdown
reference](https://newgraphenvironment.com/cd/reference/) for the
current function list.
([\#36](https://github.com/NewGraphEnvironment/cd/issues/36))

## cd 0.0.0.9000

Initial development version. Consumer and producer pipelines for
ERA5-Land climate departure analysis.
