# Findings — Wire up peace-fwcp.Rmd citations (#67)

## Issue context

Same playbook as #65 (kootenay-lake wire-up), now applied to
peace-fwcp.Rmd. 7 insertions total, 8 unique keys + 1 reuse,
sparingly per the philosophy memory.

## Pre-work read of `peace-fwcp.Rmd`

940-line vignette. Section structure mirrors kootenay-lake exactly
(both share the regional-vignette template per
`project_regional_vignette_template.md` memory). 10 existing
`[@key]` cites all in Snowpack + per-ecoregion-snow +
interp-snow paragraphs from #54.

## Per-AOI differences vs Kootenay

The Peace's climate departure shows **opposite precipitation
signal** to Kootenay:
- Peace: annual precip up 3-4% regionally (significant in 2 of 5
  ecoregions: BMP, NRM); soil moisture flat
- Kootenay: annual precip down ~7% (significant); soil moisture
  flat

This makes the **VPD-driven drying claim more compelling for
Peace** — soil moisture stays flat *despite* more precipitation
arriving, because warmer atmosphere drinks it back. Ficklin &
Novick 2017 is more load-bearing here than in Kootenay.

DTR asymmetry is **stronger in Peace** (0.4 °C cumulative
narrowing) than Kootenay (0.2 °C) — the textbook signal that Karl
1993 documents shows up more clearly here. Cite warranted.

EDW cite (Pepin/Rangwala) lands at L853-864 in Peace's
**Interpretation** section (which explicitly invokes "high-latitude
and high-elevation amplification"), NOT at the Spatial Pattern
section like in Kootenay. Peace's spatial pattern is dominated by
an E-W gradient (windward-of-Rockies), not pure elevation —
Pepin/Rangwala don't cleanly cover windward-slope amplification.

## Source corpus (same as #65)

Pulling from the 4 archived findings.md files (snow #53, temp #58,
precip+drying #61, framing #63). Audit log
(`planning/active/citation_audit.md`) tracks each insertion.

## Proposed insertion candidates

7 high-value insertions identified in Phase 0 read (table in
task_plan.md). Will refine via agent review in Phase 3.
