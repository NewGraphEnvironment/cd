# Archive: Temperature-departure methodology lit review (#58)

## Outcome

Established the citation backbone for the **temperature-departure**
sections of the regional vignettes — Issue 1 of the climate-departure
3-split lit reviews (precip+drying = #61, interpretation framing
forthcoming). 10 peer-reviewed papers added to the
`NewGraphEnvironment/climate` Zotero collection (key `8MH9LCC9`),
local ragnar DuckDB at `data/rag/temp_methodology.duckdb` (gitignored,
677 chunks, 10 sources), and a synthesis-plus-citation-map
`findings.md` ready for the downstream vignette branch to consume
selectively per the plain-language philosophy
(`feedback_vignette_citations_sparse.md`). Released as **v0.2.2**
(patch).

## Headline findings

1. **`cd_trend()`'s raw Mann-Kendall + Theil-Sen aligns with Vincent
   et al. 2018's Canadian temperature trend methodology** (Sen slope
   + Kendall's τ). Vincent's iterative lag-1 AC handling is a
   refinement we don't apply, but raw MK is the correct call for our
   76-year strong-trend series per Yue & Wang 2002 (cross-rag from
   snow methodology store). **Our methodology is consistent with the
   literature consensus on the trend-test question for both snow and
   temperature.**
2. **Karl 1993 is the canonical DTR-asymmetry quote**: minimum
   temperature rose at 3× the rate of maximum (0.84 vs 0.28 °C
   1951–90 NH); Vose 2005 updates to 0.141 / 0.204 / -0.066 °C/dec
   for max / min / DTR over 1950-2004 (71% global land coverage).
3. **EDW (elevation-dependent warming) is real but heterogeneous**
   per Pepin 2015 + Rangwala & Miller 2012 — important caveat for any
   "BC mountain AOI warmed faster" claim in the vignette. Mechanism
   review covers snow-albedo, water vapour, latent heat, aerosols.
4. **Salmonid thermal envelope citations are now bedded down**:
   Eaton & Scheller 1996 (foundational US 57-species analysis),
   Mantua 2010 (PNW salmon climate-stress framing), and Richter &
   Kolmes 2005 (PNW maximum-temperature criteria for chinook, coho,
   chum, steelhead). Direct backing for the v0.1.1 "summer daytime
   maximum is the salmonid thermal envelope" claim.
5. **No direct ERA5-Land 2m-temperature validation paper for BC** in
   our corpus — documented as a known caveat. Cross-references via
   Vincent 2018 / Karl 93 / Vose 05 trend benchmarks instead.

## Citation map

The "cite this for that" table at the end of `findings.md` is an
**18-row menu**, not an order. Per the plain-language vignette
philosophy (memory `feedback_vignette_citations_sparse.md`), the
downstream vignette branch picks sparingly — citations only for
authorities on findings actually visible in the AOI's graphs/tables.
BBT-auto-derived keys are baked into the table, ready for `[@key]`
markers downstream.

## Reproducing the rag store

`data/rag/temp_methodology.duckdb` is gitignored. To rebuild:

1. Download the 10 PDFs from Zotero Web API to
   `data/rag/temp_methodology_pdfs/` (one file per local label,
   filename `<label>.pdf`). The `attachKey` for each paper is
   hardcoded in `scripts/rag_temp_methodology_build.R`.
2. `ollama serve` + `ollama pull nomic-embed-text` (one-time).
3. `Rscript scripts/rag_temp_methodology_build.R` — ~28 s, produces
   677 chunks across 10 sources.

To re-mine: `Rscript scripts/rag_temp_methodology_query.R` →
regenerates `temp_methodology_quotes.md` (raw retrieval, archived
here at the time of merge).

## Side-channel issues filed during this work

- **`soul#43`** — convention update for `/lit-search` + `/zotero-api`
  skills: citation keys must be BBT-auto-derived, never manually set
  in the `extra` field. Caught when the user reviewed my initial
  Phase 2 adds; PATCH'd all 10 to clear the override. Future runs
  will avoid this by following the updated skill guidance.
- **`#59`** — BEC zone-shift lit-review tracker, parked until after
  the 3-split lands.

## Notable execution wrinkles

- **BBT plugin compat split** caught during key-capture: BBT 8.x is
  for Zotero 7, BBT 9.x is for Zotero 8/9. User had BBT 8.0.25 on
  Zotero 9, which auto-disabled the plugin. Updating to BBT 9.x
  restored key generation.
- **Corporate-only authorship** caught for Pepin 2015 (Mountain
  Research Initiative EDW Working Group). CrossRef returned no
  individual authors, so BBT initially fell back to a title-based
  key. PATCH'd in the 21 working-group members from the paper roster
  (N. Pepin first), BBT regenerated to
  `pepin_etal2015Elevationdependentwarming` matching convention.
- **Phase 0 prep** renamed the existing `rag_build_*.R` /
  `rag_query_*.R` scripts to `rag_*_build.R` / `rag_*_query.R`
  (`noun_verb` per cd convention), establishing the pattern before
  adding the 2 new temperature scripts. Touches CLAUDE.md and the
  snow-archive README's "how to reproduce" section.

## Closing ref

- Issue: NewGraphEnvironment/cd#58
- PR: NewGraphEnvironment/cd#60 (squash `fa8d74a`, merged 2026-05-05)
- Release: v0.2.2 (tag pushed)
- Downstream consumer: future vignette wire-up branch (out of scope
  for this issue)
