# Task: Wire up kootenay-lake.Rmd interpretation citations from 3-split lit reviews (#65)

## Problem

The `kootenay-lake.Rmd` vignette interpretation paragraphs make
claims about temperature, precipitation, snowpack, and drying that
currently land on **zero** peer-reviewed citations in the non-snow
sections. The 3-split climate-departure lit reviews (#53/v0.1.7,
#58/v0.2.2, #61/v0.2.3, #63/v0.2.4) built the citation backbone
specifically for this consumer; time to wire it up.

## Scope

`kootenay-lake.Rmd` only. Peace-FWCP wire-up = separate downstream
issue. Per `feedback_vignette_citations_sparse.md` memory: cite
sparingly, only where finding is visible in graphs/tables, plain
language, no decoration.

## Pre-work findings (Phase 0 — already complete in this session)

Read the vignette end-to-end. Existing citations (~14) all in the
Snowpack + Per-Ecoregion-Snow + Interpretation-snow sections,
inherited from #54. **Non-snow sections have zero `[@key]` markers**
but several prose-style author refs ready to convert.

**Identified candidate insertions (7 total — sparsely applied):**

| # | Vignette location | Proposed `[@key]` | Why warranted |
|---|---|---|---|
| 1 | Line 184 ("pre-warming reference period 1951–1980") | `@hansen_etal2012Perceptionclimate` | Hansen 12 uses identical 1951–1980 base period — strongest direct precedent for cd's choice |
| 2 | Line 195–196 (WMO climate normal mention) | `@arguez_vose2011DefinitionStandard` | Defines what makes a "WMO climate normal" — grounds cd's "alternative normal" choice |
| 3 | Line 246 (existing "Karl et al. 1993" prose) | `@karl_etal1993NewPerspective` | Convert prose ref to proper cite — DTR asymmetry foundational |
| 4 | Line 581–587 (Spatial Pattern, "high-elevation amplification signal") | `@pepin_etal2015Elevationdependentwarming`, `@rangwala_miller2012Climatechange` | EDW review papers — directly visible in spatial pattern map (Figure) showing elevation-correlated warming |
| 5 | Line 984–994 (Interpretation: "atmosphere is drying", VPD up) | `@ficklin_novick2017Historicprojected` | VPD continental-scale drying — exact match to the vignette's "double-dipping" finding (Δ% in cmp_combined table shows VPD up) |
| 6 | Line 1012–1018 (Interpretation: stream temp + salmon thermal stress) | `@mantua_etal2010Climatechange`, `@eaton_scheller1996Effectsclimate` | Climate→stream-temp bridge — load-bearing for FWCP fish-passage planner audience; visible in summer-Tmax warming (Trends) |
| 7 | Line 1025 (existing "Kang et al. 2016" prose for Fraser freshet) | `@kang_etal2016ImpactsRapidly` | Convert prose ref to proper cite |

## Phase 1 — Build audit log

- [ ] Create `planning/active/citation_audit.md` with one row per
      `[@key]` insertion: vignette excerpt, source quote/paraphrase,
      rag store + topic where retrieved, my paraphrase as written,
      why warranted

## Phase 2 — Insert citations into vignette

- [ ] Edit `kootenay-lake.Rmd` for the 7 insertions above. Use
      `[@key]` for parenthetical and `@key` (or `@key [-@key]`) for
      narrative form per pandoc citeproc convention.
- [ ] Spell out acronyms on first use: DTR, EDW, FWCP, IPCC, WMO
      (most already spelled out — verify)
- [ ] Smooth prose where the citation reads awkwardly

## Phase 3 — Independent review agent

- [ ] Spawn an Explore subagent with: the audit log, the 4 ragnar
      stores under `data/rag/`, source PDFs in
      `data/rag/<topic>_methodology_pdfs/`. Task: verify each
      paraphrase in the audit log is faithful to the source quote,
      flag any drift / overreach / unsupported claims / BS.
- [ ] Address agent feedback in vignette + audit log

## Phase 4 — Render check

- [ ] Local pkgdown render of the kootenay-lake vignette to confirm:
      (a) all `[@key]` markers resolve via rbbt::bbt_write_bib,
      (b) References section auto-populates correctly,
      (c) no formatting regression in the surrounding prose

## Phase 5 — PR + release

- [ ] `/code-check` clean before commit (lint + tests — though
      vignette-only changes shouldn't affect either)
- [ ] Atomic commits — Phase 1 audit, Phase 2 vignette edits,
      Phase 3 agent review fixes
- [ ] PR with `Fixes #65`. SRED tag in PR body
- [ ] After merge: `/planning-archive` → bump v0.2.4 → v0.2.5

## Validation

- [ ] 7 (±2 after agent review) `[@key]` markers added to
      kootenay-lake.Rmd
- [ ] Audit log has one row per cite with the 5 fields filled in
- [ ] Review agent has signed off (or flagged issues addressed)
- [ ] Vignette renders cleanly with all cites resolving
- [ ] Non-snow sections now have authoritative backing for the
      load-bearing claims (warming, EDW, VPD/drying, climate-fish
      bridge)
- [ ] Snowpack section citations untouched (already wired in #54)
- [ ] No vignette section restructuring; only `[@key]` additions
      + minor prose smoothing

## Out of scope

- **`peace-fwcp.Rmd` wire-up** — separate downstream issue
- **New lit reviews** — 3-split + snow are the source corpus
- **Vignette section restructuring**
- **FWCP Peace cross-references in lines 528, 973, 996** —
  surfaced during pre-work read; per
  `feedback_thorough_cross_reference_removal.md` memory these
  shouldn't be in a stand-alone vignette, but **flagging as
  separate concern** rather than expanding scope on this branch.
  Will note in progress.md as a separate follow-up.
- **Updating `vignettes/references.bib` content beyond what
  rbbt::bbt_write_bib regenerates** — automatic at render time

## Notes for execution

- Branch: `65-kootenay-vignette-wireup`
- Citation key resolution: rbbt::bbt_write_bib at render time pulls
  from the live Zotero library, so any new BBT keys we use (which
  all came from #58/#61/#63 lit reviews) auto-resolve into
  references.bib
- BBT 9.x active; no compat issues expected
