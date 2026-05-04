# Task: Snowpack-departure methodology lit review (#53)

## Problem

Phase 5 of #48 will make defensible-sounding claims about snow ("freshet
N days earlier", "peak SWE down M%", "rain-snow transition moving
upslope"). For our reporting context (fish passage, aquatic restoration
appendices), these need to land on cited peer-reviewed methodology, not
back-of-envelope. This issue produces the citations and methodology
quotes; #48 Phase 5 consumes them.

User-confirmed decoupling:
- **#53 produces** `findings.md` with exact-page quotes for each of #48's
  four metric choices, citation keys ready to consume.
- **#48 Phase 5 consumes** `[@key]` citations into the vignette interp
  paragraph, sourced from this issue's `findings.md`.

Mirrors the existing `scripts/rag_build_departure_framing.R` pattern.

## Phase 1 — Targeted literature search

- [x] WebSearched DOI / publisher landing for each candidate; all 11
      papers confirmed with DOIs.
- [x] Paywalled papers identified: `pederson_etal2011` (Science),
      `yue_wang2002` (AGU). USGS / ResearchGate fallback paths
      flagged in findings.md.
- [x] Found **`kouki_etal2023`** for ERA5-Land snow validation
      (Cryosphere, OA, CC-BY 4.0).
- [x] Found **`yue_wang2002`** for MK + autocorrelation. Critical
      finding: prewhitening fails when a trend exists — informs
      whether cd should add autocorrelation correction (likely #43
      follow-up).
- [x] Found **`kang_etal2016`** — Fraser River Basin freshet-timing
      paper, directly maps to our fish-passage reporting context.
      Was not in original candidate list; added.
- [x] Captured 11 papers in `findings.md` with DOI + access status +
      coverage matrix mapping each #48 metric to its primary paper.

Starting candidate list:

| Citation key | Why |
|---|---|
| `mote_etal2005` Mote, Hamlet, Clark, Lettenmaier 2005 (BAMS) | Foundational PNW snowpack-decline methodology |
| `stewart_etal2005` Stewart, Cayan, Dettinger 2005 (J Climate) | Defines DOY-50 / centroid timing |
| `pederson_etal2011` Pederson et al. 2011 (Science) | Long-record context |
| `mote_etal2018` Mote et al. 2018 (npj Clim Atmos Sci) | Updated PNW summary |
| `knowles_etal2006` Knowles, Dettinger, Cayan 2006 (J Climate) | Snowfall fraction methodology |
| `najafi_etal2017` Najafi et al. (UNBC) | BC-specific Peace-relevant |
| `curry_etal2014` Curry et al. 2014 | BC mountain snowpack + climate change |
| `cayan_etal2001` Cayan et al. 2001 (BAMS) | Spring onset metric origins |
| `yue_wang2002` Yue & Wang 2002 (WRR) | Autocorrelation correction for MK |
| `munoz_sabater_etal2021` Muñoz-Sabater et al. 2021 (ESSD) | ERA5-Land dataset (already in Zotero, attachKey SUS5A57A) |

## Phase 2 — Add papers to Zotero (`snowpack-departure-methodology` collection)

- [ ] Check existing `zotero_search_items` for each candidate — many
      may already be in the library from other projects.
- [ ] Create `snowpack-departure-methodology` collection if not present.
- [ ] Add new entries via web API POST with `"collections": ["{key}"]`.
- [ ] Attach PDFs via web-API S3 upload (per `/zotero-api` skill,
      section 4) for OA papers. JS-console fallback for paywalled with
      manual download.
- [ ] Run `collection_dedup.js` if `saveItems` retries left dupes.
- [ ] Verify via `zotero_get_item_children` that PDFs attached.
- [ ] Capture per-paper `citationKey + attachKey` in `findings.md`.

## Phase 3 — Build ragnar DuckDB store

- [ ] Clone `scripts/rag_build_departure_framing.R` structure into new
      `scripts/rag_build_snow_methodology.R`.
- [ ] Update header docstring (purpose, prerequisites, output path).
- [ ] Hardcode the `citationKey -> attachKey` map from Phase 2.
- [ ] Output: `data/rag/snow_methodology.duckdb` (gitignored — `data/rag/`
      already in `.gitignore`).
- [ ] Run the build. Verify chunk count + origin count match expectations.

## Phase 4 — Mine the store for methodology quotes

- [ ] For each #48 metric, run `ragnar_retrieve()` with focused queries:
      - `swe_max`: "annual peak SWE methodology" / "April 1 SWE"
      - `snowfall_fraction`: "snowfall vs total precipitation ratio"
      - `snowmelt_doy_50`: "DOY 50 percent cumulative discharge" /
        "centroid timing CT freshet"
      - `snowmelt_rate_peak`: "peak weekly melt flashiness"
- [ ] Capture top-k chunks per query; extract exact-page quotes with
      `@key, p. N`.
- [ ] Cross-cutting queries:
      - Baseline window choice (1951–1980 vs 1961–1990 vs 1981–2010)
      - Mann-Kendall + autocorrelation correction
      - ERA5-Land snow biases (rain-snow transition zone, mountain terrain)
- [ ] Each result captured in `findings.md` under the relevant heading.

## Phase 5 — Document deviations + citation map

- [ ] **Deviations** section in `findings.md`: where cd's pipeline differs
      from literature consensus, and why. Likely candidates:
      - 7-day rolling sum (vs other freshet flashiness metric)
      - 1951–1980 baseline (vs 1961–1990 WMO normal — already in earlier
        vignette section)
      - No autocorrelation correction in MK (decision: file as #43
        follow-up if literature suggests we should)
- [ ] **"Cite this for that"** table at end of `findings.md` —
      copy-paste-ready map from "claim that lands in vignette" to
      "citation key to use". Direct input for #48 Phase 5.

## Phase 6 — PR

- [ ] `/code-check` clean before commit.
- [ ] Atomic commits — Phase 1 search log, Phase 2 Zotero adds summary,
      Phase 3 rag-build script, Phases 4–5 findings.
- [ ] PR with `Fixes #53`. SRED ref in PR body
      (`Relates to NewGraphEnvironment/sred-2025-2026#23`) — not in
      issue body per memory.
- [ ] After merge: `/planning-archive`. Archived findings.md becomes
      the long-lived methodology reference.

## Validation

- [ ] `data/rag/snow_methodology.duckdb` exists and `ragnar_retrieve()`
      returns sensible chunks for each metric query.
- [ ] 8–12 papers in `snowpack-departure-methodology` Zotero collection
      with PDFs attached.
- [ ] `findings.md` has exact-page quotes (`@key, p. N`) for each of the
      four #48 metric choices.
- [ ] PWF checkboxes match landed work.
- [ ] `/planning-archive` on completion.

## Out of scope

- **Vignette citation insertion** — happens in #48 Phase 5, sourced from
  this issue's findings.md.
- **Setting up `bibliography:` YAML in `peace-fwcp.Rmd`** — also #48
  Phase 5.
- **Original methodology research / new metric proposals.**
- **Refactoring `cd_anomaly` / `cd_trend`** — autocorrelation correction
  goes against #43 if motivated.
- **Glacier dynamics, streamflow modelling.**

## Notes for execution

- Working in parallel with `48-snow-vars` branch. Files this branch
  touches don't overlap.
- **Vignette edits forbidden on this branch** — even small ones.
- Zotero state lives outside the repo. Branch's git diff captures only
  the build script + planning files. Citation keys are committed in the
  R script's hardcoded map, so the build is reproducible.
- Ollama prerequisite: `ollama serve` + `ollama pull nomic-embed-text`
  before invocation.
