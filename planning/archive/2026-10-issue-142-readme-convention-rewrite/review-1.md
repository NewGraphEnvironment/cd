# Plan review 1 (#142) — Plan agent, 2026-10-17, spawned 07:26 UTC

Read-only reviewer; findings returned as reply text and transcribed here in summary. 22 items.

| # | Finding | Disposition |
|---|---|---|
| 1 | Glob selectors `cd_plot_*` / `cd_cache_*` are not valid pkgdown | Already avoided: topics listed, `starts_with("cd_cache_")`; `check_pkgdown()` clean |
| 2 | No NOTICE though repo ships ERA5-Land-derived rasters (`inst/extdata/example_climate.tif`, `example_daily/`, `inst/vignette-data/`) | Fixed: `NOTICE.md`, `NOTICE` added to pkgdown.yaml `allowed` |
| 3 | Example needs sf, Kendall, zyp (Suggests) after a default install | Fixed: one line after Installation |
| 4 | Ecosystem wording: cd row from wet's README; add relationship line | Fixed: "cd computes the departures from wet's yearly station values." (wet README wording) |
| 5 | gq listed but no vignette depends on or calls gq | Fixed: gq row dropped |
| 6 | Copernicus licence/attribution unconfirmed | Confirmed CC-BY-4.0 from CDS catalogue API `collections/reanalysis-era5-land`; sentence kept without a year |
| 7 | Figure y-axis reads "Mean temperature (°C)" on an anomaly plot | Fixed in `data-raw/readme_figure.R` (`labs(y = "Difference from 1951–1980 average (°C)")`); package default filed as an issue |
| 8 | "downloaded once" false: ETag revalidation re-downloads republished files | Fixed: "downloaded again only when they are republished" |
| 9 | Relative `CITATION.cff` link 404s on pkgdown (build-ignored) | Fixed: `citation("cd")` only |
| 10 | About / Title / tagline must be one string | Done in Phase 3 (About read back) |
| 11 | DESCRIPTION + authors_roles in same PR so merge regenerates CITATION.cff | Done (same PR) |
| 12 | NEWS/version for this PR | Left to `/gh-pr-merge` |
| 13 | Example output and figure go stale when 2026 lands | Accepted; script header says re-run when the catalog gains a year |
| 14 | "by season and year" correct | — |
| 15 | Maintainer section mixes legacy `cd_fetch` | Section described as "Building the published data", not "the pipeline" |
| 16 | Scope removals fit the convention | — |
| 17-22 | Acceptance: example == script markers; enumerate claims; links on both renderings; pkgdown checks; About read-back; word counts | Folded into Phase 5 / code-check |

Also: "version" vs "commit" for `cd_sha` — fixed to "which commit of cd built each file".
