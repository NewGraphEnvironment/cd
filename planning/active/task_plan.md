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

- [ ] For each new paper: CrossRef metadata fetch → POST to Web API
      with `"collections": ["8MH9LCC9"]`, tags
      `interpretation-framing-methodology` + `cd-issue-63`. **No
      `Citation Key:` overrides** (per soul#43 + #58 + #61 lesson).
      Verify each item creates with at least one personal author so
      BBT doesn't fall back to title-key (per Pepin 2015 lesson)
- [ ] Auto-attach OA PDFs via 4-step S3 upload; flag paywalled for
      user RG download
- [ ] OCR any image-only scans before attaching (per Karl 1993 +
      Richter & Kolmes 2005 + Marvel 2019 OCR lessons)
- [ ] **Auto-restart Zotero** via `osascript -e 'tell application
      "Zotero" to quit'; sleep 3; open -a Zotero; sleep 30` — per
      soul#43, no need to ask the user manually
- [ ] After BBT key generation: capture per-paper
      `BBT-citationKey + parent itemKey + attachment key` in
      `findings.md`
- [ ] Mirror PDFs into `data/rag/interpretation_framing_pdfs/` for
      ragnar ingestion (gitignored)

## Phase 3 — Build ragnar DuckDB store

- [ ] Clone `scripts/rag_precip_drying_methodology_build.R` →
      `scripts/rag_interpretation_framing_build.R`. Adapt header
      docstring + `pdf_specs` map
- [ ] Run `Rscript scripts/rag_interpretation_framing_build.R` —
      target ~400-700 chunks across ~6 sources via Ollama
      `nomic-embed-text`
- [ ] Verify chunk count + source count via DBI queries

## Phase 4 — Mine the store for methodology quotes

- [ ] Write `scripts/rag_interpretation_framing_query.R` mirroring
      the precip+drying query script. Query topics (5–6 — narrower
      than #58/#61):
      - Baseline window methodology (WMO 1961–1990 vs alternatives)
      - Cumulative-impact vs per-decade-rate framing
      - Departure from recent variability / time-of-emergence
      - Shifting baseline syndrome
      - Ecoregion as reporting unit
- [ ] Save raw retrieval to
      `planning/active/interpretation_framing_quotes.md`
- [ ] Synthesize per-topic into `findings.md`

## Phase 5 — Synthesis + citation map

- [ ] In `findings.md`: methodology-quotes-by-topic section
- [ ] Cross-cutting methodology section: how framing choices
      compose with the trend-test + baseline-window decisions from
      #58/#61 (already settled — this issue just adds citation
      backing for the framing choices, no new methodology)
- [ ] Deviations section — places where cd's framing differs from
      the literature consensus (likely: 1951–1980 vs 1961–1990; the
      cumulative-impact framing is consistent with the literature)
- [ ] **"Cite this for that"** table — N-row map from vignette
      framing claim type to BBT-auto-derived citation key(s).
      Framed as a menu, not an order, per memory
      `feedback_vignette_citations_sparse.md`
- [ ] **3-split scoreboard** in findings.md: pointer to the
      three findings.md files (#58, #61, this) for downstream
      vignette branch consumers

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
