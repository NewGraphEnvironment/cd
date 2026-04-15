# Task Plan: Vignette — tmax/tmin ecological content + map clipping

Issue: NewGraphEnvironment/cd#39
Branch: `39-vignette-tmax-tmin-maps`

## Context

`vignettes/climate-departure.Rmd` currently narrates tmean + soil_moisture
anomalies for a BC watershed AOI (Kootenay Lake). Post-#36 the package also
ships tmax/tmin on STAC, and the existing maps show context layers that
spread beyond the watershed group and dilute the story.

Goal: land two improvements in one focused PR without restructuring the vignette.

## Phase 1: Inspect + plan specific figures

- [x] Read current vignette end-to-end; list every figure chunk
- [x] Confirm AOI watershed group — `example_aoi_kotl.gpkg` IS the WSG, no fwapg needed
- [x] Decide on the 2 tmax/tmin angles to ship: tmax/tmin trend asymmetry + diurnal range
- [x] Existing `data-raw/example_context_kotl.R` already builds context_kotl.gpkg via fwapg

## Phase 2: Watershed group helper

- [x] Not needed — AOI = WSG, vignette-side `st_intersection` is the pragmatic clip

## Phase 3: Clip existing maps to watershed group

- [x] `load-context` chunk: `st_intersection(layer, aoi)` for towns/lakes/rivers/streams/highways
- [x] `spatial-tmean` chunk: `terra::mask(departure, aoi)` so non-WSG cells are NA
- [x] `spatial-sm` chunk: same masking treatment
- [x] Render verified end-to-end

## Phase 4: tmax/tmin narrative content

Shipped 2 of the 4 candidate angles:
- [x] **tmax + tmin annual anomaly** — two `cd_plot_timeseries` chunks side-by-side showing tmin warming faster
- [x] **Diurnal range trend** — DTR = tmax − tmin annual with linear-trend overlay
- [x] Ecological framing in 3 bullets: ET intensification, cold-air pooling weakening, stream thermal regime
- [ ] (Skipped, not blocking) Frost days, heat stress envelope, VPD × tmax — out of scope for this PR

## Phase 5: Build + verify

- [x] Render locally; vignette builds clean (HTML 2.7 MB)
- [x] All figures have captions, cross-references work
- [x] devtools::check ran clean (no-tests run during dev)

## Phase 5b: User review fixes

- [x] Critical look at trend data — narrative now matches actual KOTL signal
- [x] "Day-Night Asymmetry" reframed as "Daytime Highs and Overnight Lows" — diurnal range is flat at KOTL, summer max is the dominant signal
- [x] "Salmonid" not "salmon" (anadromous runs blocked by lower-Columbia dams; FN reintroduction acknowledged)
- [x] Interpretation rewritten: precip down ~10% significant, soils dry from BOTH precip decline AND ET increase
- [x] cd_compare with method="pct_change" added for prcp/soil_moisture
- [x] kableExtra scroll_box on tables 1 (catalog), 3 (baseline), 6 (compare), and the all-trends table
- [x] Disabled bookdown section numbering (number_sections: false)
- [x] kableExtra added to DESCRIPTION Suggests
- [x] README fixed (wrong example_aoi filename + stale "vignette coming soon")

## Phase 6: PR

- [ ] Branch per issue convention, PR to main with `Fixes #39`
- [ ] SRED cross-ref in PR body (`Relates to NewGraphEnvironment/sred-2025-2026#23`)
- [ ] Archive this PWF dir to `planning/archive/` on merge

## Success criteria

- Two clean changes, one PR: tmax/tmin ecological narrative + tightened maps
- Every figure renders correctly in both gitbook and PDF output
- Keeps existing tmean / soil_moisture content intact
- Doesn't change any `R/` function signatures

## Out of scope (explicit)

- No new cd package functions
- No restructuring of existing tmean/soil_moisture content
- No change to the example AOI (Kootenay Lake stays)
- No bulk-rename of `planning/completed/` to `planning/archive/` (separate concern)
