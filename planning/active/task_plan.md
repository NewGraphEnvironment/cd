# Task: Lit-review interpretation framing methodology + reporting backing (#63)

## Problem

Vignette interpretation paragraphs in `vignettes/peace-fwcp.Rmd` and
`vignettes/kootenay-lake.Rmd` make framing choices about how to
report climate departure to FWCP fish-passage planners — choice of
**baseline window** (cd uses 1951–1980 vs the WMO 1961–1990
canon), **framing axis** (cumulative-impact: "2 °C warmer over X
years" vs per-decade rate), **reference variability** ("departure
from recent variability" per Mora 2013), and **reporting unit**
(BC ecoregions vs ecoprovinces vs watershed groups). Each is a
defensible choice but currently lands on **zero** peer-reviewed
citations. For FWCP fish-passage reporting context, these need the
same cited backing #53/#54 gave Snowpack, #58/#60/v0.2.2 gave
Temperature, and #61/#62/v0.2.3 gave Precipitation+Drying.

## Scope

Third (and final) of the three sequential climate-departure lit
reviews covering the non-snow vignette sections. Mirrors the
#58/#61 pattern verbatim. After this issue lands, the 3-split is
complete and the downstream vignette wire-up branch can pick up
the cite-this-for-that maps from all three findings.md files.

## Phase 1 — Targeted literature search

- [x] Web search candidate papers for DOI + access status; refined
      to **4 confirmed new papers** (leaner than initial 6-paper
      plan since Wiken 1986 + Demarchi 2011 BC ecoregion gov refs
      dropped — well-established convention, doesn't need a heavy
      cite)
- [x] Identified OA-fetchable: Hansen 2012 (harvard.edu),
      Livezey 2007 (meto.umd.edu). Paywalled needing RG: Arguez &
      Vose 2011, Hawkins & Sutton 2012
- [x] Cross-checked existing 19 items in the `climate` collection
      (6 reuse-relevant) + cross-rag references from snow + temp +
      precip+drying stores
- [x] Documented final candidate list + 7-topic coverage matrix
      in `findings.md` (Phase 1 search log section)

Starting candidate list (will refine):

| Citation key (proposed) | Topic / Why |
|---|---|
| `arguez_vose2011` | WMO climate normal methodology (BAMS) — baseline window |
| `livezey_etal2007` | Alternative normals (J Climate) — defending non-WMO baselines |
| `hawkins_sutton2012` | Time of emergence / signal-to-noise framing |
| `hansen_etal2012` | Perception of climate change (PNAS) — cumulative-impact |
| `wiken1986` | Canadian ecoregions framework (Env Canada) — reporting unit |
| `demarchi2011` | BC ecoregions overview (BC MoE) — BC-specific reporting unit |

Already in `climate` collection (no re-add): `mora_etal2013projectedtiming`,
`pauly1995Anecdotesshifting`, `rodrigues_etal2019Unshiftingbaseline`,
`alleway_etal2023shiftingbaseline`, IPCC AR6 WGI + SYR.

## Phase 2 — Add to NewGraphEnvironment/climate Zotero collection

- [x] For each of 4 candidates: CrossRef metadata fetch → POST to
      Web API with `"collections": ["8MH9LCC9"]`, tags
      `interpretation-framing-methodology` + `cd-issue-63`. No
      `Citation Key:` override in `extra` (per soul#43 + #58/#61
      lesson). All 4 items created with ≥2 individual creators
- [x] PDF acquisition: 2 fetched via curl (Hansen 2012 harvard.edu,
      Livezey 2007 meto.umd.edu), 2 user-provided via ResearchGate
      (Arguez & Vose 2011, Hawkins & Sutton 2012); no OCR needed
- [x] Auto-attached all 4 PDFs via 4-step S3 upload (2 fresh
      uploads, 2 deduped via md5)
- [x] Auto-restarted Zotero via osascript+open+30s — all 4 BBT keys
      generated cleanly
- [x] Captured per-paper `BBT-citationKey + parent itemKey +
      attachment key` in `findings.md`
- [x] PDFs in `data/rag/interpretation_framing_pdfs/`, gitignored,
      text-layered, ready for Phase 3 ingestion

## Phase 3 — Build ragnar DuckDB store

- [x] Cloned `scripts/rag_precip_drying_methodology_build.R` →
      `scripts/rag_interpretation_framing_build.R`. Adapted header
      docstring + 4-paper `pdf_specs` map
- [x] Ran build — produced `data/rag/interpretation_framing.duckdb`
      with **291 chunks across 4 sources** via Ollama
      `nomic-embed-text`
- [x] Verified retrieval distribution: all 4 papers contributing
      to top-5 chunks across queries (Arguez 26, Hansen 21,
      Hawkins 18, Livezey 15 — all healthy)

## Phase 4 — Mine the store for methodology quotes

- [x] Wrote `scripts/rag_interpretation_framing_query.R` mirroring
      the precip+drying query script. 6 topics × 2-3 queries × top-5
      chunks = 80 candidate chunks total (16 queries — narrower than
      #58/#61's 24 queries; topics: baseline window methodology,
      normals when trends exist, time of emergence, cumulative-
      impact / loaded dice, shifting baseline climate, departure
      from recent variability)
- [x] Raw retrieval saved to
      `planning/active/interpretation_framing_quotes.md` (373 lines)
- [x] Synthesized per-topic into `findings.md` (Phase 5)

## Phase 5 — Synthesis + citation map

- [x] In `findings.md`: methodology-quotes-by-topic section covering
      6 topics with selected quotes per paper
- [x] Cross-cutting methodology section — Hansen 2012's choice of
      the 1951–1980 base period validates cd's choice for
      cumulative-impact reporting (strongest defense across all
      three lit reviews)
- [x] Deviations section — 3 documented deviations: 1951–1980 vs
      WMO 1961–1990 baseline (defensible per Arguez & Vose 2011 +
      direct precedent in Hansen 2012), no AC correction (consistent
      across all 3 lit reviews), time-of-emergence not quantified
      per-AOI (cd uses cumulative-impact framing instead)
- [x] **"Cite this for that"** map — 11-row claim → citation
      lookup, framed as a menu not an order. BBT-auto-derived keys
      baked in
- [x] Documented existing items (6 reuse-relevant) + cross-rag
      references from snow + temp + precip+drying stores
- [x] 3-split scoreboard added to findings.md per task plan

## Phase 6 — PR + release

- [ ] `/code-check` clean (lint + tests) before each commit
- [ ] Atomic commits — Phase 1 search log, Phase 2 Zotero adds
      summary + key capture, Phases 3–5 build/query/findings
- [ ] PR with `Fixes #63`. SRED tag (`Relates to NewGraphEnvironment/sred-2025-2026#23`)
      in PR body, **not** issue
- [ ] After merge: `/planning-archive` → archived findings.md becomes
      long-lived methodology reference. Bump v0.2.3 → v0.2.4

## Validation

- [ ] `data/rag/interpretation_framing.duckdb` exists;
      `ragnar_retrieve()` returns sensible chunks for each topic
- [ ] 5–8 papers in `climate` Zotero collection with PDFs attached,
      all tagged `interpretation-framing-methodology` + `cd-issue-63`
- [ ] BBT-auto-derived citation keys captured for all new items
- [ ] `findings.md` has methodology quotes attributed by citation
      key for each query topic
- [ ] PWF checkboxes match landed work
- [ ] `devtools::test()` clean; `lintr::lint()` clean on new scripts
- [ ] Atomic-commits audit: `git log --oneline -- planning/ scripts/rag_*.R`
      tells the full story

## Out of scope

- **Temperature methodology** — covered by #58/#60/v0.2.2
- **Precipitation + drying** — covered by #61/#62/v0.2.3
- **Snowpack methodology** — covered by #53/#54/v0.1.7
- **BEC zone shifts** — #59 tracker (post-3-split)
- **Implementation of `cd_compare()` defaults / p-value** — #20 + #43
  (downstream consumers of this lit review)
- **Vignette `[@key]` insertion** — downstream consumer branch
- **Original methodology research / new metric proposals**

## Notes for execution

- Branch: `63-interpretation-framing-lit-review`
- Vignette edits forbidden on this branch
- Ollama prerequisite: `ollama serve` + `ollama pull nomic-embed-text`
- BBT 9.x already active; auto-restart pattern documented in
  soul#43 — apply directly without prompting user
- After this issue lands, the 3-split is complete; flag #59 (BEC
  zone shifts) as the natural next pickup if reporting visibility
  warrants it
