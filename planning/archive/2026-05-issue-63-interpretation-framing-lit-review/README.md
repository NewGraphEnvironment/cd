# Archive: Interpretation framing methodology lit review (#63)

## Outcome

**Wraps the climate-departure 3-split lit reviews.** Established the
citation backbone for the framing-and-baseline choices in the
regional vignettes — Issue 3 of 3 (snow = #53/v0.1.7, temperature =
#58/v0.2.2, precip+drying = #61/v0.2.3, **interpretation framing =
this issue / v0.2.4**). 4 peer-reviewed papers added to the
`NewGraphEnvironment/climate` Zotero collection (key `8MH9LCC9`),
local ragnar DuckDB at `data/rag/interpretation_framing.duckdb`
(gitignored, 291 chunks, 4 sources), and a synthesis-plus-citation-
map `findings.md` ready for the downstream vignette branch. Released
as **v0.2.4** (patch).

## Headline finding (across the 3-split)

**Hansen et al. (2012) explicitly use the 1951–1980 base period —
the same window cd uses** — providing direct precedent for cd's
baseline-window choice. Combined with Arguez & Vose (2011)'s
framework defining what counts as an "alternative climate normal"
(any departure from the standard WMO 5-attribute definition), cd's
1951–1980 baseline is well-grounded for cumulative-impact ("loaded
dice") reporting at FWCP fish-passage planner level. **The
strongest defense of cd's baseline-window choice across all three
lit reviews.**

## Citation map

11-row menu in `findings.md`. Per the plain-language vignette
philosophy (`feedback_vignette_citations_sparse.md`), the
downstream vignette branch picks sparingly — citations only for
authorities on findings actually visible in the AOI's graphs/
tables. BBT-auto-derived keys are baked into the table.

## Reproducing the rag store

`data/rag/interpretation_framing.duckdb` is gitignored. To rebuild:

1. Download the 4 PDFs from Zotero Web API to
   `data/rag/interpretation_framing_pdfs/` (one file per local
   label, filename `<label>.pdf`). The `attachKey` for each paper
   is hardcoded in `scripts/rag_interpretation_framing_build.R`.
2. `ollama serve` + `ollama pull nomic-embed-text` (one-time).
3. `Rscript scripts/rag_interpretation_framing_build.R` — ~10 s,
   produces 291 chunks across 4 sources.

To re-mine: `Rscript scripts/rag_interpretation_framing_query.R` →
regenerates `interpretation_framing_quotes.md` (raw retrieval,
archived here at the time of merge).

## 3-split scoreboard (now complete)

After this issue lands, the citation backbone for the climate-
departure narrative is complete:

| Issue | Topic | Release | Papers | Chunks | Sources | Archive |
|---|---|---|---|---|---|---|
| #53 | Snowpack | v0.1.7 | 11 | 1006 | 11 | `2026-05-issue-53-snow-lit-review/` |
| #58 | Temperature | v0.2.2 | 10 | 677 | 10 | `2026-05-issue-58-temperature-lit-review/` |
| #61 | Precip + drying | v0.2.3 | 7 | 526 | 7 | `2026-05-issue-61-precip-drying-lit-review/` |
| #63 | Interpretation framing | v0.2.4 | 4 | 291 | 4 | (this archive) |

**Total:** 32 peer-reviewed papers, ~2,500 chunks across 4 ragnar
stores. Downstream vignette wire-up branch picks `[@key]` markers
from these 4 findings.md files selectively per the plain-language
philosophy.

## Notable execution wrinkles

- **Lessons from #58 + #61 applied cleanly.** No `Citation Key:`
  overrides in `extra` (BBT auto-derives per `soul#43`). All 4
  papers had ≥2 individual creators per CrossRef (no Pepin-style
  PATCH needed). macOS auto-restart fired without user prompt and
  all 4 BBT keys captured first try (~30 s wait sufficient).
- **Wiken 1986 + Demarchi 2011 BC ecoregion gov refs dropped from
  formal scope.** The BC-ecoregion-as-reporting-unit grounding is
  established convention in BC fisheries / ecology and can be
  described in vignette prose without a heavy `[@key]` cite.
- **Lit review was the leanest of the three** — 4 new papers vs 7
  for #61 and 10 for #58. The framing topic surface is narrower;
  many of the framing references were already in the climate
  collection (Mora 2013, Pauly 1995 + descendants, IPCC AR6).

## Closing ref

- Issue: NewGraphEnvironment/cd#63
- PR: NewGraphEnvironment/cd#64 (squash `7f844a4`, merged 2026-05-05)
- Release: v0.2.4 (tag pushed)
- Downstream consumer: future vignette wire-up branch (out of scope
  for this issue and the entire 3-split)
- Next pickup if reporting needs warrant: #59 BEC zone shifts
  tracker
