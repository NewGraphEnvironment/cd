# Archive: Wire up kootenay-lake.Rmd citations from 3-split lit reviews (#65)

## Outcome

**First downstream consumer of the climate-departure 3-split lit
reviews** (#53/v0.1.7 snow + #58/v0.2.2 temperature + #61/v0.2.3
precip+drying + #63/v0.2.4 framing). Wired up the kootenay-lake
vignette's non-snow interpretation paragraphs with **8 new
BBT-keyed citations + 1 reuse**, sparingly applied per the
`feedback_vignette_citations_sparse.md` philosophy memory ("library
not prescription; cite only authorities for findings visible in
the AOI's graphs/tables, plain language, no decoration"). Released
as **v0.2.5** (patch).

## Citations added (7 insertions, 8 unique new keys)

| # | Vignette section (line) | Citation key | Topic |
|---|---|---|---|
| 1 | Trends (L184) | `@hansen_etal2012Perceptionclimate` | 1951–1980 base period precedent |
| 2 | Trends (L195) | `@arguez_vose2011DefinitionStandard` | WMO climate normal definition |
| 3 | Daytime/Overnight (L246) | `@karl_etal1993NewPerspective` | DTR asymmetry foundational |
| 4 | Spatial Pattern (L584) | `@pepin_etal2015Elevationdependentwarming` + `@rangwala_miller2012Climatechange` | EDW + heterogeneity caveat |
| 5 | Interpretation/drying (L984) | `@ficklin_novick2017Historicprojected` | VPD continental-scale drying |
| 6 | Interpretation/salmonids (L1014) | `@mantua_etal2010Climatechange` + `@eaton_scheller1996Effectsclimate` | Climate→stream-temp→fish bridge |
| 7 | Interpretation/Fraser (L1027) | `@kang_etal2016ImpactsRapidly` (reuse) | Fraser freshet advance — prose→[@key] format consistency |

Snow-section citations from #54 untouched (already wired up cleanly
in v0.1.7).

## Audit trail

`citation_audit.md` is the load-bearing artifact — one row per
insertion with: vignette excerpt, source quote/paraphrase, rag
store + topic where retrieved during lit-review mining, paraphrase
as written, and why warranted (visible-in-vignette feature). The
"what is where by who said what where" trail.

## Independent verification

Spawned an Explore subagent before merge to verify each audit row
against the source quote archives + PDFs. **All 7 rows passed**:
no hallucinated quotes, paraphrases faithful, all cites
load-bearing (not decorative). One minor scope concern flagged:

- **Ficklin & Novick 2017 paraphrase** initially said "documented
  across the western United States" but the paper covers the
  entire continental US (1979–2013) with western/southern
  concentration in historical results. **Fixed inline before
  merge** to "documented for the United States as a whole, with
  the strongest historical VPD increases concentrated in the
  western and southern portions, driven by combined air-
  temperature increases and relative-humidity declines."

## `vignettes/references.bib` regenerated

Via `rbbt::bbt_update_bib(path_rmd = "vignettes/kootenay-lake.Rmd",
path_bib = "vignettes/references.bib", overwrite = TRUE)`. Now 18
entries (was 11):
- 8 new (arguez, eaton, ficklin, hansen, karl, mantua, pepin,
  rangwala)
- 9 carried forward from #54 snow lit review wire-up
- 1 dropped (`munoz-sabater_etal2021` wasn't actually cited in
  this vignette — rbbt correctly dropped it)
- 1 reused (kang_etal2016 was already cited in the snow section)

## Side-channel observations (out of scope for #65)

3 FWCP Peace cross-references at L528, L973, L996 slipped back in
despite the v0.2.1 scrub (per `feedback_thorough_cross_reference_removal.md`
memory). **Not touched on this branch** — flagged in `progress.md`
as a separate small follow-up issue worth filing. Vignettes are
stand-alone; cross-region comparisons belong in PR descriptions.

## Closing ref

- Issue: NewGraphEnvironment/cd#65
- PR: NewGraphEnvironment/cd#66 (squash `18b0091`, merged 2026-05-05)
- Release: v0.2.5 (tag pushed)
- Next consumer: peace-fwcp.Rmd citation wire-up (separate
  downstream issue) + the Peace cross-ref scrub follow-up
