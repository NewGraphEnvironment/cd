# Task: Vignettes: per-ecoregion prcp trend is % of normal per year but labelled mm/yr (#102)

The per-ecoregion roll-up builds its prcp column from `res$trn`, which `data-raw/*_vignette_data.R` computes with `cd_trend(ano, ...)` — a trend of **anomalies**. prcp's anomaly type is `pct_normal`, so the slope is **% of normal per year**, but the column is named `` `prcp mm/yr` `` and the caption says "annual precipitation trend (mm per year)":

- `vignettes/peace-fwcp.Rmd:761` and the caption at `:775` (lines as of v0.6.10)
- `vignettes/kootenay-lake.Rmd:857` and the caption at `:871`

Measured from the committed `inst/vignette-data/peace_fwcp.rds`: the first ecoregion's annual prcp trend from 1951 has slope `0.0521`, on anomalies carrying `anomaly_type = "pct_normal"`, `unit = "%"`.

The plan review for #97 reports that the same label was ported into the `fish_passage_peace_2025_reporting` and `fish_passage_skeena_2025_reporting` appendices; not verified here.

**Approach:** fix the labels and leave the data alone. Every other prcp figure in these vignettes is on the % of baseline scale. A mm/yr column would add a second scale, so the issue's alternative (trending `ts`) is not taken. (Corrected after the plan review: it would not need a regen, since a Theil-Sen slope scales exactly, slope × baseline mean / 100.) The slope stays per year, as the issue proposes; rescaling to per decade would change the numbers, not just the label.

Also folded in at the plan gate: the Kootenay `facet-prcp` caption (`kootenay-lake.Rmd:697`) was copied from Peace and names BMP/NRM, neither of which is in Kootenay.

## Phase 1: Relabel the roll-up prcp trend (#102)
- [x] `vignettes/peace-fwcp.Rmd` rollup chunk: rename `` `prcp mm/yr` `` to `` `prcp %/yr` ``. Change the caption's "annual precipitation trend (mm per year)" to "annual precipitation trend (percentage points of the 1951-1980 normal per year)". *(Shipped as "percent of the 1951-1980 baseline mean per year", Phase 4.)*
- [x] `vignettes/kootenay-lake.Rmd` rollup chunk: the same two edits.
- [x] Grep `vignettes/`, `R/`, `data-raw/` and `README*` for any remaining `mm/yr` or `mm per year` attached to an anomaly trend (expected: none).

## Phase 2: Kootenay facet-prcp caption
- [x] Replace the copied sentence at `kootenay-lake.Rmd:697` with one written from the committed numbers: NCM and PTR show statistically significant precipitation decreases over the full record; SBF and TOP decline but not significantly. *(Shipped for the three ecoregions the article shows; TOP is filtered out at `kootenay-lake.Rmd:98`, code-check round 3.)*

- [x] (Added mid-run) PTR is Purcell Transitional Ranges, on the AOI's eastern edge, not "Pacific and Cascade Ranges" in the southwest: fix the name at the per-ecoregion intro (`:608`) and the `map-wsgs` caption (`:892`), from `inst/extdata/context_kootenay_lake.gpkg`.

## Phase 3: Downstream appendices
- [x] File one issue each in `fish_passage_peace_2025_reporting` and `fish_passage_skeena_2025_reporting`. Each names the file:line, the measured unit, and the fix, and links cd#102 (public).
- [x] The issue text follows the public-repo rule: no hosts and no private links. These repos are not edited from this branch. Filed: fish_passage_peace_2025_reporting#50, fish_passage_skeena_2025_reporting#21.

## Phase 4: Plan-review fixes (planning/active/review-plan.md)
- [x] Caption says "percent of the 1951-1980 baseline mean per year", not "normal" (the vignettes reserve "climate normal" for WMO 1981-2010)
- [x] Shown `per-ecoregion-recipe` passes `method = "pct_change"` to `cd_compare()`, matching the bundled data behind the `pct change` columns
- [x] `data-raw/kootenay_lake_vignette_data.R` and `data-raw/peace_fwcp_vignette_data.R` assert their facet-prcp caption clauses before saving
- [x] Out-of-scope Kootenay prose filed as cd#146; downstream issue bodies updated to the final wording

## Phase 5: Code-check fixes (review-round2..4.md)
- [x] Round 2: guard checks the ecoregion count; stale findings line
- [x] Round 3: captions describe the three ecoregions shown (TOP filtered at >50 km²); guards read the vignette's threshold; cd#146 corrected
- [x] Round 4: intro narrowed to the trend figures and roll-up table (the WSG overlap table does show TOP); Peace data script takes its area filter from the vignette; threshold regex anchored to a bare `> N, ]`

## Verification
- Install the branch with `pak::local_install()`. The rds is unchanged, but `build_article` reads the installed cd.
- Run `pkgdown::build_article("peace-fwcp")` and `build_article("kootenay-lake")`.
- Grep the rendered HTML: `prcp %/yr` and the new captions are present, and `mm/yr` and `BMP, NRM` are absent from Kootenay.
- No R code changes, so the test suite is not re-run for this. `/code-check branch` before the PR.

## Validation
- [ ] Both articles render; rendered-HTML greps pass
- [ ] `/code-check` clean (once over the branch with `/code-check branch`)
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
