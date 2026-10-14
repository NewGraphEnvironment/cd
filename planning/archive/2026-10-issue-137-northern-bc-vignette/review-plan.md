# Plan review — #137 (background Plan agent, 2026-10-14)

Returned as reply text (Plan agents cannot write); recorded here with my verdict on each.

| # | Finding | Verdict |
|---|---|---|
| B1 | `devtools::check()` never builds vignettes: DESCRIPTION has no `VignetteBuilder` | Confirmed (grep). Gate is now `devtools::install()` + `pkgdown::build_article()`, plus a check that no evaluated chunk touches the network |
| B2 | pkgdown 2.2.0 renders articles with its own html_document, so bookdown figure numbers / `\@ref` do not work | Accepted: figures referred to by name, no numbers |
| O1 | Install before `build_article()` (renders against installed cd) | Accepted |
| O2 | Re-derive the upper/lower Bulkley numbers on the Houston split before writing that sentence | Done in Phase 4 data: tmean +1.9 / +2.0 °C (same change); rule: "same change" only if \|Δ\| < 0.2 °C, asserted |
| O3 | References before prose | Accepted: Phase 6 checks run before the watershed-health section is written |
| O4 | Phase 1 unticked | Stale: ticked in f0da163 |
| G1 | 3-yr window shown per year in the seasonal, melt and summer figures too | Accepted |
| G2 | Show 2023 is not carrying the 3-yr result; weather-vs-climate sentence | Accepted: 2024–2025 mean stored; BULK +2.1 °C without 2023 |
| G3 | Assert no record-low snow | Accepted (stopifnot in data script) |
| G4 | Link the regional vignettes; say they use 2015–2025 | Accepted |
| G5 | Units-in-words, captions-only read, VPD wording, grep rendered HTML not Rmd | Accepted |
| G6 | Label "Williston Reservoir"; registry keys for towns/lines | Label accepted. gq `town`/`streams_all` carry no colours (probe), so only lake / rivers_poly / watershed_group_boundary are used |
| G7 | Bundle full series + plot-ready tables | Full series already bundled; scorecard built in the data script |
| G8 | Extract per AOI; print cell counts | Already per AOI; cell counts added |
| G9 | Suggests for any layout package | patchwork added to Suggests (CRAN) |
| G10 | AOI size budget | Already simplified, 224 KB |
| G11 | regenerate_bib.R as its own checkbox; peace-fwcp header and CLAUDE.md wording; `bibliography:` in YAML | Accepted |
| G12 | Pin or derive the windows | Derived from the catalog's last complete year; prose inline |
| A1 | "Winter" = Jan, Feb, Dec of one calendar year | Confirmed (`cd_aggregate()`); captions say "December, January and February" and never "winter 2022–23" |
| A2 | swe_max is the mean of cell peaks; doy_50 = half the calendar year's melt | Confirmed (`backfill_edh_snow.py:28-30, 290-299`); wording adjusted |
| A3 | One direction lookup for sign/tint | Accepted (`warm_if` column) |
| A4 | Soil moisture change is relative % | Accepted |
| A5 | Glacier cells could dominate swe_max | Not present in BULK: normal peak 225–1,000 mm over 156 cells; guard added anyway (per-cell SD > 0, max < 5,000 mm) |
| A6 | "earliest 30 years" is wrong (record starts 1950) | Already dropped from cd_compare in f0da163; also fixed in research/baseline_period.md |
| A7 | Grid cell is about 6.5 × 11 km, not 9 km | Accepted |
| A8 | Gate each stream-impact row on the data | Accepted: winter precipitation fell 2–5 % over 10 yr, so the "more winter rain" row is cut or reframed to the snowfall-share change |
| A9 | test-cd_variables checks bundled rds tables carrying unit + anomaly_type | Noted: the rds carries neither column beside a lookup |
| S1 | cd_compare default 2015:2025 called "a recent decade" | Into the follow-up issue |
| S2 | "upper + lower = BULK" check is circular | Accepted: replaced with "intersection with BULK clips < 0.5 %" |
| S3 | Name the BC outline source | Done (union of watershed groups) |
| C1 | Two tables (scorecard + streams) vs "one table" | The streams table is the prose section's small table the issue itself asks for; noted |
| C2 | ≤ 3 colours on the map | Accepted: one gq fill for all three groups, named by label |
| C3 | Hard 400-line budget; fig.width ~7 in | Accepted |
| C4 | Precise baseline sentence | Accepted |
