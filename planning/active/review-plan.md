# Plan review (#102), Plan agent, 2026-10-16 ~04:16 UTC

The agent is read-only, so its reply was transcribed here by the parent session. Every claim was probed before triage.

| # | Category | Finding | Triage |
|---|---|---|---|
| 1 | Blocker | `e95cad7` names PTR "Pacific and Cascade Ranges" | Already fixed in `4a2f676`; the reviewer saw an uncommitted snapshot |
| 2 | Gap | "the 1951-1980 normal" clashes with the vignettes' WMO 1981-2010 "climate normal" (`peace-fwcp.Rmd:208`, `kootenay-lake.Rmd:216`) and with NEWS 0.6.8, which stopped calling 1951-1980 a normal | Fixed: "percent of the 1951-1980 baseline mean per year"; downstream issue bodies edited to match |
| 3 | Gap | The shown `per-ecoregion-recipe` calls `cd_compare()` with the default `method = "mean_diff"`, while the table's `pct change` columns come from `pct_change` | Fixed: recipe passes `method = "pct_change"` (eval = FALSE chunk) |
| 4 | Gap | The facet-prcp captions are static and SBF sits at p 0.061 | Fixed: `data-raw/*_vignette_data.R` assert each caption's clauses before saving (northern-bc pattern); tested on the committed rds, with 5 planted defects each stopping |
| 5 | Assumption | The plan said mm/yr "would need a data regen"; a Theil-Sen slope scales exactly (slope × mean_b / 100) | Reason corrected in task_plan.md; the choice (keep %) stands |
| 6 | Scope | TOP is 26 km², about one ERA5-Land cell; Peace drops <100 km² ecoregions | Filed in cd#146 |
| 7 | Scope | Kootenay "soil moisture flat" (`:273`, `:990`) contradicts significant declines | Verified; filed in cd#146 |
| 8 | Scope | "+1.6 to +1.9 °C" omits PTR at 1.49 | Verified; filed in cd#146 |
| 9 | Scope | "Three findings" introduces four, in both vignettes | Verified; filed in cd#146 |
| 10 | Scope | WSG "same drying signal": only KOTL significant | Verified; filed in cd#146 |
| 11 | Scope | "for this list" carry-over (`:883`) | Cosmetic; not filed |
| 12-13 | Ordering | Settle wording before Phase 3; commit PTR before renders | 13 already true; 12 handled by editing the issue bodies |
| 14 | Acceptance | Grep rendered HTML for "Pacific and Cascade" and "normal per year" absent | Added to the re-render check |
| 15 | Acceptance | PWF behind commits | Done in this commit |
| 16 | Acceptance | NEWS line names both relabels and the Kootenay caption | For `/gh-pr-merge` |
