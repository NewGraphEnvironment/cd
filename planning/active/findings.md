# Findings — Snowpack-departure methodology lit review (#53)

## Issue context (verbatim from #53)

Phase 5 of #48 will make defensible-sounding claims like "freshet has
shifted N days earlier," "peak SWE has declined M%," and "the rain-snow
transition is moving upslope." For our reporting context (fish passage,
aquatic restoration appendices), these claims need to land on cited
peer-reviewed methodology, not back-of-envelope. Without that,
downstream report reviewers can fairly push back on choice of metric,
baseline window, trend test, and bias-correction (or lack thereof).

The four metrics shipping in #48 are themselves methodology choices:
**7-day rolling sum** for freshet flashiness; **DOY-50** for melt
timing; **annual peak SWE** for snowpack magnitude; **annual snowfall
fraction** for precipitation phase. Each has a literature behind it —
this issue produces a `findings.md` of exact-page quotes that justify
each metric choice, indexed by citation key, ready for #48 Phase 5 to
consume.

## State found during plan-mode exploration

### Existing rag-build pattern

`scripts/rag_build_departure_framing.R` is the template to mirror:
- Hardcoded `citationKey -> attachKey` map
- Reads PDFs from `~/Zotero/storage/{attachKey}/`
- Writes DuckDB to `data/rag/{name}.duckdb` (gitignored — `data/rag/`
  already in `.gitignore`)
- Uses `ragnar` package with `embed_ollama(model = "nomic-embed-text")`
- Verifies via `n_chunks` and `n_origins` queries

### Existing Zotero entries we can reuse

From `scripts/rag_build_departure_framing.R` (lines 31–38):
- `munoz_sabater2021` — attachKey `SUS5A57A` (ERA5-Land dataset paper)
  → directly relevant, drop straight into the snow rag-build map.
- `mora_etal2013` — attachKey `36G25ZK9` (climate departure timing)
  → general framing, less central to snow but worth including.
- `hersbach_etal2020` — attachKey `IE8SUWCS` (ERA5 global reanalysis)
  → context for ERA5-Land's parent dataset.

### Vignette citation infrastructure status

`vignettes/peace-fwcp.Rmd` currently has **zero citations**. No `bibliography:`
YAML field, no `[@cite]` markers, no `references.bib`. Phase 5 of #48 will
wire this up for the first time. This issue's deliverable is the
`findings.md` with citation keys ready — the YAML wiring lands in #48.

## Architecture decisions taken (user-confirmed)

1. **Decoupled boundary.** This issue produces methodology notes and a
   ragnar store. Vignette citation insertion happens on the `48-snow-vars`
   branch in Phase 5. Avoids merge conflicts.
2. **Branch is parallel to `48-snow-vars`.** Off main, separate PRs.
3. **Vignette edits forbidden on this branch** to keep the boundary clean.
4. **Mirror existing rag-build script structure** verbatim, just with a
   different citation-key map and output path.

## Search log

_Phase 1 will populate this section with per-paper search results._

## Papers added to Zotero (`snowpack-departure-methodology` collection)

_Phase 2 will populate this section with `citationKey + attachKey + DOI +
PDF status` per paper._

## Methodology quotes by #48 metric

_Phase 4 will populate these subsections with exact-page quotes._

### `swe_max` (annual peak SWE)

### `snowfall_fraction` (annual sf/tp ratio in %)

### `snowmelt_doy_50` (day of 50% cumulative melt)

### `snowmelt_rate_peak` (annual max of 7-day rolling melt)

## Cross-cutting methodology

### Baseline window (1951–1980 vs alternatives)

### Mann-Kendall + autocorrelation

### ERA5-Land snow biases (validation literature)

## Deviations from consensus

_Phase 5 will populate this section with where cd's choices differ
from the literature consensus and why._

## "Cite this for that" — citation map for #48 Phase 5

_Phase 5 will populate this table as copy-paste-ready input for the
vignette interp paragraph._

| Vignette claim | Citation key | Page |
|---|---|---|
