# Task: Wire up peace-fwcp.Rmd citations from 3-split lit reviews (#67)

## Problem

`peace-fwcp.Rmd` non-snow interp paragraphs make claims with zero
peer-reviewed citations. The 3-split lit reviews + #65 kootenay
wire-up established the playbook; this is the second consumer.

## Pre-work findings (Phase 0)

940-line vignette. Same section structure as kootenay-lake.
Existing 10 cites all in Snowpack + per-eco-snow + interp-snow
(inherited from #54). Non-snow sections have zero cites.

**Identified candidate insertions (7 total):**

| # | Vignette location | Proposed `[@key]` | Why warranted |
|---|---|---|---|
| 1 | L176 Trends ("pre-warming reference 1951–1980") | `@hansen_etal2012Perceptionclimate` | Hansen 12 uses identical base period |
| 2 | L186 Trends (WMO climate normal) | `@arguez_vose2011DefinitionStandard` | Defines WMO 5-attribute normal — grounds cd's alternative |
| 3 | L238 Daytime/Overnight ("Karl et al. 1993" prose) | `@karl_etal1993NewPerspective` | Convert prose ref; **DTR asymmetry stronger in Peace** (0.4 °C narrowing) than Kootenay (0.2 °C) — directly visible in dtr plot |
| 4 | L859-864 Interpretation ("high-latitude and high-elevation amplification") | `@pepin_etal2015Elevationdependentwarming`, `@rangwala_miller2012Climatechange` | Vignette explicitly invokes EDW + heterogeneity |
| 5 | L887-897 Interpretation/drying (VPD up despite precip rise in places) | `@ficklin_novick2017Historicprojected` | **Stronger Peace case than Kootenay** — soil moisture flat *despite* precip rising 3-4% in 2 ecoregions; pure VPD-driven evaporative-demand effect |
| 6 | L925-938 Interpretation/salmonids | `@mantua_etal2010Climatechange`, `@eaton_scheller1996Effectsclimate` | Climate-stream-temp-fish bridge |
| 7 | L937-938 Interpretation/Fraser ("Kang et al. 2016" prose) | `@kang_etal2016ImpactsRapidly` | Convert prose ref; Kang's Fraser AOI directly comparable to Peace headwaters |

**Skipped from initial plan:** Spatial Pattern (L554-560) EDW cite.
Peace's dominant warming gradient is E-W (windward-of-Rockies),
not elevation-based. Pepin/Rangwala doesn't cleanly support
windward-slope amplification. Don't decorate.

## Phase 1 — Build audit log
- [ ] Create `planning/active/citation_audit.md` mirroring #65's
      structure (1 row per cite with vignette excerpt, source quote,
      rag store + topic, paraphrase as written, why warranted)

## Phase 2 — Insert citations
- [ ] Edit `peace-fwcp.Rmd` for 7 insertions
- [ ] Smooth prose where citation reads awkwardly

## Phase 3 — Independent review agent
- [ ] Spawn Explore subagent with audit log + 4 ragnar quotes
      archives + source PDFs; verify each paraphrase faithful;
      flag drift / overreach / decoration / hallucinated quotes
- [ ] Address feedback

## Phase 4 — Render check
- [ ] Regenerate `vignettes/references.bib` via `rbbt::bbt_update_bib(
      path_rmd = "vignettes/peace-fwcp.Rmd", ...)` — but careful:
      this regenerates for peace-fwcp KEYS only and would drop
      kootenay-only keys. **Use combined regeneration:** detect
      keys from both Rmds, union the sets, then write bib.
- [ ] Render vignette locally to confirm cites resolve

## Phase 5 — PR + release
- [ ] `/code-check` clean
- [ ] Atomic commits — Phase 1 audit, Phase 2 vignette edits,
      Phase 3 review fixes, Phase 4 bib regen
- [ ] PR with `Fixes #67`. SRED tag in PR body
- [ ] After merge: `/planning-archive` → bump v0.2.5 → v0.2.6

## Validation
- [ ] 7 (±agent feedback) `[@key]` markers added
- [ ] Audit log filled out with 5 fields per row
- [ ] Review agent signed off
- [ ] Vignette renders cleanly with all cites resolving
- [ ] kootenay-lake.Rmd cite resolution NOT broken by bib regen
- [ ] Snowpack-section citations untouched

## Out of scope
- **`kootenay-lake.Rmd`** — done in #65/v0.2.5
- **New lit reviews**
- **Vignette section restructuring**
- **FWCP Peace cross-references in `kootenay-lake.Rmd`** —
  separate small follow-up

## Notes
- Branch: `67-peace-vignette-wireup`
- BBT 9.x active; auto-restart pattern not needed (no new Zotero
  adds — all keys already in `NewGraphEnvironment/climate`)
- `vignettes/references.bib` currently has 18 entries from #65;
  after this issue should have all keys cited in EITHER vignette
  (union)
