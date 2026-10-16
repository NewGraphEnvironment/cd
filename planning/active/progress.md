# Progress — Vignettes: per-ecoregion prcp trend is % of normal per year but labelled mm/yr (#102)

## Session 2026-10-15 (PDT)

- Plan-mode exploration — phases approved by user (Kootenay facet caption folded in at the gate)
- Created branch `102-vignettes-per-ecoregion-prcp-trend-is-of` off main
- Scaffolded PWF baseline from issue #102 with approved phases
- Next: start Phase 1

## Session 2026-10-16 (UTC)

- Phase 1 `bddea85`, Phase 2 `e95cad7` + `4a2f676` (PTR name, found while writing the caption), Phase 3 issues fish_passage_peace_2025_reporting#50 and fish_passage_skeena_2025_reporting#21
- Both articles rendered with the branch installed; table headers and captions verified in the HTML
- Plan review (Plan agent) landed after Phases 1-3: triage in `review-plan.md`; fixes in Phase 4; out-of-scope Kootenay prose filed as cd#146
- Code-check round 1: Clean (`review-round1.md`)
- Caption assertions tested against the committed rds by sourcing the block with `ecoregion_results` read from it: both pass, and five planted defects (SBF significant, TOP slope up, NCM 1981 significant, OMM significant, NRM slope down) each stop with the claim's name
- Code-check round 2 (`review-round2.md`): two fragile findings, one inside the round-1 assertion fix ("all four" unchecked) and a stale findings.md line. Fixed; caption assertions enumerated clause by clause (findings.md) and mutation-tested, 11 of 11 stop
- Code-check round 3 (`review-round3.md`): the Kootenay vignette filters ecoregions to >50 km², so TOP is not shown; the facet-prcp caption ("all four ... not in SBF or TOP"), the map-wsgs caption (TOP "on the western edge") and the round-2 guard were all checked against the unfiltered set. Fixed captions to the three shown, the intro says TOP is left out, data-raw guards read the vignette's threshold; verified on the rendered page and figure. cd#146 corrected (its item 5 premise was wrong)
- Code-check round 4 (`review-round4.md`): the intro's "figures and tables ... leave it out" was false for the WSG overlap table (a second path that bypasses the vignette's filter). Narrowed; Peace data script filters with the vignette's threshold; regex anchored; stale plan quotes annotated; cd#146 item 5 corrected again
