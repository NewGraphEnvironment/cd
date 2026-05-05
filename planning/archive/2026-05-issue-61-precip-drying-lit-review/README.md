# Archive: Precipitation + drying methodology lit review (#61)

## Outcome

Established the citation backbone for the **precipitation +
drying** sections of the regional vignettes — Issue 2 of the
climate-departure 3-split lit reviews (temperature = #58/v0.2.2
done, **interpretation framing = #63 filed**, BEC zone shifts =
#59 tracker post-3-split). 7 peer-reviewed papers added to the
`NewGraphEnvironment/climate` Zotero collection (key `8MH9LCC9`),
local ragnar DuckDB at `data/rag/precip_drying_methodology.duckdb`
(gitignored, 526 chunks, 7 sources), and a synthesis-plus-citation-
map `findings.md` ready for the downstream vignette branch to
consume selectively per the plain-language philosophy
(`feedback_vignette_citations_sparse.md`). Released as **v0.2.3**
(patch).

## Headline finding

The v0.1.1 vignette claim that "soils dry from both ↓P and ↑ET" is
now backed by:

1. **`@ficklin_novick2017Historicprojected`** — VPD US continental-
   scale drying, "spring, summer, and fall seasons exhibited the
   largest areal extent of significant increases in VPD... caused
   by air temperature increases and relative humidity changes"
2. **`@williams_etal2020Largecontribution`** — anthropogenic warming
   drove ~47% of the 2000–2018 NA megadrought severity, "the second
   driest 19-year period since 800 CE"
3. **`@trenberth_etal2014Globalwarming`** — Penman-Monteith
   evapotranspiration is the right way to compute drought; rebuts
   prior "drought is decreasing globally" claims using proper PDSI
   methodology

The atmospheric-evaporative-demand half of the drying story is
well-grounded in this corpus.

## Citation map

The "cite this for that" table in `findings.md` is a **15-row
menu**, not an order. Per the plain-language vignette philosophy,
the downstream vignette branch picks sparingly — citations only
for authorities on findings actually visible in the AOI's graphs/
tables. BBT-auto-derived keys are baked into the table, ready for
`[@key]` markers downstream.

## Reproducing the rag store

`data/rag/precip_drying_methodology.duckdb` is gitignored. To
rebuild:

1. Download the 7 PDFs from Zotero Web API to
   `data/rag/precip_drying_methodology_pdfs/` (one file per local
   label, filename `<label>.pdf`). The `attachKey` for each paper
   is hardcoded in `scripts/rag_precip_drying_methodology_build.R`.
2. `ollama serve` + `ollama pull nomic-embed-text` (one-time).
3. `Rscript scripts/rag_precip_drying_methodology_build.R` —
   ~25 s, produces 526 chunks across 7 sources.

To re-mine: `Rscript scripts/rag_precip_drying_methodology_query.R`
→ regenerates `precip_drying_methodology_quotes.md` (raw retrieval,
archived here at the time of merge).

## Notable execution wrinkles (lessons applied from #58)

- **No `Citation Key:` overrides in `extra`** — BBT auto-derives per
  NGE convention (`soul#43`). All 7 items have ≥2 individual
  creators per CrossRef, so no Pepin-style corporate-author PATCH
  was needed.
- **macOS Zotero auto-restart automated** for BBT key generation:
  `osascript -e 'tell application "Zotero" to quit'; sleep 3; open
  -a Zotero; sleep 30`. Verified working for 7 items; ~30 s wait
  was sufficient. Pattern added to `soul#43` for future runs.
- **Trenberth 2014 BBT key** came back as
  `trenberth_etal2013Globalwarming` because CrossRef issued =
  2013-12-17 online (print issue 2014-01). Left as-is per the
  auto-derived convention; year discrepancy is cosmetic.
- **OCR'd Marvel 2019** — the user-provided RG download was the
  LLNL preprint (image-only scan, working title differs from
  published Nature title but same DOI). One ocrmypdf pass was
  enough.

## Side-channel update during this work

- **`soul#43` body edited** (not commented) to add three follow-up
  wrinkles: corporate-author guard (Pepin 2015 case from #58),
  the macOS auto-restart bash recipe, and the BBT plugin compat-
  split note (BBT 8.x↔Z7, BBT 9.x↔Z8/9).

## Closing ref

- Issue: NewGraphEnvironment/cd#61
- PR: NewGraphEnvironment/cd#62 (squash `c37399c`, merged 2026-05-05)
- Release: v0.2.3 (tag pushed)
- Downstream consumer: future vignette wire-up branch (out of scope
  for this issue)
