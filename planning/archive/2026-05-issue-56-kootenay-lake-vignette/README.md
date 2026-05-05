# Issue #56 — Kootenay Lake regional vignette

New `vignettes/kootenay-lake.Rmd` covering the southern Kootenays
(KOTL + LARL + DUNC + SLOC, ~24,200 km²). The "keep + expand"
resolution of #49: replace the legacy single-WSG KOTL vignette
(removed in v0.1.4) with a regional vignette that uses the v0.2.0
snow variables to tell a snow-pack story for an east-west
precipitation gradient region. Unlike the FWCP Peace, total annual
snowfall is dropping (-15%), not just snowmelt timing shifting,
and precipitation itself is declining (-7%, p = 0.02). Adds a
per-WSG facet view and the bundled AOI/context geodata + 5-site
ASWS QA cross-check (pooled r = 0.90, mean bias -54%).

Closed by PR #57 → release v0.2.1.
