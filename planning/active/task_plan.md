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

- [ ] Read current vignette end-to-end; list every figure chunk
- [ ] Confirm AOI watershed group code / fwapg query (or note that we need to add one)
- [ ] Decide on the 2-3 tmax/tmin angles to actually ship (don't cram all four)
- [ ] Sketch figure list in findings.md so reviewer can preview the narrative shape

## Phase 2: Watershed group helper

- [ ] Pull the watershed group polygon containing the example AOI from fwapg
- [ ] Cache as an `sf` object early in the vignette setup chunk
- [ ] Decide: inline fwapg query vs a small helper function (prefer inline unless reused)

## Phase 3: Clip existing maps to watershed group

- [ ] For tmap static figures: `st_intersection(layer, wsg)` on every context layer before plotting
- [ ] For mapgl interactive: `fitBounds` to the WSG extent, add WSG outline as a faint reference layer, don't render features outside
- [ ] Keep the four-corner rule (legend / logo / scale / keymap each in own quadrant)
- [ ] Self-review each rendered figure per cartography convention (legend over least-important terrain, map fills frame, no element overlap)

## Phase 4: tmax/tmin narrative content

Pick 2-3 (not all) of:
- [ ] **Shrinking diurnal range** — plot `tmax - tmin` annual trend with commentary on evapotranspiration / cold-air pooling
- [ ] **Frost days** — count of months per year with `tmin < 0 °C` (or a simpler monthly-proxy). Commentary on pest range / phenology.
- [ ] **Heat stress envelope** — `tmax > threshold` frequency with commentary on salmon thermal stress
- [ ] **VPD × tmax compound** — single hot-dry summer figure showing drought stress signal

Keep prose tight: 1-2 paragraphs per figure.

## Phase 5: Build + verify

- [ ] Render pkgdown locally — check vignette builds and images render
- [ ] Check render time stays ≤ 2 min
- [ ] Verify all figures have captions, cross-references work
- [ ] `lintr::lint_package()` passes
- [ ] `devtools::check()` passes with 0 errors / 0 warnings

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
