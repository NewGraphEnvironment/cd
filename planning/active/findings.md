# Findings — Wire up kootenay-lake.Rmd citations (#65)

## Issue context (verbatim from #65)

The `kootenay-lake.Rmd` vignette interpretation paragraphs make
claims about temperature, precipitation, snowpack, and drying that
currently land on zero peer-reviewed citations in the non-snow
sections. The 3-split climate-departure lit reviews built the
citation backbone specifically for this consumer; time to wire it
up.

## Pre-work read of `kootenay-lake.Rmd`

1031-line vignette. Section structure:
- L50 Area of Interest
- L127 Connect to the Data Catalog
- L154 Extract Climate Time Series
- L182 Trends
- L240 Daytime Highs and Overnight Lows
- L296 Snowpack (heavily cited from #54 — 14 `[@key]` markers in
  this + per-ecoregion + interp-snow paragraphs)
- L512 Recent vs Pre-warming
- L576 Spatial Pattern
- L627 Per-Ecoregion Variation
- L879 Watershed Groups Across Ecoregions
- L959 Interpretation
- L1031 References

Existing `[@key]` markers (14): all in Snowpack section + Per-
Ecoregion-Snow + Interpretation-snow. **Non-snow sections have
zero cites.**

## Pre-work concern flagged (out of scope, separate follow-up)

3 FWCP Peace cross-references slipped back in despite the v0.2.1
scrub:
- L528: "and unlike the FWCP Peace just to the north..."
- L973: "diverges sharpest from the FWCP Peace just north..."
- L996: "diverge from the FWCP Peace pattern..."

Per `feedback_thorough_cross_reference_removal.md` memory, these
shouldn't be in a stand-alone vignette. **Out of scope for #65**
(citation wire-up only) — flagged here for the user to call as a
separate follow-up issue.

(The Fraser Basin reference at L1024-1025 is fine — different
region used as a literature anchor for freshet timing, not a
cross-ref to the sibling Peace vignette.)

## Source corpus

Pulling `[@key]` markers from the 4 cite-this-for-that maps:
- `planning/archive/2026-05-issue-53-snow-lit-review/findings.md`
- `planning/archive/2026-05-issue-58-temperature-lit-review/findings.md`
- `planning/archive/2026-05-issue-61-precip-drying-lit-review/findings.md`
- `planning/archive/2026-05-issue-63-interpretation-framing-lit-review/findings.md`

For each candidate insertion, the audit log
(`planning/active/citation_audit.md`) tracks: vignette excerpt,
source quote/paraphrase, rag store + topic, my paraphrase as
written, why warranted.

## Plan-mode insertion candidates

7 high-value insertions identified in Phase 0 read (table in
task_plan.md). Will refine/cull during Phase 1 audit-log build
and Phase 3 review-agent feedback.

## Citation audit log

See `planning/active/citation_audit.md` (built during Phase 1).
