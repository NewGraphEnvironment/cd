# cd — Climate Departure

R package for climate departure analysis from ERA5-Land reanalysis data. Computes anomalies for custom areas of interest with flexible baselines and trend statistics.

## Fork / Upstream Status

- **Origin:** `NewGraphEnvironment/cd` (private)
- **No upstream** — this is an original package
- **SRED:** `NewGraphEnvironment/sred-2025-2026#23`

## Repository Context

**Primary Language:** R (consumer-side) + Python (producer-side, EDH backfillers)
**Framework:** R package (devtools, testthat 3e, pkgdown)
**Spatial:** `terra`, `sf`
**Data:** ERA5-Land via [DestinE Earth Data Hub (Zarr)](https://earthdatahub.destine.eu/), served as COGs on S3 via STAC
**S3 Bucket:** `stac-era5-land` (us-west-2)
**pkgdown:** `newgraphenvironment.com/cd/`

## Architecture

**Producer** (GitHub Action, monthly): Python backfillers fetch hourly Zarr from EDH, aggregate, derive (VPD/RH/soil); R stage 3 writes COGs and pushes the STAC catalog:
`scripts/backfill_edh_*.py` → `scripts/pipeline_stage3_edh.R` → `scripts/pipeline_update_edh.R` (the GH Action's monthly entry point) → `cd_cog_write()` → `cd_stac_catalog()` → `cd_s3_push()`

The historical `cd_fetch()` / `cd_derive()` R-side producer functions still ship (with tests) for users who want a CDS-based fallback, but are not what runs in CI. See v0.1.0 / #36 for the migration history.

**Consumer** (user-facing, local R):
`cd_catalog()` → `cd_crop()` → `cd_extract()` → `cd_baseline()` / `cd_anomaly()` / `cd_compare()` → `cd_trend()` → `cd_summary()`

**Key design decision:** Raw climate values on STAC (not pre-computed anomalies). All baseline/anomaly/trend computation consumer-side for maximum flexibility over reference periods and comparison windows.

## Function Prefix

All functions use `cd_*` prefix. Naming convention: `noun_verb` (e.g., `cd_cog_write` not `cd_write_cog`).

## EDH (DestinE Earth Data Hub)

Producer pulls hourly ERA5-Land Zarr from EDH for the BC bbox (~48-60° N, 114-140° W) and aggregates to monthly / seasonal / annual on a single EPSG:4326 grid. Python only on the producer side (Zarr ecosystem maturity); R consumer-side reads the COGs over `/vsicurl/`.

Token lookup order: `EDH_TOKEN` env var, then `~/.Renviron`. Configured in CI via secret.

Key gotchas:
- Temperature in Kelvin (subtract 273.15)
- Precipitation in m/day (× 1000 × days_in_month → mm/month)
- Snow accumulation variables (`snowfall`, `snowmelt`) reset at 06:00 UTC each day — diff-and-clamp logic lives in `scripts/backfill_edh_snow.py` (#48)
- tmax/tmin daily aggregation currently uses UTC-day boundaries, not local-time — known limitation tracked at #37

## Climate Variables (15 total since v0.2.0)

**Core climate (7):** all monthly natives, also seasonal + annual

| Variable | Units | Anomaly Type |
|----------|-------|--------------|
| tmean | °C | absolute |
| tmax | °C | absolute |
| tmin | °C | absolute |
| prcp | mm | pct_normal |
| vpd | hPa (Tetens-derived) | absolute |
| rh | % (temp+dewpoint-derived) | absolute |
| soil_moisture | m³/m³ (4-layer mean) | pct_normal |

**Snow monthly natives (4):** also seasonal + annual

| Variable | Units | Anomaly Type |
|----------|-------|--------------|
| swe | mm | pct_normal |
| snowfall | mm w.e. | pct_normal |
| snowmelt | mm w.e. | pct_normal |
| snow_cover | % | pct_point_diff |

**Snow annual derived (4):** annual only

| Variable | Units | Anomaly Type |
|----------|-------|--------------|
| swe_max | mm | pct_normal |
| snowfall_fraction | % | pct_point_diff |
| snowmelt_doy_50 | day-of-year | absolute |
| snowmelt_rate_peak | mm/day | absolute |

The `pct_point_diff` anomaly type is for already-percentage variables (treats anomaly as percentage-point difference, not relative percent).

## Season Definitions

Configurable via `cd_seasons()`. Default: standard meteorological (DJF, MAM, JJA, SON). Override for custom seasons (e.g., wet/dry, growing season).

## Development Workflow

1. Branch per issue (or group): `N-description` (use `/planning-init <N>`)
2. PWF baseline (task_plan.md / findings.md / progress.md) committed first
3. Build → test → `/code-check` → atomic commits with `Fixes #N` (each commit updates the matching task_plan checkbox)
4. PR (`/gh-pr-push`) — SRED tag (`Relates to NewGraphEnvironment/sred-2025-2026#23`) goes in the PR body, not on issues
5. Merge + release (`/gh-pr-merge`) — bumps DESCRIPTION + NEWS, tags, watches CI
6. Archive — `planning/active/` → `planning/archive/<YYYY-MM-issue-N-slug>/` with a one-paragraph README per directory

## Scripts (current)

**Producer (EDH):**
- `scripts/backfill_edh_all.py` — all 7 core climate variables (tmean, tmax, tmin, prcp, dewpoint→VPD/RH, soil moisture)
- `scripts/backfill_edh_tmax_tmin.py` — separate tmax/tmin path (hourly → UTC-day max/min); see #37
- `scripts/backfill_edh_snow.py` — 4 snow natives + 4 derived (#48); handles ECMWF accumulation reset
- `scripts/_lib.py` — shared safeguards (single-instance pgrep guard, exponential backoff, atomic write, timestamped logging, EDH token loader)
- `scripts/pipeline_stage3_edh.R` — monthly TIFs → COGs + STAC + S3 push
- `scripts/pipeline_update_edh.R` — monthly GH Action entry point (incremental)
- `scripts/qa_monthly.R` — month-end QA cross-check

**Misc:**
- `scripts/rag_snow_methodology_build.R` / `rag_snow_methodology_query.R` — ragnar lit review (#54)
- `scripts/rag_departure_framing_build.R` — ragnar store for departure framing
- Naming: `rag_<topic>_<verb>.R` (`noun_verb`, mirrors the `cd_*` function convention)
- `data-raw/make_hexsticker.R` — hex sticker (reads from DESCRIPTION)
- `data-raw/example_*.R` — bundled AOIs + context geodata for vignettes

## Vignettes

Two regional reporting vignettes in `vignettes/`:
- `peace-fwcp.Rmd` — FWCP Peace Region (~73,000 km², 16 WSGs across 5 ecoregions)
- `kootenay-lake.Rmd` — southern Kootenays (~24,200 km², 4 WSGs across 4 ecoregions; sharp east-west precip gradient)

Both share the same structure (Area of Interest → Trends → Snowpack → Spatial Pattern → Per-Ecoregion → WSGs Across Ecoregions → Interpretation). Heavy data is precomputed by `data-raw/<vignette>_vignette_data.R` into `inst/vignette-data/<vignette>.{rds,tif}` so pkgdown CI doesn't re-fetch from S3 on every render. ASWS QA cross-checks are in `data-raw/qa_snow_validation*.R` — run locally only, results land in `planning/archive/<issue>/`.

**Bibliography regen.** After adding or removing `[@key]` markers in either vignette, regenerate `vignettes/references.bib` from Zotero/BBT by running `Rscript data-raw/regenerate_bib.R`. Pulls source records via rbbt → BBT, writes the union of keys across both vignettes. Requires Zotero running with BBT enabled (BBT 9.x for Zotero 8/9). CI does not run this — the bib is committed and pkgdown reads the static file.

**Chunk pattern (v0.2.8).** Visible code in both vignettes is dominated by `cd::cd_*()` calls — the package showcase. Boilerplate (ggplot AOI maps, Spatial Pattern map, kableExtra wrappers, facet-plot recipes) is hidden via `echo = FALSE`. Heavy cd recipes (`cd_extract`, `cd_baseline + cd_anomaly + cd_trend + cd_summary`, `cd_compare`, per-ecoregion + per-WSG loops) are lifted into shown `eval = FALSE` companion chunks above the actual data-load chunks (named `<chunk>-recipe` shown / `<chunk>-load` or `<chunk>-table` or `<chunk>-reshape` hidden). Reader sees: cd recipe → output → narrative. Snow plot chunks (`snow-swe-max` etc) stay fully visible since they're already pure cd_*() calls. All cd function calls use `cd::` namespace prefix for explicit package attribution.

The two-vignette template is the foundation for additional regional reporting appendices (cf #47) — port directly to a `fish_passage_<region>_<year>` reporting context.

## Data Directories (gitignored)

- `data/backfill/` — overnight backfill working data
- `data/rag/` — ragnar DuckDB stores

## CI considerations

- `data-raw/*.R` runs **locally only** — never on CI. Outputs land in `inst/extdata/` or `inst/vignette-data/` and are committed.
- `bcsnowdata` (used by ASWS QA scripts) is GitHub-only — **never** add it to DESCRIPTION Suggests; pak can't resolve it on the pkgdown runner. Same for any other GitHub-only package.
- **CI cannot commit a gitignored path.** `logs/*.log` is ignored, so the old "commit the run log back to main" step in `climate-update.yml` staged nothing, skipped the commit, and only ever reached `git push` — which 403s during `git-receive-pack` ref advertisement even with nothing to push. Four months of red runs. Use `actions/upload-artifact@v4` for run output and keep the token `contents: read` (#78).
- **`setup-r-dependencies@v2` installs dependencies, not the package.** Any workflow running a `scripts/*.R` entry point that calls `library(cd)` needs `extra-packages: local::.`, or the script falls through to a `devtools::load_all()` that isn't installed on the runner (#78).
- **Probe credentials at the top of long jobs.** `pipeline_update_edh.R` STEP 0 checks EDH auth and round-trips an S3 sentinel object before any work, turning a stale `EDH_TOKEN` from a six-hour failure into a four-second one. `aws sts get-caller-identity` alone is not enough — it proves the keys parse, not that the bucket is writable. EDH's HTTP Basic auth needs `httpauth = 1L` on the curl handle; libcurl otherwise waits for a `WWW-Authenticate` challenge EDH never sends.
- **A 4xx from EDH at STEP 0 is not evidence the token is bad — the probe says it is anyway.** `pipeline_update_edh.R` collapses every status >= 400 into `EDH rejected the token`, so a 401 (bad credential), a 403 (authenticated but refused) and a 404 all read as an expiry. Checked against the EDH account on `2026-09-07` after a red dry-run: the standard key **never expires** and the classic key had seven months left, so that 403 was never an expiry and rotating the secret would have changed nothing. EDH's free tier is a **monthly download quota that resets at midnight on the 1st**, and the run that spends it is the monthly live cron — so a red run shortly after a green 1st-of-month run points at quota, not credentials. Classic keys must be used against `data.earthdatahub.destine.eu`; the pipeline already does.
- **A weekly dry-run cron is cheap insurance.** It proves the plumbing between monthly live runs *and* keeps the workflow active — GitHub auto-disables scheduled workflows after 60 days of repo inactivity, a silent failure no notification catches.
- **Close the auto-filed failure issue when the cause is fixed.** `climate-update.yml` dedups by label: it comments on *any* open issue tagged `climate-update-failure` and only opens a new one when none exists. A resolved-but-open thread therefore captures every future incident — a November failure lands as a comment on an August ticket describing a fixed cause, which reads as old news and gets skimmed. Deduping is the right design; it just assumes the thread is closed on resolution, and nothing enforces that. Caught in #79, which stayed open after #78 fixed its root cause.


<!-- BEGIN SOUL CONVENTIONS — DO NOT EDIT BELOW THIS LINE -->


# Cartography

## Style Registry

Use the `gq` package for all shared layer symbology. Never hardcode hex color values when a registry style exists.

```r
library(gq)
reg <- gq_reg_main()  # load once per script — 51+ layers
```

**Core pattern:** `reg$layers$lake`, `reg$layers$road`, `reg$layers$bec_zone`, etc.

### Translators

| Target | Simple layer | Classified layer |
|--------|-------------|-----------------|
| tmap | `gq_tmap_style(layer)` → `do.call(tm_polygons, ...)` | `gq_tmap_classes(layer)` → field, values, labels |
| mapgl | `gq_mapgl_style(layer)` → paint properties | `gq_mapgl_classes(layer)` → match expression |

### Custom styles

For project-specific layers not in the main registry, use a hand-curated CSV and merge:

```r
reg <- gq_reg_merge(gq_reg_main(), gq_reg_custom("path/to/custom.csv"))
```

Install: `pak::pak("NewGraphEnvironment/gq")`

## Map Targets

| Output | Tool | When |
|--------|------|------|
| PDF / print figures | `tmap` v4 | Bookdown PDF, static reports |
| Interactive HTML | `mapgl` (MapLibre GL) | Bookdown gitbook, memos, web pages |
| QGIS project | Native QML | Field work, Mergin Maps |

## Key Rules

- **`sf_use_s2(FALSE)`** at top of every mapping script
- **Compute area BEFORE simplify** in SQL
- **No map title** — title belongs in the report caption
- **Legend over least-important terrain** — swap legend and logo sides when it reduces AOI occlusion. No fixed convention for which side.
- **Four-corner rule** — legend, logo, scale bar, keymap each get their own corner. Never stack two in the same quadrant.
- **Bbox must match canvas aspect ratio** — compute the ratio from geographic extents and page dimensions. Mismatch causes white space bands.
- **Consistent element-to-frame spacing** — all inset elements should have visually equal margins from the frame edge
- **Map fills to frame** — basemap extends edge-to-edge, no dead bands. Use near-zero `inner.margins` and `outer.margins`.
- **Suppress auto-legends** — build manual ones from registry values
- **ALL CAPS labels appear larger** — use title case for legend labels (gq `gq_tmap_classes()` handles this automatically via `to_title()` fallback)

## Self-Review (after every render)

Read the PNG and check before showing anyone.

### Placement

1. Correct polygon/study area shown? (verify source data, not just the bbox)
2. Map fills the page? (no white/black bands)
3. Keymap inside frame with spacing from edge?
4. No element overlap? (each in its own corner)
5. Legend over least-important terrain?
6. Consistent spacing across all elements?
7. Scale bar breaks appropriate for extent?

### Does it communicate?

Every check above is about **where elements sit**. A map can satisfy all seven
and still fail to say what it is about — so these are not optional extras, they
are the half of the review that the placement list structurally cannot reach.

8. **Is every prominent feature in the legend?** Work the other direction from
   the usual one: rank what draws the eye *in the rendered image*, then confirm
   each of the top few appears in the legend. Building the legend from the layer
   list instead answers "did I list my layers", which is a different question and
   always says yes.
9. **Is the subject obvious to someone who has never seen this area?** An AOI
   that renders identically to its surroundings is not delineated by a thin
   boundary line — the reader has to be told where to look. Containment (a fill,
   a dimmed exterior, a mask) is what does it.
10. **Does the symbology have a hierarchy, or is it flat?** If one class holds
    the great majority of the features, it will dominate regardless of how
    correct its size is. Ask what the map is *for* and de-emphasise or filter
    accordingly — and say in the caption or prose that you did.
11. **Does the basemap earn its contrast cost?** A basemap that adds no readable
    terrain is not neutral: it lowers the contrast of everything drawn over it.
    Blend parameters that mute it into a flat field are worse than no basemap.
12. **Is the type sized for the width it is published at, not rendered at?** A
    7 in figure squeezed into a ~700 px column loses roughly 40% — text set at
    `size = 0.5` for the render lands at a few pixels on the page. Check the
    figure at its delivered width.

### Why this half exists

Added 2026-08-26 after gq's flagship vignette map was reported as passing all
seven placement checks and was, on being looked at, unreadable: 89% of its point
symbols were one modelled class, the basemap was a featureless grey field, the
AOI was indistinguishable from its surroundings, and the single most prominent
feature on the map — a bright red 397-feature habitat network — **was not in the
legend at all**, while the prose beneath the figure described its styling in
detail (gq#61).

The seven checks had returned green, accurately. They were simply not asking.

See the `cartography` skill for full reference: basemap blending, BC spatial data queries, label hierarchy, mapgl gotchas, and worked examples.

## Land Cover Change

Use [drift](https://github.com/NewGraphEnvironment/drift) and [flooded](https://github.com/NewGraphEnvironment/flooded) together for riparian land cover change analysis. flooded delineates floodplain extents from DEMs and stream networks; drift tracks what's changing inside them over time.

**Pipeline:**

```r
# 1. Delineate floodplain AOI (flooded)
valleys <- flooded::fl_valley_confine(dem, streams, area_field = "upstream_area_ha")

# 2. Fetch, classify, summarize (drift)
rasters   <- drift::dft_stac_fetch(aoi, source = "io-lulc", years = c(2017, 2020, 2023))
classified <- drift::dft_rast_classify(rasters, source = "io-lulc")
summary    <- drift::dft_rast_summarize(classified, unit = "ha")

# 3. Interactive map with layer toggle
drift::dft_map_interactive(classified, aoi = aoi)
```

- Class colors come from drift's shipped class tables (IO LULC, ESA WorldCover)
- For production COGs on S3, `dft_map_interactive()` serves tiles via titiler — set `options(drift.titiler_url = "...")`
- See the [drift vignette](https://www.newgraphenvironment.com/drift/articles/neexdzii-kwa.html) for a worked example (Neexdzii Kwa floodplain, 2017-2023)


# CI Monitoring

When this repo has GitHub Actions workflows, scan recent runs on session start. Catches failed pkgdown deploys, broken vignette builds, and stale citation regenerations that would otherwise linger until the user manually checks.

## On Session Start

```bash
gh run list --limit 5 --json status,conclusion,name,createdAt,databaseId \
  --jq '.[] | select(.conclusion == "failure")'
```

If any failures since the last visit, surface to the user before starting other work:

> Workflow `<name>` failed `<time>` ago (run `<id>`). Investigate with `gh run view <id> --log-failed`. Fix or proceed with current task?

User decides; do not auto-fix.

## Particular Failures Worth Naming

- **pkgdown** — docs site on GitHub Pages broken
- **R-CMD-check** — package may not install
- **Vignette / build-vignettes** — vignette docs incomplete
- **update-citation-cff** — CITATION.cff stale

## Why This Matters

Without this scan, post-merge workflow failures linger until someone (often the user) notices a stale docs site or a missing vignette. The session-start sweep catches them on the first re-entry into the repo.

## Pairs with `/gh-pr-merge`

The skill watches workflows triggered by a fresh merge in real time — that's the targeted catch. This convention is the backstop for failures that landed when no one was watching (merges via web UI, scheduled triggers, manually-triggered workflows).

## A green run does not mean the site is current

CI conclusion and published content are two different facts. Check the second one
directly when it matters — the deploy commit, not the run status:

```bash
git fetch -q origin gh-pages && git log -1 --format='%s' FETCH_HEAD
# "Deploying to gh-pages from @ owner/repo@<sha> 🚀"  <- is <sha> your HEAD?
```

GitHub can create a workflow run minutes after the push that triggered it, and
out of order with a later push. Observed 2026-08-26 in `fly`: `7a7700c` built and
deployed at 17:21, then its own *parent* `be77eca` had its run created at 17:22:52
— twelve minutes after that push — and deployed over it. Both runs green, `gh run
list` all success, published site one commit stale.

Things that do **not** fix this, so don't reach for them:

- `cancel-in-progress: true` — cancels an *overlapping* run. Here the runs never
  overlapped (`created == started` on both, second created after first finished),
  so there was nothing to cancel.
- A `concurrency:` group — the r-lib pkgdown template already sets one at the job
  level (`group: pkgdown-${{ github.event_name != 'pull_request' || github.run_id }}`).
  Grepping for a top-level `concurrency:` key misses it and invites a redundant
  "fix". Serializing runs doesn't order events that arrive late.

There is no workflow-side fix, because the reordering happens before the workflow
exists. The remedy is detection: check the deploy provenance, and re-dispatch
(`gh workflow run <file> --ref main`) if it's behind. Harmless when the stale
commit changed nothing the site publishes — confirm via `.Rbuildignore` / `_pkgdown.yml`
rather than assuming.

## Don't use `gh run watch` to wait

It polls hard enough to trip GitHub's *secondary* rate limit, which `gh api
/rate_limit` does not report — every primary bucket reads full while calls return
403. Retrying extends it. Poll sparsely with `gh run view <id> --json status,conclusion`,
and prefer `git fetch` over the REST API for anything git can answer.

## A setup failure and a build failure look identical in the status column

`gh pr checks` and the Actions UI report one word per job. A run that died fetching its
own toolchain and a run that died because the code is broken both read `fail`, and only
the second says anything about what you just shipped.

```
Error in download.file(...) : status was 'SSL connect error'
download of package 'pak' failed
Error in loadNamespace(x) : there is no package called 'pak'
```

That is `setup-r-dependencies` failing before the package was ever built. Seen
2026-09-02 on a tagged spacehakr release, where the same workflow had passed on the merge
commit minutes earlier with identical content — the natural but wrong reading is "the
release is broken".

**Read which step failed before drawing a conclusion**, especially on a release commit
where the instinct is to distrust the tag:

```bash
gh run view <id> --log-failed | grep -iE 'error|fatal' | head
```

If it died in dependency setup, rerun once. If it dies the same way again it is the
upstream CDN, and the honest move is to say so and stop — not to keep spending runs on
something no change in the repo can fix.


# Code Check — R packages

Traps specific to R package internals: `R CMD build`, `.Rbuildignore`, roxygen,
lintr, `data-raw/`, testthat, pak, and the DBI/duckdb/arrow data layer. Gated on
`NAMESPACE`, which is what separates the 16 package repos from the 16 bookdown
reports that also carry a `DESCRIPTION`. Spatial entries (terra, sf, bcdata) are
in `code-check-spatial.md`, which reports also load.

### Read-back shape must match write-back shape

A script that reads a file, transforms it, and writes it **back to the same path** is
idempotent only if the reader accepts the shape the writer produces. If it reads with
`col_names = FALSE` expecting raw input but writes a parsed frame with headers, the
second run parses its own output as data.

The damage is worst when the file carries a join key. In the fish data pipeline a
pit-tag merge re-derived `rowid` every run and wrote it back; a second run would have
appended the same 53 tags again and renumbered the key joining tags to individual fish,
silently shifting five prior years of records. A type error was the only thing that had
prevented it.

- Guard the merge on a natural key (`anti_join` on the id), not on run count.
- Write back only when there is something new.
- Test by running twice and diffing the file — `cmp` should report no change.

### Moving prose into a code chunk hides it from tools that scan the document

- Tools that scan an R Markdown document for prose — citation detection,
  cross-references, spell-check, word counts — skip code chunks. Making a section
  conditional by moving it into a `results='asis'` chunk therefore removes it from
  everything that was reading it as prose, with no error.
- Caught 2026-08 in `template_permit_fish`: the move hid the section's `[@key]`
  citations from `rbbt::bbt_detect_citations()`, and the next `bbt_write_bib()`
  **overwrote `references.bib` with zero entries** — breaking citations in every
  document sharing that Rmd, not just the one changed. The symptom is `(key?)` in
  the rendered output, far from the edit that caused it.
- Fix for rbbt specifically: pass keys used inside chunks explicitly —
  `bbt_write_bib(path, keys = union(bbt_detect_citations(), "the_key"))`.
- General rule: before moving content into a chunk, name what else was reading it
  as prose.

### `fs::dir_ls(glob = )` matches the FULL path, so a bare filename pattern matches nothing

- `fs::dir_ls(dir, glob = "form_*.gpkg")` returns **zero** for a directory full of
  `form_*.gpkg` files. The glob is tested against the whole path
  (`/Users/.../project/form_pscis.gpkg`), which does not start with `form_`.
- It fails **silently and in the safe-looking direction** — an empty result reads
  as "this project has none", not as "the pattern was wrong". Seen 2026-08-27 in
  rtj#221: a harvest driver found no forms in a project holding four, and a
  second glob (`"*/form_*.gpkg"`) masked it by accidentally matching.
- Use an anchored `regexp` instead, which is matched the same way but says so:
  `fs::dir_ls(dir, regexp = "/form_[^/]+\\.gpkg$", recurse = FALSE, type = "file")`.
- Set `recurse` deliberately while you are there. A recursive search of a Mergin
  project picks up `.mergin/`'s own cache copies and anything under `hold/` —
  stale duplicates that then get processed as if they were live.

### `glue()` trims common leading whitespace
- `glue::glue()` strips the common indentation of its input, so a template whose
  output must preserve exact indentation (XML, YAML, Makefiles, Python) comes
  out subtly wrong — valid-looking, wrongly indented.
- For those blocks use a raw string with a `gsub()` placeholder instead of a
  glue template. Seen in rfp's QML form builder, where the photo widget's XML
  indentation has to survive verbatim.
- Related, and the opposite mistake: glue does **not** re-parse interpolated
  values, so literal `{...}` inside a *value* is safe. Don't rewrite a working
  generator to escape braces that were never a problem — probe it first.

### `f(g(x)) <- v` needs a `g<-`, not an evaluated `g(x)`

- R parses **any** call on the left of `<-` as a replacement function, all the
  way down. `xml2::xml_text(node_for(ml)) <- expr` does not evaluate
  `node_for(ml)` and assign into the result — it looks for `` `node_for<-` ``
  and errors with `could not find function "node_for<-"`.
- It reads as correct because the single-call form is idiomatic and works:
  `xml_text(node) <- v`, `names(x) <- v`, `levels(f) <- v`. Only the *nested*
  form breaks, so the habit is what leads you into it.
- Fix: assign the inner result first.
  ```r
  target <- node_for(ml)       # not xml_text(node_for(ml)) <- expr
  xml2::xml_text(target) <- expr
  ```
- The error names a function nobody wrote, which sends you looking for a missing
  import or a typo rather than at the line's shape. Caught 2026-08-27 in rfp#201
  with `xml2::xml_text(.qgs_preview_node(ml)) <- expr`.
- Applies to every replacement form — `attr<-`, `[[<-`, `dim<-`, `st_crs<-`. If
  the left side has two calls, one of them has to move to its own line.

### `download.file(quiet = TRUE)` never tells you the HTTP status — read it from `curl`

`utils::download.file(method = "libcurl")` sets `CURLOPT_FAILONERROR`, so on a 4xx with a
body libcurl aborts before writing it and R raises, in order, a *warning*
(`downloaded length 0 != reported length 842`), a second warning carrying the status
(`HTTP status was '404 Not Found'`), and an error. With `quiet = TRUE` the error text is
just `cannot open URL '…'`. So:

- a `tryCatch(warning = …)` unwinds on the **first** warning and never sees the status;
- a `tryCatch(error = …)` with warnings suppressed sees an error with no status in it.

Either way a text classifier reads a permanent 404 as a transient failure — or the
reverse. The dead-URL fixture that would expose it is exactly the one nobody keeps; an
httpbin `/status/410` has `Content-Length: 0`, skips the length warning, and passes.

Measured 2026-09-05 in knowledge#5: a fix that matched `HTTP status was '4..` classified
two ACAT 404s as `fetch_failed` and stopped a run that should have continued. The fix
that held reads the status explicitly:

```r
h    <- curl::new_handle(followlocation = TRUE, timeout = 120)
resp <- tryCatch(curl::curl_fetch_disk(url, dest, handle = h), error = function(e) NULL)
# NULL -> transport failure; else resp$status_code, and dest holds the error BODY on a
# non-200 (curl does not set FAILONERROR), so unlink(dest) on every non-ok path
```

Same shape for page fetches: `xml2::read_html(url)` on a 403 throws a message you would
have to parse; `curl_fetch_memory()` gives the code and `read_html(resp$content)` the page.

### `on.exit()` at a script's top level never fires
- `on.exit()` registers a handler on the *current frame*. At the top level of a
  file run with `Rscript`, that frame is the global environment, which never
  exits — so the handler is registered and then simply never called.
- It looks correct, and it is correct inside a function. The failure is silent
  and, when the thing being cleaned up lives outside the repo, invisible to
  `git status`: rfp accumulated six staging directories in `$HOME` before anyone
  noticed, from two different scripts that both looked right.
- Use `withr::defer(cleanup, envir = globalenv())`, which registers a finalizer
  that runs at session end. It prints `Ran 1/1 deferred expressions` — that line
  in script output is the confirmation it worked, not noise.
- Probe rather than assume when checking this: a cleanup target inside
  `tempdir()` is removed by R's own session cleanup regardless, so testing there
  reports success for both the working and broken versions.

### A `data-raw/` script must load the source tree, not the installed package
- `requireNamespace("pkg")` succeeds whenever **any** version is installed, so a
  guard shaped like `if (!requireNamespace("pkg")) pkgload::load_all()` silently
  runs against the installed one. A generation script operates on the source
  tree by definition; reading a different copy of the package to do it is the
  bug.
- The gap is routinely enormous and nobody notices, because nothing errors.
  Measured in rfp: the installed package was **sixteen releases behind** the
  working branch, with a lookup table missing a whole row and an internal
  constant missing three entries.
- It fails quietly in both directions. One script iterated the stale lookup and
  **skipped an item entirely**, reporting 11 where the source had 12. Another
  generated two committed artifacts through a stale scan; those artifacts turned
  out byte-identical when regenerated correctly, but only because the input data
  happened not to exercise the missing entries — the same accident that let the
  original bug ship.
- Fix: `pkgload::load_all(quiet = TRUE)` **unconditionally**, and call functions
  unqualified. `pkg::` and `pkg:::` in a `data-raw/` script reach the installed
  namespace and defeat the point.
- Check for it by asserting a count the script should cover:
  `nrow(registry)` against items processed. A silent skip is invisible otherwise.

### `lintr` also resolves against the installed package, not the source tree
- The same installed-vs-source trap as the `data-raw` case above, in a tool
  where it reads as a code defect rather than a stale dependency.
  `object_usage_linter` resolves a package-level object through the installed
  namespace, so **every internal constant added on the current branch** is
  reported as `no visible binding for global variable`.
- It is convincing because the surrounding constants resolve fine — they are in
  the installed copy. Confirm before "fixing" anything:
  ```r
  exists(".my_new_constant", asNamespace("pkg"))   # FALSE  -> lint artifact
  exists(".an_old_constant", asNamespace("pkg"))   # TRUE
  ```
  If the new one is absent from the installed namespace and the old one is
  present, the warning clears on reinstall and there is nothing to change.
- Corollary for reading a lint report at all: **compare against the baseline
  before treating a count as signal.** Lint the file as it stands at `HEAD`
  (`git show HEAD:R/f.R > /tmp/f.R`) and diff the counts by linter. A file that
  already carried 26 lints in the repo's prevailing style is not a file your
  change made worse.
- And check whether the repo has a `.lintr` at all. Without one, `lint_package()`
  runs the strict defaults, which disagree with tidyverse continuation-indent
  style on essentially every wrapped call — hundreds of hits that are house
  style, not defects.

### Regenerated binaries churn git even when nothing changed
- Formats that embed a creation timestamp or other run-varying metadata produce
  a different file on every rebuild. An unconditional write then puts a binary
  diff in every commit, and a real change becomes invisible among the noise.
- GeoPackage is the live case: `gpkg_contents.last_change` made a ~100 KB file
  churn on each rebuild of an unchanged form.
- **Remove the nondeterminism at the writer where the format lets you.** For
  GDAL-written GeoPackages that is one config option — `OGR_CURRENT_DATE` pins
  the timestamp GDAL would otherwise stamp into `gpkg_contents.last_change`:
  ```r
  sf::st_write(x, path, layer = lyr, delete_layer = TRUE, quiet = TRUE,
               config_options = c(OGR_CURRENT_DATE = "2000-01-01T00:00:00.000Z"))
  ```
  Measured 2026-08-28 on GDAL 3.8.5: two writes of identical data differed
  (`cdac16f3…` vs `2198f60c…`); pinned, they were byte-identical. Pin a
  **constant**, not a run-derived value — the real write time already lives in
  git, and a value that varies per run is the churn you were removing. COG via
  `terra::writeRaster(filetype = "COG")` was deterministic under the same test
  with no intervention, so not every regenerated binary churns; check the
  format before adding a guard. Bounds: minimal fixtures (a 3-point layer, a
  60×60 raster) — verify on a multi-layer GeoPackage with rtree indexes before
  wording it as a guarantee; and it reaches only GDAL writes, so a `sqlite3`
  write to the same file still moves the header change counter
  (`code-check-spatial.md`, "A GeoPackage is a SQLite database, and that leaks in three
  ways"). (soul#153)
- **Where the format is genuinely nondeterministic, write to a temp file,
  compare the things that actually matter, replace only on a real difference.**
  Choose the comparison deliberately — for a GPKG that is `PRAGMA table_info`
  **plus** geometry type **plus** CRS, because CRS lives outside the column list
  and comparing columns alone silently keeps a stale projection. Then a file
  appearing in the diff means something genuinely changed.
- Text artifacts that are byte-stable can just be rewritten every time; the
  guard is only worth it where the format is not.

### Tests that silently do not run

`expect_snapshot()` **skips on CRAN**, and `testthat` treats a non-interactive run
as CRAN by default. A regression net written with it passes locally, reports
`SKIP` in CI, and is silently absent in exactly the run that matters. The failure
is invisible: the suite is green either way.

Seen 2026-08-28 in link#227 — a golden test pinning the output of the most
delicate SQL in the package, written to make a refactor provably
behaviour-preserving, was skipped the moment it ran non-interactively.

Use explicit assertions for anything that is a **regression net**:

```r
# Skips on CRAN — fine for reviewing human-readable output, useless as a guard
expect_snapshot(list(n = nrow(got), ids = sort(got$id)))

# Runs everywhere
expect_identical(nrow(got), 8L)
expect_identical(anyDuplicated(got$id), 0L)
```

If the pinned values come from live data that may legitimately move, say so in a
comment and re-pin deliberately — do not loosen the assertion to make it stop
failing, which converts the guard back into decoration.

Same class, different mechanism: `skip_if_no_db()` and friends are correct for
tests that genuinely need a database, but a suite where the only coverage of a
behaviour sits behind a skip has no coverage of it in CI. When a check matters,
give it a mock-based twin that always runs.

### pak Behavior
- pak stops on first unresolvable package — all subsequent packages are skipped
- Removed CRAN packages (like `leaflet.extras`) must move to GitHub source
- PPPM binaries may lag a few hours behind new CRAN releases

### Reproducibility
- Branch pins (`pkg@branch`) are not reproducible — document why used; the fuller pin policy (no suffix by default, never a bare SHA) is under "Two repos pinning the same remote" below
- Pinned download URLs (RStudio .deb) go stale — document where to update

### `R CMD build` ships every top-level directory not in `.Rbuildignore`
- Internal coordination directories — `comms/`, `research/`, `planning/`, `dev/` — land in the tarball and therefore in the library of anyone installing from GitHub. `R CMD check` only flags this as a NOTE ("Non-standard files/directories found at top level"), which is easy to scroll past among the notes you have decided to live with.
- `.gitignore` does **not** cover this. A locally-gitignored file (e.g. `.aider.chat.history.md`) is still picked up by `R CMD build`.
- The gap appears over time rather than at scaffold: found 2026-07-31 in rfp, where `planning`, `.claude`, `CLAUDE.md` and `dev` were all excluded but `comms` and `research` — added later — were not. 10 files of cross-repo coordination notes were shipping.
- This matters most for the three-layer repo split (see `newgraph.md`): `comms/` is internal-by-definition, so a public-flipped package that ships it leaks exactly what the flip was meant to purge.
- Audit every R repo at once:
  ```bash
  for d in ~/Projects/repo/*/; do
    [ -f "$d/DESCRIPTION" ] || continue
    for sub in comms research planning dev; do
      if [ -d "$d/$sub" ] && ! grep -qE "^\^${sub}\\\$" "$d/.Rbuildignore" 2>/dev/null; then
        echo "$(basename "$d") ships $sub/"
      fi
    done
  done
  ```
  Run 2026-07-31: 20 hits across 16 repos. `comms/` in `link`, `fish_passage_template_reporting`, `neexdzii_kwa_benthic_2025`; `research/` in `link`; the rest `planning/` or `dev/`.
- Verify a fix against the tarball, not the config — the `.Rbuildignore` regex is easy to get subtly wrong:
  ```bash
  R CMD build . >/dev/null && tar tzf pkg_*.tar.gz | grep -c '^pkg/comms/'   # expect 0
  ```
- **`.Rbuildignore` does not govern pkgdown, and `.gitignore` does not govern `R CMD build`.** Five fixes in one issue (ngr#7, merged as ngr#36, 2026-09-02), each correct on its own surface and silent on an adjacent one: `^CLAUDE\.md$` in `.Rbuildignore` while pkgdown rendered `CLAUDE.html` (200), served the verbatim `.md` (200) and indexed it in `search.json` on a public site; `README.html` in `.gitignore` while the tarball shipped it; `--no-build-vignettes` in `build_args` sparing five runners a live third-party API while `R CMD check` reported vignette sources with no `inst/doc` as 2 WARNINGs — failures under r-lib's `error_on: "warning"`. `.Rbuildignore`, `.gitignore`, pkgdown's root-page rendering and the deploy action's `clean:` are four enforcement points for "what ships and what publishes", and none consults the others. `pkgdown-publishing.md` prescribes the `rm -f CLAUDE.md` step and an allowlist gate. Verify each surface's own artifact — `tar tzf` the tarball, `curl` the published URL — with a positive control, because "everything 404s" and "the site is broken" are the same observation without one; and where two requirements conflict outright, as the vignettes did, find the third option: `vignettes/articles/`, which `R CMD build` does not build as vignettes — and which `usethis::use_article()` also adds to `.Rbuildignore`, so the sources do not ship either. The mechanism is in `code-check.md`, "A guard's scope, escape hatches, and remedies".

### `R CMD build` ships the `.git` FILE when you build from a worktree

The rule above covers directories someone added. This is the one nobody added:
in a checkout made by `git worktree add`, `.git` is a **file** holding
`gitdir: /absolute/path/to/the/developer/machine`, and it ships.

R excludes version-control entries with an `isdir`-gated rule:

```r
isdir   <- dir.exists(allfiles)                                  # .build_packages
exclude <- exclude | (isdir & (bases %in% c("check", "chm", .vc_dir_names)))
```

A worktree's `.git` is not a directory, so the gate is false and nothing else
matches it. `.gitignore`, `.gitattributes` and `.gitmodules` are safe — they sit
in `.hidden_file_exclusions`, which is **not** `isdir`-gated. `.git` is the only
version-control name with a legitimate file form and no ungated rule, so it is
the whole exposure. Fix is one anchored line, which touches neither `.github` nor
`.gitignore`:

```
^\.git$
```

**This reaches every repo here, because `code-check.md` prescribes
worktree-per-session.** Measured 2026-08-31 in gq#76: `gq/.git` present in the
tarball, absent after the line. Sweep the R repos — any package built from a
worktree has been shipping a developer path.

Two things generalise past R:

- **Ask which *layout* a guard runs in, not only what it asserts.** The guard
  that would have caught this tested `dir.exists(".git")` — false in a worktree —
  so in the checkout layout these conventions prescribe, it silently skipped.
  Fixing the skip made it run there for the first time and it failed immediately
  on something real. A guard that cannot run is not a weaker guard, it is an
  absent one. Same family as "A guard's scope, escape hatches, and remedies" in
  `code-check.md`, one level out: there
  the lookup is wrong, here the whole test never executes.
- **A fix that is invisible in the layout CI runs needs pinning.** Removing
  `^\.git$` changes nothing in a `.git`-*directory* checkout — which is what
  `actions/checkout` produces — because R excludes it anyway there. So the line
  protecting the tarball was itself unguarded. Assert the property directly
  (`expect_true(rbuildignore_excluded(".git", patterns))`), since it is a fact
  about the pattern file rather than about this checkout.

### `.Rbuildignore` has no comment syntax — every line is a live regex

`tools:::inRbuildignore` loops over every non-empty line and ORs `grepl()` of it
against the file list. It strips nothing and skips nothing, so a `# explanatory
note` is a pattern. One containing `.*` or a leading `^` silently drops files
from the tarball, and nothing reports it.

Caught 2026-08-31 in gq#76, in prose added to that file the same day. Measured
benign there (all five lines compiled, none matched any of 226 shipped paths) and
removed regardless. Keep the rationale in the guard or the commit message.

Generalises to any line-oriented config whose reader does not implement comments
— check before assuming `#` is inert, because the failure is silent and the file
*looks* documented.

### Base name shadowing in formal args
- Avoid `names`, `length`, `data`, `c`, `t`, `T`, `F`, etc. as formal argument names. R's function-lookup fallback often rescues `names(x)` calls inside a function whose arg is also called `names` — but it's a confusing read, breaks under refactors, and generates a real "could not find function" error when the lookup heuristic misses (e.g. inside lapply/vapply/match.fun chains). Prefer descriptive alternatives: `label_names`, `n`, `df`, etc.
- Caught in mc#33 round 1 — `mc_label_ensure(names)` worked by luck when calling `names(existing)` to read a named-vector's names; renamed to `label_names` for safety.

### Cross-function consistency for label/string normalization
- When two functions in the same package both decide whether a string is a "system value" (or any normalized form), they MUST use the same comparison. Mismatches are silent bugs that surface only on edge cases.
- mc#33 example: `mc_label_ensure` used `toupper(nm) %in% sys` (case-insensitive system-label skip), but `resolve_label_names` used `nm %in% sys` (case-sensitive). Result: `add = "inbox"` with `create_missing = TRUE` was silently broken — ensure skipped creation, resolve couldn't match. Fix: both use `toupper(nm) %in% sys` and the resolver normalizes its return to the canonical case.
- Generalized check: when reviewing a diff that adds normalization (case, whitespace, prefix-trim) on one side of an interaction, grep for the other side and align them.

### `$` on a list partial-matches, so a longer sibling key answers for a missing one

- `x$foo` on a list returns `x$foo_bar` when `foo` is absent and `foo_bar` is the only key with
  that prefix. `[[` does not — it matches exactly. This is base R behaviour on **lists**, not a
  quirk of any package, and it fires on anything parsed from JSON or YAML.
- It fails toward a **confident wrong answer**, and the damage lands on the `is.null()` guard
  rather than on the read:
  ```r
  x <- list(link_log_note = "no log table in source schema")
  is.null(x$link_log)     # FALSE  <- the NOTE answered
  is.null(x[["link_log"]])# TRUE
  ```
  So "the row is absent, explain why" becomes "the row is present" and the code then reports every
  field of it missing — an error message pointing nowhere near the cause.
- The sibling-key shape is common precisely where it hurts: `x`/`x_note`, `id`/`ids`,
  `item_ids`/`item_ids_complete`, `path`/`pathname`, `count`/`counts`. Two of those were live in
  one 80-line file (floodplains#33, 2026-09-01), and the first cost a failure three checks away
  from its cause.
- **Rule: read parsed documents with `[[`.** Reserve `$` for objects whose key set you control and
  that have no prefix pairs — and even then it is a habit worth not having, because the key set is
  controlled until someone adds `_note`.
- Where the convention matters, pin it with a **premise assertion** so it cannot be tidied away by
  someone who does not know why:
  ```r
  expect_true(is.null(x[["link_log"]]) && !is.null(x$link_log))   # why this file uses `[[`
  ```
- `warnPartialMatchDollar = TRUE` surfaces it globally and is worth setting while debugging a
  "this field is present when it should not be" symptom. It is off by default, so nothing tells
  you otherwise.


### A database driver's value is not a base R type — and it fails twice

A column fetched through DBI does not arrive as the base type its SQL type suggests. RPostgres
returns `text[]` as class **`pq__text`**, for which `is.list()` is **FALSE**, `length()` is **1**,
and the single element is the **raw Postgres array literal** — `"{BT,CH,CO}"`, braces and all.

That shape defeats a type-dispatching coercion twice over, and the second failure is the dangerous
one:

```r
x <- row$species                    # class pq__text
is.list(x)                          # FALSE  -> the list branch is skipped
length(x)                           # 1      -> the vector branch is skipped
                                    # falls through unchanged
jsonlite::toJSON(x)                 # Error: No method asJSON S3 class: pq__text
x[[1]]                              # "{BT,CH,CO}"  <- unwrapping is NOT enough
jsonlite::toJSON(I(as.character(x[[1]])))
                                    # ["{BT,CH,CO}"] <- valid JSON, wrong value, NO error
```

- **First it errors**, which is survivable. **Then the obvious fix stops the error and emits a
  plausible wrong value** — one brace-wrapped string where an array was meant. Nothing downstream
  can tell. The literal needs parsing, splitting on *unquoted* commas: an element containing a
  comma is double-quoted, and a naive `strsplit` corrupts it silently.
- **Subsetting drops the class.** `row$col[i]` returns a plain character; `as.list(row[1, ])`
  preserves `pq__text`. So a probe written the first way exercises a **different branch** than the
  code it is meant to be testing, and reports a pass the production path does not earn. Measure on
  the exact expression the caller uses, and assert the class as a premise.
- **No hand-built fixture contains one.** This is the fixture-cannot-reach-the-failure-mode rule
  arriving through a *type* rather than through data: a guard can be thorough, exercised against
  input built to break it, and still never construct a driver value. Build the driver shapes
  explicitly — `structure(list("{A,B}"), class = "pq__text")` needs no database.

Caught 2026-09-01 in floodplains#33: it would have aborted a pipeline step on its first real run,
after the expensive work had completed. It reached `main` because the database was wrongly believed
to be down (see `code-check-infra.md`, "The database is down is usually the probe"), so the only
code path that touches a driver value was never executed.

Generalises past Postgres arrays — `blob`, `json`/`jsonb`, `hstore`, `numeric` via `bit64`,
and every driver's own vector classes. **Whenever a DBI row crosses into a serializer, print
`class()` of each column once and write the coercion against what you see**, not against the SQL
type. And give the serializer a guard that names the offending *path*: jsonlite reports the class
with no location, which in a nested document is a scavenger hunt.

### arrow dplyr backend: no grouped slice — bridge to duckdb
- arrow's dplyr backend errors on grouped `slice_max`/`slice_min` (`arrow_not_supported("Slicing grouped data")`). The working pattern for any "latest per group" over parquet/S3: `arrow::open_dataset(...) |> dplyr::filter(...) |> arrow::to_duckdb() |> dplyr::group_by(...) |> dplyr::slice_max(...)`.
- The `to_duckdb()` bridge is also a return-type contract: helpers that return the lazy query should keep the bridge even when they no longer need it internally, or downstream callers using grouped verbs break. (water-temp-bc#17, #23)

### as.POSIXct on a Date pins UTC midnight; on a character it uses the machine zone
Two different hazards, both worth refusing, and an earlier version of this entry conflated them (soul#154; corrected 2026-09-05 after measuring across three machine zones on R 4.5.2).
- **`Date`:** `as.POSIXct.Date` is `.POSIXct(unclass(x) * 86400, tz = tz)` — the instant is **always UTC midnight**, and `tz =` changes only the rendering attribute. Measured: `America/Vancouver`, `UTC` and `Asia/Tokyo` all give epoch `1786752000` for the same `Date`, so it is machine-zone *invariant*. The hazard is the opposite one: a `Date` names a calendar day, which has no single instant, and R silently pins it to UTC midnight — **you cannot ask for local midnight**. A record dated `2026-08-15` that meant local midnight in BC is seven hours out, and nothing reports it. When accepting `Date` inputs, say which midnight you mean and construct it explicitly; widen Date upper bounds to `< next-day-midnight` so the whole calendar day is included. (water-temp-bc#17, trap#15)
- **`character` with no zone:** this *is* machine-zone dependent — the same three zones gave three different instants (`1786806000`, `1786780800`, `1786748400`). Force the zone at parse time (`as.POSIXct(x, tz = "UTC")` on a character honours `tz`), and see the next entry for the one-format-per-vector truncation.

### as.POSIXct on character infers ONE format for the whole vector
- `as.POSIXct(x)` on a character vector picks a single format by finding the first candidate that parses **every** element — and `strptime` **ignores trailing characters**. So one coarse value silently truncates the entire column, and nothing warns:
  ```r
  as.POSIXct(c("2026-08-15 18:33:46", "2026-08-15 18:34:20", "2026-08-16"))
  #> all three at 00:00:00   <- the times are gone
  ```
  One minute-precision value does the same to its neighbours' seconds. Order-independent, and the values are not `NA` afterwards, so an `is.na()` guard on the result cannot see it.
- Same family as the `Date` case above, and worse: that one shifts by a known offset, this one destroys information.
- Fix: match each value's **shape** with an anchored regex, then parse it with the format that shape implies — per element, not per vector. Anchoring at both ends is what turns trailing junk into an error instead of a silent truncation.
- `tryCatch` around the whole call is not a fix either. `as.POSIXct.character` **throws** on an unrecognised string rather than returning `NA`, so a catch-all handler that blanks the vector then makes the "which value failed?" report name element one — usually a perfectly good timestamp. Compute the failing set per element inside the error path.
- Caught 2026-08-24 in crate#9. Three bugs in one parse (this, a dropped `+02` offset, and the misleading error), all silent, all with the suite green at 171 passing.

### Inserting a helper between a roxygen block and its function rebinds `@export`

- roxygen2 attaches a block to **whatever object follows it**. Add a helper directly
  above the function the block documents and the docs, `@examples` and `@export` all
  bind to the helper. The real function loses its export, and roxygen writes an `.Rd`
  for an internal helper.
- `devtools::test()` will not catch it. `load_all()` exports everything regardless of
  NAMESPACE, so the suite stays green at full pass while the package's main function
  is no longer exported — it fails only for someone who installs it.
- Caught 2026-08-28 in fly#30: `export(fly_footprint)` disappeared and
  `fly_film_media.Rd` appeared; 120 tests passed throughout. The signal was in
  `devtools::document()` output, not the test run.
- Read what `document()` prints, every time. `Writing '<something unexpected>.Rd'` or
  `Deleting` on a file you did not touch is the tell. Cheap confirmation:
  ```bash
  git diff NAMESPACE            # an export you did not intend to change
  grep -c "^export(" NAMESPACE  # count should not fall
  ```
- Put internal helpers at the top of the file or in their own file. The roxygen block
  must sit immediately above the function it documents, with nothing between.

### open_dataset(unify_schemas = TRUE) requires aligned types
- Cross-prefix/file schema unification only merges what types allow: `timestamp[us, tz=UTC]` will not merge with naked `timestamp[us]`, `Grade: string` not with `Grade: double`. Audit the schemas of every file group BEFORE promising unified reads over a mixed archive; plan a normalization pass otherwise. (water-temp-bc#17)

### duckdb larger-than-memory dedup: shard the work — settings won't save you
- duckdb's **window operator** (QUALIFY row_number ...) does not spill enough to survive big partitions (OOM'd an 8 GB limit on a ~124M-row input). The **arg_max/struct-payload hash aggregate** cannot spill its state either (observed OOM with an empty temp dir). `preserve_insertion_order = false` and fewer threads help but do not fix it.
- **In-memory duckdb connections never offload to disk at all** — `SET temp_directory` on `dbConnect(duckdb())` is a no-op for operator spill. File-backed (`dbdir = <file>`) is required for any spilling.
- The structure that works at any scale: **hash-shard by a column inside the group key** (e.g. `hash(STATION_NUMBER) % K = k`, K = `ceiling(input_rows / shard_rows)`), one aggregation pass per shard, each writing its own ordered output file. A key never crosses shards, so dedup stays exact; memory scales 1/K. Extra passes cost scan time only — per-pass aggregate state is what OOMs, so when in doubt shard smaller. (water-temp-bc#23)
- **Local runs at the same duckdb `memory_limit`/`threads` do NOT validate a constrained runner.** 10M-row shards passed a Mac at the exact 4 GB / 2-thread settings but OOM'd the real 7 GB GHA runner (partition 46 squeaked through in 94s, 47 died 15s in) — abundant physical RAM masks how tight duckdb's accounting runs at its internal limit. Only the real runner is the real test; size shards with margin (water-temp-bc ships 6M), and treat a near-timeout/near-limit pass as a failure to fix, not a pass. (water-temp-bc#23 run 29675228557, fixed in PR #25)

### `nzchar(NA)` is TRUE — non-empty checks silently pass NA
- `nzchar(NA)` returns `TRUE`, so the natural "is this cell filled in" test — `all(nzchar(trimws(x)))` — waves through a column full of `NA`. `trimws(NA)` is `NA`, and `nzchar()` of that is `TRUE` unless you pass `keepNA = TRUE`.
- Use an explicit guard: `filled <- function(x) !is.na(x) & nzchar(trimws(x))`. Same trap in reverse for `read.csv()`, which yields `""` for an empty field but `NA` for a literal `NA` — so a file can fail one check and pass the other for the same visual blank.
- Bites hardest in validators, where the whole point is catching a half-authored row. (link#233, 2026-08: a dictionary contract test asserting every row carried a description would have passed on an entirely NA column.)
- **`readr` is how the all-`NA` column arrives, and typing it does not fix the count.** A CSV column that is empty in every row is typed **logical `NA`**, so the over-count is total rather than partial: `sum(nzchar(trimws(x$col)))` reports the row count where the honest answer is zero. Hit 2026-08-28 in a floodplains#44 regression harness — "6 citations survived" when the correct answer was 0. `col_types = cols(col = col_character())` stabilises the type and does nothing for the count, because readr's default `na = c("", "NA")` still yields `NA` (measured 2026-09-03); the `filled()` guard above is the remedy.
- **Filter the NA *before* `paste`, not after — `paste` stringifies it.** The remedy above is a predicate on a vector, and it stops working the moment the values are joined first: `unique(unlist(strsplit(paste(x, collapse = ";"), ";")))` turns an all-`NA` column into the literal key `"NA"`, which `nzchar()` then happily keeps because it is a three-character string. Measured 2026-09-04 in floodplains#77 — a README chunk deriving "N citations" from `flood_scenarios.csv` returned the bogus key `"NA"` for 20 of 23 areas, and one literal `NA` cell in a populated file gave 13 keys where 12 were real, silently. `x <- x[!is.na(x)]` on the way in. The tell is a comment calling `nzchar()` load-bearing sitting *after* a `paste`.

### A `for` loop that builds `aes()` captures the loop variable lazily

`aes()` quotes its arguments, so `aes(fill = lab[i])` is not evaluated until the plot is drawn —
by which time `i` holds its **last** value. Every layer added in the loop ends up carrying the
final iteration's label:

```r
for (s in scen) p <- p + geom_sf(data = d[[s]], aes(fill = lab[match(s, scen)]))  # WRONG
```

It fails toward a plot that *renders*, which is what makes it expensive: measured 2026-09-04 in
floodplains#77, a three-scenario panel drew as one solid colour with a one-entry legend, and it
looks exactly like a z-order bug — reversing the draw order changed which colour won and nothing
else, twice, before the cause was found.

Bind the layers into one frame with a factor whose **level order is the draw order**, and let a
single `geom_*` map it:

```r
d <- do.call(rbind, lapply(ord, function(s) { g <- d[[s]]["geom"]; g$grp <- lab[match(s, scen)]; g }))
d$grp <- factor(d$grp, levels = lab[match(ord, scen)])
ggplot() + geom_sf(data = d, aes(fill = grp)) + scale_fill_manual(values = pal, breaks = lab)
```

`breaks =` then pins legend order independently of draw order, which you almost always want
reversed from it. Same trap for any `lapply`/`Map` over layers, and for `vapply` closures that
capture an index rather than a value.

### `strsplit()` drops a trailing empty field, so a trailing separator vanishes

```r
strsplit("a|b", "|", fixed = TRUE)[[1]]   # "a" "b"
strsplit("a|",  "|", fixed = TRUE)[[1]]   # "a"        <- length 1, not c("a", "")
strsplit("|a",  "|", fixed = TRUE)[[1]]   # ""  "a"    <- leading empty IS kept
```

Leading empties survive and trailing ones do not, which is what makes it hard to
reason about from memory. The failure is silent and lands on the **guard**, not the
happy path: a validator refusing an empty part in a `|`-separated key cannot fire on
`"a|"`, because by the time it looks there is no empty part left — and `"a|"` is the
spelling a person is most likely to type.

Fix with a sentinel, so the split sees a non-empty last field:

```r
.split_keep <- function(x, sep) {
  parts <- strsplit(paste0(x, "\u0001"), sep, fixed = TRUE)[[1]]
  parts[length(parts)] <- sub("\u0001$", "", parts[length(parts)])
  parts
}
```

**Third instance of this class in one repo**, which is why it is here rather than in a
commit message. rfp#268: a `layer<TAB>base<TAB>` TSV read as three fields to `awk` and
two to R, so a path could be read as a base. rfp#275: `.nk_cols("a|")` returned `"a"`,
so a trailing `|` was absorbed and the empty-part guard was unreachable — found because
that guard *failed to throw*, not by review. The general form is that R and every other
splitter you hand the string to disagree about the last field.

Two habits: when a separator is user-authored, assert the round trip on `"a|"`,
`"|a"` and `"a||b"` explicitly; and when a guard on malformed input will not fire,
suspect the tokenizer before the predicate.

### `identical()` on two reader results tests the reader, not the file

`identical(read_csv(f), read_csv(f))` can be **FALSE** for the same unchanged bytes:
readr tibbles carry a `problems` attribute — an external pointer — that differs between
reads (readr 2.2.0; `spec` is identical, measured). An
assertion written that way fails spuriously and sends you looking for a bug in the code
under test — the one red check in an otherwise-green guard was the assertion, not the
code (floodplains#44, 2026-08-28).

When the claim is "this file was not modified", compare the **file**:
`tools::md5sum()`, or `readLines()`. Compare parsed objects only when the claim is
genuinely about content, and then compare the columns you mean rather than the whole
object.

### Under `R CMD check`, tests run from a temp dir against the INSTALLED package

Two shapes, both green under `devtools::test()` and broken under `R CMD check`,
`devtools::check()`, a tarball check, or an installed-tests run — the direction that
costs the most time. The `.git`-file entry above asks which *layout* a guard runs in,
and the `data-raw/` entry is the mirror image (a script that should read the source
tree reading the installed copy); these are about where the tests *run* and what
package they *see*.

**The tests run against the installed package.** An installed `R/` holds `<pkg>`,
`<pkg>.rdb` and `<pkg>.rdx` and **zero** `.R` files, so a test reading the source tree
finds nothing. Measured on rfp (rfp#257):

```
$ Rscript -e 'cat(length(list.files(system.file("R", package="rfp"), pattern="[.]R$")))'
0
```

The live case was an oracle asserting that every delegation target exists in the
package delegated to, via `file.path("..", "..", "R", paste0(nm, ".R"))` guarded by
`if (!file.exists(path)) return(character())` — always taken under `R CMD check`, so the
oracle checked nothing. Reproduced against the installed package in a directory with no
source `R/` beside the tests: the source-file scan failed 1 of 16, the function-body
scan failed 0 of 19. **Read what will actually run**, which exists in every layout:

```r
src <- unlist(lapply(names(shims), function(nm) {
  deparse(body(get(nm, envir = asNamespace("pkg"))))
}))
```

The premise is what caught it: `expect_true(length(targets) > 0)` turned a silently
vacuous pass into a loud failure. The same trap reaches any test reading `data-raw/`
or `inst/` by relative path, or a fixture anchored at the repo root — `system.file()`
is the portable form; a relative path out of `tests/testthat/` is not.

**The tests run from a temp dir.** `devtools::check()` defaults `check_dir` to a temp
directory, so tests execute from `<tmp>/pkg.Rcheck/tests/testthat`. A test that asserts
the runner's working directory — `expect_match(.crd_git_provenance(".")$repo, …)`,
which asserts cwd is a git worktree — errors there because `git -C .` fails
(cred#23/#25). The tell: the assertion describes the *environment*, not the function.
Build a fixture instead (`git init` a temp dir, add a known remote), which also makes
the assertion mean something, since the expected value is then known rather than
whatever the runner happens to sit in. Verify by running the suite from outside the
worktree, not just `devtools::test()`.

### CSV whitespace: `trim_ws` and `strip.white` do not do what the name suggests

- `readr::read_csv()` defaults to **`trim_ws = TRUE`** and silently strips leading
  and trailing whitespace. Where whitespace is *meaningful* — a QGIS layer name
  deliberately prefixed with a space so it sorts first — a trimmed value binds to
  nothing, with no error. Use base `utils::read.csv()`, or pass
  `trim_ws = FALSE`.
- `read.csv(strip.white = TRUE)` applies **only to unquoted fields**, and
  `write.csv()` quotes every character column. So a round-trip guard that
  compares `read.csv()` against `read.csv(strip.white = TRUE)` is *structurally
  incapable of failing* — both readers return the same thing, and the check
  passes for nothing.
- The second point is the trap: the guard looks right, runs green, and proves
  nothing. Probing for the real failure mode is what surfaces the `readr` one.
  Caught 2026-08 in rfp#174, where five leading-space layer names were at stake.

### `R CMD check` rejects a filename containing a space

- "checking for portable file names" fails on any file in the built package
  whose name has a space. It is an ERROR, not a NOTE, so CI goes red.
- Bites when shipped files are named after human-readable strings — layer names,
  form labels, report titles. 40 of 50 in one case, one of which *began* with a
  space.
- Fix: derive a slug for the filename and keep the real name in an index CSV
  beside it. Resolve through the index, never by reconstructing a path from the
  display string.

### A library call that dispatches on a global option is not a pure function

A function whose *units* or *algorithm* are chosen by a session-wide setting behaves
differently depending on what the caller did before reaching your code. Inside a
package that is not a nuisance, it is a silent correctness bug: the option is set
somewhere you do not control, usually for a good reason, and your result changes
without any warning.

`sf::st_distance()` is the live case. With s2 on — the default — a lon/lat distance
comes back in **metres**. With s2 off it does not. And `cartography.md` in this very
repo prescribes **`sf_use_s2(FALSE)` at the top of every mapping script**, so the
setting is routinely off in exactly the sessions that do spatial work.

A tolerance compared against that number then silently changes what it means. A gate
written as "reject a fix whose bracketing vertices are more than 50 m apart" becomes
"more than 50 degrees apart" — which rejects nothing, on a planet 180 degrees wide.
It fails toward **pass**, and neither the code nor the output carries a unit.

- **The tell is a call whose behaviour is documented in terms of a global.** Grep the
  function's docs for `options(`, `Sys.setenv`, or a package-level `*_use_*` toggle.
  If the answer depends on one, you cannot call it from library code and reason about
  the result locally.
- **Compute it yourself when the maths is small enough to own.** A haversine is six
  lines, has no global state, and was measured against `sf::st_distance()` over 200
  BC-scale pairs at **under a millimetre** of disagreement. A gate that is a fraction
  of a percent out is strictly better than one whose units move with a setting.
- **Where you must call it, pin the option locally** (`withr::with_options()`, or the
  library's own scoped setter) rather than assuming the caller's state — and assert the
  unit in a test, because that is the property that silently changes.

Generalises well past `sf`: `stringsAsFactors` historically, `OutDec`, `digits`,
`stringi` locale collation (see the `sort()` entry above), pandas' `mode.chained_assignment`,
anything reading `TZ`. Ask of any library call in package code: *what could a caller
have set that changes this answer?*

Caught 2026-09-01 in trap#25 while replacing a time-based tolerance with a
distance-based one — the gate was the whole point of the change, and it would have
been unitless in half the sessions that ran it.

### `identical(-0, 0)` is TRUE in R, and the two still digest differently

A hash over R's serialized bytes — which is what `digest::digest()` takes by default —
separates positive and negative zero, even though every value comparison says they are
the same. So a "normalize the values before hashing" routine that collapses `NaN` and
`NA_real_` can still be machine-dependent through a sign nobody can see.

```r
identical(-0, 0)                                    # TRUE
digest(c(-0, 1)) == digest(c(0, 1))                 # FALSE
v[which(v == 0)] <- 0                               # the collapse; `which()` because
                                                    # v == 0 is NA where v is NA, and R
                                                    # refuses an NA subscript in assignment
```

Reachability is the part worth checking rather than assuming: an integer raster cannot
carry a signed zero, so an Int8 fixture proves nothing either way. It becomes live the
moment a float enters — a warped DEM interpolating to exactly sea level, or a 0/1 mask
where half the cells are zero.

Caught 2026-09-02 in floodplains#65. It was written as a *premise* — an assertion
stating that a signed zero could not matter, added for completeness — and the premise
went red. Two habits from that: write the premise you believe is obvious, because it
costs one line and is the only thing that can contradict you; and when a normalization
exists to remove machine dependence, enumerate the axes it does **not** cover rather
than trusting the two you thought of.

### Two repos pinning the same remote at different tags is an unsolvable install

`Remotes:` pins are per-repo, but resolution is global. When repo A pins
`Owner/pkg@v2` and depends on repo B that pins `Owner/pkg@v1`, `pak` is asked for one
package at two tags and refuses:

```
! Could not solve package dependencies:
* deps::.: dependency conflict
```

The message names **neither the package nor the tags**. Nothing in the failing repo's
own `DESCRIPTION` looks wrong; the conflict is only visible by reading the transitive
dependency's `DESCRIPTION` too.

The cost arrives before the protection does. A pin buys a reproducible install and
insulation from a broken default branch; it charges a repin in every consumer on every
release of the pinned package, and any two consumers that drift apart produce this.
With one consumer a pin is free, so the trap is invisible until the second appears.

Decide deliberately, and apply the decision to *every* consumer at once:

- **Pin everywhere** when the dependency's own CI is weak or absent — accept the repins.
- **Pin nowhere** when it has a real check matrix — accept that a break on its default
  branch turns consumers' CI red on unrelated PRs.

Mixing the two is the only option that fails outright. Note the asymmetry when choosing:
pinned, a break is loud, immediate and correctly attributed; unpinned, it is rare,
delayed, and shows up in a repo that did not change.

Measured 2026-09-02 across ngr/rfp/spacehakr: the pin was added when spacehakr had no
releases and a live `R CMD check` ERROR, and the second consumer arrived after
spacehakr had a five-runner check matrix. Unpinned both.

The symptom is misleading in a second way: **CI fails with no check output at all**,
because dependency installation dies before anything runs. A red run whose log contains
no `R CMD check` section is this.

Two things the pin decision above leaves implicit, and the second is the policy:

- **A `Remotes:` entry is required; a version suffix on it is not.** These packages are
  not on CRAN, so the entry is how pak finds them at all. Only the `@tag` / `@sha` half is
  optional, and only that half conflicts. Conflating the two is what makes "get rid of
  the pins" ambiguous.
- **Default to no version suffix.** A pin in one repo becomes a constraint on every
  dependency graph that repo appears in. Pin only with a stated reason and a plan to
  move it.
- **A bare SHA pin is the harmful form and deserves naming separately.** It resolves to
  no release, never moves, and goes stale with nothing that would ever say so. Measured
  across the fleet, the two SHA-pinned repos sat 10 and 11 commits behind their target
  (3 and 5 months), while both *tag*-pinned repos were on their target's latest release
  and doing exactly what a tag pin is for. So: drop bare SHAs, default tags to absent,
  keep a tag only with a reason. Inventory at the time of writing: 10 repos carry
  `Remotes:`, 22 entries between them, 4 with a version suffix (inventoried in soul#164).

### `file(open = "wb", encoding = )` does not re-encode on write

The `encoding` argument to `file()` governs how bytes coming *in* are interpreted. It
does not convert on the way out, and a binary-mode connection ignores it entirely. So
this writes ASCII while reading as a declaration of UTF-16:

```r
con <- file(path, open = "wb", encoding = "UTF-16LE")
writeLines(c("Site,Longitude,Latitude", "S1,-127.1,54.2"), con)  # plain ASCII on disk
close(con)
```

This is worse than an ordinary bug because it usually appears in a **test fixture**, and
a fixture that silently writes the wrong thing produces a test that passes while proving
nothing. Reading the test tells you it is UTF-16; only the bytes disagree. Convert
explicitly and assert the bytes before trusting anything downstream:

```r
writeBin(iconv(txt, from = "UTF-8", to = "UTF-16LE", toRaw = TRUE)[[1]], path)
readBin(path, "raw", 8)   # 53 00 69 00 ... — null-interleaved, or it is not UTF-16LE
```

Measured 2026-09-02 in spacehakr#21: the encoding-conversion test passed against a
fixture that never had the encoding problem it existed to prove. Caught only because a
downstream end-to-end test produced a 0-row layer.

This is the "fixture that cannot reach the failure mode" family in `code-check.md`, by a
mechanism that family does not cover: there the fixture is visibly too easy, here it
*declares the right thing and does something else*, so no amount of reading finds it.

### A scalar helper called from `glue()` or `mutate()` recycles instead of erroring

`glue()` vectorises over its inputs. A helper that takes **one** id and filters a frame by it
(`assets[assets$id == item_id, ]`) does not — called inside the glue it compares a column against
the whole id vector with recycling, returns some other row's data, and **nothing errors**.

Measured 2026-09-04 in stac_floodplains_bc: every map popup rendered another item's download
links — BULK's offered `bowr`, `larl` and `mork`. The item name beside them was correct, which is
what made it invisible.

The sibling shape is a positional helper assigned into a re-ordered frame:

```r
props |> arrange(wsg) |> mutate(km2 = f(props))   # WRONG: f() indexes the UNSORTED frame
props |> mutate(km2 = f(props)) |> arrange(wsg)   # right: derive, then order
```

That one shipped too — 22 of 23 popups carried another watershed group's area, while the same
helper feeding a table was correct because there the `mutate()` already preceded the `arrange()`.
One derived fact, two consumers, only one right.

- **Anything not vectorised gets its own `mutate()` above the glue**, computed with an explicit
  `vapply(ids, \(i) f(x, i), character(1))`.
- **Derive before you re-order**, never after.
- The check that finds it is not reading the code: **assert each rendered row against its own
  key** — every href in an item's popup must contain that item's id. 230 links, 0 wrong, is a
  measurement; "looks right" is not.

### Never name a durable artifact by a hash the library reserves the right to change

`rlang::hash()` carries **no cross-version stability guarantee**, and rlang says so in
its own NEWS for 1.3.0:

> `hash()` now uses its own walking strategy… **This does mean that with this version
> all hash values will now be different.** …you should assume it's always possible for
> a new version to invalidate existing hashes.

So any hash used as a **filename, cache key, dedup key or content address** is a
dependency upgrade away from re-keying everything at once. The failure is silent in
the worst way: nothing errors, nothing warns, and the only symptom is work being
redone — "the pipeline got slower", which nobody files.

Measured 2026-09-03 in drift#48: rlang 1.3.0 landed between two frozen goldens, moved
every cache key, and orphaned an entire raster cache. Both pre-upgrade goldens fail to
reproduce; the one re-pinned afterwards holds.

**Hash content you canonicalize yourself, with a published algorithm.** Render each
member to a string, then hash *the string's bytes*:

```r
digest::digest(canonical_string, algo = "xxhash64", serialize = FALSE)
```

`serialize = FALSE` is the load-bearing part — it keeps R's serializer out of the path
entirely. The distinction that matters is not "digest is better than rlang" but that
digest implements a **specified** algorithm and pins this call shape to the upstream
XXH64 reference vector in its own test suite, where rlang reserves the right to change.
Pin that same vector as a control, so a future failure separates *the hashing layer
moved* from *our inputs changed* — a distinction a key golden alone cannot make.

Note this is the `serialize = FALSE` path specifically; the default serializing path has
its own hazard (see the `identical(-0, 0)` entry above).

Three things that will bite the canonicalizer, all measured:

- **`digest(x, serialize = FALSE)` silently hashes only the FIRST element of a character
  vector.** `digest(c("a","b"))` and `digest("a")` are byte-identical, no warning. If the
  canonicalizer ever returns length > 1 every key collapses to one value — a *total*
  collision, not a probabilistic one. `stopifnot(length(s) == 1L)` is the cheapest
  high-value line in such a change.
- **Branch `is.logical()` before `is.numeric()`**, or `TRUE` renders as `1` and collides
  with the number.
- **Prefer IEEE-754 bytes to `sprintf("%.17g")`** for numerics: `is.na(NaN)` is `TRUE`, so
  any `is.na()` sentinel collapses `NaN` into `NA_real_`, and `%g` routes through libc,
  making exponent formatting a platform variable. `writeBin(as.double(x), raw())` has
  neither problem. That matters most where a repo has **no cross-platform CI**, so its
  goldens are verified on exactly one machine.

**Tag each member by type** rather than relying on position-and-coercion. Without a tag,
`NULL` collides with the literal `"<none>"`, `NA` with `"<NA>"`, `10` with `"10"`, and
`TRUE` with `"TRUE"`. Those are usually prevented by coercion at the call sites — an
invariant held by convention and written down nowhere, which the next member added will
not follow.

**Truncate deliberately.** A key collision does not crash; it silently serves the wrong
artifact, and nothing downstream detects it. 12 hex chars is 48 bits; keeping a native
64-bit digest costs four characters. If a key is being broken anyway, that is the only
moment the widening is free.

**And version the directory the artifacts live in**, so a deliberate key change is a
migration rather than a silent orphaning: superseded generations stay findable and
countable instead of becoming disk nobody can attribute. Route *every* path-construction
site through one helper — the clear/reclaim function is the one that gets missed, and
left pointing at the superseded generation it reports success having deleted nothing.

### `vapply(..., USE.NAMES = FALSE)` strips ALL dimnames, row names included

A named `FUN.VALUE` looks like it guarantees row names on the returned matrix. It does not
survive `USE.NAMES = FALSE`, which drops the whole `dimnames` attribute rather than only the
column names taken from `X`:

```r
f <- function(x) c(path = paste0("p", x), n = "1")
r <- vapply(c("a", "b"), f, c(path = "", n = ""), USE.NAMES = FALSE)
is.null(dimnames(r))          #> TRUE
r["path", ]                   #> Error: no 'dimnames' attribute for array
```

Measured on R 4.5, 2026-09-04. The tell is that the error names `dimnames` while the code
that looks wrong is the `FUN.VALUE`, so the fix gets attempted on the wrong line — a first
attempt here shipped a code comment asserting the opposite, and only running the function
caught it.

Keep the default (`USE.NAMES = TRUE`) when you index rows by name; the column names it adds
are the input strings and cost nothing. Index positionally only with a comment saying why.

### `source()`ing a config into the render environment leaks it into the next render

`source(params$config)` inside an Rmd puts every config value into the environment `render()`
evaluates in. Render a second config in the same session and every value the second file does not
set is inherited from the first — silently, as wrong content rather than as an error. Verified in
safety_plan_template: a second config omitting `date_start` still resolved to the first config's
value. `render()`'s `envir` defaults to the caller's frame, so an `Rscript` loop over configs and
an interactive re-render after switching configs both hit it.

What it costs scales with what the config names. Here it reached a safety document: a plan could
render carrying another trip's dates, partner crew and emergency contacts, and — since those names
drive the output filename — overwrite that trip's PDF on the way past.

Source into its own environment, and clear the previous generation's names before copying:

```r
cfg <- new.env()
source(params$config, local = cfg)
if (exists(".cfg_names")) rm(list = intersect(.cfg_names, ls()))
.cfg_names <- ls(cfg)
for (.nm in .cfg_names) assign(.nm, get(.nm, envir = cfg))
```

**Guarding each read with `exists()` is not sufficient** — a stale value is exactly what `exists()`
is satisfied by. The guard reports the variable present, and the render proceeds on the last
render's answer.

This does not conflict with `bookdown.md`'s "Fresh-Rscript scoping gotcha — use
`render_book(envir = globalenv())`". That rule is about helper **functions** resolving through the
closure chain; this one is about per-render **config values**. Sourcing config into its own env and
then copying into the render frame preserves the shared lookup chain that rule needs
(safety_plan_template, commits `2cb8745`, `239b6ad`, 2026-09-06).

### One very long table cell hangs paged.js, and it presents as a Chrome timeout

A ~600-character free-text field in a `kable` cell wedged `pagedown::chrome_print` indefinitely.
The symptom is `Failed to generate output in N seconds (timeout)` followed by
`handle_read_frame error: asio.system:54 (Connection reset by peer)`, which reads as a Chrome or
environment problem — so the repairs it invites are environmental. Raising the timeout to 300 s and
isolating the Chrome profile both failed here before the real cause surfaced. paged.js was not
slow; it was not converging on a layout for a cell it could not break.

One call separates the two: `chrome_print()` a trivial HTML file. If that succeeds, Chrome and the
environment are fine and the document is at fault — then look for unbounded free-text columns in
rendered tables. Fix at the source, dropping or truncating narrative columns before they reach a
letter-width table, rather than tuning the renderer around content it cannot lay out
(safety_plan_template, commits `2cb8745`, `239b6ad`, 2026-09-06).

### `stats::aggregate()` has three separate silent behaviours, and each fails in a different direction

All three measured on R 4.5, all three met inside one 800-line script (drift#67).

**It ERRORS on an empty subset instead of returning a 0-row frame.**

```r
aggregate(n ~ id, df[df$keep, ], sum)      # df[df$keep, ] has 0 rows
#> Error in aggregate.data.frame(lhs, mf[-1L], FUN = FUN, ...) : no rows to aggregate
```

So a guard written *to keep an empty stratum alive* is exactly the branch that kills the run —
and it dies at whatever stage the empty subset first appears, which on a long pipeline is
usually the last one. Wrap it: return a typed 0-row frame when `nrow(sub) == 0`.

**`aggregate(formula)` applies `na.action = na.omit` to the model frame BEFORE `FUN` runs**, so
any `na.rm = TRUE` inside `FUN` is dead code and a row with `NA` in *any* referenced column is
deleted outright — not passed through as `NA`.

```r
aggregate(area ~ id, data.frame(id = 1:3, area = c(1, NA, 3)), sum)
#>   id area          <- id 2 is GONE, not NA
#> 1  1    1
#> 2  3    3
```

The damage lands downstream: an **inner** `merge()` onto that result then drops the row from the
data entirely, and a later `is.na(x) <- 0` fill turns a record that had a value into one that
reads as a legitimate zero. Pass `na.action = stats::na.pass` and merge with `all.x = TRUE` —
noting `sum(c(1, NA))` is `NA`, so the NA state persists under a different cause and may still
need asserting.

**`by = list(...)` silently DROPS NA groups.** So adding rows with an `NA` key — the natural way
to carry "this item produced no result" into the same table as the ones that did — deletes
exactly those rows. `addNA(factor(x), ifany = TRUE)` keeps them; recover the values with
`as.integer(as.character(...))`, which returns `NA_integer_` for the NA level without a warning.

Related, same family and same script: **`x$col <- value` errors on a 0-row data frame** —
`replacement has 1 row, data has 0`. A `write.csv` / `read.csv` round trip of a 0-row frame
gives a header-only file that reads back with **every column typed `logical`**, so the crash
appears at the consumer, far from the producer that legitimately emitted nothing.
`x$col <- rep(value, nrow(x))` is 0-row-safe.


### `deparse(body(f))` excludes formal defaults, so a body scan cannot see a default

A guard that scans function bodies for a forbidden literal is blind to that literal in a
**signature**. Measured on R 4.5:

```r
f <- function(image = "qgis/qgis:latest") { x <- 1; x }
grepl("qgis/qgis:latest", paste(deparse(body(f)), collapse = ""))   # FALSE
grepl("qgis/qgis:latest", paste(deparse(f),       collapse = ""))   # TRUE
```

That matters because **a formal default is how a package-wide constant is usually
expressed** — `image =`, `path =`, a URL, a schema name. So the shape most likely to
carry the thing you are forbidding is the one shape the scan cannot reach, and the guard
reports clean against the exact regression it names.

Caught 2026-09-06 in rfp#282: a test asserting no rolling docker tag remained in `R/`
reported **FAIL 0** with the pre-fix default restored on both entry points. `deparse(o)`
instead of `deparse(body(o))` — one word, 0 hits as shipped and 2 with the bug restored.

Two things worth knowing before switching:

- **`deparse()` walks the AST, not the srcref**, so a comment mentioning the literal does
  **not** false-positive. Verified against two legitimate mentions in the same package.
- **Choose per guard, not globally.** A scan for something that can only appear in a body
  — a re-inlined argument vector, a direct `system2()` call — is correctly `body()`, and
  widening it to `deparse(o)` only adds surface. The question is whether the thing being
  forbidden could be written as a default.

The entry above, "Under `R CMD check`, tests run from a temp dir against the INSTALLED
package", prescribes `deparse(body(get(nm, envir = asNamespace("pkg"))))`. That snippet is
right about the half it is teaching — read the installed bodies, never `../../R/*.R` — and
carries this blind spot for any guard whose literal could sit in a signature. Reconciling
the two is soul#208.

**Anti-vacuity, since this guard's premise is easy to get wrong:** asserting the namespace
has objects proves the scan *ran*, not that the predicate can *fire*. Plant the shape:

```r
planted <- function(image = "forbidden") NULL
expect_true(grepl("forbidden", paste(deparse(planted), collapse = "\n"), fixed = TRUE))
expect_false(grepl("forbidden", paste(deparse(body(planted)), collapse = "\n"), fixed = TRUE))
```


### `tryCatch(warning = )` DISCARDS the value the expression produced

A `warning =` handler is not a filter — it replaces the whole expression, so a call that
**succeeded** and merely warned returns the handler's value and the result is thrown away.
The entry above covers a `warning =` that unwinds too early to see a status; this is the
opposite direction, and it is worse because the call worked.

`read.table` is the routine way to meet it. It warns `incomplete final line found by
readTableHeader` whenever a small file has no trailing newline and `readTableHead` reaches
EOF, so a table that parsed perfectly is refused:

```r
d <- tryCatch(read.csv(path),
              error   = function(e) structure(list(), msg = conditionMessage(e)),
              warning = function(w) structure(list(), msg = conditionMessage(w)))  # WRONG
# 1-4 data rows, no trailing newline -> refused as "could not be parsed"
# 5+ data rows                       -> parses
d <- tryCatch(suppressWarnings(read.csv(path)),                                    # right
              error = function(e) structure(list(), msg = conditionMessage(e)))
```

The row-count threshold is what makes it invisible: measured on R 4.5, files of 1-4 data
rows were refused and 5+ parsed. Any fixture of a realistic size passes, and a small real
input — a 3-frame archive, a 2-row config — fails in production.

**Suppress the warnings you do not want; never handle them, unless the warning genuinely
means the value is unusable.** And note the two are separable: a binary file read through
`read.csv` warns about embedded nulls *and* returns a garbage frame, which the next
validation step rejects on its own. Letting it through the parse loses nothing.

Caught 2026-09-06 in fly#50 (review round 4), inside the fix for a different instance of
the same mechanism — two states given one representation while the fact that separates
them (`d` *is* a data.frame) sits computed and unread.

### `match()` treats NA as a matchable VALUE, so two unknowns join to each other

`match(NA, c("1", NA))` is **2**. So an `NA` on the left matches an `NA` on the right, and
a lookup keyed on a column that may be blank silently attributes one record's data to
another:

```r
m <- match(id_frame, tab$id)   # id_frame all-NA (the caller has no such column)
                               # tab$id has one NA (the source left it blank)
                               # -> every unmatched record gets that row
```

It fails toward a **confident wrong answer** rather than a miss, and downstream code has
no way to tell. Guard both sides explicitly — the left because the caller may not carry
the key at all, the right because the source may leave it blank:

```r
m <- match(a, b)
m[is.na(a) | is.na(b[m])] <- NA_integer_
```

**And a key built with `paste0()` defeats the guard before it runs.** `paste0("r_", NA)`
is the three-character string `"r_NA"`, so both sides become a real value that matches:
by the time `match()` sees it there is no `NA` left to test. Return `NA_character_` from
the key builder instead, and then guard the `match()` as above — the two fixes are not
alternatives, they close the same hole one step apart.

```r
key <- function(a, b) { out <- paste0(a, "_", b); out[is.na(a) | is.na(b)] <- NA_character_; out }
```

Worst form: an identifier scheme the parser cannot read at all — an alphanumeric frame
number where an integer was assumed — collapses *every* record onto one key on both sides.

Measured 2026-09-06 in fly#50: a photo frame present in no source file was handed another
frame's camera, with the "this was resolved exactly" flag set. Same family as
`nzchar(NA)` being `TRUE` above — a value meaning "absent" that a predicate reads as
present.

### `expect_message(expr, regexp)` checks only the FIRST condition, so a progress line hides the message under test

testthat 3e captures the first message the expression emits and matches the regexp
against **that one**. A function that prints progress before the thing you are asserting
therefore fails the expectation, and the real message escapes to the console — where you
can see it, printed a few lines above a failure saying no such message was thrown. The
output contradicts the verdict, which sends you looking at the function rather than at
the assertion.

```r
expect_message(f(x), "could not be unpacked")   # f() prints "Downloaded 1 of 1 files" first
#> Error: `f(x)` did not throw the expected message.
#> (and the expected message is right there in the console output)

expect_true(any(grepl("could not be unpacked", testthat::capture_messages(f(x)))))   # right
```

`capture_messages()` returns all of them and the assertion says what it means. Use it for
anything that emits more than one message, which in practice is anything that reports
progress. Caught 2026-09-06 in fly#50, where the same call also cost a detour into
whether a temporary fixture directory was being deleted early — it was not.


# Code Check — Shell

Tool-level traps in bash, sed, git and `gh`, and in the host toolchain those commands
depend on. These load everywhere because they are about the shell the agent runs
commands in, not about `.sh` files in the repo.
The general mechanisms — a guard that fails toward pass, a fixture that cannot
reach the failure mode — live in `code-check.md`; this file is the quirks.

### `git diff a..b` compares TIPS; a change on `a` shows up as the branch's

Two-dot is the difference between two commits. Three-dot (`a...b`) is the difference from
their **merge base** — what the branch actually did, and what GitHub shows in a PR.

So anything that landed on the base since the branch forked appears **inverted** in a
two-dot diff: a file `main` *deleted* reads as a file the branch *added*.

Measured 2026-09-04 in rtj. A branch touched four files. `git diff --stat main..branch`
listed five, the extra being a one-line addition to a CSV. `main` had removed that line in a
merged PR; the branch had never touched the file at all:

```
two-dot   : CLAUDE.md docs/… env/prod/main.tf progress.md manifest.csv
three-dot : CLAUDE.md docs/… env/prod/main.tf progress.md
```

It cost a wrong merge-order rationale written into a PR description ("merge #279 first,
both touch this file"), caught by the PR reviewer reading the diff GitHub renders. The
failure is quiet because the two-dot output is *correct* — it answers a question nobody
asked.

- Use `a...b` for "what does this branch change", which is nearly always the question.
- `git log a..b` is the opposite convention and two-dot is right there — it lists commits
  reachable from `b` and not `a`. The asymmetry between `log` and `diff` is the trap.
- Confirm against the branch's own commits when it matters:
  `git log --oneline a...b -- <path>` shows *which* side touched a file.

### git pathspec excludes: use the long form
- `:!path` is short-form magic, and git keeps parsing magic characters after the
  `!`. A path starting with one aborts the whole command:
  `:!_pkgdown.yml` → `fatal: Unimplemented pathspec magic '_'`.
- Use `:(exclude)path`. `:!./path` also works, but the long form says what it means.
- Anything building pathspecs from a file (`.Rbuildignore`, `.gitignore`) will
  eventually meet a leading `_`, `(`, or `^`.

### `sed 1d f1 f2 f3` strips only the FIRST file's header

`sed` treats multiple file arguments as one concatenated stream, so a line-address
script applies once across the whole set rather than per file. Stripping CSV headers
this way — especially via `find … -exec sed 1d {} +`, which batches many files into one
invocation — leaves every header but the first embedded in the data.

It is silent, and it lands rows that parse. Caught 2026-08-30 concatenating 24 paged WFS
responses: 23 stray header rows entered a 223,667-row analysis and showed up only as a
row-count reconciliation failing by exactly 23.

```bash
for f in pages/*.csv; do sed 1d "$f"; done > combined.csv   # per file
awk 'FNR>1' pages/*.csv > combined.csv                      # or FNR, which resets
```

Reconcile the row count against what the source said it would be. That is the check that
catches this, and it costs one line.

### `sed -n '/X/,$d' file` prints nothing at all

`-n` suppresses auto-print, and `d` only deletes — so nothing is ever emitted and the
output is empty. The intent (print up to a marker) needs `sed '/X/,$d'` without `-n`, or
`sed -n '1,/X/p'`.

Fails toward an **empty file**, which downstream reads as "no matches" rather than as a
broken command. Same family as "A guard that fails toward pass" in `code-check.md`: the
silent direction is the dangerous one.

### Reading a file line-by-line drops the last line without a trailing newline
- `while IFS= read -r line; do ...; done < file` skips a final line that has no
  newline after it. Use `while IFS= read -r line || [ -n "$line" ]`.

### Empty arrays under `set -u` on bash 3.2
- macOS still ships bash **3.2**, where `"${ARR[@]}"` on an empty array is an
  unbound-variable error under `set -u`. Guard with `[ ${#ARR[@]} -gt 0 ]`
  before expanding. Scripts written and tested on Linux bash 5 hit this only on
  a Mac, and only when the array happens to be empty.

### Quoting
- Variables in double-quoted strings containing single quotes break if value has `'`
- `"echo '${VAR}'"` — if VAR contains `'`, shell syntax breaks
- Use `printf '%s\n' "$VAR" | command` to pipe values safely
- Heredocs: unquoted `<<EOF` expands variables locally, `<<'EOF'` does not — know which you need
- Unquoted heredocs also run **command substitution**: backticks in prose (markdown code spans!) execute and are replaced by their output, usually empty. Writing markdown through an unquoted heredoc silently deletes every `` `word` `` in it — no error, and the damage only shows on re-read. Seen 2026-08-06 writing a memory index line: a markdown code span followed by "gone as a concept" landed as "gone as a concept", subject removed. Any heredoc carrying prose or markdown wants `<<'EOF'`.
  - **The rule collapses the moment you also need interpolation.** `<<'EOF'` is
    the fix for prose and `<<EOF` is the fix for variables, and a heredoc that
    needs both has no safe form — which is exactly when the trap fires, because
    the quoting choice now looks forced rather than careless. Seen again
    2026-08-26 in rfp#186 writing a findings file that had to carry a generated
    project name: `` `normal` `` in a markdown table ran as a command and its
    empty output replaced the word, leaving `| enabled, , **resolves** |`.
    Escaping the backticks individually is not a fix either — you have to get
    every one, and the misses are silent.
  - Fix: keep the heredoc quoted and substitute afterwards, or write the file
    from Python where there is no substitution layer at all:
    ```bash
    cat > out.md <<'EOF'      # prose safe, placeholder left literal
    Project: __NAME__
    EOF
    sed -i '' "s|__NAME__|$NAME|" out.md
    ```
  - Detection is cheap and worth doing whenever prose went through an unquoted
    heredoc: `grep -n ', ,\|(( ))\|  |' file` finds the empty spans a swallowed
    code span leaves behind.
- Pass-through-ssh args: `printf '%q'` escapes per-arg so workload paths with spaces / quotes / metacharacters survive the local-shell → ssh-argv → remote-shell round-trip. Without it, `ssh host 'cmd' "$path"` joins args with spaces on remote and re-parses, losing argument boundaries.
- **A plain `git commit -m "…"` runs command substitution too, and unlike the heredoc cases it
  SUCCEEDS.** The rules above are about forms that fail loudly. This one does not: backticks in a
  double-quoted `-m` string execute, bash prints `something: command not found` to **stderr**, and
  the commit lands anyway with the span replaced by empty output. Seen 2026-09-02 in floodplains:
  a message reading ``prov_keys() now takes a `part` argument`` committed as "now takes a
  argument". The only signal was one stderr line scrolling past above a successful commit.
  - Markdown code spans are exactly what a good commit message is full of — function names,
    arguments, file paths — so the failure targets careful messages, not sloppy ones.
  - Fix is the one already prescribed for multi-line bodies, applied to single-line ones too:
    write the message to a file and `git commit -F`, or use single quotes when the text has no
    apostrophes. `git commit --amend -F msg.txt` repairs it after the fact.
  - Detection, since the commit is already made: `git log -1 --format=%B | grep -n "  \|takes a $"`
    finds the collapsed double spaces an eaten span leaves behind.
- `git commit -m "$(cat <<'EOF' ... EOF)"` chokes on apostrophes in prose bodies in some contexts — the bash parser surfaces an unmatched-quote error even though heredoc bodies should be quote-neutral. Resilient default for multi-line commit messages: write the body to `/tmp/msg.txt` and use `git commit -F /tmp/msg.txt`.
- **The same trap has a silent variant: `Rscript -e` / `python -c` carrying backslash escapes.** The heredoc case above fails loudly, which costs a retry. Passing a regex inline does not: `\\b` reaches the interpreter mangled, so `grepl()` returns 0 matches against text it matches perfectly from a file. Nothing errors. Seen 2026-07-31 in rfp#93 — the 0 read as "my regex is wrong" and nearly triggered a rewrite of working code; the identical regex scored 4 matches the moment it ran from `/tmp/x.R`.
  - Rule: anything carrying a regex, nested quotes or backslashes gets written to a file and run (`Rscript /tmp/x.R`). Inline `-e` is for trivial one-liners only.
  - Diagnostic: when an inline command returns a surprising *result* rather than an error, suspect the quoting layer before the code, and re-run from a file to find out which is wrong. That one step separates a real bug from a shell artifact.

### Heredoc precedence in pipelines
- `cmd1 | cmd2 <<EOF` — the heredoc binds to `cmd2` (the rightmost simple command). If you intended `cmd1` to receive it, put `<<EOF` on cmd1 explicitly: `cmd1 <<EOF | cmd2`.
- Symptom when wrong: ssh body silently echoed by tee/cat/etc, ssh side gets empty stdin, exits 0 (or near-0) without doing anything. Caught the hard way 2026-05-01 in cypher_restore-fwapg.sh.

### Paths
- Hardcoded absolute paths (`/Users/airvine/...`) break for other users
- Use `REPO_ROOT="$(cd "$(dirname "$0")/<relative>" && pwd)"`
- After moving scripts, verify `../` depth still resolves correctly
- Usage comments should match actual script location

### Diagnose env/PATH problems in the shell that actually runs, not the ambient one
- Get ground truth **before** forming any theory:
  `env -i HOME=$HOME TERM=$TERM bash -lc 'echo $PATH | tr ":" "\n" | nl'`
  (swap in `zsh` to check the other side). Numbering shows ordering and
  duplication in one read.
- **Claude Code runs bash regardless of the user's login shell**, so a PATH
  measured from an agent shell says nothing about the terminal the user sees.
  Establish which shell is interactive (`echo $0`, or the prompt style) before
  opening any rc file.
- **The mutation is usually one level down from the obvious file.** A
  `for file in ~/.{path,exports,aliases,extra}; do source "$file"; done` loop in
  `.bash_profile` hides real `PATH=` assignments in files you never opened. Grep
  every sourced file, not just the rc files.
- Caught 2026-08-19: a 39-entry PATH with 12 duplicates took **three** wrong
  diagnoses — `.zprofile` (which did run `brew shellenv` five times, but the
  interactive shell was bash, so it was irrelevant), then `.bashrc` sourcing
  `.bash_profile`, then tmux inheriting a stale env. The cause was `~/.path`
  hand-prepending what `brew shellenv` already sets, plus three directories that
  no longer existed. One `env -i` run ended it.
- The same mistake closed an infra issue prematurely: MacPorts was removed and
  verified **in bash**, while `.zprofile` kept exporting `/opt/local/bin` on
  every zsh login for months. Verified in one shell, broken in the one that runs.

### Parallel writers sharing one output file interleave mid-record
- `xargs -P N ... >> shared_file` (or any fan-out where N processes append to the same fd/path) is only safe while each record fits in a single `write()`. O_APPEND makes individual `write()` calls atomic, but a large record (anything beyond pipe/stdio buffer size, ~64 KB) spans multiple writes — concurrent jobs interleave mid-record and corrupt the file.
- The trap is latent: small records never trip it, so the pattern looks proven until the first large payload arrives. Caught 2026-07-11 in rtj's `stac_register-pypgstac.sh` — 20 parallel `curl | jq -c` jobs appending STAC items to one NDJSON worked for every prior collection (KB-scale items), then 9 MB floodplain items interleaved and produced an orjson decode error ~864 KB into line 1.
- Fix pattern: each parallel job writes its own temp file (unique name, e.g. md5 of the input), concatenate after the fan-out completes:
  ```bash
  cat urls.txt | xargs -P 20 -I {} fetch_one.sh {} "$OUT_DIR"   # each writes $OUT_DIR/<md5>.json
  find "$OUT_DIR" -maxdepth 1 -name '*.json' -exec cat {} + > combined.ndjson
  ```
- **Concatenate with `find -exec … +`, never `cat "$OUT_DIR"/*`.** This fix is what
  creates the file count that then blows `ARG_MAX` — see "`cmd dir/*` dies on
  ARG_MAX at scale" below. The two traps are a matched pair, and writing the glob
  form here is what put the bug into rtj's registration script twice.
- Pair with a count guard — parallel `curl` failures under xargs are also silent: `[ "$(wc -l < combined.ndjson)" -eq "$EXPECTED" ] || exit 1` before any downstream load.

### `mktemp` template needs enough X's, and a failed `mktemp` leaves an empty var
- BSD/macOS `mktemp -d -t <name>` requires the template to contain at least 3 `X`s (`XXXXXX` is the safe default). Without them, mktemp errors to stderr (`too few X's in template`) and **prints nothing to stdout**.
- Pattern: `SCRATCH=$(mktemp -d -t aider-smoke) && cd "$SCRATCH" && <destructive>`. When mktemp fails, `$SCRATCH=""`. `cd ""` is a no-op that **leaves you in the caller's cwd**. The destructive command (`rm`, `git init`, `git add+commit`) then runs in cwd instead of a throwaway tmpdir.
- Caught the hard way 2026-05-13: a Claude smoke test inside the rtj checkout did exactly this, accidentally committed a `demo.R` to the active feature branch, which then rode the squash-merge into rtj/main and had to be cleaned up post-merge.
- Fix patterns:
  - Always use `XXXXXX` (6 X's) in the template: `mktemp -d -t aider-smoke.XXXXXX`.
  - Guard the result: `SCRATCH=$(mktemp -d ...) || exit 1; [ -n "$SCRATCH" ] || exit 1`.
  - Use `set -euo pipefail` so the failed command-substitution kills the script.

### `cmd dir/*` dies on ARG_MAX at scale — and only after the expensive work succeeded

- A glob expands to argv. 98k filenames is roughly 6 MB against a ~2 MB limit, so
  `cat "$DIR"/*.json` fails with `argument list too long` — **after** whatever
  produced those files already succeeded. Silent-after-success: the costly stage
  worked and the cheap one threw it away.
- Caught 2026-07 in rtj#196: it killed a STAC registration following a completed
  80-minute download.
- **Recurred 2026-08-29 in the same script**, because #196 wrote this entry but
  never repaired `rtj/scripts/geoserv/stac_register-pypgstac.sh`, and the
  parallel-writers entry above still prescribed the glob. 102,460 downloaded item
  JSONs concatenated fine with `find`; the load then took 27 seconds. The costly
  stage had already succeeded both times.
- The cost is worse than a wasted download when the script **deletes before it
  loads**: that registration removes the collection in step 2, so failing in step
  4 left a live public API serving zero items until it was repaired by hand. A
  destructive-then-rebuild sequence turns "retry it" into an outage.
- Safe form — `find` batches under the limit itself:
  ```bash
  find "$DIR" -maxdepth 1 -name '*.json' -exec cat {} + > combined.ndjson
  ```
- The trap is latent, and it rides in on the fix for a different one:
  per-file fan-out (see "Parallel writers sharing one output file interleave
  mid-record" above) is correct, and it is exactly what produces the file count
  that later blows argv. Small sets look proven for as long as you test on them.

### A `curl` in a parallel fan-out needs `--max-time`

- Without it, one hung connection pins a worker slot indefinitely. Since a fan-out
  usually prints nothing until it finishes, a wedged pool and a slow pool look
  identical from outside — there is no signal to distinguish "still working" from
  "will never finish".
- Set `--max-time` on every per-URL fetch, and pair any silent multi-minute stage
  with a periodic progress line (a file count is enough). Same reasoning as
  `statement_timeout` on long DB work: the point is to fail loud rather than hang
  quiet.

### BSD vs GNU sed/grep portability (macOS hits this constantly)
- macOS ships BSD `sed`/`grep`. Linux CI/cloud-init hosts ship GNU. Snippets that work on one silently misbehave on the other.
- **`\+` and `\|` are GNU BRE extensions.** On BSD they're treated as literal `+` and `|`, so the regex still "matches" but matches nothing useful — leaving raw input unchanged.
  - Symptom seen 2026-05-28: `sed 's/[^a-z0-9]\+/-/g'` on macOS left spaces in an issue-title slug, producing an invalid git branch name.
  - Fix: use `sed -E` (POSIX ERE) so `+`, `|`, `?`, `(...)` all work without escapes on both flavors. The same regex becomes `sed -E 's/[^a-z0-9]+/-/g'`.
- **`s|pat|repl|` delimiter conflicts with `|` in alternation/replacement on BSD.** Pick a delimiter that does not appear in pattern or replacement (`#`, `,`, `:` are common choices). Compound `s|x|y|; s|^| /||` chains where the trailing `||` looks like an empty delimiter break on BSD sed even when GNU accepts them.
- **Don't parse `ls`.** BSD `ls` emits ANSI colour codes when stdout is a TTY *or* when `CLICOLOR_FORCE` is set in env (often by shell rc files), and the codes leak through pipes. Downstream `grep`/`sed` chokes on the embedded escapes (`[01;31m...[0m`).
  - **A third cause, and the one that bites agents: an alias in the invoking shell.** Measured 2026-08-28 — in an agent Bash call `ls` was aliased to `command ls --color`, so `ls -A dir | grep -v '^\.gitkeep$'` returned `^[[0m^[[00m.gitkeep^[[0m`, the grep failed to filter it, and a directory-empty guard false-failed on a correct tree. The identical command was fine inside a script file, where no alias applies and `ls` resolved to GNU coreutils — so testing it from a script *proves nothing about how it will run inline*. `CLICOLOR_FORCE` was not involved in that instance; check `type ls` before trusting either.
  - Use `find <dir> -maxdepth 1 -mindepth 1 -type d -exec basename {} \;` for directory listings, or `printf '%s\n' <dir>/*/` for a glob, or `for d in <dir>/*/; do basename "$d"; done`.
- **When writing a snippet you expect to ship in a `skills/` SKILL.md or any cloud-init runcmd**: it must be POSIX-portable. Default to `sed -E`, avoid `\+`/`\|`, and don't pipe `ls`.

### `&` binds to the whole `&&` list, so assignments never reach the parent

- `cmd1 && VAR=$(...) && nohup prog > "$VAR.log" & disown` backgrounds the
  **entire list**, not just `nohup`. `VAR` is assigned inside the background
  subshell, so it is empty in the parent — and a following `tail -f "$VAR.log"`
  reads the wrong path or errors while the job runs fine, writing somewhere you
  are not looking.
- The symptom lies about which side failed: the `tail` says
  `No such file or directory`, which reads as "the job never started". It started.
- Fix: assign **before** the list — `VAR=$(...); cmd1 && nohup ... &` — or
  `printf` the resolved path from inside the backgrounded shell so the parent can
  read it from output.
- Hit twice in one floodplains session (2026-08-27) launching detached runs.
- **The same shape makes `$!` the wrong PID, and that failure hands you a plausible
  number instead of an error.** `mkdir -p "$D" && : > "$D/rss.txt" && Rscript job.R &`
  then `PID=$!` gives the *list's* subshell, not `Rscript` — so a sampler built on it
  (`ps -o rss= -p $PID`) records the shell. Measured 2026-09-05 in drift#62: 39 samples
  alternating 3104 / 1488 KiB, from a run whose R process peaked at 14.2 **GiB**. Nothing
  errors, the trace is well-formed, and it was committed as the evidence record before a
  reviewer compared its peak against the other three groups'. Start the long command
  **alone** — `Rscript job.R > "$D/run.log" 2>&1 &` on its own line, every `mkdir`/`: >`
  before it — and sanity-check the first sample's magnitude against what the job should
  use, because the wrong-PID trace is off by three orders of magnitude and looks fine.

### `gh` CLI
- **`gh pr create` resolves branch from CWD, not `--repo`**. Specifying `--repo NewGraphEnvironment/X` does NOT switch branch resolution — the command still reads the current working directory's checked-out branch. To open a PR in repo X, `cd` into X's checkout first, or pass `--head <branch>` explicitly.
- **`gh issue create` / `gh pr create` with heredoc bodies fail on prose containing special shell characters** (apostrophes, dollar signs, backticks). Use `--body-file /tmp/issue.md` instead — every project's `newgraph.md` convention specifies this; codified here for the underlying class. The two are written interchangeably, so the trap applies to both: `gh pr create --body "$(cat <<'EOF' … EOF)"` breaks the parser on a prose apostrophe and bash reports `unexpected EOF while looking for matching '"'`, aborting the whole command before anything runs.
- **Do not let a base-branch deletion decide a stacked PR's fate.** Merging the base
  does not retarget the child: it still points at a merged branch, `gh pr view` reports
  it `MERGEABLE`/`CLEAN`, and merging it there is a no-op against history already on
  main (seen 2026-08-30 merging rfp#231 then rfp#234). GitHub documents auto-retargeting
  when the base branch is *deleted*, and it is not dependable: measured 2026-08-31 in
  rfp, `--delete-branch` on the base **closed** the child two seconds after the merge
  (`base_ref_deleted` and `closed` share a timestamp), left `base` unchanged, and
  `gh pr edit --base` then refused with *"Cannot change the base branch of a closed
  pull request"*. Commits are safe either way — the head branch survives on origin —
  but the PR, its review thread and its CI attach have to be recreated. Retarget
  explicitly **while the child is still open**, then merge the base:
  ```bash
  gh pr edit "$CHILD_PR" --base main      # FIRST, and while it is open
  gh pr merge "$BASE_PR" --merge --delete-branch
  gh pr view "$CHILD_PR" --json mergeable,mergeStateStatus,statusCheckRollup
  ```
  Checks are attached to the head SHA, not the base, so they survive the
  retarget — but confirm rather than assume, since a required check configured
  per-base may not. If the child is already closed, reopen it *then* retarget, or
  open a fresh PR from the surviving head branch.
- **Before you *cut* a branch, verify local is current with origin.** The mirror of the
  rule below, and easier to miss because everything about the working tree looks fine. A
  clean tree and the right branch name say nothing about whether that branch is 19 commits
  behind. A branch cut from a stale base regenerates its content from stale input, and the
  PR either conflicts (loud, cheap) or auto-merges non-overlapping hunks and quietly
  reverts someone's newer edit (silent, expensive). Assert it:
  ```bash
  git fetch -q origin
  [ "$(git rev-list --count HEAD..@{u})" -eq 0 ] || { echo "local behind origin"; exit 1; }
  ```
  Caught 2026-08-28 syncing CLAUDE.md across 25 repos: preconditions checked clean-tree
  and on-default-branch but not up-to-date. `nrp-nutrient-loading-2025` was 19 behind, one
  of those commits having touched the same file, and the PR conflicted. The 24 that merged
  cleanly still had to be proven safe after the fact — by asserting the sync commit changed
  nothing above the CLAUDE.md marker, which is the invariant the operation actually claimed.
- **A per-item loop reports the wrapper's exit, not the items'.** `for r in ...; do
  script "$r"; done` exits 0 whenever the *last* item succeeds, however many failed before
  it. The task notification then says "completed (exit code 0)" over a batch with real
  failures in it. Same family as "A wrapper's exit is not the work" in `code-check.md`, and
  the fix is the same shape:
  gate on in-band markers. Print a per-item `OK`/`FAIL` line and count the FAILs, or
  accumulate `RC=$((RC+1))` and `exit "$RC"`. Never read a loop's exit as "all items
  succeeded".
- **Distinguish "the action failed" from "the cleanup after it failed".** A wrapper that
  treats any non-zero from `gh pr merge` as *merge failed* will report a false negative
  when the merge succeeded and only `--delete-branch` errored. Two of three failures in the
  same 2026-08-28 run were misreported this way — one had already merged. Re-read the
  authoritative state (`gh pr view --json state`) before acting on a failure report, rather
  than trusting the exit code of the compound command.
- **And the same compound can half-succeed while reporting success.**
  `gh pr merge --delete-branch` deletes the local branch before the remote one, so a local
  delete that fails takes the remote delete with it — and the command still reports the
  merge as done, because it was. Observed 2026-08-31: a **worktree** held the branch, `gh`
  printed `failed to delete local branch ... used by worktree at ...`, and the remote
  branch survived. Nothing else in the output suggested a branch had been left behind.
  Benign in isolation; it matters because a surviving branch reads as unmerged work to the
  next person, and because the worktree-per-session rule in `code-check.md` ("A shared
  working tree") makes the trigger routine rather than exotic. Confirm the deletion rather than assuming it, and
  verify the branch is merged before cleaning up by hand:
  ```bash
  gh pr merge "$PR" --merge --delete-branch
  git ls-remote --heads origin "$BRANCH"        # expect empty
  git merge-base --is-ancestor "$BRANCH_SHA" origin/main \
    && git push origin --delete "$BRANCH"
  ```
- **Never send a push's stderr to `/dev/null`.** The rule below assumes you *notice* an
  unpushed branch. Suppressing the push's error removes the only signal that it happened,
  and the very next step in the usual sequence — `git branch -D` after a merge — then turns
  the commit into a dangling object. `git push -q ... 2>/dev/null` is the shape; `-q`
  already silences success, so the redirect can only ever hide a failure. Caught 2026-08-29
  in soul: a suppressed rejection meant `gh pr create` had no branch to open against, the
  cleanup deleted the branch anyway, and the commit survived only via `git reflog`. Keep
  stderr, or test the exit status explicitly:
  ```bash
  git push -u origin "$BRANCH" || { echo "push failed"; exit 1; }
  ```
- **Before `gh pr merge`, verify the branch is fully pushed.** `gh pr merge` merges the REMOTE branch — commits made locally but never pushed are silently excluded, so the PR merges "successfully" while `main` is missing work you know you committed. Check `git status -sb` shows no `ahead N` before merging (or that `git rev-list --count @{u}..HEAD` is 0). Worse: if you then delete the local branch (`--delete-branch`, or a follow-up `git branch -D`), the unpushed commits become **dangling** — recoverable via `git reflog` / `git fsck --lost-found` then `git cherry-pick`, but only if you notice they're missing. Caught twice 2026-07 in `floodplains`: PR #6 merged 1 of 3 branch commits (the drift#34 `changes_only` fix + a CLAUDE.md update were unpushed → stranded as danglers → recovered and re-merged via a follow-up PR); a second branch sat 4-ahead-unpushed at compact time. The same check belongs in the `gh-pr-merge` skill's pre-merge step.

### On a fork, `main` may track upstream by design — comparing it answers nothing

`gh api repos/ORG/REPO/compare/upstream:main...ORG:main` returning
`ahead: 0, behind: 0, status: identical` reads as *"this fork has no local work"*. On a
fork whose workflow keeps `main` synced to upstream and puts the org's own commits on a
**named branch**, it means the opposite of nothing: it is the branch model working, and
every local commit is somewhere the comparison never looked.

Measured 2026-09-05 on `NewGraphEnvironment/db_newgraph`, a fork of `smnorris/db_newgraph`:
`main` was byte-identical to upstream while `newgraph` was **12 commits ahead**, plus five
other branches and a merged PR history against `newgraph` as the base. The identical result
was reported to the user as "a pristine fork, no local commits at all", and the work being
asked about was on an unmerged branch off `newgraph`.

Enumerate the branches before comparing anything:

```bash
gh api repos/ORG/REPO/branches --jq '.[] | "\(.name)  \(.commit.sha[0:8])"'
gh pr list --repo ORG/REPO --state all --limit 20 \
  --json number,state,headRefName,baseRefName \
  --jq '.[] | "#\(.number) \(.state) \(.headRefName) -> \(.baseRefName)"'
```

**The PR list is the tell** — a `baseRefName` that is not `main` names the branch the fork
actually develops on. It is also the cheapest way to find the convention, because a fork's
own `CLAUDE.md` documenting the pattern is itself on that branch and invisible from `main`.

Same family as "The probe is broken before the world is" in `code-check.md`: the comparison
ran correctly and answered a question nobody asked. The tell is a result that is *too clean*
for a repo someone just told you has commits in it.

### A destructive setup and its undo must not share one timeout-able command

```bash
git stash -q && Rscript -e 'lint_package()' && git stash pop -q
```

`lint_package()` exceeded the 120 s Bash timeout, the command was killed, and
**`stash pop` never ran** — an entire branch's work sat in the stash with a clean
working tree while a review subagent was concurrently reading those files. Recovered
with `git stash pop`, and only because the next command printed a suspiciously empty
`git status`.

Any `save; do-slow-thing; restore` chain has a window where a timeout, a crash or an
interrupt leaves the system in the saved state, and the longer the middle step the
wider it gets. `&&` does not help — the undo simply never executes.

- **Never stash to compare against a baseline.** `git show HEAD:path > /tmp/x` is
  non-destructive and answers the same question.
- Where a save/restore genuinely is needed, put the restore in a `trap … EXIT` (one
  handler per signal — see "A second `trap … EXIT` replaces the first" below), or run
  the two halves as separate commands so a timeout cannot swallow the second.

### `git checkout <path>` restores from the index, not from HEAD

After a `git add`, `git checkout <path>` reinstates the broken *staged* copy — so the
"fix" reproduces the failure and reads as though the edit was wrong.
`git checkout HEAD -- <path>` is the one that means what people expect.

### A value validated with one numeric grammar and consumed with another

`test` and `case` read base 10. `$(( ))` reads a leading zero as **octal**. GNU `seq`
silently produces nothing for a descending range (BSD `seq 0 -1` prints `0` and `-1`,
so the same input fails differently on a stock Mac). Three predicates disagreeing
about the grammar gave five distinct failures of one guard (link#250, 2026-09-01 —
four review rounds, each finding a defect inside the previous round's fix):

| input | what happens |
|---|---|
| `0` | GNU `seq 0 -1` empty → loop body never runs → hang |
| `abc` | `[ abc -lt 1 ]` **exits 2**; `if` reads that as false → falls through → hang |
| `08` | `$((08-1))` → "value too great for base" → hang |
| `010` | **silently** becomes 8; the banner reports 10 |
| `99999999999999999999` | `10#` wraps to 7766279631452241919 → passes `>= 1` → hang |

Fix by **normalising once**, not by adding a fourth predicate: shape check
(`case ''|*[!0-9]*`), then `x=$((10#$x))`, then a bounded range. Put it where every
caller meets it, not only on the CLI flag that happens to have its own validation.

The complete candidate set for a string consumed as a count is **shape / sign / value
/ base / magnitude**. Enumerate all five or the class recurs one axis over.

### `wait` with no argument waits for every background job in the shell

Not just the ones the function started. A pool that ends with a bare `wait` silently
couples itself to whatever else the caller has backgrounded, and hangs outright if any
of them is long-lived — with all its own work already finished and nothing on screen
to say so. A 2-second sampler loop in a benchmark script wedged a pool whose four jobs
had all completed (link#250).

Track the pids you spawn and wait on those:

```bash
recompute_one "$w" &
all_pids="$all_pids $!"
...
for pid in $all_pids; do wait "$pid" 2>/dev/null || true; done
```

### A `pgrep -f` waiter matches its own command line, so it never exits

`until ! pgrep -f "job" >/dev/null; do sleep 30; done` is the obvious way to wait for a
background job, and it cannot terminate: the loop's **own** command line contains the
string `job`, so `pgrep -f` finds the waiter itself and the condition stays true after
the real process is long gone.

It fails quietly and expensively. Nothing errors, the job finishes normally, and the
waiter spins until something kills it — so a session that launched three of them for
three stages sits waiting on a stage that ended, with the log on disk saying `Done`.
Measured 2026-09-06 in rtj: two waiters were still looping after their refresh had
written its completion block, and `pgrep -fl` showed each matching only *the other
waiter and itself*.

Wait on the **PID**, which cannot self-match:

```bash
nohup Rscript long_job.R > run.log 2>&1 &
PID=$!
while kill -0 "$PID" 2>/dev/null; do sleep 30; done
```

`kill -0` tests for existence without signalling. Note the `&`-binding trap above —
assign `PID` on its own line, and start the long command alone, or `$!` is the
subshell's.

Where only a pattern is available, exclude the waiter explicitly (`pgrep -f "job" |
grep -v $$`), or match on something the loop's own text does not contain — but the PID
is the form that has no failure mode.

**Diagnose it with `pgrep -fl`, not `pgrep -f`.** The count alone says "still running";
the listing shows *what* matched, and a waiter matching itself is obvious the moment
you can read the command lines. This is the refinement of `always-away.md`'s "check
`pgrep` before declaring a run dead": checking is right, and looping on the check is
where it goes wrong.

### `timeout` is GNU coreutils — a portable deadline

An assertion around something that might hang can only pass or hang, never fail
(`code-check.md`, "Restore the bug and prove the guard fires"). The deadline that
makes it able to fail cannot be `timeout`: that is GNU coreutils and absent from a
stock macOS, so depending on it makes the assertion skip on the machine it was
written for. Portable:

```bash
with_deadline() {  # $1 = seconds, rest = command; returns 124 on deadline
  local secs="$1"; shift
  "$@" & local cmd_pid=$!
  ( sleep "$secs"; kill -9 "$cmd_pid" 2>/dev/null ) & local killer=$!
  local rc=0; wait "$cmd_pid" 2>/dev/null || rc=$?
  kill "$killer" 2>/dev/null || true; wait "$killer" 2>/dev/null || true
  [ "$rc" -ge 128 ] && return 124
  return "$rc"
}
```

Distinguish 124 from a real non-zero, or a hang gets reported as a refusal. Same
reasoning as `--max-time` on a fan-out `curl` above: fail loud rather than hang quiet.

### `aws s3 cp` cannot tell a missing key from a missing bucket

Measured 2026-08-31, aws-cli 2.34.34. Both cases return **exit 1** with identical text:

```
fatal error: An error occurred (404) when calling the HeadObject operation: Key "..." does not exist
```

So absence cannot be inferred from a transfer command. Any "the object isn't there
yet, so create it" branch built on `s3 cp` also fires on a typo'd bucket or prefix —
and then writes the "first" copy somewhere nobody will look for it.

Establish absence positively with two probes: `s3api head-bucket` (reachable? exit 0
vs 254) then `s3api head-object` (present? exit 0 vs 254). Only *reachable AND
missing* is a confirmed absence. `head-object` returns **403, not 404**, for a missing
key when the caller lacks `s3:ListBucket`, so 403 must not count as absence either —
or a permissions problem reads as a first run.

Related: match error tokens anchored — `\(PreconditionFailed\)`, `\(412\)`, `\(404\)`
— never a bare `412`/`404` substring, which matches any request id or byte count
containing those digits.

### A verification command can be shadowed by a shell function or alias
- The shell is initialized from the user's profile, so `diff`, `grep`, `ls`, `cat` and friends may resolve to a wrapper rather than the binary you assume. Measured 2026-08-24 in gq: `diff` was a shell **function** delegating to `git diff`, so `diff -q a b` — a byte-comparison in an idempotency check — died on ``unknown switch `q' `` and the step reported **NOT IDEMPOTENT** for two files that were in fact identical.
- That direction is survivable because it is loud. The dangerous one is a wrapper that exits 0 on a comparison it never performed, which reads as "verified".
- For anything whose output you are about to treat as evidence, bypass the lookup: `command diff`, `\diff`, or a tool with no common wrapper — `cmp -s` for byte-equality, `md5` / `sha256sum` for a value you can print. Printing the digest beats printing a verdict: it stays checkable after the fact.
- `type <cmd>` tells you what you actually have. Worth running the first time a verification step returns something surprising, before believing the surprise.

### psql does not interpolate `:'var'` inside a dollar-quoted string, and `\quit N` exits 0

Two traps in the same file type, both of which read perfectly and fail at run time.

**Interpolation.** psql substitutes its `-v` variables in the query buffer, but a
dollar-quoted body is a *string literal* to it, so nothing inside `$$ … $$` is
substituted. The natural form dies with a message that points at SQL syntax rather
than at the quoting layer:

```sql
DO $$ DECLARE v text := :'run_uid'; BEGIN ... END $$;
-- ERROR:  syntax error at or near ":"
```

Pass parameters through session settings instead, set outside the block:

```sql
SELECT set_config('app.run_uid', :'run_uid', false) \gset
DO $$ DECLARE v text := current_setting('app.run_uid'); BEGIN ... END $$;
```

**`\quit` takes no exit code.** `\quit 1` warns `extra argument "1" ignored` and
exits **0** (measured, psql 16.10 and 18.3). So a guard written as

```
\echo 'FATAL: …'
\quit 1
```

prints FATAL in red and then reports **success** — fail-toward-pass on precisely the
branch that exists to stop a silent zero-row pass. Raise instead, with
`\set ON_ERROR_STOP on` at the top of the file:

```sql
DO $$ BEGIN RAISE EXCEPTION 'no run_uid supplied'; END $$;
```

Related, same family: a `.sql` file whose checks are all bare `SELECT`s has no exit
status at all — a human reading output is the only verdict. If the script is invoked
by anything, at least one check must `RAISE`.

Caught 2026-09-01 in link#262, in a verify script whose own header advertised that it
"exits non-zero on a real failure".

### A second `trap … EXIT` replaces the first

`trap` registers **one** handler per signal. Registering cleanup for a temp file and
then cleanup for a database schema leaves only the second — the first is silently
discarded, and nothing warns.

```bash
trap 'rm -f "$TMP"' EXIT
trap 'drop_schema' EXIT        # the rm never runs again
```

One handler, both jobs:

```bash
cleanup() { rm -f "$TMP"; [ "$MADE" = 1 ] && drop_schema; }
trap cleanup EXIT
```

**Arm it before the thing it cleans up exists**, guarded by a flag. Registering the
trap *after* the resource is created leaves a window in which `set -euo pipefail` can
exit with no handler installed — and that window is exactly where a failure lands.

The two halves interact, which is how this survives review: adding `ON_ERROR_STOP` to
a psql call can turn a previously exit-0 setup step into an abort *inside* that
window, reopening a leak the early trap was added to close. Both changes individually
right; neither measured against the other. Caught 2026-09-01 in link#262.

### A `local` statement cannot read a variable it is assigning in the same statement

`local a="$1" lab="$2" m="/tmp/marker_${lab}"` expands `${lab}` **before** `lab` is
assigned. Under `set -u` that is a fatal `lab: unbound variable`; without it, the
variable is silently empty and whatever it was building points at the wrong path.

It reads as one tidy declaration, which is the whole trap — the same three
assignments on three lines are correct.

```bash
run_one () {
  local a="$1" lab="$2" m="/tmp/fp_${lab}"   # WRONG: ${lab} is empty here
  local a="$1"                                # right: one per line
  local lab="$2"
  local m="/tmp/fp_${lab}"
}
```

**And the wrapper reported exit 0.** Caught 2026-09-02 in floodplains: the function
aborted on its first call, the script died before its `ALL RUNS DONE` line, and the
background task notification still said *completed (exit code 0)*. The only signal was
one line in a redirected output file. This is "A wrapper's exit is not the work"
(`code-check.md`) meeting a `local` bug — gate on the in-band marker (`ALL RUNS DONE`), never on the wrapper.

Same shape for `declare`, `readonly`, and `export` with multiple assignments, and for
`local -r`. If two names on one line have a dependency between them, they belong on
two lines.

### Inside an `EnterWorktree` session, the Bash tool refuses command text that names git

The harness applies an isolation guard to a session that entered a worktree: *"a
worktree-isolated session's git operations must target its own worktree."* It decides by
scanning the **command text**, not by what the command would do. Measured 2026-09-02 on
soul#166, four refusals in one session:

| refused | why |
|---|---|
| `cd "$WT" && git … && …` | compound with `cd` |
| `git -C "$WT" archive … \| tar -x` | a pipe containing git |
| `git -C "$WT" add a b && git -C "$WT" commit …` | two git commands chained |
| `python3 - <<'PY' … "git worktree" … PY` | a heredoc whose *prose* contained the word |

The last one is the trap: a multi-file text edit whose replacement strings happen to
mention git is refused for the mention, and the error reads as a git problem.

What works: one plain command per call, absolute paths (the shell cwd resets between
calls, so relative paths resolve outside the worktree after the first), `git -C
<worktree-path> <verb>`, and `--output=<file>` in place of pipes — `git diff --output=…`,
`git archive --output=…`. For edits that mention git, **write the script to a file with the
Write tool and run `python3 <path>`**: the command text then names no git. Do not spend
turns on phrasings; it is a property of the harness, not a setting.

Three more shapes, measured 2026-09-03 on soul#168, and the second is the one that
costs something:

- A `for` loop whose body runs `gh` with a path built from a shell variable is refused
  too — *"runs gh with a value computed at runtime … cannot be shown not to be git"*.
  Spell each `gh` call out with literal absolute paths.
- **`gh pr merge` from inside a worktree merges, then errors** — `fatal: 'main' is
  already used by worktree at …` — because its post-merge `git checkout main` cannot
  run. The merge has landed and the error says nothing about it; `--delete-branch` has
  *not* deleted the remote branch. Same recovery as the half-succeeding `--delete-branch`
  under `gh` CLI above: read `gh pr view --json state,mergeCommit`, then `git ls-remote
  --heads origin <branch>`, and delete by hand after `merge-base --is-ancestor`.
- `ExitWorktree(remove)` refuses while the local default branch is behind origin,
  because it counts the just-merged commits as unmerged. Exit with `keep`, `git pull
  --ff-only` on main, then `git worktree remove <path>` and `git branch -d <branch>` —
  lowercase `-d`, so git itself checks the branch is merged.

### A `git filter-repo` seed carries the source repo's tags, and a path sed misses the language's path constructor

Two traps from seeding one repo out of another's history (fish_passage_template_reporting#236,
2026-09-02), both silent.

- **Tags survive the path filter** whenever the commit they point at does. The first
  `git push -u origin main` of the filtered clone pushed three of the source repo's release tags
  into the new repo, where they squat on the names its own first releases need — the stray-tag
  trap in the seeding direction. `git tag -l` on the filtered clone before pushing; delete what is
  not the new repo's own.
- **`sed 's#data/planning#data#'` rewrites the string form only.** Every
  `file.path("data", "planning", ...)` — eight sites in four scripts — survived, and the grep that
  followed the sed reported zero remaining hits because it searched for the same string. Nothing
  static found it; running one consumer did (it aborted writing to a directory that no longer
  existed). After any path repoint, grep the constructor form too (`"planning"` as a bare
  segment, `os.path.join`, `Path(...) /`), and run one script that writes.

### `git check-ignore -v` prints the matching pattern, and its exit status is not a per-file verdict

`-v` reports the **last matching pattern**, negations included. So a path un-ignored by a `!` rule
prints a line *and exits 0* — which reads as "still ignored" when the file is in fact tracked.

Measured 2026-09-04 in stac_floodplains_bc, adding `!data/readme_items.rds` under `data/*.rds`:

```
$ git check-ignore -v data/readme_items.rds
.gitignore:9:!data/readme_items.rds   data/readme_items.rds     # exit 0 — but NOT ignored
```

`planning.md`'s "expect no output" is right for a plainly-unignored path (nothing prints, exit 1);
it does not hold once a negation is involved. Test each path and branch on the status:

```bash
for f in a b c; do git check-ignore -q "$f" && echo "IGNORED $f" || echo "ok $f"; done
```

And **not-ignored is not tracked.** The predicate that matters for anything a reader will fetch is
`git ls-files --error-unmatch <path>` — see "A link to a repo-hosted artifact must be *tracked*"
in `code-check.md`.

### `sips -Z` scales up as well as down

`sips -Z N` resamples so the longest side is N — in **either** direction. Run over a mixed set to
"shrink images for the web", it enlarges everything already smaller than N, and the batch can come
back barely smaller than it started.

Measured 2026-09-04 over 104 images: `-Z 1400` took a 934x700 PNG **up** to 1400x1049, and the set
went 60 MB → 51 MB where the intent was a quarter of that. Guard on the source dimension:

```bash
mx=$(sips -g pixelWidth -g pixelHeight "$f" | awk '/pixel/{if($2>m)m=$2}END{print m+0}')
if [ "$mx" -gt 1200 ]; then sips -Z 1200 "$f" --out "$o"; else sips "$f" --out "$o"; fi
```

The tell is a resize pass whose total barely moves. `-resampleHeightWidthMax` behaves the same way;
ImageMagick's `convert -resize '1200x1200>'` is the form that only shrinks.

### Assert capabilities, not versions — a tool upgrade can remove one silently

A tool upgrade across the fleet can remove a capability without reporting failure.
Version numbers do not predict the loss, exit codes stay zero, and the break surfaces
later somewhere unrelated. Four instances on one host in one session (2026-08-20):

- **GDAL silently lost its Parquet driver.** `brew upgrade` moved `apache-arrow` out
  from under a compiled link in libgdal. `ogr2ogr --version` still answered; `Parquet`
  simply stopped appearing in `--formats`. Exit 0 throughout.
- **GDAL 3.13.3 turned a GeoPackage-extension warning into a hard error.** Identical
  source: 0 failures on 3.13.0, 10 on 3.13.3. Package CI was green, so the repository
  alone could not surface it (rfp#149).
- **A checkout sat 93 commits behind** while `git status` reported in-sync, because it
  had not fetched; a package installed from it was reported as "latest".
- **Uncommitted work sat 15 days on one machine**, staged and never committed,
  invisible to every other host.

Two of these were mis-reported in-session before being caught — including an A/B test
"proving" a regression whose comparison keg was itself broken (a missing dylib meant
`ogr2ogr` never ran, producing a coincidentally identical failure count). The common
shape is real state with no signal.

- **Probe the operation, not the version.** `ogr2ogr --version` says nothing about
  whether Parquet works; `ogr2ogr -f Parquet` round-tripping two features does. Every
  check that matters performs the thing the fleet depends on: Parquet write and
  read-back with field types preserved, the PostgreSQL vector driver present, COG
  creation, `mergin push` incrementing the server version, a package's exported
  functions callable, QGIS at or above what the report templates target.
- **Probe, upgrade, re-probe, diff.** Never a bare `brew upgrade` (or `pak::pak`, or
  `uv tool upgrade`) on a working host. A capability that flips pass→fail becomes a
  loud failure with a named rollback instead of a silent one. Same reasoning as "A
  wrapper's exit is not the work" in `code-check.md` — a package manager is another
  wrapper that reports success while the work did not survive.
- **Declare what a repo needs.** Repos that shell out to external tools state the set
  (GDAL with COG support, `aws`, `jq`, `python3` for the STAC repos) so "can this host
  run this?" is answerable before a long job starts rather than halfway through.
- The probe also flags checkouts behind origin and uncommitted work older than N days —
  neither is visible from any single machine's routine output.

The honest failure mode is that this rots because nobody runs it: run the probe at
session start beside the CI scan, schedule it unattended, and commit the results per
host so any machine can see what the others measured. Implementation is kdot#37 (soul#69).

### An amd64-only image needs `--platform`, and it works on your machine because it is cached

`docker run` resolves from the local image store before it reaches a registry, so on an
arm64 Mac an amd64-only image runs fine once pulled — **and the command that pulled it is
not necessarily the one in the code.** Measured 2026-09-05, macOS/arm64:

```
$ docker run --rm qgis/qgis:4.2 echo hi
docker: no matching manifest for linux/arm64/v8 in the manifest list entries
$ docker run --rm --platform linux/amd64 qgis/qgis:4.2 echo hi
hi
```

It fails on a clean machine, a new laptop, CI, or after `docker system prune` — never on
the machine it was written on. The tell is a `docker run` in code beside a `docker pull`
in a README or a test helper, where only one carries the flag.

That split is the usual shape: rfp's **test harness** passed `--platform linux/amd64` and
resolved a pinned digest, while three **runtime** call sites did neither, so the shipped
functions worked only while a rolling tag happened to be cached (rfp#282). A container
invocation in test code and in runtime code are two invocations of one operation, and only
the test one runs in CI — build the argv in one place.

Two adjacent settings worth reading before blaming emulation for being slow, both **off by
default** and both one checkbox:

```bash
python3 -c "import json;d=json.load(open('$HOME/Library/Group Containers/group.com.docker/settings.json'));
print({k:d.get(k) for k in ['useVirtualizationFrameworkRosetta','useVirtualizationFrameworkVirtioFS']})"
```

`useVirtualizationFrameworkRosetta` false means x86_64 containers run on QEMU when Rosetta
is available on the host; `useVirtualizationFrameworkVirtioFS` false puts bind mounts on
gRPC-FUSE, which is the slow path for the many-small-file reads a container workload
usually opens with. Check the Docker Desktop version too — 4.17.0 was still installed on a
macOS 26.2 machine, so the Rosetta support present was its earliest form.


# Code Check — Spatial

terra, sf, bcdata, GDAL/OGR CLIs. Same gate as `cartography.md`, verbatim: report
repos do spatial work without being packages, so this loads wherever a bookdown
project, anything carrying a `DESCRIPTION`, or a QGIS project exists.

### Negative coordinates get parsed as CLI options — every BC bbox hits this
- BC longitudes are all negative, so `--bounds -124.73 49.485 -124.595 49.565` fails with `Error: No such option: -1`. The parser sees a leading `-` and reads it as a flag. Affects click/argparse-based tools generally, not just bcdata.
- Use the **bracketed single-argument form with `=`**: `--bounds="[-124.73, 49.485, -124.595, 49.565]"`. The `=` keeps the value attached to the option, and the brackets keep it one token. A bare comma-joined string (`--bounds "-124.73,49.485,..."`) is not equivalent — it threw an unrelated traceback.
- Same class: any CLI taking negative numbers (elevation offsets, `--nodata -9999`, buffer distances). Reach for `--opt=value` by default rather than discovering it per-tool.

### bcdata: an empty result raises AttributeError, it does not return an empty collection
- A bbox query matching nothing exits non-zero with `AttributeError: You are calling a geospatial method on the GeoDataFrame, but the active geometry column to use has not been set.` — geopandas complaining about an empty frame, several layers below the query.
- The trap: that reads as a broken query, not as "zero features," so a real and meaningful **absence** looks like tooling failure. Don't conclude a layer is unavailable from this error.
- **Prove absence before acting on it.** Re-run the same query against a wider bbox known to contain features; if that returns rows, the empty result is real data. Caught 2026-08-22 establishing that BC's FTEN trail layers are genuinely empty over an entire island — the wider-box control returned 851 features, which is what turned "the query is broken" into "the province has no trails here."
- Wrap counts defensively: `try: json.load(...)` around the parse, and treat the failure as `0 features` only after the wider-box control passes.

### bcdata: `BBOX()` rejecting a bbox that is a length-4 numeric vector — seen once, unquoting fixed it

The two entries above are the bcdata Python CLI; this is the R package. Observed once
(fly#35, bcdata version not recorded):

```r
bb <- unname(as.numeric(sf::st_bbox(sf::st_transform(aoi, 3005))))
length(bb)   # 4
bcdata::filter(qry, bcdata::BBOX(bb, crs = "EPSG:3005"))
#> Error: 'coords' must be a length 4 numeric vector
bcdata::filter(qry, bcdata::BBOX(!!bb, crs = "EPSG:3005"))   # worked
```

**The mechanism is not established.** `filter()` on a bcdc promise goes through
dbplyr's translation, and on bcdata 0.5.3 / dbplyr 2.6.0 a global or function-local
`bb` translates correctly with or without `!!` (measured 2026-09-03, no network). So
this is a diagnostic hint, not a rule: if that error appears for a vector that is
numeric and length 4, try `!!` before rewriting the bbox code — the error names the
right argument and a constraint the input satisfies, so it reads as a data problem
and cost two failed attempts and an inspection of `st_bbox()` output. Same family as
`code-check-shell.md`'s `Rscript -e` entry: *when a command returns a surprising
result, suspect the quoting layer before the code*. If it recurs, record the bcdata
and dbplyr versions and the calling context, which is what would turn this into a
rule.

### terra: operator dispatch and edge cases in package code
- **SpatRaster `%in%` is not dispatched when terra is *imported* (only when *attached*).** Inside a package (terra in `Imports`, used via `::`), `some_raster %in% vec` falls through to base `match()` and errors with `'match' requires vector arguments`. A `library(terra)` smoke test passes (attaching installs the S4 method), so the bug hides until package context. Use `terra::subst(x, from, to, others = ...)` or `terra::classify()` for code-set membership/masking instead of the `%in%` operator. Same trap for any operator terra defines via S4 that base also defines as an ordinary function. (drift#34)
- **`terra::freq()` errors on an all-NA raster** (`replacement has length zero`) rather than returning a 0-row table. Any path that can yield an all-NA layer (an impossible filter, everything masked out) must guard: `f <- tryCatch(terra::freq(r), error = function(e) NULL)`, then treat `NULL`/0 rows as "no values". Don't assume the empty case gives `nrow(freq(r)) == 0`. (drift#34)
- **`terra::minmax()` reports *cached* statistics, not computed ones.** It defaults to `compute = FALSE` and returns `Inf`/`-Inf` for any raster whose min/max have never been calculated — which is every file-backed raster until something touches it. A guard written on top of it therefore fires on real data:
  ```r
  r <- terra::rast("a_richly_varied_image.png")
  terra::hasMinMax(r)              # FALSE FALSE FALSE FALSE
  terra::minmax(r)                 # min Inf ... / max -Inf ...
  terra::minmax(r, compute = TRUE) # min 0 0 0 0 / max 11 18 18 255
  ```
- The trap is that it *appears* to work, because plenty of upstream operations compute min/max as a side effect — `terra::crop()` does, so anything arriving via `maptiles::get_tiles(crop = TRUE)` has them. Correct by accident, through an internal that is not a contract. Pass `compute = TRUE`, and test the guard against a **file-backed** fixture: one built by `rast(vals = ...)` is in memory, has statistics cached, and cannot reach this. (gq#57, 2026-08 — a flat-tile detector called every file-backed raster flat, and the whole fixture set shared the one property that hid it.)

### terra: `extract()` returns no row for ground beyond the raster, and counts cells by centre

- Two traps in one call, and both make a partial result look complete.
- **Ground past the raster's *extent* yields no row at all**, not an `NA` row. So measuring
  coverage as the non-`NA` share of what came back reports a footprint hanging half off the
  data as fully covered. A raster cropped to an AOI is exactly this shape — no `NA`
  interior, it simply stops — which is how most people obtain one, so this is the common
  case rather than the exotic one. Measured in fly#9: every frame reported coverage `1`
  while the sampled elevation was wrong by 83 m.
- **`extract()` takes a cell when its *centre* falls inside the polygon.** So a denominator
  computed from the polygon's *area* in cell units is a different measurement from the
  numerator, low by roughly `2/k` for a polygon `k` cells across. On a raster with no
  missing data at all and room to spare, that reported 91% coverage at 900 m cells.
  Count the denominator the same way — cells on a grid aligned to the raster's own via
  `terra::align()` — or use `exact = TRUE` and accept it being ~23x slower.
- Do the alignment **per feature**, not once over their union: the union's bounding box
  spans the whole set, so one outlying feature sizes the grid to the *gap*. Two points
  700 km apart went to 243 million cells against 16 thousand counted separately.
  `terra::extend()` has the same failure — it sizes to the union of raster and features.
- Fine test rasters hide all of this. A 30 m grid makes the `2/k` error invisible, and a
  fixture whose CRS matches the data leaves every reprojection branch unexecuted. Test at
  two resolutions, with anisotropic cells, and in a geographic CRS.

### A `...` constructor may discard trailing arguments based on the class of the first one

- A constructor that takes `...` is free to branch on **what its first argument
  is** and build the result from that alone. Everything you passed after it is
  then dropped — silently, with no warning and no error, because from the
  constructor's point of view nothing went wrong.
- The live case is `sf::st_sf()`, whose attribute frame is chosen by a chain
  ending:
  ```r
  df = if (inherits(x, c("tbl_df", "tbl"))) x
       else if (length(x) == 1) data.frame(row.names = row.names)
       else if (!sfc_last && inherits(x, "data.frame")) x
       else if (sfc_last  && inherits(x, "data.frame")) x[-all_sfc_columns]
       else if (inherits(x[[1]], c("tbl_df", "tbl"))) x[[1]]     # <-- keeps ONLY arg 1
       else cbind(data.frame(row.names = row.names), as.data.frame(x[-all_sfc_columns], ...))
  ```
  So `st_sf(df, a = , b = , geometry = )` keeps `a` and `b`, and
  `st_sf(tbl, a = , b = , geometry = )` throws them away. **Same call, same
  data, different class — different columns out.**
- **The failure is invisible for as long as your fixtures share one class.** In
  fly#35 four columns recording how each airphoto footprint had been sized never
  reached a single caller of the package's own documented data source, because
  `bcdata::collect()` returns a tibble and every fixture in the package read back
  as plain `sf, data.frame`. Two releases shipped that way with a green suite:
  geometry and every downstream number stayed correct, and only the audit trail
  went missing, so nothing errored and nothing looked wrong.
- **Fix: build the frame first, then hand the constructor one argument.** The
  columns are then inside the argument the branch keeps, whichever branch it is,
  and the caller's class is untouched:
  ```r
  attrs <- sf::st_drop_geometry(x)
  attrs$a <- a
  attrs$b <- b
  result <- sf::st_sf(attrs, geometry = g)      # not st_sf(x, a =, b =, geometry =)
  ```
  Coercing instead — `st_sf(as.data.frame(st_drop_geometry(x)), a =, ...)` — also
  restores the columns, but downgrades a tibble caller's class as a side effect.
  Prefer the version that changes one thing.
- **Test by sweeping the class axis, not by adding cases along it.** Assert
  identical names *and values* across plain / tibble / grouped / vendor-classed
  shapes of the same data. Read the tibble honestly (`st_read(as_tibble = TRUE)`)
  rather than overwriting `class()`, and assert that premise inline so a future
  upstream change fails by naming the real cause.
- **Do not over-state what survives.** `sf::st_transform()` moves `sf` to the
  front of the class vector, so `bcdc_sf, sf, ...` returns `sf, bcdc_sf, ...`.
  The class *set* is carried; the order is not. An
  `expect_identical(class(out), class(in))` written from three shapes that all
  lead with `sf` passes, and then fails on the one real caller you wrote it for.
- Swept 2026-08-29 across all 61 repos in `~/Projects/repo` — 1500 `.R` files and
  389 purled `.Rmd` chunks, parsed with R rather than grepped, looking for
  `st_sf()` with a non-literal first positional argument plus trailing column
  arguments. **`fly` was the only instance.** A regex misses this: the original
  defect was a multi-line call. Validate any such scanner against both known
  answers before believing a clean result — the pre-fix file must be flagged and
  the fixed one must not, or "no hits" is indistinguishable from a broken scan.
- Generalizes past `sf`. Ask it of anything taking `...`: *does this constructor
  decide what to keep by looking at the first argument?* Same shape in any
  language where a variadic builder dispatches on an argument's type.

### terra: `mask()` is `touches = TRUE`, so two "clip to the polygon" routines disagree by a cell ring

Swapping one polygon clip for another looks like a refactor and is a **methodology
change**. `terra::mask()` defaults to `touches = TRUE` — every cell the polygon
touches is kept — while most other clips rasterize at **cell centre**:
`terra::rasterize()` without `touches`, `gdalcubes::filter_geom()`, and
`gdal_rasterize` without `-at`. Nothing errors, nothing warns, and the values
agree exactly where both have data. Only the *footprint* moves.

```r
mask(r, v)                  # 150 cells   <- the default
mask(r, v, touches = FALSE) # 122 cells
# true polygon area: 123.4 cells
```

The magnitude is a perimeter-to-area ratio, so it is worst exactly where these
clips get used — thin corridors, floodplains, riparian buffers. Measured
2026-09-01 in drift#47 on a 3.3 km reach: **−15.5%** of the analysed footprint
(49,244 → 41,608 cells) from a change whose entire stated purpose was to remove a
redundant step. Against a parity tolerance of ±1 ha on 943 ha, that is 30–150×.

- **Do not describe a clip without naming its rule.** drift's roxygen said "cells
  whose centre falls outside become `NA`" for a `terra::mask()` call, and was
  wrong for two releases. Anyone reasoning about boundary hectares from that doc
  was off by a ring.
- **An axis-aligned fixture cannot catch this.** A rectangle on a cell boundary
  makes both rules agree, so the test passes for nothing. Use a polygon with
  fractional coordinates and no edge parallel to the grid, and assert the premise
  beside the property — `expect_gt(touch, centre)` — so a future terra default
  change fails by naming the real cause.
- **To swap in a cell-centre clip without moving the footprint**, buffer the
  polygon by `>= res * sqrt(2)/2` first: if a polygon intersects a cell square,
  that cell's centre is within a half-diagonal of it, so the buffered
  cell-centre footprint is a guaranteed superset of `touches = TRUE`. Then keep
  the `mask()` to trim back, and the output is byte-identical.

Generalises past terra: whenever two libraries both offer "clip raster to
polygon", assume they disagree at the boundary until measured. Count the cells.

### terra: `sources()` on a derived raster is `""` or a random temp path, never the input

- A raster that came out of `crop()`, `project()`, `mask()`, or arithmetic is **derived**, so it
  has no source file. `terra::sources()` returns `""` when the result fits in memory — and a
  **random per-process temp path** when terra spills to disk:
  ```r
  sources(rast(file))                      #> /…/dem.tif
  sources(crop(...))                       #> ""    inMemory TRUE
  sources(project(...))                    #> ""    inMemory TRUE
  terraOptions(todisk = TRUE); sources(crop(...))
                                           #> /private/tmp/RtmpFcjh9X/spat_ad2f168560ce_44335_Sskvi….tif
  ```
- The reach for it is provenance — *"what file did this raster come from?"* — and both branches
  answer wrongly. The empty branch is survivable: it reads as absent and a fallback fires. **The
  disk branch is the dangerous one**, because a temp path is a plausible-looking string that
  differs on every run and every machine, so it silently destroys byte-stability in whatever
  record it lands in, and nothing flags a value that *looks* like a path.
- Worse, which branch you get depends on **size**: small AOIs stay in memory and large ones spill.
  So a fixture proves the empty case and production hits the poisoned one.
- If a function crops or reprojects before returning, `sources()` cannot answer this **at all** —
  do not reach for it. Record the resolver plus the raster's measurable geometry (`crs`, `res`,
  `ncell`, `ext`), or have the package expose what it resolved (`attr(out, "source") <- source`).
- Caught 2026-09-01 in floodplains#33: `flooded::fl_dem_aoi()` builds its MRDEM-30 URL inside its
  body, so `formals()` does not expose it either. `sources()` looked like the way to measure the
  output instead of restating the input — the right instinct, applied to an object that cannot
  carry the answer.

### `sf::st_as_binary()` returns a LIST of raw vectors, so `is.raw()` on it is FALSE

The obvious way to feed WKB into a canonicalizer is a `is.raw(x)` branch that hex-encodes
it. That branch never matches: `st_as_binary()` returns a **list** of raw vectors classed
`"WKB"` — one element per feature — so `typeof()` is `list` and `is.raw()` is `FALSE`.

```r
w <- sf::st_as_binary(sf::st_geometry(g), endian = "little")
class(w); typeof(w); is.raw(w)      # "WKB"  "list"  FALSE
```

Branch on `is.list()` **before** any vector branch and recurse, or the geometry member
falls through to whatever the numeric/character fallback does — which either errors or,
worse, hashes a stringified list. Join the per-feature hex on a separator so two feature
*orderings* of the same set still key apart.

Nothing else is lost by hex-encoding the raw content: Z and M dimensions live in the WKB
geometry **type code**, not in an R attribute, and an empty geometry has its own distinct
bytes. The `"WKB"` class attribute and `endian = "little"` are constants at the call
site, so dropping them from the hash removes no distinction — and the hardcoded endian is
why such a key is already platform-independent.

Caught 2026-09-03 in drift#48, before shipping, by a reviewer rather than by a test — a
raw-only branch reads as obviously correct.

### Canonicalize geometry before hashing it — ring order and orientation are not fixed by topology

`code-check.md`'s cache-key row prescribes hashing WKB
(`sf::st_as_binary(sf::st_geometry(x), endian = "little")`) rather than the sfc
object. Correct as far as it goes, and it misses a step that sits *before*
serialization: **the geometry itself is not canonical.** Two topologically identical
polygons can differ in ring order, ring orientation, or start vertex, and produce
different WKB and different hashes. A cache keyed that way misses on input that is
geometrically the same; a content hash built that way reports a change where there is
none.

Prior art is `bcgov/FIT_changedetector` (GeoBC's change-detection tool,
`src/fit_changedetector/changedetector.py` at `5adde29`; it was `diff.py` when #95 was
filed and moved seven hours later), whose hash canonicalizes first — two steps, both
load-bearing:

```python
df[df.geometry.name].normalize().set_precision(precision, mode="pointwise")
```

- **`normalize()`** — GEOS canonical form: consistent ring order and orientation.
- **`set_precision()`** — snap coordinates to a stated grid, so floating-point noise
  below the precision of the data does not register as a difference (they default to
  0.01 m, 1e-7 for geographic CRS).

**Record the precision alongside the hash** — a hash at an unstated precision is not
comparable to one at another.

The R side needs care, because the obvious name is wrong. **`sf::st_normalize()` is
not GEOS normalize** — it rescales geometry to the unit bounding box, and recommending
it here would be actively wrong. sf 1.1.2 wraps GEOSNormalize as the internal
`sf:::CPL_geos_normalize(sfc)` with no exported caller (swept the namespace, 2026-09-02).
The exported route is the `geos` package: `geos::geos_normalize()` then
`geos::geos_set_precision()`, then hash the WKB (`sf::st_as_binary()` also takes a
`precision` argument for the second half on its own). Mind the two conventions for the
number: sf's `precision` is a **scale factor** — `st_set_precision(x, 100)` rounds to
0.01 units — while FIT_changedetector's `set_precision(0.01)` and
`geos::geos_set_precision()` take a **grid size**. Record which one the stated
precision means, or a hash comparison across the two is off by orders of magnitude.
Verify whichever you use against both known answers — one pair of polygons that differ only in ring order must hash
equal, and one that differs in a vertex must not (the `geos` sequence passed both with
default arguments, geos 0.2.5, 2026-09-03).

Filed from floodplains#45, where byte-level determinism was the goal and this turned
out to be the durable answer to the adjacent question — "did the *content* change?"

### sf: `st_join(largest = TRUE)` ignores the join predicate
- `sf::st_join(x, y, join = predicate, largest = TRUE)` does **not** use `predicate` to decide matches — with `largest = TRUE`, sf runs `st_intersection(x, y)` and keeps the feature of greatest overlap area, so matching is *always* intersection-based regardless of what `join =` is set to. A function that exposes a configurable predicate AND a largest-overlap mode therefore silently mis-attributes when both are combined: pass `st_within` expecting containment, get anything that merely *overlaps*. Verify against sf source, not the argument list — the `join` arg is accepted and ignored, not rejected. Fix: abort when a non-default predicate is combined with the largest-overlap mode, rather than honouring one and dropping the other. (drift#42)
- Corollary: `largest = TRUE` also drops zero-area geometries from consideration — so a predicate join against **point** or **line** overlays cannot use largest mode at all (no area to compare). Point/line attribution must go through the plain (`largest = FALSE`) predicate path.

### sf: name validation must account for the geometry column
- The active geometry column is a named entry in `names(x)`, but its name is **not fixed** — `"geometry"` from `sf::st_read()` of some sources, `"geom"` from a GeoPackage/PostGIS layer, `"geometry"` or `"_ogr_geometry_"` elsewhere. Code that validates user-supplied column names with `cols %in% names(x)` will happily accept the geometry column, then break downstream (`st_join` drops `y`'s geometry, so a requested "attribute" column silently never appears; a 0-row short-circuit path may instead attach a stray empty sfc). A same-name collision check across two sf objects also misses this when the two layers name their geometry differently. Guard explicitly with `attr(x, "sf_column")` — reject it from the caller-supplied column set. (drift#42)

### sf: `st_intersection()` / `st_difference()` return a GEOMETRYCOLLECTION that QGIS will not draw
- Intersecting or differencing two polygon layers yields a `GEOMETRYCOLLECTION` wherever the inputs *also* touch along a line or at a point. The polygonal part is real and `st_area()` reports it correctly, so every numeric check passes — but QGIS renders the feature as nothing, and it reads to the user as "one row with no geometry".
- The failure is silent in exactly the wrong direction: written to a GeoPackage the layer reports its `geometry_type` as `Geometry Collection` and its area as correct. Nothing errors. It surfaces only when someone opens it.
- Whether it fires depends on the geometry, not the code, so the same call can be clean on one input and a collection on the next. Do not conclude from one working case that a path is safe.
- Fix: `sf::st_collection_extract(g, "POLYGON")` then cast to a single type before writing. Areas are unchanged — the discarded fragments have zero area.
- **Assert it on anything you hand over**, not just the layer you expect to be interesting: no `GEOMETRYCOLLECTION` in `st_geometry_type()`, and `sum(st_is_empty())` is 0, across *every* layer in the file. Caught 2026-08-31 in floodplains only because the user opened the deliverable and asked why a layer looked empty.

### sf: reproject the polygon to get a lat/lon bbox, never transform the projected bbox corners
- To hand a geographic (EPSG:4326) bounding box to a bbox-filtered query (WFS/OGC features, `?bbox=`), reproject the whole AOI **geometry** then take its bbox: `sf::st_bbox(sf::st_transform(aoi, 4326))`. Do **not** compute the bbox in the projected CRS and transform its two corner points — a projected rectangle's edges bow under reprojection, so the corner-transformed box is skewed and generally too short on one axis. The pre-filter then silently under-covers the true extent: features inside the AOI but outside the shrunken box are never fetched, and a downstream clip can only *remove*, never recover them. Symptom: counts a few percent low near the north/south extremes of an area, with no error. A native-CRS bbox filter (e.g. ogr2ogr `-spat <bounds> -spat_srs EPSG:3005`) is unaffected — only the reproject-the-corners step is the bug. (rfp#12)

### An offset regex must be anchored to a time, or a date looks like a zone
- Refusing or stripping a trailing UTC offset with something like `[+-][0-9]{2}(:?[0-9]{2})?$` also matches the end of a plain ISO date: `"2026-08-15"` ends in `-15`, which reads as a −15 hour zone. Require the offset to follow `HH:MM[:SS[.fff]]`.
- The mirror mistake is requiring four offset digits. `±hh` is valid ISO 8601 and is what Postgres emits for whole-hour zones; a two-digit-offset value then falls through the guard, gets stripped as trailing junk, and the instant moves by hours with nothing reported.

### A reader that accepts a UTC offset may not be applying it

- The rule above is about parsing an offset correctly. This is the case where the
  parse never happens: the value is accepted, no error is raised, and the offset is
  **silently discarded**. GDAL does this with a GeoPackage `DATETIME` — it returns
  the wall-clock digits, which the caller then reads in the machine's zone.
- So the same file yields a different instant on every machine. Measured 2026-09-01
  on `trap`, writing one value and reading it back under three zones:

  ```
  stored                      TZ=America/Vancouver   TZ=UTC       TZ=Asia/Tokyo
  2026-07-21T14:04:28Z        14:04:28Z              14:04:28Z    14:04:28Z
  2026-07-21T14:04:28-07      21:04:28Z              14:04:28Z    05:04:28Z
  2026-07-21T14:04:28+05:30   21:04:28Z              14:04:28Z    05:04:28Z
  ```

  **The tell is that the two offsets give identical answers.** Only the `Z` row is a
  fact about the file; the other two are facts about the reader.
- **The test that let it through asserted `-07` on a `-07` machine**, where a
  wholly-ignored offset and a correctly-applied one produce the same number. The
  coincidence was written into the fixture by choosing an offset equal to the local
  one, so no amount of running it locally could have found it — CI on a UTC runner
  did. Same family as "a fixture set that cannot reach the failure mode", with the
  blind spot supplied by the machine rather than by the data.
- Two things follow, and the second is the general one:
  - **Refuse what you cannot read.** Where every real value carries `Z`, accepting an
    offset buys nothing and costs a silent multi-hour error. Refusing it with its own
    message — a missing zone and an untrusted zone are different failures — is
    strictly better than honouring a parse you have not verified.
  - **Test a timezone-sensitive property in more than one zone**, and make one of them
    differ from the developer's. `withr::with_timezone()` costs nothing. The property
    worth asserting is *the instant is the same in every zone*, which a single-zone
    test structurally cannot check.
- Generalises past GDAL to anything that returns a naive local timestamp from a
  zone-bearing source: some JDBC drivers, `datetime.fromisoformat` before 3.11 on
  certain shapes, spreadsheet readers. If a library hands back a value with no zone
  attached, assume the zone was dropped rather than applied, and prove otherwise.

### Ask the file about its field names, not R

`sf::st_read()` returns a data frame, and R makes column names syntactic on the way in.
A field the GeoPackage stores as `Site/Site` arrives as `Site.Site`; an accent survives,
a slash does not. So a claim about *what the file contains* cannot be checked by reading
the file into R — that measures R's name mangling, not the writer's behaviour.

```r
sf::st_read(gpkg, "sites") |> names()   # "Site.Site"  "Year.Année"  <- R's names
system2("ogrinfo", c("-so", gpkg, "sites"))  # Site/Site, Year/Année  <- the file's
```

The practical consequence, not just a documentation nicety: a SQL `-where` / `query`
against such a layer must use the **file's** field name, quoted. The name visible in the
session is not the name the query engine sees.

Bilingual slash-separated headers (`Site/Site`, `Year/Année`) are a general shape of
Canadian federal open data rather than one publisher's quirk, so this comes up whenever
that data is ingested. Verified against GDAL 3.x, 2026-09-02 (spacehakr#21) — where the
first check read the layer back with `st_read()` and nearly recorded R's behaviour as
GDAL's.

Related: the geometry-column naming note above, which is the same hazard on the geometry
rather than the attributes.

### QGIS embeds a layer's style in the `.qgs`, so rewriting the `.qml` sidecar changes nothing

A `.qgs` carries each layer's style **inside** its `<maplayer>` node — the sidecar's
children are copied in when the layer is declared. QGIS does not re-read that sidecar
for a layer the project already holds. So a tool that rewrites a GeoPackage and its
`.qml` leaves the project describing the *old* schema, and the two disagree silently.

The failure is invisible to every ordinary check. Measured on a live field project
whose form went from 39 to 41 columns:

```
 Form CABIN Visit    fieldConfig= 38  attrEditorField= 37  defaults= 38
   date_time_start in fieldConfig: FALSE
```

The table has the new columns; the layout does not name them. A tab layout renders
only what `attributeEditorForm` names, so the fields are **unreachable**, and the
`now()` defaults live in `<defaults>`, so they are **NULL** as well. Row counts,
file checks, schema parity against the GeoPackage and **QGIS Desktop itself** all
pass — the form opens and looks correct. It is wrong only on the device, in front of
a crew.

Two consequences worth carrying:

- **Assert against the `<maplayer>`, not the GeoPackage.** Compare the node's
  `fieldConfiguration`, `attributeEditorField` and non-empty `defaults` against the
  sidecar the writer just produced. Comparing the node to the *table's columns*
  instead fails on correct data — a shipped style deliberately omits identity and
  relation keys (measured: 40 config / 39 editor for a parent, 4 / 3 for its child).
- **Refresh the node in place, reusing its own `<id>` and `<layername>`.** Removing
  and re-adding the layer changes the id, and every surface holding it — layer tree,
  `layerorder`, map themes, `custom-order`, the legacy legend, `<relation>` entries —
  either follows or silently does not. Read the id from the node; a digest-derived id
  reproduces only for projects the same tool built, never for one QGIS touched.

rfp ships this as `rfp_qgs_form_add(restyle = TRUE)` (rfp#260, 0.57.0).

Same shape wherever a consumer caches a copy of an artifact at declare time rather
than resolving it at read time — check whether the consumer re-reads, before assuming
that rewriting the source is enough.

### A GeoPackage is a SQLite database, and that leaks in three ways

Writing to one directly (a `layer_styles` row, an attribute fix) is a plain `INSERT` and needs
no GDAL. But the container's own machinery then shows up in places that have nothing to do with
your write. All three measured 2026-09-03 in stac_floodplains_bc#46.

- **SQLite bumps a header change counter on ANY write transaction.** So a step that rewrites
  identical rows still moves the file's bytes — and with them any published `file:checksum`.
  Idempotence has to mean *skipping the write*, not writing the same thing again: read the rows
  back, compare, and return before opening a transaction. One pass over a virgin file was
  byte-reproducible; the second pass was not, until the skip was added. `AUTOINCREMENT` is a
  second source of the same problem (`sqlite_sequence` only ever grows) — assign ids explicitly.
- **GDAL lists non-spatial tables as layers.** `ogrinfo` and `sf::st_layers()` both return
  `layer_styles` alongside the real ones, with or without a `gpkg_contents` row, so any loop of
  the form *for every layer, assert this column exists* breaks the day someone adds an
  attributes table. Filter on the **property** — a geometry, via `geomtype` being non-`NA` or
  `gpkg_contents.data_type = 'features'` — never on the table's name, which passes the day a
  second non-spatial table appears. And guard the filter: if it removed everything, the
  assertions below it are vacuous.
- **A feature table's rtree triggers call SpatiaLite functions plain `sqlite3` does not have.**
  An `UPDATE` on a spatial layer from Python dies with `no such function: ST_IsEmpty`. Fine in
  production if you only touch non-spatial tables; it bites when a *test* wants to mutate real
  geometry-bearing rows. Drop the triggers on the throwaway copy first, and say in a comment
  that it is test-only.

Related, and worth knowing before adding a style table: QGIS's own writer registers
`layer_styles` in `gpkg_contents` and adds triggers. Neither is needed — QGIS auto-styles
without them — and the registration costs a second wall-clock timestamp
(`gpkg_contents.last_change`) beside `layer_styles.update_time`, so writing *less* than QGIS
does removes a churn vector. `OGR_CURRENT_DATE` does not reach either one, because a `sqlite3`
write never goes through GDAL.


### The same leak reaches R and OGR SQL, and a GeoPackage's bytes are not its content

Four more measurements of the section above, all 2026-09-05 in rtj#285 against live
Mergin projects. Each was found by a driver failing after it had already written, which is
the expensive place to find any of them.

- **RSQLite can `DELETE` from a spatial layer but not `UPDATE` or `INSERT`.** The asymmetry
  is which triggers call SpatiaLite: the rtree *insert* and *update* triggers use
  `ST_IsEmpty`, and the `rtree_<t>_<g>_delete` and `trigger_delete_feature_count_<t>`
  triggers do not — verified by reading the trigger SQL out of `sqlite_master`. So a
  delete-one-row driver works through DBI and an edit-one-row driver dies with
  `no such function: ST_IsEmpty`. The remedy in production is not dropping triggers, it is
  GDAL: `ogrinfo -sql "UPDATE ..."` registers those functions.
- **`DBI::dbExecute()` reports `total_changes()`, not the rows you changed.** A one-row
  `DELETE` on a form table returned **5** — the row plus the rtree and feature-count trigger
  writes — so `deleted == 1L` fails on a completely correct delete and sends the operator to
  restore a good file. Assert the **state** instead: the target row was there before and is
  gone after. A control delete on a trigger-free table returns 1, which is exactly what makes
  this look like a working check until it meets a spatial layer.
- **`SELECT fid FROM <table>` through `sf::st_read(query = )` returns 0 rows and 0 columns.**
  OGR treats a lone FID selection as selecting no fields, so `nrow()` is 0 whatever the table
  holds — measured 0 against an unmodified 16-row layer, while `SELECT site_id ...` returned
  16 and `SELECT count(*) AS n ...` returned 16. A row-count guard built on it can only ever
  read "empty", which is the direction that reads as success for a *deletion* check. Select a
  real column, or `count(*)`.
- **A GeoPackage's file hash is not a content identity, and a read can move it.** Two copies
  of one Mergin version — one taken by `file.copy` before a conversion, one downloaded from
  the server afterwards — differed in **5 bytes**, all SQLite header change-counter and
  version fields, with content identical (60 tables, 312,896 rows, same per-table counts).
  Separately, a `journal_mode` round trip changes the sha256 while a plain GDAL update-mode
  open/close does not. So "did anyone edit this file" cannot be asked with a checksum over
  `.gpkg`s — QGIS merely opening one is enough. Ask it of the **content** (row and style-row
  counts per layer, or a canonical digest), and keep checksums for the text files, where a
  save really does rewrite the bytes. The client's own change predicate agrees: a Mergin
  working tree whose store differed from its basefile by 373,732 bytes reported clean,
  because geodiff compares content and not bytes.

### A coordinate stored as an attribute can disagree with the geometry it describes

A spatial layer that also carries `LATITUDE` / `LONGITUDE` columns has the same fact twice, and
nothing keeps them consistent. BC's EMS monitoring locations
(`bcdc_query_geodata("634ee4e0-c8f7-4971-b4de-12901b0b4be6")`) store **`LONGITUDE` positive** —
`127.1931` for a station whose geometry is correctly at `-127.1931`.

Differencing the attribute against another source therefore puts every feature ~16,000 km away:

```r
sf::st_drop_geometry(ems)$LONGITUDE[1]              #>  127.1931
sf::st_coordinates(sf::st_transform(ems, 4326))[1,] #>  X -127.1931   Y 54.8039
```

**The failure presents as a broken join, not a sign error.** A 100% mismatch rate across 74 joined
records reads as "the key is wrong" and sends you back to the join — which is the one place the bug
is not. Measured 2026-09-04 joining CABIN sites to EMS.

Take coordinates from the geometry (`st_coordinates()`), always. If you must use the attribute,
assert it against the geometry once rather than trusting it — and note the sanity check `all(lon <
0)` passes on the *geometry* and fails on the *attribute*, so check the one you are about to use.

### GeoJSON in a projected CRS is silently non-portable

`sf::st_write()` and `ogr2ogr` will write GeoJSON from a projected object and emit a `crs` member
naming it:

```json
"crs": {"type":"name","properties":{"name":"urn:ogc:def:crs:EPSG::3005"}},
"coordinates": [956783.23, 1042595.57]
```

RFC 7946 **mandates WGS84 and removed the `crs` member**. QGIS honours it, so the file opens
perfectly on the desktop where it was written — and GitHub's map preview, Leaflet and Mapbox all
read those numbers as lon/lat and place the feature in the Atlantic.

So the format that renders it correctly is the one least likely to be used to check it. Transform
explicitly and say so:

```r
sf::st_write(sf::st_transform(x, 4326), path, layer_options = c("RFC7946=YES"))
```

Assert on the written file, not the object: no `crs` key, and coordinates inside
`[-180,180] x [-90,90]`. Caught 2026-09-04 in `stewardship_upper_wedzin_kwa`.

Related: prefer GeoJSON over GeoPackage for a **tracked** layer. Git deltas text and stores a whole
new copy of binary SQLite on every write — four commits of one 196 KB layer had already put 692 KB
of blobs into history. Ship the gpkg as a gitignored rebuild.

### `sf::st_perimeter()` needs lwgeom on projected data, and lwgeom is not a dependency of sf

An exported sf function whose body branches on `requireNamespace("lwgeom")` is an
undeclared dependency: `R CMD check` does not report it, and a test suite cannot see it
on a machine that happens to have lwgeom installed. `st_perimeter()` is the live case —
on a projected CRS it delegates to lwgeom and errors without it (sf 1.1.2), so a package
that rejects lon/lat input takes that branch on **every** call. Caught 2026-09-04 in
drift#44 by a review round, not by tests: the suite was green, the exported function
would have failed on first use for any install without lwgeom, and the pkgdown CI
(Imports + Suggests only) would have gone red on the examples.

```r
as.numeric(sf::st_length(sf::st_boundary(sf::st_geometry(x))))   # no lwgeom
```

Measured identical to `st_perimeter()` (max abs diff 0) across 93 raster-derived patches
including 21 MULTIPOLYGON and 2 with holes; `numeric(0)` on zero rows. **Bare `st_length()`
on polygons returns 0**, silently. Pin it with a test that `"lwgeom" %in% loadedNamespaces()`
is `FALSE` after the call (unload first; it goes red with `st_perimeter()` restored).

Same shape in `st_geod_*`, `st_minimum_bounding_circle()`, `st_split()`, `st_subdivide()`:
the function is in sf's namespace, so `sf::` reads as a declared dependency while the branch
needs one nobody declared. Read the body for `requireNamespace` before relying on it. This is
"A fixture that cannot reach the failure mode" arriving through the *environment*: no fixture
varies which packages are installed.

### terra keeps a result in memory whenever it fits, so a per-class loop over a large grid accumulates full-grid rasters

`ifel()`, `focal()`, arithmetic and `rasterize()` return in-memory SpatRasters whenever the
result fits under `memfrac` (60% of RAM by default). On a 169M-cell grid each one is 1.35 GB,
and a loop that computes two per class and never frees them holds 2.7 GB per iteration —
measured 11.3 GB peak for **one** class and killed for memory at eight on a 64 GB machine
(drift#44, 2026-09-05, the BULK floodplain at 10 m, 97.7% NA). `inMemory()` was `TRUE` on
every intermediate. Unit tests on a 40x40 fixture cannot reach this; only a run at scale did.

Pass `filename = tempfile(fileext = ".tif")` to every intermediate that is not the return
value (`app`, `focal`, `rasterize`, `segregate` all take it) so terra streams in chunks, and
`unlink()` them in `on.exit()`. Prefer one multi-layer pass over a per-class loop:
`segregate(x, classes = ks, other = 0L)` gives a 0/1 layer per class in ascending order,
`focal()` processes the stack per layer, and `zonal()` returns one column per layer — three
calls in place of `3 * n_classes`. Same run afterwards: 143 s, peak set by the upstream
stage. LZW-compressed intermediates measured ~0.2 bytes/cell/layer, so disk is not the
constraint. Do not fix it with `terraOptions(memfrac = )` from library code — that is a
global a caller did not ask you to change.

### `geom_sf(data = NULL)` draws nothing, silently

A `NULL` `data` argument does not error and does not warn — the layer inherits the plot's data,
which for `ggplot()` with no global data is empty, so it contributes a **zero-row layer**. The
figure builds, writes, and is missing whatever that layer was.

The reachable shape is a list subscript that has stopped matching: `ff[[primary]]` is `NULL` the
moment `primary` names a key the list no longer has, and a list built from config changes without
anybody editing the constant that indexes it. Measured 2026-09-04 in floodplains#77 — with the
scenario set derived from a CSV and the primary scenario left as a literal, the overview panel
wrote successfully at 373,719 bytes with its entire floodplain ribbon absent, under a subtitle
still naming the scenario. Nothing in the render said a word.

Assert membership where the index is not derived from the same source as the collection:

```r
if (!key %in% names(x)) stop("`", key, "` is not among (", paste(names(x), collapse = ", "),
                             ") — the layer would draw nothing and say nothing about it")
```

Same class as *"Zero-length, empty, and unset are three different things"* in `code-check.md`,
landing in a graphics device rather than a data frame: the wrong value is a perfectly valid one,
and the output is a plausible picture.


### terra: `app()` calls a vector-tolerant `fun` once per CELL, and reads a 5-column return on a 5-column raster as transposed

Two contracts inside `terra::app()` that read as the opposite of what they are, both measured on
terra 1.9.34 (drift#9, 2026-09-05):

- **Dispatch.** `app()` first tries `apply(chunk, 1, fun)` — one R call per cell — and falls back
  to `fun(chunk)` only when that errors. A `fun` written to accept a bare vector (the natural
  "handle both shapes" reflex: `v <- matrix(v, ncol = n)`) therefore silently runs per cell:
  measured 360,013 calls / 6.96 s against 2 calls / 0.12 s on a 600 x 600 x 7 stack, 57x, values
  identical. Chunks always arrive as matrices, single cells included, so **refuse anything else**:
  `if (!is.matrix(v)) stop("matrix chunks only")` is what forces the vectorised path. Nothing in
  a suite sees it — both paths give the same numbers — so pin the closure directly and let a
  scale run carry the timing. The same defect reappeared in the benchmark script that measured it.
- **Shape inference.** `app()` decides the output layer count from a test chunk of
  `min(ncol, 13)` cells and checks `ncol(result) == ntest` *before* `nrow(result) == ntest`.
  A `fun` returning k columns on a raster exactly k columns wide (k < 13) is read as transposed,
  and every chunk is written across layers with no warning. Silent scrambling on a legal input;
  pad such a stack by one column (`extend()` then `crop()` back), and assert the output against an
  arithmetic reference on widths 4, k, k+1.

Also from the same run: `wopt = list(steps = n)` is honoured as a **floor** on chunk count and is
the library-local way to bound the R-side matrices `fun` receives (left to its memory heuristic, a
64 GB machine takes a 192M-cell grid in one or two chunks, ~10 GB of matrices); and the default
`app()` datatype is `FLT4S`, while `INT2S` overflows at `from * 1000 + to` once a class code reaches
33 (every ESA WorldCover code) with a *warning* from `writeValues()`, not an error, that fires before
`writeStop()` — so promote it to an abort and keep the partial file on the cleanup list.

### terra: `levels<-` and `coltab<-` copy before they strip; `set.cats(NULL)` is the in-place form

Both replacement methods begin with `x@pntr <- x@pntr$deepcopy()`, so no placement of
`levels(r) <- NULL` / `coltab(r) <- NULL` can mutate a caller's raster — and a test asserting "the
caller's rasters are untouched" is decoration under every variant, because nothing the code could
do would reach them. `terra::set.cats(r, layer = i, value = NULL)` mutates in place, strips every
layer when looped, costs no copy, and is the form a caller-unmutated test can actually guard.
`coltab(stack) <- NULL` strips **layer 1 only** (`layer = 1` default, `removeColors(layer[1] - 1)`);
`levels(stack) <- NULL` strips all. `rast(list)` copies in-memory sources — seven 192M-cell
rasters cost ~10 GB again — so spill in-memory inputs to temp files before stacking. And terra
writes a RAT sidecar (`<file>.tif.aux.xml`) beside **any** factor it writes (`resample()`,
`writeRaster()`), which an `unlink(files)` of the `.tif` alone leaves behind; a palette on a
non-byte band warns on every write. Strip both on a copy before writing, and unlink the sidecar
too — guarded on `length(files)`, because `paste0(character(0), ".aux.xml")` is `".aux.xml"` and
`unlink()` resolves that in the working directory (drift#9 round 7, 2026-09-05).

### terra `metags()`: the empty case is `NULL`, and the sidecar is half the artefact

Three measured facts about raster **container** metadata, all of which fail quietly
(floodplains#83, 2026-09-05, terra 1.9.34 / GDAL 3.8.5).

**`metags()` returns `NULL` for a raster with no tags — not a 0-row frame.** So
`if (!nrow(metags(r)))` raises `invalid argument type`, and `metags(r) <- NULL` on that
same raster dies with `value[, 3] <- "" : incorrect number of subscripts on matrix`. A
strip written without that guard aborts on precisely the rasters that need no stripping,
so it works on the machine with the bug and breaks everywhere else. Nothing on disk
reaches it either — every written GeoTIFF carries `AREA_OR_POINT` — so only a
constructed zero-tag case finds it. Guard with `!is.null(tg) && NROW(tg) > 0`.

**Band category names can live ONLY in the `.aux.xml`.** `GDAL_PAM_ENABLED=NO gdalinfo`
on a terra-written factor raster shows no `Categories` block at all. So the `.tif` and its
sidecar are one artefact: a repair that rewrites the `.tif` and renames it into place
without the sidecar destroys the published RAT, and **every content check still agrees** —
a values-plus-geometry digest does not read class labels, so `is.factor()` goes FALSE with
the digest byte-identical. This is the mirror of the rule above ("unlink the sidecar too"):
on cleanup you must remove both, on repair you must **move both**, and assert
`terra::cats()` before and after rather than inferring it from a `gdalinfo` diff — that
diff reads each file with its own sidecar and so cannot see one go missing at rename time.

**A guard reading dataset tags must disable PAM.** GDAL merges a sidecar's dataset-level
`<Metadata>` block into the default domain, so a sidecar carrying `TIFFTAG_SOFTWARE=QGIS`
puts two "stray" tags on a clean raster — and GDAL writes that sidecar as a side effect of
anyone *opening* the file. Unguarded, the property depends on who has looked at the raster,
and a `.tif` rewrite cannot remove a sidecar tag, so the file is "repaired" and reports
dirty forever. Set `GDAL_PAM_ENABLED=NO` around the read and restore the prior value.
Read through GDAL (`sf::gdal_utils("info", …, "-json")`), not `terra::metags()`, whenever
terra is the library under suspicion — and select the default domain **by position**, since
its key is the empty string and `md[[""]]` silently matches nothing.

### `ggmap`: a fixed `zoom` silently crops points off the basemap, and `calc_zoom()` does not fix it

`ggmap::get_map()` fetches ONE fixed-size image at whatever `zoom` it is given. Points outside
that image are still drawn by `geom_point()`, land off the basemap, and are clipped away — the
map renders successfully, looks plausible, and is missing sites. No warning and no error, so the
loss is invisible unless you already know how many points you expected. A hardcoded `zoom = 9`
did this in safety_plan_template: 8 sites spanning 1.5 degrees of latitude showed as 2 pins, on a
map crews navigate by.

`ggmap::calc_zoom()` is not the fix — it ignores Mercator latitude compression and returns the
same too-tight zoom. A 640 px Google static image spans `900/2^z` degrees of longitude, but those
same pixels cover only `cos(latitude)` as much **latitude**, a factor of ~1.75 at 55 N. At zoom 9
near Chetwynd the image covers 1.76 lon x 1.00 lat against the 1.88 x 1.72 needed: the longitude
axis fits, the latitude axis loses three quarters of the sites, and only one of the two axes is
the one anybody checks.

Solve both axes and take the looser one:

```r
map_cos  <- cos(mean(bb[c("bottom","top")]) * pi/180)
map_zoom <- floor(min(log2(900 / diff(bb[c("left","right")])),
                      log2(900 * map_cos / diff(bb[c("bottom","top")]))))
map_zoom <- max(3L, min(as.integer(map_zoom), 13L))   # guard identical coords -> Inf
```

The clamp is load-bearing rather than cosmetic: one site, or two sites at the same coordinates,
gives `diff() == 0` and `log2(x/0) == Inf`.

**Verify rather than eyeball** — count the points falling inside `attr(basemap, "bb")` and assert
it equals `nrow()`. A visual check is precisely the check this failure defeats, since the map that
dropped six of eight sites is a clean and credible map (safety_plan_template, commit `7d25df4`,
2026-09-06).

### terra: `zonal()` outside its six-function fast path materializes the WHOLE grid in R

`terra::zonal()` dispatches to C++ only when `fun` is one of `max`, `min`, `mean`, `sum`,
`notNA`, `isNA`. Anything else — `"modal"`, a quantile, any R closure — falls through to

```r
xz <- c(x[[i]], z); v <- as.data.frame(xz, na.rm = FALSE)
stats::aggregate(v[, 1], v[, 2, drop = FALSE], fun, ...)
```

which is one data-frame row per cell, per layer. On a floodplain grid that is 169M rows (BULK)
or 204M (KOTL), ~2.7 GB as doubles before `aggregate` copies it — so the obvious answer to
"take the modal value per zone rather than the mean" is a silent OOM on a machine that handles
the mean fine. Read from the method body, terra 1.9.34.

**Use `terra::crosstab(c(zone, layer), long = TRUE, useNA = TRUE)` instead.** It is
`x@pntr$crosstab()`, pure C++ and streamed, and `long = TRUE` returns only observed
combinations with zeros dropped — cells per (zone, value), from which the modal value, the full
within-zone distribution and exact denominators all follow, with no statistic chosen in advance.
Measured on a 10x10 fixture: columns come back **numeric, not factor**, and `useNA = TRUE` keeps
the NA group, so `as.integer()` on a value column is the value and not a level index.

Two things `zonal(fun = "mean", na.rm = TRUE)` also gets wrong that the crosstab does not:
it computes over **non-NA cells rather than zone cells**, which is a different denominator than
most callers mean and is invisible in the result; and it returns `NaN`, not `NA`, for an
all-NA zone, which `merge(all.x = TRUE)` will not surface as missing.

Caught 2026-09-06 in drift#67, by a reviewer disassembling the method rather than by a test —
both paths return the same numbers on a fixture small enough to run.


### sf: close a rotated ring by copying the first vertex, never by recomputing it

Rotating a polygon by multiplying its whole vertex matrix — `xy %*% rot` — looks exact,
and for a ring built closed it is not. `%*%` computes rows **independently**, and an
optimised BLAS may block or vectorise them differently, so the fifth row (a duplicate of
the first, by construction) can come back a few ulps away from where the first landed:

```r
xy  <- matrix(c(-1000,-1000, 1000,-1000, 1000,1000, -1000,1000, -1000,-1000),
              ncol = 2, byrow = TRUE)             # closed: row 5 == row 1
rad <- 230 * pi / 180
r   <- xy %*% matrix(c(cos(rad), sin(rad), -sin(rad), cos(rad)), nrow = 2)
identical(r[1, ], r[5, ])                          # FALSE
r[1, ] - r[5, ]                                    # 0  -2.842171e-14
```

`sf::st_polygon()` requires **exact** closure and raises *"polygons not (all) closed"* —
an **error**, not a warning — so one unlucky feature aborts the whole batch rather than
losing itself. Rotate four vertices and append the first again:

```r
xy <- matrix(c(-hc,-ha, hc,-ha, hc,ha, -hc,ha), ncol = 2, byrow = TRUE)  # four
if (is.finite(b)) xy <- xy %*% rot
xy <- rbind(xy, xy[1, , drop = FALSE])             # close by COPY
```

**Whether it fires depends on the angle and the dimensions**, so a fixture that happens
not to hit it proves nothing: measured 2026-09-02 in fly#26, this had been latent on
`main` for every rotated non-square footprint since fly#32 and 1338 passing tests never
saw it. Sweep the angle — `seq(0, 359.5, by = 0.5)` — rather than sampling a handful,
and assert that the *recomputed* form still fails somewhere in that sweep, or the test
silently becomes decoration once the fix makes the property true by construction.

Generalises past rotation to any affine map applied to a closed ring, and past sf to any
library that validates closure by exact equality. The rule is the same: a closing vertex
is a **copy**, never a computation.


### terra: `plot(type = "classes", levels =, col =)` maps colours by POSITION, per layer

A `levels`/`col` pair is not a value-to-colour mapping. `terra::plot()` matches the vectors
against **that layer's own sorted unique values**, so a layer missing a class shifts every class
after it — and each panel of a multi-panel figure is mapped independently.

Measured 2026-09-06 in drift#66 on a 7-layer IO LULC stack carrying codes 1, 2, 5, 9, 11. Five of
the seven years contain no code 9 (Snow/Ice), so their four values took the first four colours and
**Rangeland drew in Snow/Ice's blue** — 705 cells, in the panel the figure existed to show,
contradicting the legend printed beneath it from the same vectors:

```r
present <- sort(unique(values(stack)))          # 1 2 5 9 11 across the STACK
ct <- ct[match(present, ct$code), ]
terra::plot(stack[[i]], type = "classes", levels = ct$class_name, col = ct$color)
#> layer i has 1 2 5 11 -> code 11 draws ct$color[4], not ct$color[5]
```

Computing the class set over the whole stack is exactly the instinct that produces it: it is the
right way to build a **legend**, and the wrong way to build a per-layer `col`.

Use a colour table, which is keyed by cell value and cannot desynchronise:

```r
for (i in seq_len(terra::nlyr(x))) terra::coltab(x, layer = i) <- data.frame(value = , col = )
terra::plot(x[[i]], legend = FALSE)
```

- **A single-layer fixture cannot reach this**, and neither can a stack whose layers happen to
  carry every class. The trigger is a *missing* class in *some* layer.
- **Reading the code will not find it** — the vectors are correct and the legend built from them
  is correct. Read the rendered image and check one cell of a known class against the legend.
- Same shape for any renderer taking parallel `breaks`/`labels`/`col` vectors and re-deriving the
  domain per facet.

### terra: `wrap()` carries the tempfile basename in `varnames`, so a committed artifact churns

`sources()` on a derived raster (above) is the well-known half. `varnames` is the quiet one:
terra keeps the **basename of whatever `filename =` produced**, and `wrap()` serialises it, so an
`app()`/`focal()` written to `tempfile()` puts a per-process random string into the saved object.

```r
r <- terra::app(x, fun = f, filename = tempfile(fileext = ".tif"))
terra::varnames(r)                       #> "file178092823716a"
saveRDS(terra::wrap(r), "committed.rds") #> different bytes on every run
```

Measured 2026-09-06 in drift#66. Values, extent and CRS all round-trip **identically** — the
diff is entirely `@attributes$varnames` — so every content check agrees while the file changes on
each regeneration and a real change becomes invisible in the noise. Pin it, with `longnames`,
before wrapping or writing:

```r
terra::varnames(y) <- rep("<a stable name>", terra::nlyr(y))
terra::longnames(y) <- rep("", terra::nlyr(y))
```

The check is a byte comparison of two consecutive regenerations, not an inspection of the object:
`cmp` on the two `.rds` files is what found it, after `identical(values(a), values(b))` had said
they matched. Note this pins only the **per-process** variation — a `date` field in the same
artifact still churns daily, which is a deliberate provenance choice rather than a defect, so say
which one the artifact is making.


# Code Check Conventions

Structured checklist for reviewing diffs before commit. Used by `/code-check`.

This file holds the **mechanisms** — the shapes that keep producing bugs regardless of
language — and a short set of standalone rules. Tool-specific traps live beside it,
each gated on the repo's contents: `code-check-shell.md` (bash, sed, git, `gh`; always),
`code-check-r.md` (package internals; `NAMESPACE`), `code-check-spatial.md` (terra, sf,
bcdata, GDAL; bookdown, `DESCRIPTION` or QGIS repos), `code-check-infra.md` (provisioning;
`*.tf`, cloud-init, compose).

When a bug class is discovered, add a **row** under the mechanism it instances. Add a
new mechanism only when no row fits. Add to a tool file only when the rule is about
that tool rather than about a shape.

## Mechanisms

Thirteen shapes that keep producing bugs. Each is stated once; the table under it is
the evidence — every instance dated, with where it was caught and what it cost. The
rule is the thing to check a diff against. The rows are why the rule is trusted.

When a new instance turns up, add a row. Add a new mechanism only when no row fits,
which is rare: the previous version of this file carried 31 lines cross-referencing
another entry — "same family as", "sibling of", "mirror of", "refines" — and every
one was right.

### A guard that fails toward pass

A check decides whether to do something consequential — cut a tag, run a migration,
report a sweep clean. Work out which way it fails when the command *inside* it errors.
If the error path and the "nothing to do" path look the same, the guard is
indistinguishable from a working one right up until it silently eats the action.

The usual shapes: `IF=$(cmd)` tested with `[ -z "$IF" ]`, where an aborted `cmd` reads
as "nothing changed"; a loop over a computed list, where an empty list runs zero times
and exits 0; a `cmd | grep pattern` whose exit is grep's; a search whose regex the
local tool does not support, returning empty like an honest no-match; a `case`
allowlist that matches substrings. The mirror mistake is a guard that fails toward
**abort** on an operation where partial failure is certain — `exit 1 if errors` over
98k requests throws away completed work on a 0.002% transient rate.

**Assign first, test the exit status, then test the value. Branch on empty explicitly.
Test the guard against both known answers before shipping it** — one case that must
fire and one that must not. A guard nobody has seen fail is decoration.

| date | where | instance |
|---|---|---|
| 2026-08-12 | soul gh-pr-merge | **A guard must not fail toward "skip"** — `IF=$(git diff …)` aborted, empty read as "nothing shipped", five commits of real package changes classified as needing no release |
| 2026-08-26 | gq#56 | **An empty result set is not a pass — a loop over nothing exits 0** — GitHub never dispatched the PR's workflows; the watch loop iterated zero runs and reported all green; poll for the runs to exist, then branch on empty explicitly — and branch on the reported `conclusion` (`success\|cancelled\|skipped\|""`) rather than `--exit-status`, which reported a run r-lib's `cancel-in-progress` legitimately cancelled as a failure (2026-08-26) |
| 2026-08-29 | stac_dem_bc | **A guard must not fail toward "abort" either** — 98,040 items, 2 transient failures, exit non-zero skipped the publish and the manifest recording 98,038 successes was never committed; retry in-process before an error can reach the exit code, gate on a rate against a stated tolerance tested against both answers, persist progress on the failure path (`if: always()` in CI), and ask which direction the failure costs more |
| 2026-08-29 | rfp | **A grep that cannot show a failure is not a check** — `cmd \| grep -E "added"` matched the line printed one statement before `Error: could not find function`; the work was then finished by hand, hiding that the driver had not |
| 2026-08-31 | link | **A search that finds nothing has proven nothing until it has found something** — `\b` unsupported on macOS grep; an IP-address audit returned empty and was written into an issue as "no IPs in any tracked file" |
| 2026-09-01 | trap#18 | **A guard nothing corroborates has to count, not match** — `all(grepl(ok, v))` is TRUE for an empty `v`; the xpath needed `xml_ns_strip()` and without it found 0 of 600; only a count turned the tests red |
| 2026-08-31 | link | **A guard placed mid-operation can be defeated by the operation itself** — a clean-tree precondition placed after the run writes its own logs; fired on every real run, for a reason unrelated to what it guarded |
| 2026-08-31 | link | **A job that writes into its own tracked output directory poisons every dirty-check** — a provenance `dirty` flag set on all 21 dispatcher rows, every one false; the flag then carries no information and readers ignore the column; match the predicate to the subject — `git status --porcelain --untracked-files=no -- . ':(exclude)path/to/logs'`, long-form exclude because an aborted status reads as clean, `--untracked-files=no` decided deliberately since it also hides a new source file — and read provenance back against independently measured ground truth |
| 2026-08-31 | fly#42 | **A `case` allowlist matches a substring, not a token** — `case " $allowed " in *" $item "*)` passes an item whose name spans two entries; use an explicit equality loop (`for a in $allowed; do [ "$a" = "$1" ] && return 0; done`), and strip only the suffix that actually matched — `${b%.html}` then `${b%.md}` reduces `index.md.html` to `index` |
| 2026-08 | cyclops#10 | **`cmd > file` truncates before `cmd` runs — a failed command leaves a poisoned empty file** — a timed-out `op read` would have left a zero-byte credential that `[ -f ]` then blessed forever; guard on `-s`, write atomically |
| 2026-09-04 | stewardship_upper_wedzin_kwa | **A run that selects nothing must not overwrite the artifact a run that selected something produced** — a `--since` filter excluded every visit, the fetch loop iterated zero times, and the resulting empty frame was written over a 238-row manifest that had cost 238 live HTTP requests; the run reported success because nothing failed. Merge rather than replace, and skip the write entirely when the new set is empty |
| 2026-09-03 | rtj#259/#260 | **A completion check that enumerates the known-bad states passes for a state nobody enumerated** — a driver's post-condition filtered for its own four actionable outcomes, a copy of the todo filter written twice. A fifth outcome was later added (a form blocked from its rebuild) and landed in neither list, so a run that left the form stale printed `Done.` with the push command under it, on a project with no rollback. Its sibling path returned `Nothing to do.` and exited 0 *before* the check ran. **Invert to the complement**: assert every row is a deliberate resting place — `ok`, or one of the two report reasons that are deliberately final — so an outcome nobody has thought of defaults to **stop** rather than to pass. That does not prevent the next drift; it makes the next drift loud. Three review rounds had each fixed an instance of the same class; the complement is what stopped it being re-fixed |
| 2026-09-03 | stac_floodplains_bc#46 | **`if not parsed: continue` turns "I could not read it" into "it is fine"** — a style validator skipped every content check when its category parse came back empty, so a `nullSymbol` renderer (a real one that draws nothing) and a `singleSymbol` one both sailed through; every classified layer in every item could have shipped drawing nothing, green. An empty parse is a THIRD state beside pass and fail — name the expected shape and assert it, rather than treating unreadable as exempt. **And check which direction the mirror runs**: the same review found the paired defect, a guard asserting a *data* property ("this watershed lost trees") where it meant an *artifact* property ("this style draws what it categorizes"), which would have refused a correct release on a correct dataset — measured margin 3 across 48 layers. Ask of every assertion whether it is about the thing you built or about the data that happened to flow through it |
| 2026-09-04 | rtj#265 | **A coercion that truncates rather than refusing defeats a guard watching for NA** — `as.integer()` does not reject a fractional value, it silently truncates: measured `"2.5"`→`2`, `"0.9"`→`0`, `"-3.7"`→`-3`, no warning and no `NA`. A cast guard written as "report the values that became `NA`" therefore fires on `""` and `"5+"` (benign, or at least loud) and misses **every** instance of the thing it exists for — a column that is not an integer at all. `"0.9"`→`0` is the sharp case: a real measurement becomes zero with nothing said. Compare against `round()` with a tolerance instead of watching for `NA`, and split the two failures by what they cost — a parseable-but-fractional value should **abort** (truncation corrupts a real value; there is no correct silent behaviour), while unparseable→`NA` warns by value with empties separated out. Verify by restoring the old guard and running both over the same inputs: they should catch **disjoint** sets, which is what proves it is a gap closed rather than one guard swapped for another |
| 2026-09-04 | rtj#265 | **A rule stated in a comment is not an enforced rule, and the safe-looking default is usually the dangerous value** — a driver's header said `--themes` must NEVER be `"all"`, citing the incident that produced the rule, while the call site read `themes %||% "all"` and a dry run reported the plan and passed. Three artifacts disagreed — header, PR description, code — and the dry run printed the dangerous value as if it were information. Where a comment says "never X", grep the file for X before believing it; where a default exists because a value is required, make omission an **error** rather than a fallback, and put that check ahead of any dry-run return so a plan-only run refuses rather than reporting a plan it would not have been safe to run. Both this and the row above were found by a PR reviewer on a check reporting green — the review's *conclusion* was SUCCESS both times, and the finding was in the comment body |
| 2026-09-03 | link#278 | **A driver default that selects a methodology, a data scope or a deployment target answers a question nobody asked** — distinct from an ordinary default: `verbose = FALSE` is a preference, `config = "bcfishpass"` picks which of two biological methodologies you shipped, and the tell is that the alternative would also have run cleanly and produced different, equally plausible numbers. Fifteen drivers in one package defaulted to a parity config while the operator expected the package's own, so six watershed groups were modelled on the wrong methodology into a product line already seventeen deep, caught by an offhand question afterwards. Worse when the default is *named* like the safe one (`bcfishpass` vs a config literally called `default`). The remedy is not a policy fixing each answer; it is **removing defaults that silently answer for you**: make the argument required, and where a default must stay, print the resolved decision at start-up with the alternative named. Review question for any driver diff: does this fallback choose a method, a scope or a target? A fleet sweep of the shape is soul#178 |
| 2026-09-04 | floodplains#77 | **Widening a guard is how it starts refusing correct content, and case-insensitivity is the cheapest way in** — a catalogue-fact grep was widened after missing 5 of 12 restatements, and the new latitude pattern `\b\d{1,3}\.\d+\s*[NS]\b` ran under `re.IGNORECASE`, so `[NS]` also matched a lowercase **s**: `0.39 s`, a timing figure from the repo's own notes, was refused as a collection extent. Compile flags **per pattern**, not per sweep. Two habits that caught it: keep a **negative control set** of sentences the repo legitimately writes and assert they still pass, and check *what the guard reads* — this was the one arm of three not stripping `<script>`, so an embedded bootstrap payload with 30 CSS durations (`.15s`) sat one leading digit from failing a page that was fine |
| 2026-09-05 | stac_floodplains_bc#61 | **A currency gate read from the artifact the assertion pins downgrades FAIL to SKIP** — a byte-identity assertion pinned a built `meta.json`'s digest and gated itself on that same file's `produced_datetime`, so it would skip whenever upstream had re-run. Any regression that moved or nulled that field — a broken provenance read, a lost section, a rename — therefore made the gate skip **under a message blaming upstream**, on the one arm that exists to notice the code moving the artifact. Read a currency gate from the independent source it is really about (the producer's own file), never from the subject. A pin needs one gate per **independent input** to the digest, too: the same assertion's second gate covers the local sf/GDAL/PROJ triple, because the areas and geometry inside that file are computed on the machine that runs it, and an ungated toolchain difference FAILS rather than skipping |
| 2026-09-05 | rfp#281 | **A render or export API returns Success when its inputs silently failed to load** — `QgsLayoutExporter.exportToImage()` returned `ExportResult.Success` for a report figure whose basemap and every remote raster were missing: under `--network none` the same project read **42 invalid layers against 18** and exported in 3.6 s against 9.5 s, with the same return code both times. The result code answers *did the writer run*, never *is the output what was asked for* — and the degraded output is a plausible picture, so nothing downstream looks wrong either. Same for a missing font, an unresolved image path (three logos rendered as red-X placeholders, still Success) or a layer whose style failed to load. **Gate on the count of inputs that failed to resolve, not on the return code** — and gate it *differentially*, since real projects arrive already carrying some (18 here before anything was driven), the same reasoning as `.qgs_dangling_refs()`. The rendering sibling of "A wrapper's exit is not the work": there the wrapper lies about the work, here the work lies about itself |
| 2026-09-05 | floodplains#83 | **The one destructive step is the one that must not go unchecked, and `file.rename()` returns FALSE rather than erroring** — a repair verified four properties before replacing a file and then discarded both renames' return values. Measured with the target made immutable so only the rename could fail: it reported `Repaired 1 of 1`, exited **0**, and left the file carrying the tags it existed to remove — while the summary's `FAILED (left untouched)` line became uncontradictable, since the one state where it is false could never enter the failed set. Same family as `file.copy()` above, one verb over, and worse because it is the *last* step: everything before it aborted safely. Where two files must move together, rename the one whose failure moves nothing **first**, and report a half-completed pair as exactly that rather than as a success |
| 2026-09-06 | drift#67 | **A content hash computed at the END of a run stamps the file as it finished, not as it ran** — a `script_sha` written where the metadata is assembled records the state of the source *after* any mid-run edit, so a uniformity check across parallel outputs sees one value and accepts two definitions of the same measurand. That is the guard against mixing versions failing toward pass, on the one thing it exists to catch, and it was live: the file genuinely was edited between group runs. Hash at the **start**, beside the run timestamp, and use the captured value. `digest(file =)` errors loudly on an unresolvable path, so a bad working directory stops rather than writing NA. Generalises to any provenance stamp — git SHA, config digest, tool version — read at write time rather than at read time |
| — | — | **Silent Failures** — `\|\| true` hides real errors; an empty variable before `rm`/`destroy` needs `[ -n "$VAR" ] \|\| exit 1`; `grep` returning empty feeds downstream silently |

### A fixture that cannot reach the failure mode

Hand-picked fixtures test the cases you thought of. If every one is structurally
incapable of triggering the bug class you are fixing, a green run means nothing — and
it is more dangerous than no test, because it licenses the word "validated". A fixture
that matches the code's happy path leaves whole branches not merely untested but
never executed: one raster in the data's CRS makes every reprojection an identity.

Before declaring a fix verified, ask what the fixtures have in common and whether that
shared property is the very thing the bug depends on. Vary the fixture along exactly
the axes it cannot reach. Prefer a global structural invariant — antisymmetry,
conservation, every node reaches a terminal — over more examples, because an invariant
cannot be gamed by fixture choice. And check a threshold against the **least
favourable** member of the population, computed, not the vivid one you remember.

| date | where | instance |
|---|---|---|
| 2026-08 | link#227 / fresh#214 | **A fixture set that cannot reach the failure mode is not validation** — 8 hydrology fixtures all compared groups with *differing* stream codes; the bug fires only between groups sharing one; the next case tried dropped the group the whole Fraser drains through |
| 2026-08 | rfp#139 | **A negative-case fixture rots when the positive set grows** — a refusal test picked EPSG:4326 because nothing supplied it; shipping an `<srs>` for a tracking layer made it resolvable and the test failed blaming the code; assert the premise beside the property |
| 2026-09-02 | fly#26 | **An assertion invariant under the transformation you are adding stays green while its premise dies** — a film-footprint regression net pinned shape two ways, area and bbox aspect. Rotation preserves area exactly, and a rotated square's bbox is still a square (`w = h = s(|cos b| + |sin b|)`), so both survived the change that falsified their stated premise ("Square, so unrotated") and the test kept passing while measuring nothing. The fixture was fine — it is the **assertions** that could not see it. Before adding a transformation, ask of every existing assertion whether it is invariant under that transformation; what discriminated here was ring vertex 1's azimuth from the centroid, `bearing + 225`, which pins angle, sign and vertex order together |
| 2026-08-27 | flooded#40 | **A comparison test proves nothing if the fixture makes both sides identical** — grouping by `gnis_name` vs `blue_line_key` was a bijection in the test data, so the two runs were the same run with different labels |
| — | water-temp-bc#23 | **Test fixtures must mirror production column TYPES, not just shapes** — fixtures had `Grade` as string, production has double; a `coalesce(Grade, '')` sentinel passed 27 tests and broke on first contact |
| 2026-09-01 | stac_floodplains_bc#23 | **A cross-item consistency check cannot see a defect that hits every item** — a uniform-key validator measures variance; keying a new asset by a stem that was already a key would have overwritten a raster in every item and every check would pass; pair with one absolute assertion |
| 2026-09-01 | stac_floodplains_bc#34/#35 | **Declaring a schema extension is not evidence the field is populated** — the STAC classification extension's Item branch validates `classification:classes` without requiring it, so an item declaring the extension with the field on zero assets passes `pystac.Item.validate()` clean, and a loss that uniform is invisible to the cross-item check above as well; read the schema's own `required`/`anyOf` for the branch you actually validate (Item, Collection and Asset differ) rather than assuming the extension's purpose is enforced, and where the field is optional write the absolute assertion — a hardcoded count or key set, because one derived from the artifact goes empty alongside it |
| 2026-08-31 | floodplains | **A per-tenant key looks global whenever your test data has one tenant** — `patch_id` numbered within sub-basin; five areas had one sub-basin each, so it was observably unique; the only 13-sub-basin area had 2032 rows and 1973 distinct ids, a 6% mis-apportionment; ask what the id is unique *within* and prefer the composite (`patch_id`, `name_basin`) even where today's data makes the extra column redundant |
| 2026-08-30 | fly#38 | **Check a threshold against the least favourable case, computed — not a remembered example** — tolerance set to 1.10 against a remembered 0.442; the binding case was 0.0949, `log(1.10)` is 0.0953, 0.4% too loose, and it let through the one input it existed to catch |
| 2026-08 | rfp#168 | **Mocking the transport means the request is never built** — `local_mocked_bindings(.do_http=)` gives full coverage of response handling and none of the request; the wrong content type returned 400 on every Overpass endpoint with 130 tests green; make the wire format a pure function and assert it offline |
| 2026-09-02 | floodplains#64 | **A fixture that varies the artifact but not the reader tests nothing reader-dependent** — two GeoTIFFs with different containers, both read with the same terra in the same process, digests asserted equal; delete both normalization lines and all nine assertions still passed, because storage type only varies with what the *reader* does, and the real trigger was a `.aux.xml` sidecar beside one file that the fixture had no reason to model; closed by asserting the property on plain vectors with no file I/O — name the axis the guard exists to test, then check the fixture actually varies it |
| 2026-09-05 | rfp#265 | **An early return can make the defect unreachable for every input anyone exercises** — the fixture-blindness above with the short-circuit inside the code under test rather than in the data. `_project_files()` returns at `if (version is None or version == head)`, so a **HEAD read never executes the next line** — which passed a project *path* where the client wants a UUID. Measured with a control: `<project>@HEAD` returned 1029 files and `<same project>@HEAD-1` 404'd, as did an unrelated project's own `HEAD-1`, so it was the version and not the project. Every caller had only ever read HEAD, so a whole pinning design downstream worked by coincidence and would have broken the next time anyone bumped a version. The correct call sat 130 lines up in the same file **with a comment explaining it**, which is the tell that the branch was never walked rather than never understood. Ask which branch a realistic input takes before trusting a green suite, and test the case the early return skips — here a read at `HEAD - 1`, since a HEAD read structurally cannot fail |

### A proxy is not the property

A condition that stands in for the thing you actually want. It fixes the case in front
of you and leaves every other state with the same property wide open, because a proxy
is correlated with the property and a guard needs equivalence. The tell is a condition
naming a **mechanism** — "has no row in table X", "elapsed over 2 minutes", "block
size is 128" — where the requirement is a **capability** — "can be resolved", "is
well-supported", "costs N requests". Ask what property you were testing for, and
whether the condition is equivalent to it or merely adjacent.

Proxies compress (a 14,950x allocation difference showed as 5x in wall-clock, inside
CI jitter), and they can be **inverted** — a long GPS gap meant the subject stood
still, which is when interpolation is most accurate, so the time gate rejected the
best fixes. Assert the quantity that actually differs. Where the property is internal,
name it and observe it. Measure the sign of a correlation before trusting it.

| date | where | instance |
|---|---|---|
| 2026-08-29 | fly#9 | **A proxy assertion does not guard the thing it stands for** — elapsed time as a stand-in for cell count; 243M vs 16k cells showed as 1.0 s vs 0.18 s; the guard written for the defect passed on it |
| 2026-08-29 | rfp#218 | **A guard that encodes the cause you measured is a proxy for the property you want** — "has no `gpkg_spatial_ref_sys` row" stood in for "`st_crs()` can resolve it"; a row that exists and resolves to nothing passed; four review rounds, three failure arms, one guard each |
| 2026-09-01 | trap#25 | **A proxy can be inverted, not merely imprecise** — elapsed time to the nearer vertex as an error bound; the logger emits on movement, so long gaps are stillness; Spearman −0.154; 15 of 16 long gaps had the subject move ≤18 m and the gate rejected all 16 |
| 2026-08-31 | — | **A structural property is not a performance measurement** — 128×128 blocks vs 512×512 read as "16x the range requests"; `CPL_CURL_VERBOSE` counted 14 against 14; the block cache absorbs it |
| 2026-09-01 | drift#47 | **A structural prediction can point the opposite way from reality** — `gdalcubes::filter_geom()` at 64 px chunks skips 26.7% of the ground, so the read should get cheaper; over the wire it made 693 requests against 462 and took 47% longer, because the COGs are `Block=512x512` and a sub-block chunk refetches the same source block per chunk; "A structural property is not a performance measurement" compresses, this one reverses; the tell is a prediction that counts one thing while the bill is itemised in another — measure in the unit you are billed in |
| 2026-08-30 | fly#32 | **Do not branch on a value only some code paths populate** — `sized <- !is.na(half_side)` is a property of which route ran first; three conditions in one function each broke on the same `NA`-by-construction fact; batch-dependence is the confirming symptom; the remedy is distinct from the proxy's — derive the predicate from inputs known before any route runs, not a truer measurement |
| 2026-08-31 | gq#76 | **A premise check satisfied by the happy path's own structure is decoration** — `any(dir.exists(paths))` is TRUE whether or not the sweep recursed, because top-level dirs are always present; restore the defect and watch the premise fail |
| 2026-09-01 | link#250 | **Asserting a proxy instead of the property passes on the defect** — a pool's width asserted through its job count; 3 jobs at width 8 and at width 10 both write 3 result files and exit 0, so the assertion passed against an octal bug that halved the width — the proxy was blind to it, not merely compressing it; derive the property exactly: each job appends `+` on start and `-` on end (single small appends, atomic under `O_APPEND`), then `awk '$0=="+"{n++; if(n>m)m=n} $0=="-"{n--} END{print m+0}' events` is the width actually used, and with the bug restored it reports `ran 8-wide, expected 10`; ask whether your assertion could tell the property from a neighbouring value — if two widths produce identical observations, it is about something else |
| 2026-09-07 | drift#72 | **A combined evidence score is a proxy for its parts, and it is wrong in opposite directions depending on whether they are independent — so measure that first** — merging independent legs discards what each knew, and merging dependent ones counts the same measurement twice; both surface as one plausible number with no way to tell which happened. drift had both, measured, in the same dataset: #62 Q4 found the geometric and temporal legs independent to nearly independent (clean-break share 0.494 vs 0.575, 0.490 vs 0.621, 0.518 vs 0.515) and concluded *"neither leg predicts the other well enough to stand in for it — a patch needs both tags"*, while #67 found date agreement and the sustained/endpoint split are **one measurement read two ways** (*"the split is `break_year` thresholded … do not report them as two corroborating legs"*). Keep one named column per axis and let the consumer rank; where a strength already exists as a number (`pmin(n_before, n_after)`, 1-3 here), publish it rather than its threshold — a boolean derived from it is the lossy form, and nothing downstream can recover what it dropped. Corollary on **grain**: an aggregate row is not a place, so a spatial attribution cannot attach to one however the vocabulary grows — `Trees -> Rangeland, break, 2019, 13,480 cells` spans a whole floodplain, and asking which fire it was has no answer at that row. Check the grain before designing the column |

### Verification that reads its own output

A check whose reference was produced by the thing it checks cannot disagree with it.
Hash-on-write proves nothing changed *since you hashed*; a reference generated by
feeding your artifact to the consumer is your artifact with a blessing; a round-trip
through your own reader validates only self-consistency; a verifier on the writer's
library shares every blind spot the library has; a probe that reads back the value it
was handed is a round-trip through your own assignment. Every one returns identical,
forever.

Measure at the furthest downstream point you can reach — the rendered primitive, the
bytes on the wire, the row as the consumer's own client reads it. Ground truth is the
**consumer's own output**, constructed from inputs that are not your artifact. Diff
the bytes at the boundaries, not just the parsed structure. And for every field you
write that your own code never reads back, name what does read it.

| date | where | instance |
|---|---|---|
| 2026-09-01 | stac_floodplains_bc#23 | **A checksum you compute yourself cannot detect corruption that predates it** — two unchecked `file.copy()` calls fed straight into checksum computation; a truncated copy would have published bytes plus a checksum confirming them; `file.copy()` signals failure by returning `FALSE`, not by erroring, so `stopifnot(file.copy(…))` |
| 2026-08-30 | rfp#227 | **A reference generated by feeding your artifact to the consumer is circular** — `loadNamedStyle(ours); saveNamedStyle(ref)` hands back your file; build the reference from the consumer's API instead |
| 2026-08 | rfp#17 | **A round-trip through your own reader proves nothing about interop** — `layer_styles` rows with `f_table_schema` NULL round-tripped through DBI; QGIS matches with `= ''` and NULL never equals, so every style was invisible and nothing logged; the same reader on both sides of a *fixture* is the floodplains#64 row under "A fixture that cannot reach the failure mode" |
| 2026-08-27 | rfp | **A verifier built on the writer's own library shares its blind spot** — ElementTree drops `<!DOCTYPE>` on write and does not need it to parse; the structural compare reported IDENTICAL |
| 2026-09-01 | stac_floodplains_bc#34/#35 | **A well-formed file the consumer ignores is worse than a malformed one** — GDAL's PAM parser silently ignores a `.aux.xml` sidecar carrying an `<?xml …?>` declaration: 0 RAT rows read, 2 with the declaration removed, bytes otherwise identical; Python's `ElementTree.write()` emits it for `xml_declaration=True` or, with the default `None`, for any encoding spelled other than `utf-8`/`us-ascii` — `encoding="utf8"` writes one, `"utf-8"` does not (measured, CPython 3.14) — so the writer's spelling of a string decides whether the consumer reads anything; a full run with the declaration on published COGs with no class labels at all, every gate green; pass `xml_declaration=False` explicitly; the third of this family — the round-trip row is your own reader, the verifier row is the writer's library, this is the production reader rejecting silently; put the guard on the consumer having read the file, not on the write having succeeded, round-trip through the real consumer once, and suspect the serializer's defaults — it fails toward *absent*, which reads as "nothing to find" |
| 2026-08-26 | gq#16 | **Measure the output, not the input you handed in** — `pointsGrob$size` read back gave 5.08 mm, the value tmap was handed; the engine draws 3.81 mm; every symbol shipped 25% undersized while documented as exact; 0.2 inch exactly was the tell |
| 2026-08-26 | rfp#186 | **A value nothing reads is wrong silently — get it from the consumer, not from reasoning** — QGIS `<alias index=>` off by one because OGR excludes the integer primary key too; QGIS resolves by name so nothing broke; settled by comparing 99/99 against aliases QGIS itself wrote |
| 2026-09-02 | floodplains#65 | **A guard suite that validates shape can be complete and still never read a value** — eight published values mutated one at a time, PASS on all eight; one had shipped 42x wrong; re-derive each value from the artefact it names |
| 2026-09-01 | stac_floodplains_bc#33 | **A check's detect step and its explain step must use the same predicate** — exact compare to detect, tolerant compare to explain; `'-738.20'` vs `-738.2` entered the block and produced an empty message |
| 2026-09-05 | floodplains#79 | **A cache keyed on fewer inputs than the comparison varies makes an A/B assert a file equals itself** — the plan was to prove a widened request left the shared results unchanged by running it both ways and diffing. `drift`'s `stac_cache_key()` hashes the AOI and request parameters but **not `years`**, and cache files are `<year>_<key>.nc` — so the narrow run's outputs are re-read off disk by the wide one, byte-for-byte, and the assertion is green against any regression whatever. The sibling half is worse because it looks like evidence: the upstream query range was `min(years)..max(years)`, identical for both, so the two runs issued *the same request* and a committed log already showed 14 items returned for a 3-year ask. **Before building an A/B, name the input you are varying and check it reaches the cache key and the wire request** — if it reaches neither, the comparison is a tautology and the honest move is to say the property holds by construction. Distinct from the under-keyed-cache row under "Written data outlives the fix": there the wrong data ships, here the *check* cannot fail |

### A guard's scope, escape hatches, and remedies

Every guard grows the things that silently disable it. An **exemption list** that
covers every input makes the assertion unreachable — and reads as more careful than
the correct version because it is longer. A **lookup** that matches a container rather
than the artifact checks a stranger's copy. A **literal set** used as a filter covers
whatever the data happens to contain today and grows blind as it grows. A guard that
compares against a **vendored witness** is pinned to the copy, not the world. A guard
that reads a **coarser grain** than its property passes on the grain. A **remedy** in
the error message is code the caller will run, and nothing checks it.

Read the escape hatches before the assertion. Enumerate the inputs programmatically
and diff against the declared set. Require a reason on every exemption — one whose
reason says the rule *is* satisfied is an entry to delete. Pin scope against its
source of truth. For every literal a guard rests on, ask whether it is a **contract this
repo chose** — hardcode it, because a derived expectation cannot fire — or a **fact about
a third party's behaviour** — read it from the artifact, because a value reasoned from how
a producer behaves is where the accidental scope comes from. Terminate by enumeration,
not by a reviewer saying you have converged: the class recurs one axis over, and three
"this is now terminal" claims were wrong on one PR.

| date | where | instance |
|---|---|---|
| 2026-08-28 | gq#66 | **A drift guard must cover every input it claims to** — walking all sources then comparing against their *union* passes for an item present in one and absent from another; the tell is a lookup whose key omits the source |
| 2026-08-30 | gq#77 | **A guard's scope is usually a coincidence, and it will not announce itself** — `opaque <- c("esri_world_topo")` pinned to nothing; five instances across four review rounds, two of which would have shipped an opaque satellite raster over every field map |
| 2026-09-04 | stac_floodplains_bc#26 | **A guard written against the whole artifact silently redefines every mode that passes it a subset** — new per-item checks also asserted whole-catalogue set membership, so a documented single-item republish path (`--only`) began refusing every item but the two the set named. Nothing announced it: the release harness shims the validator away, so its own suite could not see it. The line is not "set compare vs the rest" but whether an arm names an id the subset **contains** — six of seven did. Three review rounds each got that partition wrong in one direction, including one that fixed it for an arm and not its mirror; write the partition down beside the guard, because it is what the next person will get wrong |
| 2026-08-30 | gq | **A guard that compares against a vendored copy cannot see the copy go stale** — two of three vendored artifacts had silently drifted; the exemption test compared against `template_groups.csv` rather than the templates, so the issue saying "the suite is red" was itself stale; two remedies, not alternatives — a currency check gated on the source being present (`skip()` in CI, said out loud), and a date or upstream version stamped beside the witness |
| 2026-08-26 | gq#61 | **A guard's escape hatches are where it goes to die — read them first** — a `legend_exempt` list naming all nine drawn layers with reason "drawn and legended"; a `dir.exists("vignettes")` lookup that walked out of the package under `R CMD check` |
| 2026-09-04 | floodplains#73/stac_floodplains_bc#26 | **Comparing a published artifact against its local source cannot tell "already current" from "never regenerated"** — sweeping 20 published STAC items for staleness by diffing each one's published area against the upstream file, two items matched exactly and were labelled *already corrected*. They were the two that had **never been re-run**, so both sides were the same stale July output — the equality was the defect, not the absence of one. The discriminator is regeneration status (here, does `provenance.json` exist), never equality: a comparison whose two sides can share one source is blind exactly where nothing was updated. Byte comparison does not rescue it either — GeoPackages rewritten layer-by-layer differed by one 4096-byte SQLite page with identical content, so checksums answered "same build?" when the question was "same content?"; only a content measure (area) separated the cases, and a 2% tolerance on it then mislabelled a genuinely stale item at 1.5% |
| 2026-09-02 | stac_floodplains_bc#19/#40/#32 | **A guard that reads a copy of its subject, or a coarser grain of it, passes on the copy** — `NEWS.md` on disk vs `git show "$tag:NEWS.md"`; `git describe` picking a note tag; file mtime vs the section's own timestamp; three grains before the property was per-key |
| 2026-09-01 | stac_floodplains_bc#22 | **A new feature can silently invalidate an unrelated flag's stated rationale** — `--skip-sync` justified as "every href resolves"; adding `file:checksum` made that insufficient; grep the bypasses when you add a guarantee |
| 2026-09-02 | ngr#7/#36 | **A fix that reaches one enforcement surface reads as complete on all of them** — five in one issue, each correct in its own dimension and silent in an adjacent one: `^CLAUDE\.md$` in `.Rbuildignore` while pkgdown published `CLAUDE.html` to the public web; a publish gate tested against both answers except under `nullglob`, where the loop runs zero times over an empty site; a CI flag sparing five runners a live API while `R CMD check` then failed on the same vignettes; one property enforced by mechanisms that do not read each other's config, and the fix is *evidence to everyone afterwards that it was handled*; name every mechanism enforcing the property, verify against the artifact each one produces with a positive control, and when two requirements conflict outright find the third option — the R surfaces and their remedies are under `R CMD build` in `code-check-r.md` |
| 2026-09-01 | stac_floodplains_bc#34/#35 | **A literal reasoned from a producer's behaviour, when the artifact answers directly** — three review rounds on one guard, each fix resting on a new reasoned premise: `OVERVIEW_LEVEL=0` selects an overview (GDAL only *warns* on an unknown open option, so a typo opens full resolution and the guard compared a band to itself); width is the dimension that shrinks (a 1×1024 raster's first overview is 1×512, so a 400×4000 raster with overviews stripped returned CLEAN); 512 is the driver's threshold (it is the *default* `BLOCKSIZE`, which the writing script may override, and a correct 600×600 COG at `BLOCKSIZE=1024` blocked the release); the same file already parsed the TIFF tag by hand rather than asking GDAL, and that discipline was not applied to the premises; enumerated, the file's literals were contracts (row counts, property sets), format constants (multihash prefix, tag number) and one third-party default — read that one from `ds.block_shapes`, which has no level above it to be derived from |
| 2026-09-04 | floodplains#77 | **A guard and the ignore rule that blinds it can land in the same commit** — a render check asserted `git status --porcelain` gained nothing, to catch a chunk that plots inline and leaves `README_files/` behind. `.gitignore` listed that exact path five lines away, added by the same change, so porcelain reported **OK** with the directory sitting on disk. Check a named-artifact property **by name**, and pair it with `--ignored` as the complement for whatever nobody thought to name — measured, the two arms catch different things: shortening the name list left arm 2 green while `--ignored` still failed. The escape hatch here was not inherited; it was written by the same author, in the same hour, for a good reason |
| 2026-09-01 | fly#37 | **A guard's error message must not recommend a remedy that walks back through it** — the guard refused non-POINT and suggested `st_cast(x, "POINT")`, which reproduces the original 20→100 row bug; run the remedy for every input a clause can receive |
| 2026-09-01 | stac_dem_bc#34 | **A guard that fires correctly and then points at the wrong fix** — four on one branch: an id-mismatch guard telling the operator to repoint `STAC_BUCKET_URL` at a bucket they already had (the bucket had not moved, only the collection); a deterministic both-keys failure reported as "transient, RE-RUN" when every re-run raises the identical error; a message promising "the run still publishes what it completed" on the path where the exit code discards it. Ask what someone would *do* on reading it, not whether the guard fired |
| 2026-09-05 | stac_floodplains_bc#61 | **A guard that says "this would reach X" must read X's own exclusions, not enumerate the source** — a new arm compared each published item's whole directory against its assets and reported every extra file as one that "would reach the public bucket". The release syncs with `--exclude '.*' --exclude '*/.*' --exclude '*.json' --exclude '*.aux.xml'`, and its own comment records why: macOS drops `.DS_Store` into item directories and GDAL writes PAM sidecars when a read triggers statistics. So the guard would have **refused a release** over a file that provably cannot ship — opening the folder in Finder was enough — while telling the operator to delete something the transport already ignores. The fix is not a hardcoded skip-list but reading the patterns out of the shipper (here `catalogue_release.sh`), the same way a timestamp pin is read from the one file that defines it: a second copy is one fact derived twice and the two part company at the first edit. Assert the parse rather than trusting it — an empty pattern set fails toward refusal (loud), but one containing a bare `*` blesses everything, so reject that by name. **And check what already covers the thing you just sanctioned**: a `.aux.xml` here is still refused, by the guard that names the real defect (the RAT is not embedded) rather than claiming a bucket leak |
| 2026-09-01 | flooded#47 | **Deriving a guard's key is not the fix for hardcoding it — when the key is a judgement, deriving it inverts the guard** — the contract-vs-third-party sentence above, read as "never hardcode", produces the opposite defect, and the wrong version looks careful. A **set** (which layers exist, which columns a schema declares) has a source of truth to derive from; a **judgement** (which column means drainage area, which basemap is opaque) has none, and keying it to whatever a formal or default holds today couples the guard to a value free to move for unrelated reasons. A guard keyed to `formals(fl_stream_rasterize)$field` — commented *"derived from the formal rather than hardcoded, so the two cannot drift"* — inverted completely when only that formal was corrected: false alarm on the right input, silence on the actual defect, a self-contradicting message. The two that must not drift are the guard and *the wrong column*, so key it to the literal `"channel_width"`. And the test does not save you — its premise line reddens, but reads as "the default changed, update the expected name", and that repair leaves the suite green with the guard pointing the wrong way: a failure toward the **wrong fix**, not toward pass (soul PR #136) |
| 2026-09-05 | rtj#293 | **A guard outlives the upstream behaviour it was written against, and its continued refusing reads as correctness** — a refresh driver refused to run whenever the project root held a `.geojson`, then deleted every one after its passes, because an upstream script ran `rm -f *.geojson` there. That script had since been removed upstream and the intermediate moved to a `tempfile()` workdir, so **the only thing deleting those files was the guard's own sibling cleanup** — a matched pair defending nothing. Nothing signals this: a guard that refuses looks exactly as correct on its last day as its first, and here it blocked the work on three of four projects and sent the design toward a keep-list nobody needed. **Five documents asserted the dead premise** — two READMEs, a CLAUDE.md, an ops doc and two code comments — which is the shared-ancestor problem in `karpathy.md` with the guard itself as the loudest witness. Before designing around a constraint a guard encodes, **read the upstream that imposed it**, not the guard or the prose describing it; a one-line `grep` for the script named in the comment ended it. Sibling of the vendored-witness row: there the copy went stale, here the *world* moved and the guard did not |
| 2026-09-06 | rtj#285 | **A guard that returns the offenders and lets the caller build the complement will have the complement built wrong, on the branch that fires** — a `.qml` check correctly scoped to a split-layer directory returned only the offenders; the call site then captioned *every* `.qml` on the server as "elsewhere, untouched by the split" and `basename()`-stripped it, so the one offending file printed indistinguishably from a benign root sidecar precisely when the guard FAILED. The helper was right, and the seven tests written with it all drove the helper in isolation, so restoring the defect left them green. "Write the partition down beside the guard" (the stac_floodplains_bc#26 row above) is not enough when the guard hands back half of it: **return the partition** — `list(bad, other)` — so "the halves are disjoint and together cover everything" becomes a property a test holds rather than a convention the call site has to remember; the three assertions written that way fail on the old composition and the helper-only ones do not. The original scope was itself the coincidence this mechanism names: the check passed only because the single project it had ever run against carried no `.qml` anywhere, while the other three carried 7, 3 and 4 |
| 2026-09-06 | rtj#298 | **A guard against a silent drop must be keyed to the OUTCOME, not to the flag that caused it** — the conjunction of the row above and the rfp#243 row, and it cost three review rounds on one PR. A refresh driver gained `--only=` and `--types=`; `--add=` combined with `--only=` silently dropped the added layer, so a guard was written as `setdiff(add, only)`. It closed `--only` and left `--types` wide open — the types branch zeroes a non-matching type's refresh AND add, so `--add=<aws layer> --types=bcdata` refreshed 29 layers and dropped the requested one without a word (measured live). A per-flag rule has to be re-derived for every narrowing flag, and the third one misses again; `setdiff(add, kept)` — *did what was asked for survive?* — cannot, whatever narrows the run. **And the tests could not see either version.** The one written for it drove the validator directly, which has no type information, so it passed trivially; then deleting the **call site** left all 86 checks green, because every assertion drove the extracted helper. Two things closed that: a structural assertion that the driver still calls its extracted decision (`grepl("check_adds_survived", deparse(plan_refresh))` — weak, but it always runs and catches the deletion that happened), and an end-to-end arm through the driver against a real project, reported as SKIPPED rather than passed when absent. Both end-to-end arms then failed on the *good* file — **including the positive control**, which is what said it was the harness and not the guard: a sourced dependency was missing. With only the negative arm it would have read as the guard being broken |

### A fix lands in one of two callers that share a harness

Two entry points over one library, two workflows over one action, two scripts sourcing
one shell lib. A defect found through one caller gets fixed there, and the sibling
keeps it — silently, because the shared code is fine and nothing compares the callers
to each other. The count is the signal, not the instance: if you have fixed the same
class twice in one of a pair, the pair is the bug.

Fix in the harness where the behaviour belongs to it. Where it genuinely belongs to a
caller, grep the sibling in the same commit, and assert the shared policy is the one
both use rather than trusting an import to have been wired up.

| date | where | instance |
|---|---|---|
| 2026-08-31 / 09-01 | stac_dem_bc#34 | **Five gaps between `item_migrate` and `item_backfill` over one extraction** — `--limit 0` read as "no limit"; a missing clobber guard; no completeness statement at all; a dry-run ordering fix; `get("assets", {})` returning `None` on an explicit null. Two were found by reviewers *after* the third, which is what made the pair rather than the instances the thing to fix. A test asserting `item_backfill.error_tolerable is _tolerable` is what stops the policy silently forking again |

### Restore the bug and prove the guard fires

A test that stays green against the code it was written to reject is decoration, and
reading it will not tell you. Put the defect back, run the test, watch it go red. Pull
the exact prior bytes from git — a hand-rewritten "previous version" is a different
program, more likely to fail than the real defect was, so a green reconstruction proves
nothing and a red one proves almost nothing. And print a value that proves the patch
took: in R, `load_all()` creates two bindings, and patching only `asNamespace()` leaves
test code calling the original. Then run the file with `testthat::test_file()` —
`test_local()` and `devtools::test()` reload the package and discard the patch.

| date | where | instance |
|---|---|---|
| 2026-08 | gq#52; flooded#41; fly#9 | **Restore the bug and confirm the test fails** — three tests in one PR whose input could not reach the assertion; a patched namespace giving a false green until `package:` was patched too; a reconstruction failing 4 tests where the real prior code failed 0 |
| 2026-08-30 | fly#38 | **`local_mocked_bindings(.env = )` is the cleanup environment, not the target** — `.env = asNamespace()` installs correctly and never unwinds; a stub returning TRUE leaked into every later test; the tell was `expect_true(f())` passing while `file.exists(out)` failed; the fix is `local_mocked_bindings(f = stub, .package = "pkg", .env = parent.frame())` — `.package` names the target, `.env` what the mock unwinds with |
| 2026-09-02 | spacehakr#20 | **A stub that never forces its argument leaves the inner call unevaluated** — `x \|> collect()` is `collect(x)`; a stubbed `collect` that never touches `x` means `bcdc_query_geodata` never ran and the spy on it stayed NULL; `force(x)` in the stub |
| — | fly#35 | **Restore-the-bug output is truncated at 10 failures, hiding guards you asked about** — three guards added, the restoration run showed only the first; testthat's reporters stop at 10, and the knobs differ per reporter: `set_max_fails()` sets `TESTTHAT_MAX_FAILS`, which only the progress reporter reads, while `reporter = "summary"` reads `options(testthat.summary.max_reports = )` (measured, testthat 3.3.2 — `set_max_fails(Inf)` left the summary cap at 10); set the one your reporter reads, or read the returned object — `as.data.frame(test_file(f))$failed` carries every failure whatever the console printed |
| 2026-09-01 | trap#2 | **`test_local()` reloads and silently discards the patch** — `testthat::test_local()` and `devtools::test()` call `load_all()`, which rebuilds both bindings after you patched them; four restored bugs read 0/0/0/0 through `test_local()` and 6/1/2/2 through `test_file()`, with the probe value printing correctly both times; run the affected file with `testthat::test_file()` and keep the probe — each catches a different half |
| 2026-09-02 | spacehakr#20 | **A green-but-empty test blamed on `.package =` not reaching `pkg::fn()` — it does** — the diagnosis was that `local_mocked_bindings(.package = "bcdata")` does not intercept a fully-qualified `bcdata::bcdc_query_geodata()` and only `mockery::stub()` does; measured 2026-09-03 on testthat 3.3.2 it intercepts inside `local()`, inside `test_that()`, and when installed before the namespace loads, because `::` resolves through the namespace binding `.package =` patches; the stub that was never reached was the unforced `collect` argument ("A stub that never forces its argument leaves the inner call unevaluated", same PR), and `mockery` "working" did not discriminate; when a mock is installed and not reached, prove the call was evaluated before blaming the mocking tool |
| 2026-09-01 | link#250 | **An assertion with no deadline can only pass or hang — never fail** — `if ( thing_that_might_hang ); then` is only reached when the call returns, so restoring the defect does not turn the test red, it sits there, and the suite reports nothing rather than a failure; wrap it in a deadline (`with_deadline()` in `code-check-shell.md` — `timeout` is GNU-only and absent on stock macOS) and distinguish its 124 from a real non-zero, or a hang is reported as a refusal |
| 2026-09-03 | stac_floodplains_bc#46 | **A restored bug can fire a DIFFERENT guard, and the exit code cannot tell you which** — five mutations of a GeoPackage's style table each exited 1, all read as "the guard fired", and none of them had reached the guard under test: mutating the file changed its bytes, so the checksum check ran first and short-circuited. The proofs only meant anything with the item builder re-run in between so the checksums matched. **Grep the output for the message you expect, never just the status** — a suite with N guards has N ways to exit 1 and only one of them is your evidence. A sixth proof in the same run was false the other way: the mutation was a plain-text replace on serialized XML, and `ElementTree` escapes `>` as `&gt;` in attribute values, so it matched nothing and silently tested the unmodified artifact. Assert the mutation took (`assert q.count(old) == 2`) before trusting what follows it |
| 2026-09-04 | stac_floodplains_bc#26 | **And a restored bug can exit 0, when the proof mutates the wrong copy of a deliberately-duplicated literal** — the mirror of the row above. Where literals are duplicated on purpose (a builder's and a validator's, so the guard is not `x == x`), a proof must mutate **the copy the guard reads**. Adding a bogus id to the builder's set marked no item, so the validator passed — correct behaviour, reported as `WRONG GUARD (rc=0)`. `rc=0` on a restored bug reads as a pass, so it is the direction that gets believed; before concluding the guard is broken, check which copy the assertion actually consults |
| 2026-09-03 | rfp#243 | **A test that drives the helper covers the other VALUE, not the call site that chooses it** — a fix changed which argument a builder passes its helper on one branch; the test added for it called the helper directly with two hardcoded literals, so restoring the defect left 587 assertions green across six files. The commit message and the test comment both claimed it was guarded. Guard the *chooser*: a spy on the helper that records the argument and delegates, asserting what the caller picked — and resolve the real function BEFORE installing the spy, or it records its own delegating call |

### A shared working tree, and what generators leave in it

A working tree has one checked-out branch. Two sessions in it can `git checkout` out
from under each other mid-edit, and uncommitted work then sits on the other session's
branch — a later commit lands it there, a `--delete-branch` strands it. Worse: a
`git push -u origin main` pushes the local ref named `main`, not `HEAD`, so a commit on
the wrong branch prints `Everything up-to-date` and nothing was sent. Generators —
config regenerators, formatters, `csv.writer` rewriting every line's terminator — put
side effects in the tree that `git add -A` sweeps into a commit describing something
else. And running a generator is not committing what it generated: a build in a temp
dir leaves the repo's artifact stale while the author truthfully reports having
verified it.

One worktree per session (`-b <new-branch>`, chained with `&&`). **The tag and release
step needs a worktree too.** Every example here is an edit, so a reader who follows the
rule still runs `git checkout main && git tag` in the shared checkout — which was on
another session's branch with 281 lines of its uncommitted work when it happened
(soul#141, 2026-09-01; nothing broke, by luck). Release from a throwaway tree detached
at `origin/main`, push `HEAD:main` and the tag from there, and leave the shared
checkout's `main` alone; `gh-pr-merge` step 5 carries the form. Assert the branch
before any commit or flip. Stage by path. Generate from the committed tree, never the
checkout — a mid-edit source is internally inconsistent, which is worse than stale.
Verify the artifact after a push, not the push output. **And a dirty peer repo you are
only passing through is someone's in-flight work, not leftovers** — `git pull` reporting
"Already up to date" says nothing about the working tree, and staged edits are invisible
to it. Do not tidy, commit, `git checkout .` or `git add -A` in a repo you came to read.

Recovery, when it has already happened: back up the touched files, confirm the other
branch's changes do not overlap yours, and `git checkout <your-branch>` carries
uncommitted work across. If you committed onto their branch, restore their pointer with
`git branch -f`. If their branch has an open PR, cherry-pick forward through a throwaway
worktree rather than force-pushing into someone else's PR.

| date | where | instance |
|---|---|---|
| 2026-07 / 2026-08 | floodplains; gq#57; rtj | **Two agent sessions must not share one git working tree — give each a worktree** — three collisions in one session including a `--public-clean` scrub that committed onto a parallel session's feature branch; a cross-repo fix landing in someone's open PR; a memory-audit commit reporting `Everything up-to-date` while absent from `origin/main` |
| 2026-08-26 | fly | **Generating from another repo's working tree copies its half-finished edits** — `karpathy.md` gained a section and its pointer was corrected minutes later in a separate commit; the sync landed between them and shipped "see §5" for a rule that had become §6; `git pull` said up to date throughout |
| 2026-08-27 | floodplains | **`git add -A` after a generator sweeps its side effects into your commit** — a "one-line config change" of 6 files, 28 insertions, 50 deletions; the file count was the only warning |
| 2026-09-03 | soul#168 | **A file staged for one commit and set aside rides into the next one** — "stage by path" assumes the index is empty when you start; two files staged for phase 2, then left while phase 3 was written in another file, landed in phase 3's commit with phase 3's message, and the only signal was a file count in `--stat`; before every commit read `git status --short` and expect exactly the paths you mean, and `git restore --staged <path>` anything you set aside |
| 2026-09-04 | stac_floodplains_bc#26 | **A file staged and then EDITED commits the version from before the edit** — the sibling of the row above, on content rather than paths: `git add NEWS.md`, then a correction to the same file, and a plain `git commit` ships the stale copy. Here the staged version carried a release-note figure already known to be wrong; `git status` says `MM` and nothing else does. Caught by a reviewer, not by the author. Read `git status --short` before every commit and treat a second `M` as unfinished, or diff what you are about to ship with `git diff --cached` rather than `git diff` |
| 2026-08-28 | rfp#219 | **Running a generator is not committing what it generated** — four schema CSVs gained a column, the builder ran clean in memory, the shipped GeoPackages were never rebuilt; CI caught it only because a drift guard rebuilds and byte-compares |
| 2026-08-29 | stac_dem_bc | **A writer that rewrites a whole file changes more than the rows you added** — Python `csv.writer` converted an entire CSV to CRLF on a two-row append; 21 insertions, 19 deletions for two rows; open in append mode with an explicit `lineterminator` and diff before staging — staging by path does not help when the churned file is the one you are staging |
| 2026-08-28 | floodplains#44 | **Config round-trips discard everything that is not data** — a "load, change a key, write back" update (`yaml::write_yaml`, `json.dump`, `toml.dump`, some `yq -i`) round-trips the data and silently drops comments, key order, blank lines and equivalent spellings (`null` vs `~`); the file still parses with the right values, so nothing fails, and what is lost is the only record of why a setting is what it is; the first working fix for a runner destroying hand-maintained config then deleted 8 lines of rationale in one `area.yml` and an open question in another — a fix for silent data loss is itself a prime candidate for it; edit only the lines you own (locate the key, rewrite that line keeping its trailing comment, append new keys past the block they must not land inside, refuse rather than mangle a nested block), reserve the full serialize for the create path, and assert it — count comment lines before and after and check `all(before_lines %in% after_lines)`; the region run went from 50 deletions to 2 insertions |
| 2026-09-04 | stac_floodplains_bc#53 | **A committed generated artifact churns on every render unless every id and timestamp generator is pinned — and a `self_contained` renderer may reach the network to make one** — a 5.8 MB `index.html` rewrote itself identically on each build from three sources: `htmlwidgets` container ids, `mapgl`'s `paste0("legend-", as.hexmode(sample(...)))` legend id, and — the one that mattered on its own — pandoc's `--embed-resources` **fetching the shields.io badges at render time**, putting a network call inside a render documented as needing none and varying the output with whatever came back. `htmlwidgets::setWidgetIdSeed()` and `set.seed()` pin the first two; the third is fixed by keeping remote images off the self-contained target. Same class the repo pins `OGR_CURRENT_DATE` and uuid5 for, one toolchain over. **Assert it rather than assuming: render twice and compare digests** — the byte-compare is what found all three, and what will find the fourth |
| 2026-09-01 | — | **The two safe ways to edit a CSV each break the other's case** — `csv.writer` re-quotes every field by its own rules, so editing 2 rows of a 6-row file rewrote all 6 and buried the real change ("A writer that rewrites a whole file changes more than the rows you added" covers the terminator half, not the quoting half); the obvious fix, plain-text replacement inside the field, then put a comma into an unquoted field, every data row gained a column, and `read.csv` silently consumed column 1 as row names; the rule is conditional — plain-text only when the field is already quoted or the inserted text carries no delimiter, `csv.writer` (with `lineterminator='\n'`) only when every data row is being edited anyway; afterwards assert field count per row and the reader's column names, because a column shift produces data that parses |
| 2026-09-05 | stac_orthophoto_bc | **`git checkout -b` in a shared checkout branches off whoever else's branch is out, and drags their uncommitted work with it** — a new branch for issue #6 was cut while the tree sat on a parallel session's `9-…` branch, so it started at *their* baseline commit and inherited eight of their modified/untracked files. Nothing in `checkout -b` says which base it used. The tell came one step later and reads as unrelated: `git checkout main` refused with `Your local changes to the following files would be overwritten` — naming *their* files, in a session that had edited none of them. `git checkout -b x main` pins the base but still carries their working tree; only a worktree separates both. Before branching in a shared checkout, `git branch --show-current` and `git status --short`, and if either is not yours, `git worktree add <path> -b <branch> main` instead. Recovery is cheap **if nothing was committed**: `git checkout <their-branch>` (same SHA, so no file moves) then `git branch -D` yours |
| 2026-08-26 | fly | **Dirty files in a peer repo are another session's work, and tidying them destroys it** — `soul/conventions/` went dirty and clean three times inside ten minutes while another session authored convention text; a well-meant `git add -A` or `git checkout .` from a session that only came to read would have committed or discarded a half-written rule. The worktree rule above covers two sessions *editing* one repo; this is the cheaper read-only case, named in the paragraph above only since this row — leave the tree alone, and if you must know whether it is yours, `git status` and `git diff --cached` before touching anything (soul#116) |

### A wrapper's exit is not the work

A wrapper reports its own exit. `caffeinate`, `time`, `ssh … | tee`, a background
task, a per-item loop, a `;`-chained pair — all routinely surface exit 0 while the
inner job hit `Execution halted`. Merging stderr into stdout corrupts the stdout you
parse, and only on a long line; a `\r` progress bar on stderr makes interleaved log
lines vanish entirely; `system2()` quotes the command and pastes the arguments raw, so
a path with a space silently splits and the empty stdout reads as "nothing to report".

Gate on the artifact: in-band error markers (`grep -c "Execution halted\|Error:"` is 0)
**and** the output's mtime is newer than a marker touched at run start. `set -euo
pipefail`, `&&` between steps of one operation, stderr to a file whose contents you
carry onward (not its path — a temp file is gone by the time the assertion needs it).
Read the exit status, not just the output.

| date | where | instance |
|---|---|---|
| 2026-07 | floodplains | **A wrapper's exit 0 is not "the work completed" — gate on in-band error + output mtime** — a Pass-2 change declared "12.4×, byte-identical" and merged; the run had halted before writing, so the A/B compared the unchanged baseline against its own backup |
| — | — | **pipefail with ssh+tee** — `ssh … \| tee log` returns tee's exit; remote work skipped, notification said completed |
| 2026-09-05 | floodplains#79 | **A `\|\| fallback` after a pipe is unreachable, so an absence probe prints nothing and reads as "checked"** — the sibling consequence of the row above, and worse because there is no wrong output to notice. `ls .github/workflows/*.yml 2>/dev/null \| sed 's/^/  /' \|\| echo "none — CI is n/a"` takes its exit from `sed`, which succeeds on empty input, so the `echo` never runs: the step emitted **nothing at all** and was one glance from being recorded as "no CI, nothing to watch" on a merge that had in fact dispatched a run. The tell is a branch that is supposed to *always* print something printing nothing. Test the command, then format: `if ls … >/dev/null 2>&1; then …; else …; fi`, or assign first and branch on the value. Same fix as the guard rows above — assign, test the status, then test the value — but the shape hides here because the `\|\|` looks like the guard rather than the thing that needs one |
| 2026-08 | — | **Never silence stderr on a mutating command, and never chain one with `;`** — `git mv … 2>/dev/null; mv …` succeeded doing the wrong thing and the failure surfaced one command later as "cannot stat" |
| 2026-08-29 | stac_dem_bc | **A progress bar on stderr silently eats your log lines** — per-item `logger.warning` beside tqdm; failing ids unrecoverable from the log locally and in CI |
| 2026-08-30 | rfp#227 | **Merging stderr into stdout corrupts the stdout you are parsing** — a 145-field JSON line with `QObject::killTimer` spliced into it after a year of working on 20-field payloads; and the fix's temp file was unlinked before the assertion that needed it |
| 2026-08-29 / 08-31 | gq#64, gq#76 | **`system2()` shell-quotes the command but not the arguments** — `git -C "/some path"` split, empty stdout read as "not a git checkout", every later check skipped; and it *raises* on a missing command, so a skip written after the call is unreachable; `shQuote()` every path argument and read `attr(out, "status")` |

### Zero-length, empty, and unset are three different things

`paste0(character(0), "x")` is `"x"` — one phantom row from an empty frame. A
zero-length value in a row-builder yields zero rows, so the whole group vanishes from
a `map_dfr()` and the output looks correct, just shorter. `x == character(0)` is
`logical(0)`, so every branch is false and the fallback runs — usually *create*,
producing an unnamed object rather than an error. `VAR="${A:-}"` sets the empty
string, which passes a presence test (`"PROJ_LIB" in os.environ`) that `unset` fails.
`names(character(0))` is NULL, which `expect_setequal()` refuses — so the guard breaks
the day you finally earn the empty state.

Guard the empty frame explicitly (`if (!nrow(x)) return(character(0))`). Fold to a
scalar at the boundary (`sum()` over `st_area()`). Test the argument, not the search
result. Build commands as arrays and add an assignment only when there is a value. Use
`stats::setNames(character(0), character(0))` and say why.

| date | where | instance |
|---|---|---|
| 2026-08-24 | trap#14 | **`paste0()` treats a zero-length argument as `""`** — an empty annotation table produced one composite key, reported as "an annotation matching no session" |
| 2026-08-28 | fly#30 | **A zero-length value in a row-builder drops the whole record, group and all** — a coverage table silently omitted a photo-year whose frames all had unresolvable footprints |
| 2026-08-28 | rfp#213 | **A zero-length value in a comparison makes every branch false and silently picks the fallback** — two exported writers documented `group = NULL` as "root" and "registry default"; both created an unnamed group at the end of the tree where everything draws under the basemaps |
| 2026-07-31 | rfp#93 | **Empty is not unset — `VAR=` passes a presence check that `unset` fails** — `PROJ_LIB=` made rasterio call `set_proj_data_search_path("")` and fail with "Cannot find proj.db"; read as a missing dependency; and never write `[ -n "$X" ] && arr=(…)` as a bare top-level list — under `set -e` a false test aborts the script; use an explicit `if` |
| 2026-08 | gq | **`expect_setequal()` refuses NULL, and `names(character(0))` is NULL** — the "every exemption still needed" assertion errors at the exact moment the list is correctly emptied |
| 2026-09-05 | floodplains#79 | **`is.null()` cannot tell a key that is absent from a key that is present and empty, and both skip the guard** — a config flag guarded by `if (!is.null(cfg$x) && <malformed>) stop(...)`. `x:` with no value, `x: ~` and `x: null` all parse to `NULL`, so the guard short-circuits and `isTRUE(NULL)` is FALSE: the area ran the default while its committed config *read* as opted-in, silently. Measured on all three spellings. The three states are absent / present-empty / present-valued, and the predicate collapsed the first two — the same shape as "Empty is not unset" above, one layer up in the config parser. `"x" %in% names(cfg)` discriminates (TRUE for present-empty), which keeps an explicit `x: false` legal. The tell: a guard written to catch a *wrong* value, on a key whose *absence* is also meaningful — ask what the parser returns for the empty spelling before trusting the null check |

### The probe is broken before the world is

When an ad-hoc probe reports that long-shipped code is broken, the prior belongs on
the probe. The tell is an obviously-correct item in the failure list: a probe reporting
13 things missing, one of which you can see with your own eyes, is wrong about all 13.
A 100% failure rate on shipped code is as implausible as 50%. A 200 with a perfect
schema can still be a placeholder image or a "trial expired" page — every cheap
assertion passes because the shape is right and only the meaning is wrong. And
constructing a sibling path from a known-good one assumes a uniform naming convention;
the 404 then reads as "does not exist" rather than "I guessed wrong".

Print a positive control. Reconcile the count against the population. Enumerate the
container rather than construct the path. Inspect the bytes you are acting on, never a
formatted rendering of them. When a claim is flagged as under-evidenced, narrow it —
widening adds a quantifier over a population you have not enumerated, and on one memo
every widening broke and every narrowing held.

| date | where | instance |
|---|---|---|
| 2026-08-29 / 09-01 | rfp#216, rfp#242 | **A probe reporting a defect in long-shipped code is usually a broken probe** — 13 theme groups "dangling" because the path walk anchored at the unnamed root; 0 of 25 when anchored right; and 13 of 13 "mismatches" from `identical(length(x), 1)` — integer vs double |
| 2026-08 | gq#57 | **A valid response is not a correct one — services fail in the shape of success** — Carto went key-only and served an "API KEY REQUIRED" watermark through a vignette, `R CMD check`, and a pkgdown deploy; the watermarked tile had *fewer* dark pixels than the clean one, so the measured detector could not separate them — measure before shipping one; prefer providers that cannot enter the degraded state (keyless, pinned), detect only the separable degenerate cases, canary on a human's machine not CI, and warn rather than discard |
| 2026-08-27 | BC LidarBC | **List the container; do not construct the sibling path** — swapping `/dem/` for `/dsm/` 404'd on 2017 tiles (suffixed `_dsm.tif`); "no surface model" became a project's central constraint for weeks; listing showed DSM in 25 of 38 |
| 2026-08-27 | rtj#221 | **Do not build an exact-match edit from a formatted display** — `sed 's/^/  /'` padded the read; the replace matched nothing; two failed rounds before `repr()` showed two spaces where the display implied four |
| 2026-09-01 | flooded#52 | **A claim flagged as under-evidenced gets repaired by widening, and widening is what breaks** — six review rounds, 36 findings; every fix added a quantifier over a ragged dataset×resolution×lineage grid; terminated by reproducing the old behaviour to the digit and measuring every row |
| 2026-09-03 | rtj#243 | **A defect rate is a claim about the population filter first, and the subject second** — a photo-reference audit reported 142 of 290 references (49%) dangling on the server, which flipped a design conclusion and was one command from being written into another repo's issue as fact. The filter for the *reference* side was right; the filter for the *server* side required the path to contain a `photos/` directory, so every image stored elsewhere was invisible and counted as missing. Re-run on all image extensions, case-insensitive: **6 of 290, 2%** — and those six reconciled exactly to an already-filed issue about bare filenames. A 49% failure rate in a shipped project was the tell, and the reconciliation that catches it is cheap: **count both sides of a ratio with independently-justified filters, and re-run the denominator's filter one notch looser before believing a rate**. Sibling of the positive control above — here the control is a *second, more lenient* population, not a known-good item |
| 2026-09-05 | rfp#275 | **A differential baseline stops being one the moment the parent moves** — a branch suite was compared against a baseline measured earlier the same session, at a commit that had since stopped being the branch point: another session shipped a release into `main` in between. The comparison still *ran*, still produced two numbers, and would have attributed six failures on a parent that no longer existed. Re-run at the real branch point the counts moved 4409 → 4711 on the baseline side alone. **A baseline is only valid against `git merge-base HEAD origin/main`**, so in a shared checkout re-derive it at push time rather than reusing the one taken at branch time — and note the failure direction: the stale baseline was *lower*, which flatters the branch. Sibling of "a measurement carries the time it was taken", where what expired is the reference rather than the reading |
| 2026-09-06 | rfp#282 | **An instrument that is not stable within one version cannot speak to the difference between two — and it reads as a regression or as equivalence with equal confidence.** Smoke-testing two container versions before pinning one, the written style differed on a colour and read as a version regression; the same image run twice differed identically, because the renderer mints a symbol with a random colour. Then the *other* script's PNG came out byte-identical across the two versions and that was written into the findings file as the gate's evidence — also luck, since two runs at one image are not byte-identical either. **Both directions in one session**, on one gate. Re-measured on painted-pixel count, which is stable within a version: 7779 across three runs at each. The discriminating test is one command and precedes every A/B: **run the same image twice before comparing two of them.** Distinct from the stale-baseline row above — there the reference expired, here the *ruler* is noisy — and from a proxy, which is stable but measures the wrong thing. The tell is a difference you cannot explain mechanically, or an agreement too clean for something with a random component in it |
| 2026-09-04 | rtj#282/#283/#284 | **And the filter can be right while the *predicate* is wrong** — the refinement of the row above, met three times in one session on one number. A photo manifest reported 142 of 290 present; the count then moved to 35, to 11, to **0 genuinely lost**, and no step was an arithmetic error. First the resolver named three directories photos were known to live in and the project also had a fourth. Then the denominator included **form-template placeholders** — six dummy filenames on a worked-example record, which is why three different projects reported *exactly six* missing, a tell sitting in my own summary table unexamined. Then the predicate itself: `exists in the project directory` was standing in for *is this photo safe*, while photos are **deliberately moved off** to control project size — so the check penalised the housekeeping it should encourage, on the gate that precedes destroying a generation. **Ask what the predicate is a proxy for before trusting the rate**, and when several independent subjects report an identical count, that equality is the finding. Each correction came from workflow knowledge no amount of re-measuring would have supplied — so when a rate survives one correction, ask who else knows what the number means |
| 2026-09-05 | rfp#268/#271 | **When you cannot list, read the PRODUCER — "unlistable" is not "unknowable"** — a bucket answered `403 AccessDenied` to a list (correct for a `s3:GetObject`-only policy), so the artifact was reported as unconfirmable and a shipped feature was documented as blocked on it, with a follow-up issue filed saying so. The job that writes the object recorded the exact key in its own source; one `HEAD` on it returned **200, 66,635,819 bytes, staged the previous day**. The reasoning was "guessing a key is the construct-the-sibling-path antipattern" — true of a key *derived from a pattern*, and the opposite of true for one *read from the code that writes it*, which is that rule's own remedy. **Before concluding an artifact's presence is unknowable, grep the producer for the path it writes**; and treat a self-filed "blocked on X" as a claim to check rather than a conclusion, since nothing downstream will ever re-test it |
| 2026-09-04 | rfp | **An error naming its own remedy, mapped onto a remembered failure instead of read** — a memory note said `op read` "times out on authorization"; the actual error was `couldn't connect to the 1Password desktop app… update to the latest version and restart the app`, and the app was running with `--just-updated --should-restart`. Not a timeout, not an authorization problem, and the fix was in the text. Cost: the *preferred* documented route was abandoned for the last-rank fallback, the user was escalated to, and then the credential's **name** was doubted — it had been right all along. Two tells, both cheap: the error prescribed an action nobody took, and the remembered failure mode had a different **shape** (a hang) than the one observed (an immediate error). **Read the error's own words before matching it to a prior**, and when a convention ranks routes, confirm the preferred route's prerequisite is genuinely absent rather than merely erroring once |
| 2026-09-03 | drift#48 | **A sibling guard that passes is only a control if it was pinned before the event** — two frozen cache-key goldens, one red and one green, and the green one was read as evidence that the shared inputs were fine. It was not: it had been **re-pinned after** the environment moved, so it could only ever agree. Recomputing its *contemporaneous* predecessor showed that value had moved too, which flipped the diagnosis from "one key's inputs changed" to "the hash function changed under all of them" and changed the fix entirely. The filed issue had reasoned from the green tick and named the wrong cause. **Before treating a passing sibling as a control, date its pin against the event** — a guard re-pinned afterwards is a photograph of the new world, not a witness to the old one. Same family as the vendored-witness rule below, arriving through a re-pin rather than a stale copy |
| 2026-09-04 | knowledge#4 | **A per-project config file can shadow the user-level one entirely, so the value you read is not the value that loads** — a repo-root `.Renviron` holding one line made R skip `~/.Renviron` completely, and every `PG_*`, `AWS_*` and `GITHUB_PAT` came back empty for any R process started in that repo. The symptom accused the world: `invalid integer value "NA" for connection option "port"`, which reads as a broken database config. `grep` on `~/.Renviron` showed the variable set, so the file was believed and the code doubted. **The positive control is the same command from a different working directory** — `PGPORT` was `5432` from `~` and empty from the repo, which localises it in one step. R, direnv, npm, git and ssh all resolve config by a search order in which a nearer file wins, and several stop at the first hit rather than merging. Ask *which* file actually loaded before trusting any variable's absence, and note the redundant-shadow shape: the offending file duplicated a value already set in `.Rprofile`, so it added nothing and hid everything |
| 2026-09-05 | floodplains#83 | **A comparison whose two sides differ in something other than the treatment indicts the wrong thing** — `gdal_edit.py -unsetmd` was measured destroying a raster's band category names, rejected for it, and that verdict written into a commit message and a script header. It does not: the test had copied the `.tif` **without** its `.aux.xml` and compared it against an original that had one, so the categories were never present to lose. The tell is the one this mechanism already names — a long-shipped tool reported broken — but the fix is upstream of "print a positive control": **enumerate what differs between the two sides before attributing the difference to the treatment.** A copy is a treatment. So is a different directory, a fresh sidecar, a warm cache. Cheap discipline: state the intended single variable out loud, then list every other way the two sides were produced |
| 2026-09 | rfp | **Write the numbers last, against the final tree** — a figure written into prose mid-change is measured against a tree that no longer exists by the time the prose ships, and the second actor is usually *you*, one commit later: *"I had even reordered the phases to write prose against the final state — and then changed the state again."* The time-stamping rule in `karpathy.md` §7 warns about measurements staled by an earlier session; this is one staled by your own later work inside a session. When a fix lands after the prose, re-measure rather than assuming the prose still holds (soul#176) |

### Written data outlives the fix

Changing the writer changes nothing already written. The code is correct, the tests
pass, the issue closes — and every existing record keeps the defect, sometimes
self-perpetuating when a job reads the published artifact back and rewrites it. A
change-detection cache persisted at detection time strands every input whose
processing then fails, invisibly, forever. A cache keyed by fewer inputs than the
write depends on returns plausible wrong data. Tightening a consumer's assertion
breaks every producer that legitimately left the field empty, and the producer that
bites is the install script nobody thinks of as one. Teaching a build step to record
provenance makes it safety-critical: a wrong SHA satisfies every guard built to catch
its absence.

Reconcile existing records — rewrite in place, do not rebuild through today's code
path. Write caches last, or atomically with the output. Over-key, never under-key, and
hash resolved values. Grep the producers before tightening the consumer, and move the
check as early as the fact is knowable. Gate a provenance write on the build's own
exit status; pin only what has no other identity; resolve an identifier once per run.

| date | where | instance |
|---|---|---|
| 2026-08-31 | stac_dem_bc#34 | **A progress manifest is a claim about a step that may not have run** — `run_rewrite` appends on the LOCAL write; CI's cache commit is `always()`; the sync is skipped on failure. So a failed run persisted a ledger asserting items were published that never reached S3, and `todo = published - manifest` skipped them forever with the completeness check and the audit both passing. Ask what an entry *claims* and whether the thing it claims actually happened — where that depends on a later step, gate the persistence on that step, not on the one that produced it |
| 2026-08-29 | stac_dem_bc | **A fix to code that writes data is not done until the written data is reconciled** — four instances in one day; 90 published items kept hrefs that could not form an HTTP request, and the monthly job wrote them back out every run |
| 2026-02 | stac_dem_bc | **A cache written before the work succeeds strands its inputs permanently** — 2,107 URLs marked seen and never built; found only by diffing the cache against outputs |
| — | drift#25 | **Cache keys must cover every output-affecting input** — rasters cached as `<source>/<year>.nc` with no AOI in the key; a second watershed received the first's raster masked to its extent, ~3% overlap looking plausible enough to almost ship; hash *resolved* values, sf geometry as WKB (`st_as_binary(…, endian = "little")`) with the CRS as a separate key member, `as.numeric()` first because `10L` and `10` hash differently, and canonicalize the geometry before serializing it (ring order and orientation are not fixed by topology — `code-check-spatial.md`) — and check the `force` escape hatch actually overwrites: drift#25's `force = TRUE` errored on the existing file, so prefer the writer's `overwrite = TRUE` over a bare `unlink()` |
| 2026-09-01 | link#264 | **Making an optional field mandatory breaks every producer that legitimately left it empty** — four producers, three fine, the fourth `update_hosts.sh` installing from a tarball with no `Remote*` fields; the rejection landed after cloud instances were paid for |
| 2026-09-01 | link | **Teaching a build or install step to record provenance is a change to a safety-critical path** — `R CMD INSTALL \| tail -3` wrote the pin for a build that failed; an env pin beat a checkout's own git state; nothing expired it; five findings inside one ~40-line fix |
| 2026-09-05 | drift#62 | **A fix to a derived number does not reach the artifacts that already quoted it, and the ones outside the repo are the ones nobody re-reads** — a review replaced `100 / pct_sustained` (dividing an already-rounded share) with `changed_ha / sustained_ha`, and the generator was re-run, so every committed CSV and the note moved. Two GitHub issue bodies filed an hour earlier under a heading naming that same CSV kept the pre-fix cells, and the note asserted they carried the numbers. Nothing in the repo can see them: they are prose, in another system, and the tables *looked* current because three of four cells were unchanged. Same mechanism as a published record surviving a writer fix, arriving as **published prose** rather than as data — and worse, because a tracker body is what the next person plans from. Two habits: **when a derived value changes, enumerate every artifact that quotes it** — repo prose, release notes, PR descriptions, issue bodies in every repo you filed into — and **verify a filed body against the artifact it names by parsing it**, not by reading it, since `5.08` against `5.09` survives any number of careful re-reads |
| 2026-08 | gq#57 | **An inventory is only complete relative to a boundary — name the boundary** — 9 lines in 6 files, verified twice, complete for gq; consumers read `soul/skills/cartography`, which shipped its own snippet naming the broken provider |
| 2026-08-31 | flooded; flooded#49 | **A defect's magnitude is dataset-specific — measure it where it lands** — a 3.59x depth error measured as ~2x area on the 10 m fixture and 16% on the 30 m production watershed; percent-of-AOI moved 27.51 → 27.50 — but a ratio is stable only when its denominator is inside the affected region too: floodplain-as-percent-of-watershed fell 8.67 → 7.35 on the same defect, the same ~15% as the hectares, because the watershed does not shrink, and three report appendices publishing that ratio beside the absolute needed both numbers restated; ask what is in the denominator before calling a proportional claim safe |

### Serialization loses meaning silently

A serializer's default for "no value" is rarely a null: `NA_real_` becomes the string
`"NA"`, R `NULL` becomes `{}`, GDAL has no null and `str(None)` writes `'None'` — each
a valid value every schema check accepts, and `{}` passes `is not None` on the far
side. A rename emits two signals — an expected key missing, an unrecognised sibling
present — and reading only the first cannot distinguish rename from absence; the
ambiguity is different at each depth, so it recurs one level out. A system that both
records and renders drifts: the sidecar computed `finish(start(x))` on one line and
reported 0.0 s for a multi-minute build. A structure transcribed from an external form
is a snapshot: the 2026 permit portal swapped Easting and Northing columns. In-place
metadata writes move a COG's IFD to the end — still valid, still hash-verifiable, no
longer cloud-optimized. Raw XML/JSON diffs report attribute order as drift.

Set `na=` and `null=` explicitly and say why; build records with `list()`, never
`[[<-`. Reject unknown keys where the set is closed, pin the key shape where keys are
data. Prefer the record over the rendering. Assert on magnitude or format, not
position. Order the layout-aware writer last, and assert the property (`cog_validate`),
not the parse. Canonicalize before diffing, and name every field you mask.

| date | where | instance |
|---|---|---|
| 2026-09-01 / 09-02 | stac_floodplains_bc#17, #36 | **A serializer's default for "no value" is rarely a null, and every wrong answer is silent** — three defaults wrong in one afternoon; a colon in a GDAL tag key collapsed eleven fields into one; and the serving API omitted the published nulls the store kept |
| — | cred#23/#25 | **jsonlite serializes NA numerics as the string `"NA"`, not `null`** — and only the numeric types: `NA_character_` and logical `NA` become `null` correctly (jsonlite 2.0.0), so a record with a failed count carries `"documents": "NA"` beside integers and round-trips unchanged forever; `na = "null"` on every `toJSON()`/`write_json()` that can receive one, and identical flags on any preview path, or the preview is not what gets written |
| 2026-09-01 | stac_floodplains_bc#17 | **A rename emits two signals, and reading only one cannot distinguish it from absence** — leaf, section, root: three review rounds, the same defect at three depths; `{"algorithm": "sha256"}` published `"sha256"` as the value |
| 2026-09-01 | link / floodplains | **When a system both records and renders, the rendered copy drifts into fiction** — `aquatic_network.stamp.md` said 0.0 s elapsed for a 4,877-segment build whose run log put the four groups at 1.04–4.12 min; the sidecar was a candidate STAC field |
| 2026-08 | template_permit_fish | **A structure transcribed from an external form or API is a snapshot, not a contract** — `UTM Zone \| Northing \| Easting` became `\| Easting \| Northing`; four of five sites transposed on a submitted permit application |
| 2026-08 | rfp#17 | **Canonicalize serialized documents before diffing them** — raw compare said 5 of 43 layers matched, arguing for an architecture change; canonicalized with uuids masked it was 46 of 47 |
| 2026-09-01 | stac_floodplains_bc#33 | **An in-place metadata write can break a format's layout contract, and nothing will say so** — every COG in a published catalogue had its main IFD at 98.9–99.6% of the file; checksums verified; `IGNORE_COG_LAYOUT_BREAK` read as boilerplate |

### One fact derived twice

A count taken from one artifact and the things counted produced from another, with a
guard comparing the two. It fires on healthy input, and because it looks like
diligence the fix goes onto the inputs rather than the comparison — so it comes back.
Line tools disagree with each other and with the truth: `wc -l` misses an unterminated
last line, `grep -c ''` exits 1 on an empty file under `set -e`, and both count lines
rather than records. A paged API's default page is a well-formed 200 whose missing
items read as *absent from the server* rather than *not requested*, and it survives
review because the fixture was smaller than the page.

Derive the expectation from the artifact the consumer actually consumes. For each
guard, name the producer of each side; if they differ, it can fire on good input.
Count records by parsing, not with a line tool. Set the page size explicitly on every
request treated as evidence, and assert it at a size larger than any plausible default.

| date | where | instance |
|---|---|---|
| 2026-08-30 | stac_dem_bc | **One fact derived twice, never reconciled** — three times in one change: 600 ids vs a page of 10; a duplicate counted twice, fetched once; one id → two hrefs counted once, fetched twice; eight of nine counts were structural and every bug landed on the ninth |
| — / 2026-07-30 | — / mdb-export | **Counting lines: `wc -l` and `grep -c` fail in opposite directions** — `grep -c` returned 1 for 102,460 single-line JSON records; `wc -l` reported 556 lines for 517 records with embedded newlines, and the number reached a README; use a `count_lines()` helper (`grep -c ''` with `\|\| n=0`) checked against all four inputs — empty, unterminated, terminated, missing — and parse records inside a structured file rather than counting lines |
| 2026-08-30 / 08-31 | stac_dem_bc; STAC catalogue | **A paginated API's default page size silently truncates a lookup used as a check** · **A paged API's default `limit` reads as absence** — `POST /search` with 600 ids returned 10; `limit=200` reported two of sixteen surveys absent; paging returned 230 with every one present |
| 2026-09-03 | rtj#259/#260 | **The set you compare against, derived from the artifact under test** — an acceptance script asserted a GeoPackage held only its form's own tables, and built "its own tables" from `st_layers()` on the *deployed* file. That listing includes the foreign table the check was hunting, so `setdiff()` came back empty and it passed on exactly the file it existed to flag; a fixture carrying `layer_styles` reported 0 failures until the set came from the *shipped* artifact instead. Not caught by four review rounds — found by running the check against a deliberately-bad fixture. **For a guard of the form "X contains only the expected set", the expected set must come from a producer the subject cannot influence**, and the same iteration must then walk the expected set rather than the subject's, or a *missing* member is invisible too |
| 2026-09-06 | drift#67 | **One column NAME carrying different populations across files is the same defect as one fact derived twice, and it is harder to see because nothing is duplicated** — five review rounds on one script, each finding the next instance *inside* the previous round's fix. At its worst `area_ha` carried three populations across four CSVs (unclipped patch / clipped published row / evaluated-area), `n_patches` counted published rows in two files and vectorized patches in two others, and one weighted mean was published under a single name with two different weights. Each was locally correct; the reader combining two tables is the one who is wrong. Two habits: **compute the measurand, its weight and any stratum threshold on ONE population**, and where a boundary case is excluded from one table and included in another, publish the reconciling count rather than the difference. Terminate by **enumerating every derived column with its population and its precision** and showing none disagrees with its name — a quiet review round cannot close this class, because the columns are individually right |
| 2026-09-04 | floodplains#77 | **A fix that derives one literal introduces another whose other half lives in a file the code never opens** — the mechanism behind four review rounds (7, 4, 7, 9 findings). Each round replaced a hardcoded value with one read from an artifact, added a new literal beside it, and wrote a *comment asserting the agreement* instead of a line checking it. Three of those comments were measurably false: `BYPRODUCTS` claimed to be `.gitignore`'s list and was missing two entries; a figure caption claimed to describe `config/disturbance.yml` while the cause list stayed hardcoded; and `nzchar()` claimed to filter empty cells it could not reach. **Terminate by partitioning every literal**, not by another round: a **contract this repo chose** must be hardcoded or the guard can never fail, and a **fact about another artifact** must be read from it or `stop()` on divergence — the two genuinely unavoidable ones carry a source-and-date stamp naming the file that makes them true. And enumerate *mechanically*: a curated list of 22 missed 7, all on one axis — literals inside strings that get **printed** (titles, captions, `fig.alt`) rather than inside values that get used, which is where a wrong caption hides because nothing consumes it |

## Rules that stand alone

General, and not an instance of a mechanism above.

### Do not edit files a long test run is reading

- `devtools::test()` (and most runners) load each test file **when they reach
  it**, not at launch. A 30-minute run therefore reads whatever is on disk at
  that moment, so edits made while it runs are half-applied and the result
  describes a tree that never existed.
- The tell is a **changing pass count** across runs of "the same" tree —
  3490, then 3496, then 3500. A moving denominator means the input was moving.
- Cost 2026-08 in rfp#178: two full Docker suites (~1 hour) both reported
  `FAIL 1`, and the failure was a test written *during* the run, executing
  against source from *before* the fix that made it pass. It was nearly reported
  as a regression.
- **Commit before a long run.** While it runs, do work that touches nothing it
  reads — issue bodies, PR text, planning. And when a long run fails, get the
  `file:line` before forming any theory: a mid-flight edit and a real regression
  look identical in a summary line.

### Adopting Existing Config

When importing config from one location into a canonical one (legacy `~/.bash_profile` → dotfiles repo, old script's env → repo, another project's `settings.json` → soul):

- **Verify every referenced path/binary exists.** Dead PATH exports, missing interpreters, stale env vars should be cut, not codified.
  Shell paths: `for p in $(echo "$PATH" | tr ':' ' '); do [ -d "$p" ] || echo "DEAD: $p"; done`
- **Ask before dropping a reference** — it may be something the user forgot to reinstall on this machine, not something to delete.
- **Curated subset, not verbatim copy.** The diff should reflect what you verified, not the whole source.

### Test the cold/create path of idempotent code, not just the warm no-op
- Idempotent provisioning code (a resolver-file writer, a config installer, a "create unless present" block) has two paths: the **cold** path that actually creates/writes, and the **warm** path that detects "already present" and skips. They exercise almost-disjoint code.
- Testing only on a host where the artifact already exists hits **only the warm no-op** — which cannot catch any cold-path bug: missing-directory, a derivation that returns empty, a pipefail abort before the write, wrong permissions, a flush that never runs. The warm path's job is literally to do nothing, so a green warm test proves almost nothing about onboarding.
- Every fresh host runs the **cold** path — that's the one onboarding depends on. Test it deliberately: back up + remove the artifact, run cold, assert it was created correctly, then re-run to confirm the warm no-op. (Caught 2026-06-23 on rtj#75: the resolver-writer's first test plan only ran the warm path on a host that already had `/etc/resolver/<suffix>`; a Plan-agent review flagged that the cold path — the one every new host takes — was untested. Fixed by `sudo rm`-ing the file and running cold before close.)
- Generalizes beyond shell: any "ensure X exists / converge to desired state" operation — Terraform resources, migrations, package installs — wants the from-absent path tested, not just the already-converged re-run.
- **The warm path is not always the trivial one.** "The warm path's job is literally to do nothing" holds for a provisioning check and inverts for anything that *compares before deciding* — a signature check, a schema diff, a content hash. There the warm path runs the most code and the cold path is the one that skips. A suite whose fixtures always build into a fresh `withr::local_tempdir()` only ever runs cold, stays green, and the comparison it never reaches can be outright broken. Caught 2026-08-28 in rfp#207: the signature built its geometry names with `paste0("gpkg_geometry_columns.", character(0))`, which is length one, so `setNames()` errored on a child table with no geometry row — but only against an existing file, so `devtools::test()` passed and `build_forms.R`, the one caller rebuilding in place, failed. When the code compares rather than converges, add a rebuild-in-place test.

### Do not write to an artifact a human is testing on

- Handing someone a deployed thing to test — a synced project, a staging
  database, a preview build — and then continuing to push changes into it makes
  two writers for one artifact. The tester chases versions, and any client-side
  lock or "another process is running" error that follows is **yours**, not
  theirs to debug.
- It also corrupts the evidence. When the tester reports a problem, you no longer
  know which version they were on, so a symptom cannot be tied to a change.
- Caught 2026-08-26 in rfp#186/#196: three pushes into a live Mergin project
  during a field test, taking it from v1 to v9 while the phone was syncing. The
  app reported "another process is running" and the tester tried removing and
  re-adding the project before the cause was identified as the other writer.
- Rule: **hand over one version and stop.** If a fix is needed mid-test, say so
  and let the tester decide when to take it. Batch changes rather than pushing
  each one. When you must push, say which version you pushed and what changed, so
  a later report can be anchored to it.

### Percent-encode a URL at construction, not at consumption

- A URL built by string-concatenation from filenames inherits whatever those
  filenames contain. An unencoded space is accepted by lenient clients — browsers,
  `aws-cli` — and rejected by strict ones, so the break is deferred and then
  arrives all at once.
- Caught 2026-07 in stac_dem_bc#25: hrefs carrying literal spaces worked for
  months, then every strict `curl` fetch failed together — 90 items, 0-byte
  fetches. Nothing changed about the hrefs; the consumer changed.
- Encode where the URL is **built**. Encoding at the point of use means every
  future consumer has to remember, and the one that forgets is the one you find
  out about in production.

### A preview flag is only safe if it previews

- `--dry-run`, `DRY=1`, `--plan` conventionally mean "show me what would happen".
  **Nothing enforces that.** A flag that skips the *expensive* step while still
  performing the *destructive* one is worse than no flag, because it is exactly
  what people reach for when they are unsure.
- Symptom: you run the preview to check something unrelated, and `git status`
  afterwards shows deletions you never asked for.
- Caught 2026-08-27 in floodplains#44: `run_region.R` prints
  `[DRY] plan + configs written; no pipeline runs` — it skips the pipeline, not
  the config write. A `DRY=1` run to verify an unrelated one-line change deleted a
  watershed group's second-species scenario rows, every literature citation in two
  `flood_scenarios.csv` files, and a `break_points.csv`. 50 deletions from a
  command documented as "plan only".
- Before trusting one, read what it actually gates. If you own it, make the flag
  return **before the first write**, not before the first slow call.
- Cheap audit either way: run `git status` immediately after a dry run.

### Bare `y`, `n`, `on`, `off`, `yes`, `no` are booleans in YAML 1.1
- The YAML 1.1 core schema resolves `y`, `Y`, `n`, `N`, `yes`, `no`, `on`, `off`, `true`, `false` (and their case variants) to **booleans**. Most parsers in wide use — libyaml, PyYAML, R's `yaml` — still do this.
- So a column, key, or field literally named `y` stops being a string the moment it is written unquoted:
  ```yaml
  cols:
    - name: y        # parses as logical TRUE, not "y"
  ```
  Nothing errors. The consumer simply never matches that entry again, and whatever it was supposed to do to it silently does not happen.
- Bites hardest in **schema and config files**, where single-letter names are normal: coordinate columns (`x`, `y`, `z`), flags, short codes. Quote them: `- name: "y"`.
- Caught twice in one file 2026-08-24 (crate#9) — once in a canonical column list and once in a variant's column list. Both found by a guard that asserted every declared name `is.character()`; reading the YAML had not found either.
- Worth an assertion rather than vigilance: after parsing any config that carries user-chosen names, check they are all strings. The failure is invisible otherwise, because the wrong value is a perfectly valid one.

### Documentation Staleness
- Moving/renaming scripts: update CLAUDE.md, READMEs, usage comments
- New variables: update .tfvars.example
- New workflows: update relevant README

### An ordered dispatch makes severity ordering load-bearing, and nothing enforces it

A `CASE`, an `if/elif` chain, or any first-match dispatch that reports a *verdict*
carries an unwritten invariant: every serious arm precedes every advisory one. Adding
an arm is the natural edit; ranking it correctly is a judgement — so the invariant
breaks quietly, and the symptom is a real failure that is never printed.

It recurs one axis over, which is the tell that the class is wrong rather than the
instance. Measured across three rounds on one file (link#262):

| round | edit | result |
|---|---|---|
| 1 | added a NOTE arm under a FAIL | shadowed the FAIL two lines below it |
| 2 | partitioned FAILs above NOTEs, wrote the invariant in a comment | correct, briefly |
| 3 | added a *conditionally* sanctioned state into a FAIL slot | shadowed the same arm again |

The invariant was never "FAILs before NOTEs" but "every arm above the line is
**unconditionally** a failure" — which no comment reliably enforces.

**Accumulate instead of dispatching.** Report every condition that holds:

```sql
coalesce(nullif(concat_ws('; ',
  CASE WHEN <a> THEN 'FAIL: …' END,
  CASE WHEN <b> THEN 'FAIL: …' END,
  CASE WHEN <c> THEN 'NOTE: …' END), ''), 'OK')
```

`concat_ws` skips NULLs, so arm order changes only the order of the joined tokens.

Two checks worth making once you have one:

- **Enumerate how the accumulator itself could drop an arm** — a false condition, a
  NULL-valued condition, an empty-string arm, a NULL separator, a nested `CASE` with
  no `ELSE`. That set is small and finite, which is what makes "this class is closed"
  a measurement rather than a claim.
- **No arm labelled FAIL may exit 0.** Sweep every single-fault state and check the
  label against the exit status; a reported-but-unenforced FAIL trains people to
  ignore the word. Where a condition is deliberately advisory, label it NOTE.

### A link to a repo-hosted artifact must be *tracked*, not merely present

When the published site **is** the repository — GitHub Pages serving `docs/`, or a
`raw.githubusercontent.com` URL — the question "does this file exist" is the wrong
predicate. The right one is "is it in the repository", because that is what a reader
gets. A file written by a script and never `git add`ed exists for exactly one person:
whoever last ran the script.

The failure is invisible from the inside. The build succeeds, the page renders, the
link opens locally, and it 404s for everybody else. It surfaces only on a fresh clone
or a real visit.

```r
in_git <- repo_path %in% system2("git", "ls-files", stdout = TRUE)
```

Three instances in one project, each with a different cause and the same symptom:

- an interactive map written by a manual script, never committed — the appendix
  linking it 404'd on the published site for months
- 32 generated popup pages whose build script was in no build chain
- photo URLs built from the wrong id column, pointing at directories that had been
  renamed upstream

Note this is the *inverse* of the dirty-check case under "A guard that fails toward
pass" (the job writing into its own tracked output directory), where untracked
outputs are noise and `--untracked-files=no` is right. The distinction is whether the
repo is the input to a build or is itself the artifact being served. Both predicates
are correct for their own subject and wrong for the other.

**Corollary — the DOM is not the whole document.** Harvesting `href`/`src` with an
HTML parser misses anything a script tag reconstructs at runtime. A leaflet map
serialises its popups as JSON, so every link inside them is invisible to
`xml2::xml_find_all(doc, "//@href")`. A DOM-only pass over a report with 51 dead links
found 2. Scan the raw text as well, and be permissive about the shape: markup built by
`paste0('<a href =', x, '.html ', 'target="_blank">')` emits `href =…` with a space
and no quotes, which most href patterns skip. In PCRE, lookbehind must be fixed width,
so `(?<=href *= *)` will not compile — match the attribute name and strip it after.

Cheap enough to run on every build, and it belongs there rather than in a checklist: a
check that must be remembered has the same failure mode as the script that had to be
remembered.

### An assertion that matches an interpolated value cannot see the claim around it

`expect_error(f(x), "some_column")` looks like it pins the guard. It pins the
**field name**, which the message interpolates — so it matches whatever sentence
is built around that name, including a sentence that is false. The guard's
predicate is tested; the guard's *claim* is not, and nothing distinguishes the two
from a green suite.

The failure mode is a package asserting opposite things about one thing, in two
places, both with tests passing:

```
`sessions` is missing named_by, which is an override column.        <- guard A
`annotations` carries named_by, which is not an override.           <- guard B
```

Measured 2026-09-02 in trap#28. Guard A's predicate had been widened to cover
`named_by` and its sentence was left behind; guard B refuses `named_by`
*precisely for not being an override*, twenty lines above it. The test written
for that exact column asserted `expect_error(..., "named_by")` — a working guard
on the predicate, structurally blind to the sentence. It pointed a reader at the
remedy the other guard rejects.

**The tell is a message that says what something *is*, rather than only naming
it.** "which is an override column", "the layer was altered", "carried from the
capture source" are claims. `{.field {col}}` alone is not.

Where a guard's message makes a claim, assert the **rendered text**:

```r
render <- function(expr) tryCatch(expr, error = function(e) conditionMessage(e))

msg <- render(f(x))
expect_match(msg, "crew-supplied")                       # the claim, positively
expect_false(grepl("is an override|are override", msg))  # and the wrong one
```

Two notes on doing it well:

- **`conditionMessage()` on a `cli_abort` condition returns the bullets too**, not
  only the headline — so the `i` and `x` lines are reachable. Every assertion that
  matched only the first line was blind to them.
- **Prefer a positive `expect_match` over a negative `grepl`.** A negative catches
  the regression it was written for and is evaded by a rewording; the positive
  assertion beside it is the load-bearing one.
- **testthat makes this stable**: `local_reproducible_output()` sets
  `cli.condition_width = Inf`, so messages are emitted unwrapped and the
  assertions do not depend on console width or on how long `TMPDIR` is. Rendering
  the same message *outside* testthat wraps it and appears to fail — a false alarm
  worth recognising rather than debugging.

**Terminate by enumerating the messages, not by reading them.** Parse the file and
walk every `cli_abort` / `warning` / `stop`, dump the literals, and mark which
make a claim. That set is finite and small — six in the trap case — so "all of
them are pinned" becomes a measurement. Doing it from recollection is what left
the sixth unpinned, and the sixth was the false one.

### A pluralisation marker takes the quantity of whatever was substituted last

`cli`'s `{?a/b}` reads the most recent quantity in the string, and **any**
substitution resets it — including a length-1 one that is not what the marker is
about. So a `cli::qty()` at the head of a message is overridden by the first
`{.path {x}}` that follows it.

Worse, the two failure directions look identical when you only render one case:

```r
# n = 4 drifted columns
"{cli::qty(length(d))}{.path {p}} carr{?ies/y} {.field {d}}, which differ{?s/} ..."
#> '/x.gpkg' carries A, B, C, and D, which differ ...     <- qty reset by {.path}
"{.path {p}} {cli::qty(length(d))}carr{?ies/y} {.field {d}}, which differ{?s/} ..."
#> '/x.gpkg' carry A, B, C, and D, which differ ...       <- the FILE "carry"
```

**And markers in one sentence may legitimately have different subjects.** Above,
`carr{?ies/y}` is about the file — always one — and `differ{?s/}` is about the
columns. The original was correct and a "fix" made it wrong, because the two
halves were assumed to disagree when they were describing different nouns. The
right answer was to delete the `qty()` and write `carries` literally, letting
`{.field {d}}` supply the quantity for the markers that genuinely track it.

Caught 2026-09-02 in trap#28, and it cost two review rounds: one to introduce the
regression and one to find it. Neither was visible by reading.

- **Identify each marker's subject before touching a quantity.** If a marker is
  about something singular, no `qty()` is wanted at all.
- **Put `cli::qty(n)` immediately before the marker it governs**, never at the
  head of the string, when one is needed.
- **A quantity does not carry between bullets.** Each element of a `cli_abort()`
  vector is its own string, so a `{?it/them}` in an `i =` bullet has no quantity
  in scope even when the headline above it interpolated one — and this failure is
  loud rather than silent: `Cannot pluralize without a quantity` replaces the
  whole message, so the abort still fires and says nothing about what was wrong.
  Each bullet needs its own `qty()`. Caught 2026-09-03 in trap#32, in a refusal
  whose headline pluralised correctly two lines above.
- **Render at n = 1 and n = 2 through the real code path**, not through
  `cli::format_error()` on a hand-built string. A single-quantity test cannot see
  either direction, and a message rendered outside its function may substitute
  different values than the function does.

Also worth knowing: a length-1 **numeric** substitution sets the quantity to the
*number itself*, so `{cli::qty(length(x))}... {length(x)} item{?s}` is fine and
looks like the same defect. Do not "fix" it.

## Security

### Process Visibility
- Secrets passed as command-line args are visible in `ps aux`
- Use env files, stdin pipes, or temp files with `chmod 600` instead

### Secrets in Committed Files
- `.tfvars` must be gitignored (contains tokens, passwords)
- `.tfvars.example` should have all variables with empty/placeholder values
- Sensitive variables need `sensitive = true` in variables.tf

### Firewall Defaults
- `0.0.0.0/0` for SSH is world-open — document if intentional
- If access is gated by Tailscale, say so explicitly

### Credentials
- Passwords with special chars (`'`, `"`, `$`, `!`) break naive shell quoting
- `printf '%q'` escapes values for shell safety
- Temp files for secrets: create with `chmod 600`, delete after use

### Gitleaks pre-commit hook
Configuration patterns and false-positive handling for the `gitleaks` pre-commit hook (kdot's Brewfile ships `gitleaks` + `pre-commit`; cyclops standardizes the hook):
- **`.gitleaks.toml` schema in v8.30+**: top-level table is `[[allowlists]]` (PLURAL, array of tables). Each entry MUST include at least one of `commits` / `paths` / `regexes` / `stopwords`. The singular `[allowlist]` and `fingerprints = [...]` forms shown in older docs fail to validate. Use `paths` + `regexes` together for targeted file-and-content allowlists. Example in `soul/.gitleaks.toml`.
- **PEM marker regex spans multi-line**: gitleaks's `private-key` rule is `(?i)-----BEGIN...PRIVATE KEY-----[\s\S]*-----END...-----`. It matches across comment prefixes, blank lines, and code-fence boundaries. **Commenting out the markers does NOT neutralize the match.** Only fix in content is to omit the literal `-----BEGIN/END...-----` strings entirely and replace with prose ("Paste your private key here, preserving headers" etc.). See the `rtj` cypher `tfvars.example` precedent.
- **`curl-auth-header` rule false-positives on non-auth headers**: matches any `-H "X: Y"` shape, not just credential-bearing headers. Trips on docs with custom CORS or app-specific headers (e.g. `Zotero-Allowed-Request: true`). Fix: targeted `[[allowlists]]` with `paths` + `regexes`. Don't path-allowlist the whole file unless content is entirely safe.
- **`pre-commit install` legacy-hook handling**: running `pre-commit install` on a repo with an existing `.git/hooks/pre-commit` renames it to `.legacy` and keeps invoking it after framework hooks. No breakage, but means hook surface is split between `.pre-commit-config.yaml` and `.git/hooks/pre-commit.legacy`. For full visibility, migrate the legacy check into `.pre-commit-config.yaml` as a `local` hook so the whole hook surface is declared in one place.
- **AWS canonical example keys are allowlisted by default** (`AKIAIOSFODNN7EXAMPLE` etc.) — don't use those in test fixtures expecting a block. Use `ghp_`-shape PAT lookalikes or other non-allowlisted patterns for hook-trigger tests.

### "Public bucket" ≠ listable: GetObject vs ListBucket
- A bucket policy granting only `s3:GetObject` on `bucket/*` makes exact-key fetches public but NOT listing — and dataset discovery (`arrow::open_dataset()`, duckdb globs, STAC `/vsicurl/` directory reads) requires `s3:ListBucket` on the **bucket ARN** (no `/*`; it's a bucket-level action).
- The breakage hides: anyone with ANY ambient AWS credentials lists fine, so "anonymous access works" goes unverified for years. Caught 2026-07-18 (water-temp-bc#23 → rtj#187): anonymous `open_dataset()` had never worked on a bucket whose whole purpose was credential-less querying.
- Review checks: for an open-data bucket, the policy needs BOTH statements (GetObject on `bucket/*`, ListBucket on `bucket`); acceptance-test anonymous access from a credential-stripped environment (`env -u AWS_ACCESS_KEY_ID ... AWS_CONFIG_FILE=/dev/null`). Note ListBucket makes the full key listing publicly enumerable — intended for open data, wrong for mixed-content buckets.

## Spreadsheets and PDFs

### A stored value is not wrong just because the raw number looks wrong

Before reporting that a spreadsheet value is off by a factor, check the cell's
**number format**. A cell formatted `0.0%` multiplies by 100 for display: stored
`0.028` renders as `2.8%`. Reading raw values with `readxl` and comparing them against
what the column header implies will make correct data look 100x wrong.

- `tidyxl::xlsx_formats(path)$local$numFmt[cell$local_format_id]` gives the format.
- The header text is not the signal. A column headed `(%)` may legitimately store a
  proportion, because the format supplies the percent.

**Why:** this cost a full wrong turn in the fish data submission work — a formula
`AVERAGE(...)/100` was reported as a provincial template defect, a correction notice to
the ministry was drafted, and the "fix" would have shipped `280.0%` where `2.8%` was
meant. Caught only because a human opened the file and looked at it.

### Verify PDF links from the annotations, not the extracted text

`pdftotext` returns anchor text, not the href. A link whose anchor reads "here" leaves
no URL in the text layer, so grepping the text proves nothing either way. Extract the
annotation instead:

```bash
qpdf --qdf --object-streams=disable in.pdf - | strings | grep -oE 'https?://[^ )>]*'
```

`pdftotext` also splits ligatures — "fish" comes out as " sh" — so a grep for any term
containing `fi`, `fl` or `ffi` can report a false absence.

### Extracted PDF text carries corrupted glyphs, and a tolerant parser turns them into wrong numbers

Worse than the ligature case above, because it fails silently with a plausible value
rather than a missing match. Three shapes, all met in one set of 18 camera calibration
reports (fly#32, 2026-08-30):

| what the PDF renders | what it means | what a naive parser does |
|---|---|---|
| `2001Opixel` | 20010 | `gsub("[^0-9.]", "", x)` **deletes** the O and returns 2001 |
| `Pixel Size [<U+F06D>m]` | `[µm]` in a Symbol font | a literal `\[µm\]` misses; a human reading the extract sees `[m]` and takes **metres** |
| `Pixel Size  5.200 m` | 5.200 µm, sign dropped entirely | reads as metres — a factor of 10^6 |

The micron sign is the common one: U+F06D is a **Private Use Area** codepoint emitted by
Word-generated PDFs, so it is neither `µ` (U+00B5) nor `μ` (U+03BC) and matches neither.

Three habits:

- **Anchor on the label, not the unit.** Take the first number on the `Pixel Size` line
  rather than matching a unit that is written three different ways.
- **Never strip non-digits to "clean" a number.** That silently deletes a corrupted
  glyph instead of failing on it. Substitute deliberately (`[Oo]` preceded by a digit
  → `0`) and let an independent check prove the result.
- **Have an independent identity to check against.** These reports state pixel count,
  pixel size *and* image size in mm, so `px × pitch == mm` catches any one of the three
  being wrong — which is what made the O→0 substitution safe rather than reckless. Where
  the document states only two of the three, the check is vacuous; know which rows those
  are rather than counting them as passes.


# NGE Feature Workflow

For non-trivial issue-driven work, follow this checklist. Each step exists for a reason — skipping leads to rework, broken builds, and avoidable bugs that we've hit repeatedly.

## The Sequence

1. **Start with `/planning-init <N>`** — given an issue number, enters plan mode for codebase exploration, presents a phase breakdown for user approval, then scaffolds branch + PWF baseline with the approved phases. One command replaces the manual issue → explore → plan → branch → scaffold dance.
2. **Write robust tests first** — failing tests that reproduce the issue or document the new behavior. Tests are the contract; they fail until the work makes them pass.
3. **Name with intent** — functions, parameters, internal helpers carry the naming style of the package they live in. Look at existing exports as the guide; consistency over cleverness. For files rather than functions — shell scripts and operational R scripts under `scripts/` or `data-raw/` — the standard is the `noun_verb-detail` pattern in `newgraph.md`, noun first.
4. **Examples that run** — every exported function gets a runnable `@examples` block. Pkgdown renders them; CI executes them. An example that doesn't run is documentation rot.
5. **Code-check before each commit** — `/code-check` on staged diff. Catches what tests miss: edge cases, hard-coded paths, unguarded variables, security issues.
6. **Atomic commits** — each commit bundles code change + checkbox flip in `task_plan.md`. The diff and the progress live in the same commit; `git log -- planning/` tells the full story.
7. **`/planning-archive` when complete** — moves PWF to `archive/YYYY-MM-issue-N-slug/`, creates a fresh `active/`. Then `/gh-pr-push` opens the PR; `/gh-pr-merge` handles the release bookkeeping.

## Where the checkpoints are not

Step 1's plan approval is the authorization for every step after it. Run steps 2–7
through to the **open PR** without stopping to report between phases — the merge in
step 7 is outside the mandate unless the instruction includes it; put the decisions that
genuinely change what gets built at the plan gate, batched, with a recommendation
first; report once when the PR is open. The rule, its boundary (before a plan
exists, a question wants an answer) and its exceptions are `karpathy.md` §8.

## Re-read origin before you open the PR, not just before you cut the branch

Verifying local is current with origin (`code-check-shell.md`, "Before you *cut* a
branch") protects the branch point. It
says nothing about the build window, which is where a parallel session lands: measured
once, a second session filed, built and merged the same feature in 18 minutes, entirely
inside the first session's planning phase, and merged 15 seconds before its first
commit. Both sessions' pre-flight checks passed and both were correct when they ran; the
duplicate surfaced hours later as a version-bump conflict across eight files.

Before opening a PR, and again before merging:

```bash
git fetch -q origin
git log --oneline HEAD..origin/main          # what landed while you worked
git diff origin/main -- DESCRIPTION NEWS.md  # a version you did not bump
```

**A version bump you did not make is the tell**, and usually the only one — the tree is
clean, the branch is healthy, and nothing in git hints that someone solved your problem
an hour ago.

On a collision, do not resolve conflicts file by file. The merge conflict hides the
useful question, which is *which body of work survives*. Ask, then re-land the delta on
top of what shipped; two independent attempts at one problem are usually complementary
rather than redundant, and a mechanical resolution keeps whichever half git preferred.

## The version lives in one place

Do not restate the current version in `README.md` or `CLAUDE.md` prose. A version
string typed into prose drifts from the moment it is written — the release step
maintains `DESCRIPTION` and `NEWS.md`, and one report repo's
`CLAUDE.md` was found eight minor versions behind, its `README.md` one behind, with both
canonical files correct. Link to `NEWS.md` instead. Where a claim genuinely must stay in
prose, `/gh-pr-merge` step 7 greps for the previous version string outside the two
canonical files and updates the prose restatements it finds, reporting each.

## When to Skip

For one-line typo fixes, version-bump-only PRs, or trivial documentation edits, the full workflow is overhead. Use judgment. The threshold is roughly: **multi-step issue, multi-file change, or anything that requires scoping** → use the workflow.

## Skills That Slot In

- `/planning-init <N>` — start
- `/planning-update` — sync checkboxes mid-session
- `/code-check` — before every commit
- `/planning-archive` — when issue closes
- `/gh-pr-push` — open the PR
- `/gh-pr-merge` — merge with release bookkeeping

## Issue bodies get edited, not appended

When work changes what an issue should say, **edit the body**. Don't add a
comment that corrects it, and retitle when the scope moves.

**Why:** an issue is read as a spec by whoever picks it up. A body saying one
thing with a comment three screens down saying the opposite costs the reader the
reconciliation, every time.

**How to apply:** `gh issue view N --json body -q .body` into a file, revise,
`gh issue edit N --body-file`. Name what changed and why when the correction is
load-bearing — the goal is a body that reads correctly top to bottom, not an
erasure of history. Comments are for genuine commentary: a merge notice, a
cross-repo pointer, a question. Applies to PR bodies too. Commit messages are
immutable history and are never rewritten this way.

**The failure mode that keeps recurring: research findings feel like
commentary.** They are not — they are the spec. If a finding changes what
someone would *build*, it belongs in the body, with the durable version in
`research/` and the body linking to it. What `research/` holds, how a file is
named and what its header carries is `planning.md`, "`research/` — what is
known, outliving the issue that found it".

**Bodies drift at the moment work finishes, not while it is in flight.** Four
instances in a single day of rfp work, all of the same shape — the code learned
something and the issue did not:

| drift | what a reader saw |
|---|---|
| premise disproved by measurement | an issue arguing for a fix that was no longer needed |
| a conclusion asserted in the body but never landed in code | body and tree contradicting each other |
| the shape of the work moved during exploration | a spec describing a design nobody built |
| a decision made and shipped, body still listing options A–D | "decision needed" on a decision a year old |

Vigilance does not catch this, because the drift happens exactly when attention
moves to the merge. `/gh-pr-merge` reconciles at that moment — see its step 3b.

## Why This Exists

We've hit snags repeatedly when half-doing this — branches that mix concerns, tests bolted on after, code-check skipped (and then a bug ships in the diff), examples that fail in pkgdown. Each step is small; the cumulative reliability gain is real. The convention is here so it becomes the default expectation, not a thing the user has to remind every session about.


# LLM Behavioral Guidelines

<!-- Source: https://github.com/forrestchang/andrej-karpathy-skills/main/CLAUDE.md -->
<!-- Last synced: 2026-02-06 -->
<!-- These principles are hardcoded locally. We do not curl at deploy time. -->
<!-- Periodically check the source for meaningful updates. -->

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

## 5. You Have No Clock Between Tool Calls

**Every duration claim comes from `date`, never from how much waiting felt like
it happened.**

Background `sleep` returns immediately from the agent's side, and the number of
times you have polled is not evidence of elapsed time. Two consecutive tool
calls can be 15 seconds apart by the clock while feeling like ten minutes of
waiting.

The failure is stating it out loud before checking. Observed 2026-08: a CI run
was reported to the user as "pending for over an hour — unusually long, probably
a stuck runner", after roughly eight background sleeps. One `date -u` showed the
run was **three minutes old** and entirely normal. The whole diagnosis — stuck
runner, duplicate triggers, something wrong with the workflow — rested on a
duration that had been invented.

**How to apply:** before saying *any* duration — "still running after N
minutes", "this has been X a while", "longer than usual" — run `date -u` and
subtract a real start time. `gh run list --json createdAt` gives it for CI. If a
claim about slowness would change what the user does next, it needs a measured
number or it does not get made.

The same rule covers process state. `ps` and task-status listings have both been
observed wrong; check the artifact (an output file's size, its mtime, the
service's own API) rather than the wrapper.

### The same blind spot picks the wrong waiting tool

Not having a clock also makes a **chain of background sleeps** feel like
waiting when it is not. Observed 2026-08 on the same session as the above:
roughly a dozen `sleep 570; check` background tasks were spawned to wait out a
55-minute test suite and then CI. Two consecutive foreground checks printed the
*same minute* — no wall time had passed between them, because the sleeps run
detached and the polling happened around them rather than after them. Every one
of those tasks was waste, and killing them produced a batch of eleven
exit-code-144 notifications that read like failures.

Pick the instrument by how many answers you need:

| you need | use |
|---|---|
| one notification when a condition becomes true | `Bash(run_in_background)` with an `until` loop that exits |
| one per state change, ending on its own | `Monitor` with a command that emits and then exits |
| a value you must have before the next step | a **foreground** call, so the blocking is explicit |

A repeated `sleep N; grep` is right in none of them. **Tell: if you are about to
spawn a second waiter for the same thing, the first one was the wrong shape.**

A `Monitor` filter must also match the failure states, not just the success
one — silence looks identical to "still running", so a watcher that greps only
for the happy path stays quiet through a crash.

### Don't edit files a long-running suite is still reading

`devtools::test()` and its equivalents load each test file **when they reach it**,
not at launch. A 30-minute run therefore reads whatever is on disk at that moment,
so edits made mid-run are half-applied and the result describes a tree that never
existed.

Cost two full Docker suites (~1 hour) on rfp#178, both reporting `FAIL 1`. The
failure was a test written *during* the run, executing against source from *before*
the fix that made it pass — nearly reported as a regression. **The tell is a moving
denominator:** 3490 passes, then 3496, then 3500, on "the same" tree.

Before a long run, commit. While it runs, do work that touches nothing it reads —
issue bodies, PR text, reading, planning. If an edit cannot wait, kill the run
rather than let it produce a result that has to be re-litigated. And when a long run
fails, get the `file:line` before forming any theory: a mid-flight edit and a real
regression look identical in a summary line.

## 6. Subagents Are Evidence, Not Dependencies

**Spawn on your own judgment. Don't block on one. Don't trust its status. Verify its claims in both directions.**

### Spawning is your call, not the user's

Deciding to spawn a subagent is an engineering judgment, the same kind as choosing
to write a test or run a grep. **Do not ask permission for it.**

The user is usually not positioned to answer. Knowing whether a fan-out beats a
sequential read requires knowing the shape of the work — which you have and they do
not, so the question forces them to guess at a technical call. Under **Always Away**
it is worse than useless: the work stalls until they wake up, for an answer that was
yours to make. *"I wouldn't be in the know enough to know when that is"*
(airvine, 2026-08-27) is the whole problem in one line.

This does not soften §1's asks — *"if uncertain, ask"* and *"if something is unclear,
stop and ask"*. Those are about **what the user wants**: intent, scope, an ambiguous
requirement, a tradeoff only they can weigh. This is about **how you carry it out**.
Ask about intent; decide about mechanism. A question starting "should I use…" is
almost always the second kind, and almost always yours to answer.

#### Standing authorization: the harness bars the Agent tool by default on Opus 5

Sessions on Opus 5 carry a hardcoded instruction from the CLI itself —
*"Do not call the AgentTool unless the user requested it"* — alongside the same
line for workflows and deep-research. It is not a setting anyone here
misconfigured, and it cannot be turned off locally: measured 2026-08-29 in
`claude` v2.1.251, the string is a literal in the bundle, emitted when the
session is on the `opus_5_prompt_bundle` and the server-side flag
`tengu_fennel_godwit` is off. That flag and the replacement text
(`tengu_heron_brook`) are both remote config; nothing in `~/.claude/settings.json`
reaches them.

The symptom is a skill quietly doing less than it says: `/code-check` reporting
*"the subagent rounds did not run — your session instruction bars the Agent
tool"*, which is the review the command exists to perform. It reads as a
configuration problem, so the fix gets looked for in the wrong place.

**The clause is conditional, so this convention is the request.** Invoking a
skill that mandates subagents — `/code-check`'s three rounds, the Plan review in
`planning.md` — **is** the user requesting them. Spawn them. This paragraph is a
standing user instruction, written for exactly that purpose (airvine,
2026-08-29), and CLAUDE.md project instructions override default behaviour by
their own terms.

It authorizes the mandated spawns and nothing wider: the bounds in this section
still hold — two or three concurrent, about five per task, no fan-out from a
child — and a workflow or deep-research run fanning out dozens of agents remains
a spending decision that needs an explicit ask.

**Spawn without asking when:**

- A skill or convention mandates it — `/code-check`'s review rounds, the Plan review
  in `planning.md`. That decision is already made; re-asking it is friction carrying
  no information.
- You want fresh eyes on your own work. The mechanism and the measurements behind it
  are in `code-check/SKILL.md`.
- A sweep over many files will **locate** what matters faster than reading serially.
  The sweep finds candidates; it does not replace the read — `planning.md` is
  explicit that agents sometimes report existing files as absent, so read directly
  whatever you are going to act on.
- Independent items can run concurrently and nothing downstream needs them ordered.

**Do it yourself when:**

- One grep answers it.
- The work depends on conversation context a subagent will not have.
- You would sit idle waiting — spawn and keep working, or do it inline.

**Bounds and defaults you enforce yourself, rather than converting into questions:**

- **Two or three concurrent is the working default, and about five per task** is
  where spend stops being incidental. Concurrency and cumulative total are different
  quantities — `/code-check`'s three rounds plus a Plan review plus an ad-hoc sweep
  never exceeds three at once while spending well past a handful. Bound both.
- Past that total, **say so in your next message.** An escape you grant yourself
  silently is not a bound; it has to land in front of the user, after the fact.
- **Do not let a subagent fan out again.** Intent does not enforce this — the child
  decides what it calls — so use the structure: the `Explore` and `Plan` types are
  defined without the `Agent` tool and *cannot* spawn. `general-purpose` can, so when
  you use it (as `/code-check` does), put "do not spawn subagents" in the prompt. The
  one case on record — a research agent that had spawned 5 children and deadlocked
  for **~3 hours** while still reporting as running (below) — never had a root cause
  established, which is exactly why this bound is structural rather than advisory.
- Unnamed, delivering by file — `planning.md` carries the mechanics.
- **Report after, not before.** Say what you spawned, and relay what it found (per
  `code-check/SKILL.md` — a subagent's report never reaches the user on its own). A
  user can object to a spawn that already happened; they cannot usefully approve one
  that has not.

**What is genuinely the user's call is budget, not mechanism.** A workflow or
deep-research run fanning out dozens of agents is a spending decision and needs an
explicit ask. Two or three reviewers is not — that is just doing the work.

Worth being concrete about the value, because the cost is the visible half and the
benefit is not: on 2026-08-27 two reviewers over one conventions draft returned
**20 findings**, caught **six** false factual claims in it, and killed a section that
would otherwise have shipped contradicting `code-check.md`. None of that review
happens if the spawn waits on a user who is away.

### Don't block

Spawn a background subagent, then keep working on the lowest-risk part of the
task — scaffolding, data files, tests. When findings arrive, treat them as a
review of landed work rather than a precondition for starting it.

If a result genuinely must precede the next step, run it synchronously
(`run_in_background: false`) so the blocking is explicit and visible.

Three observed cases where waiting would have been the expensive choice:

- A research agent spawned 5 children and deadlocked for **~3 hours**, still
  reporting as "running". The user caught it, not the agent.
- A `Plan` agent asked to review a `task_plan.md` *before the baseline commit*
  returned after the issue was implemented, reviewed, merged and tagged.
- The same pattern on a later issue: findings arrived after all four phases had
  shipped. Because the work had not waited, this cost nothing — three findings
  were still new and landed as follow-up commits.

That last one is the shape to aim for. Concurrent review is not a degraded
version of blocking review; it is often better, because the reviewer reads real
code instead of a plan.

### Don't trust status

**Never report an agent as "still running" without evidence.** Agent status and
`TaskList` have both been observed to be wrong — `TaskList` reported "No tasks
found" for an agent that was alive and later replied. Check the output file's
mtime before claiming progress, and say what you checked.

**And never record a review as "Clean" on the strength of an idle notification.**
From the parent's side an idle ping is indistinguishable from an agent that had
nothing to say, so a lost review reads as a pass — a whole `/code-check` pass was once
reported as finding nothing while three reviews were stranded, one of which had found
a data-loss bug (measured 2026-08-25; the numbers are in `planning.md`, "Spawn review
agents UNNAMED"). Passing `name` turns a spawn into a persistent teammate that idles
instead of completing; pass it only for a collaborator you will keep messaging, and
shut it down when done. The rule that survives either spawn shape:
the reviewer **writes its findings to a file and reports only the path**, and a
missing or empty file means the round produced nothing and is re-run — never
"Clean". `planning.md` carries the mechanics; `code-check/SKILL.md` applies them.

### Verify claims, in both directions

Subagent output is evidence, not verdict. Both failure modes are real:

- **Acting on a wrong finding.** One labelled BLOCKER — "`glue()` will choke on
  the literal braces in this fragment" — was disproved by a 30-second probe,
  because glue does not re-parse interpolated values. Acting on it would have
  meant rewriting a working generator.
- **Dismissing a late review wholesale.** In that same review 2 of 9 findings
  were real, including a dead link. In a later one, a finding that a
  `path|layername=` check would delete KML/GPX layers was correct, and was
  confirmed against 207 real datasources before the fix landed.

The rule that separates them: **cheap probe first, then act.** Reproduce the
claim before you fix it, and before you dismiss it. A finding you cannot
reproduce is a finding you do not yet understand.

### Fan out inside one process

A workflow that shells out **once per item** costs one permission prompt per item,
unless the command happens to be allowlisted. The same work done **inside one
process** costs one prompt total, and nothing says so until the run is already
going. Measured 2026-09-04 (knowledge#4): a harvest script issuing two `curl` calls
per report inside each subagent meant hundreds of approvals across a run — the user
had flagged it as *"a big time suck last time"* without knowing the cause — while a
sibling script doing the same fetch-download-upload work with Python `urllib` in a
single process cost **one** prompt for the entire run. Same task, same volume, three
orders of magnitude apart in interruptions.

It breaks **Always Away** directly: an unattended run that stops for approval on item
3 of 200 has not failed loudly, it has gone idle, and the wrapper reports nothing.

- **Prefer one process doing N items over N processes doing one.** Loop inside the
  language runtime; shell out once, for the batch.
- Where a per-item subprocess is genuinely required, allowlist its command **before**
  the run, not one refusal at a time during it — the allowlist fixes the commands you
  predicted, and the one that blocks is the one you did not.
- Diagnostic: if a run keeps stopping for approval, look at whether the loop sits
  inside or outside the process boundary before adding allowlist entries.


## 7. Evidence, Not Impressions

**Measure before you characterise. Presence is not provenance. "Unknowable" is a
claim.**

Six principles that all fail the same way: something *feels* established — because
it is visible, because it is present, because someone said so — and gets offered
with the confidence of a measurement.

### Measure before you characterise

When a decision turns on **what something contains**, open it and count. Do not
describe it from its structure, from an issue's claim about it, or from a tag list.
A heading tells you a thing is *present*, never that it is *populated* — an empty
`<conditionalstyles/>` and one with rules look identical in a list of child names.

Four instances in one rfp session, each corrected by the user's follow-up question
rather than by review: a tradeoff described as three times its real size; an issue's
stale claim repeated as current; an installed version reported as sixteen releases
behind when a parallel session had updated it eighteen minutes earlier; and "nothing
on main addresses this" from a local `main` three commits behind — one `git fetch`
away from the truth.

**A measurement carries the time it was taken.** One made earlier in the same
session is not a current one, least of all for anything another session can change
underneath it. For anything git-backed, `git fetch` first: reading a local clone and
reporting it as the state of the world is the same error with a longer fuse.

**And before hand-rolling a parser for a probe, check whether the code already has
one.** A bespoke parser silently narrows the population it can see, and the result
looks like a measurement rather than a sample — worse than not measuring, because it
carries a number. Measured 10 of 80 with a hand-written matcher; routed through the
package's own resolver it was 14 of 117.

### Presence is not provenance

When something's **presence** is offered as evidence for **how it got there**, find
the fact that actually discriminates. A QGIS project's `3.30.1` stamp was offered as
evidence a desktop had opened it — but the template it was copied from carries that
stamp, so a never-opened project reads the same. What actually proved it was a
tracking key the template does not contain.

The tell: reaching for the *most visible* fact rather than the *discriminating* one,
because the visible fact is consistent with the conclusion. **Consistency is not
support.** Before offering "X shows Y", ask what else would produce X. If anything
would, X is not evidence.

When the user pushes back on an inference, re-derive rather than defend. The
conclusion often survives; the reasoning that reaches it is usually different.

### Documents that share an ancestor corroborate nothing

Sibling of the rule above, one level out: there a *fact* was consistent with the
conclusion, here several *documents* are. Finding the same claim in three places
feels like triangulation and is not — if one was written from another, they are one
source wearing three hats, and the agreement is a copy, not a confirmation.

**The tell is agreement with no independent derivation.** Ask of each restatement:
what did its author read? If the answer is "one of the others", the count is one.
Prose repeats; code does not, so the discriminating check is almost always to read
the thing the prose describes.

**The release note is where this costs the most, because its readers cannot check it.**
Measured 2026-09-04 in stac_floodplains_bc#26: three claims in one set of release notes were
wrong, each restated from a prior document rather than derived from the artifact — "18 items
changed" (the count of upstream *re-runs*, six of which moved nothing; 13 changed), "5-33%"
(the issue's own summary line, contradicted by its own per-item table; 1.5-33.5%), and worst,
*"the correction is visible in the checksums, so a consumer can tell replaced data from
unchanged"*. That last one measured **140 assets across 20 items, zero unchanged** — the
re-encoding touched every byte, so the checksum answers "are my bytes current" and can never
answer "did the values change". It would have sent every consumer to a signal that cannot
answer the question they have.

Two habits, both cheap:

- **Derive every number in a release note from the artifact it describes**, at the moment you
  write it. Not from the issue, not from the last release's notes, not from memory.
- **For any sentence of the form "you can tell X by looking at Y", check that Y actually
  separates X from not-X.** A discriminator that fires on everything discriminates nothing,
  and it reads as helpful right up until someone relies on it.
- **A carve-out is a number too, and reasoning one from the shape of a literal understates
  it.** A release note recording someone else's regression said a broken smoke test "could
  validate any group except the two named in `EXPECTED_DEPRECATED`" — reasoned from the
  literal being the thing the check consults. Driven over one-group trees it could validate
  **none**: the literal names two items, so a one-group tree is always missing at least one,
  including each of those two, which are missing each other. Wrong in the direction that
  understates the reach of a defect, in the document a reader uses to decide whether to
  backport. Run the check over the population before writing the exception
  (stac_floodplains_bc#61, 2026-09-05).

Measured 2026-09-02 in link. `CLAUDE.md`, `research/study_area_run.md` and
`research/recompute_parallel_2026_09_01.md` all stated that a post-consolidate
recompute "runs over every WSG in the schema, not the run's own set, so it does not
scale with scope". One line of shell disagreed — `ALL_WSGS` is the union of the host
buckets — and the run's own log said `recompute (lnk_access, 34 WSGs)` against a
95-WSG schema. Two later commits had changed the behaviour and none of the three
documents was updated.

It was quoted to the user twice in one session as a live planning input before anyone
checked, and it was load-bearing: the claim was the *premise* for concluding that
parallelising that stage beat adding machines. A false premise had produced a
plausible roadmap.

Two habits:

- **When a document states a quantity or a scope, read the code that produces it
  before repeating it.** Especially a status section — it describes a moment, and
  nothing fails when the moment passes.
- **When you find one instance stale, grep for the sentence, not the file.** The
  claim above sat in three documents; fixing the one that was quoted would have left
  two, both reading as authoritative.

### "It can only be answered by testing" is a claim with an author

An issue or a colleague saying a question needs a field season, a device or a deploy
is stating a claim, not a property of the problem. Spend the cheap probe first.

rfp#186 opened with "three questions decide whether this is viable, and none can be
answered by reading." Two fell in about twenty minutes — one to reading a call
graph, one to re-reading a file already on disk — turning "run a field season, then
decide what to build" into "build it, then confirm one thing."

The claim is usually made by someone who knows the domain, at a moment before they
looked. Not wrong so much as **unexamined**, which is what lets it survive into the
plan. Then **bound what the probe closed**: reading a desktop plugin says nothing
about the mobile app. An over-claimed probe is worse than none.

### A real bug is not necessarily the reported bug

A defect found while investigating a symptom is **evidence, not the answer**. Before
offering it as the cause, check that it produces *exactly* the symptom described,
including the details that sound incidental.

Two confident wrong causes in a row on rfp#196 — a layer missing from a map theme
(a real bug, fixed) and a sub-pixel geometry (a real measurement). Both true;
neither explained the report. The actual cause was draw order, and the user named it
himself. The discriminating fact was in his words all along: *"as soon as I stop
tracking I can't see the track"* rules out both theories in one line.

Finding a genuine defect feels like finding *the* defect — the relief of having an
explanation is what stops the check. Write the reported symptom out and ask whether
the proposed cause produces **all** of it. Say which parts are still unexplained:
"this is a real bug and it may not be your bug" is honest and cheap.

### An enumeration is not a checklist

A probe listing what exists — subkeys present, columns found, files listed — answers
"what is here", never "what do we want". Scope arriving this way looks
evidence-backed, so it survives review.

On rfp#68, "the two Mergin subkeys that exist" became "the settings to verify",
then an item on a field checklist a human had to walk outdoors to complete. Nothing
in the codebase read or wrote `PhotoNaming`. Before a probe's output becomes work,
grep for each item and ask whether anything consumes it. When it duplicates
something already done another way, name the comparison — the existing approach
usually wins for a reason worth stating.


### A relative descriptor is meaningless without its anchor

"Upstream", "downstream", "above", "below", "before", "after", "parent" — each is
relative to something named **elsewhere in the document**, often paragraphs away and
sometimes only in a table. Resolve the anchor before drawing any inference from the
term.

Getting it wrong does not produce uncertainty, it produces a confident and specific
wrong answer — and it fails in the worst direction, because you now believe you have
*evidence* against a claim rather than merely lacking evidence for it.

Measured 2026-09-02. A field report read *"downstream sampling confirmed the presence
of coho"*. Taken as downstream of the crossing under discussion, it appeared to
disprove the user's recollection that coho were present above that crossing. The
sampling site was actually at a road crossing 1.5 km further up the stream, so its
"downstream" was still **1.1 km above** the crossing in question — the claim was true
and the correction nearly removed it from an email to the infrastructure owner, on the
one point the email existed to make.

**Where a source describes a sequence — crossings on a stream, releases in a
changelog, stages in a pipeline, commits on a branch — write the order out before
interpreting a single relative term in it.** The ordering is usually one sentence in
the source and takes seconds to find; the inference built on the wrong anchor survives
every later check, because nothing downstream re-examines it.


### A safeguard whose mechanism is a human reading a diff is not a control

When a design says "the writes are uncommitted, so the diff is the review", check
whether anyone reads diffs. Here nobody does — the user says "commit" without opening
one, stated plainly and confirmed 2026-08-28 — so every per-action confirmation loop
built on that premise was latency wearing the costume of a control. Two skills had one.

Gate on **blast radius** instead, because that fires without anyone reading anything: a
write that reaches one repo just happens; a write that reaches every repo (a soul
convention) may be appended to freely but edited or removed only through an issue. Where
a real check is needed, make it mechanical — a grep for a contradicting rule, an
assertion that nothing above the `CLAUDE.md` marker moved, a guard that resolves every
heading against a base SHA. Those are the controls; a prompt is not.

The user still wants a short, honest account of what was written. That is a report, not a
review, and confusing the two is how the loops got built.

### Not finding it is not evidence it does not exist

Before building a fetcher, harvester, backup or sourcing routine, **search the sibling
packages for the verb**. One command, and it is the difference between adding a function
and adding a second copy of one.

```bash
# Enumerate the org's installed packages rather than listing them: a hardcoded list
# named four packages; thirteen other org packages were installed on the machine this
# was measured on (2026-09-05), and the gap will grow again. Match
# on any URL-ish field, case-insensitively: RemoteUsername is set only by GitHub
# installs (a package installed from a local checkout has none) and the org name is
# not always cased the same. Forks of upstream packages come along; that is fine.
# `collapse` matters: paste() over fields that are all NULL is character(0), and
# `if` on a zero-length grepl() aborts the whole enumeration (measured, soul#171).
for p in $(Rscript -e 'for (p in rownames(installed.packages())) {
  d <- packageDescription(p)
  u <- paste(c(d$URL, d$BugReports, d$RemoteUrl, d$RemoteUsername), collapse = " ")
  if (grepl("newgraphenvironment", u, ignore.case = TRUE)) cat(p, "\n") }'); do
  echo "== $p"; grep -E "^export" "$(Rscript -e "cat(system.file(package='$p'))")/NAMESPACE" \
    | grep -iE "source|fetch|harvest|backup|manifest|download|ingest|store|snapshot|read|write|conform"
done
ls ~/Projects/repo/rtj/scripts/gis/     # operational drivers live here, not in a package
```

**Then read the README ownership table and the above-marker `CLAUDE.md` of any package
plausibly adjacent — exports understate remit.** `trap`'s README states it exists "so a
report does not have to harvest its own copy", with a manifest pinning per-snapshot
sources, schema, md5 and row count; no export says that. The old hardcoded list would
not have searched it at all; the grep finds functions; the README is the load-bearing
artifact. Measured 2026-09-04: a harvest-and-manifest layer was
proposed across three issues before `trap/README.md` was opened, with `trap` checked out
and current on the machine (soul#183).

The failure is not carelessness — it is that **a decision is invisible from where the work
is happening**. The tool exists, is correct, and is three repos away in a directory you had
no reason to open. So the path of least resistance builds it again, and the duplicate is
plausible precisely because the original was never visible.

Four instances in one session (2026-08/09), all by an agent that had just read the thread
documenting the pattern:

| Built or proposed | Already existed |
|---|---|
| a Mergin form-harvest script | `rtj/scripts/gis/mergin_data-harvest.R` — dry-run by default, parquet, photo manifest, excludes `.mergin/` cache copies |
| ad-hoc project layer curation | `rtj/scripts/gis/mergin_manifest-create.R` + per-project manifests git-tracked in rtj |
| "photo functions should go to ngr" | `sred#26` assigns photo batch ops to rfp |
| "the source fetchers should go to ngr" | `spacehakr` already existed, holding all twelve `spk_*` |

**Tell:** you are about to write something whose name is a verb the ecosystem already does
somewhere. Fetch, sync, harvest, backup, source, register, publish.

Two corollaries worth holding:

- **A function existing in two places is worse than it existing in neither.** Measured on
  `ngr_spk_geoserv_dlv` versus `spacehakr::spk_geoserv_dlv`: same name, same signature, and
  by the time anyone looked the first printed an error and carried on where the second
  aborts. Two live copies drift silently, and the drift is invisible until someone has both
  installed — which nobody did.
- **Check what the *architecture* says, not just what exists.** Two of the four above were
  wrong-home *proposals*, not duplicate code. `sred#26` had already assigned the boundary;
  reading it would have cost less than arguing the case from first principles.

Sibling of *"An inventory is only complete relative to a boundary"* in `code-check.md`, one
step earlier: that one is about a search that was complete for the wrong scope, this is
about never having searched the scope where the answer lived.

#### The storage version: one store is not the world

The same error with buckets instead of packages, and it produced three wrong answers in
one session (2026-09-04). Each was a single negative check reported as a fact:

| claim made | what was checked | where it actually was |
|---|---|---|
| "not an `aws` layer" | `rfp_source_aws.txt`, 11 entries | `db_newgraph/jobs/` — that list is what rfp *pulls*, not an inventory of what is staged |
| "not staged anywhere" | one Postgres host, one S3 prefix | a **different bucket**, written by a job that drops its temp table afterwards |
| "the imagery is not backed up" | `aws s3 ls` on two AWS buckets | **DigitalOcean Spaces** — 228 GB, reachable only via `s3cmd` |

The third is the most general: **`aws s3` and `s3cmd` address different clouds and are
invisible to each other.** A repo whose backup script uses `s3cmd` has stores that no
`aws s3 ls` will ever list, so "I checked S3" is not a statement about where the data is.

Two habits, each one command:

- **Enumerate the stores before searching them.** `s3cmd ls` and `aws s3 ls` with no
  argument each list only their own provider's buckets; the backup script names the rest.
- **Prefer the definition to the artifact.** The job that stages data says what exists; a
  bucket only shows what some past run happened to leave. Checking artifacts returned
  nothing three times here; reading the job answered it immediately.

A negative result is only ever as wide as the store you looked in. Stating it without that
qualifier is how a gap in your own search becomes a fact in an issue body — which is where
all three of these ended up before they were corrected.

And the same shape once more for **checkouts**: a `grep` across `~/Projects/repo` searches
the repos this machine happens to have, not the ecosystem. Repos are cloned per-machine and
the set differs between them — `stewardship_upper_wedzin_kwa` was absent on m4 while holding
the answer to two separate questions on 2026-09-04, so a local grep returned clean twice and
was reported as absence twice. Use `gh api -X GET search/code -f q="org:NewGraphEnvironment <term>"`,
and note it indexes **default branches only**, so a file on a feature branch is invisible to it
and needs `gh api repos/<owner>/<repo>/contents/<path>?ref=<branch>`.

## 8. Decisions Up Front, Then Run

**Ask at the plan gate. After approval, run to the PR. Before a plan exists, a question wants an answer.**

The first three subsections are one rule on one axis — *when* to come back to the
user — and they are only correct as a set; each was learned separately in a different
repo and re-derived, usually by getting one of them wrong first. The rest are
handover rules that belong beside them because they decide what the user is handed
when you do come back.

### After plan approval, run every phase to the PR

Plan approval is the authorization for every mechanical step after it. Run every
phase, commit atomically per phase, archive the PWF, push, open the PR, and report
**once**, at the end. Do not stop between phases to report progress: the decisions
that needed the user were taken at the gate, and a check-in that only reports
spends attention already committed. Under **Always Away** the cautious answer is the
wrong one — the work stalls on a question the user answered by approving the plan.

The instruction arrives as one short message covering many commits, reviews and
repos: *"Go all phases to PR"* (airvine, flooded#49, 2026-08-31; flooded#47 and
floodplains#33, 2026-09-01; trap, 2026-09-01; soul#169, 2026-09-04). One of those
runs carried four phases, a plan review, four code-check rounds, two issue-body
reconciliations and two cross-repo PRs with no further input. The merge is a separate
instruction: on soul#188 the user typed `/gh-pr-merge` once the PR was open, and asked
directly (2026-09-05) confirmed that *"to PR"* ends there.

Two things are inside the mandate; these are not:

- **Correcting the plan is inside it.** A review that disproves an approved design
  decision gets fixed mid-run and reported in the summary; that is the run working,
  not a reason to stop — unless the correction is itself a fork of the kind below (a
  key, an identifier, a schema), which goes back to the user. Blockers that cannot be resolved are filed as issues and
  named in the final report rather than held open.
- **Our own repos are inside it.** Filing issues, opening PRs and editing bodies in
  NGE repos is normal work; one run produced a follow-up issue and two cross-repo PRs
  without asking, and that was right.
- **Outward-facing actions are not** — see "Never post outside our own repos" below.
  Neither is anything a convention names as its own gate: **the merge** — *to the PR*
  ends at the open PR; `/gh-pr-merge` runs when the user invokes it or the instruction
  says so (airvine, 2026-09-05; `gh-pr-push/SKILL.md`, "Ask user before merging") — a change to the machine
  (`newgraph.md`, "State the plan before changing the machine"), or a push into an
  artifact a human is testing on (`code-check.md`). A push to the feature branch is
  inside the mandate.

### Before a plan exists, a question wants an answer

The same terseness that means "go" after approval means "answer me" before it. A
turn that ends in a question mark, with no approved plan, gets an answer and a
one-line offer of the work — not the first commit toward it. Twice in one day
(floodplains, 2026-09-02) a question was read as approval and editing started — once
after *"why not fix before publish?"*, and once after a gap had been explained, stopped
with *"do not take on 70. i want to understand"*. When the ask is to understand something, keep it short and concrete; a
worked example beats a taxonomy. *"small answers here"*, *"keep it short"* (airvine).

This is the boundary condition on the rule above, which is why they are one section:
a standing mandate to run autonomously, stated alone, is exactly what reads every
terse message as "go". **The mandate starts at plan approval.**

### What still interrupts, and where it goes

A decision that permanently shapes stored data — a key, an identifier, a schema
choice, a deprecation shim versus a hard rename — is the user's, and it goes to the
**plan gate**, batched, as two or three concrete options with the recommended one
first and the consequence stated. Two such forks put at one gate (flooded#47) were
both load-bearing and neither was derivable from the issue: the rename would also
have broken a production driver in another repo, which only the sweep surfaced.
Asked at the gate a fork costs one round-trip and buys the whole run; discovered
mid-execution it costs a stall with nobody there to answer it. Found mid-run, it is
still not the agent's to decide: ask it the same way — options, recommendation first,
phone-answerable — commit, and continue on the phases that do not depend on it while
the answer is outstanding (`planning.md`, "When Something Keeps Failing" — escalating
is not stopping).

During plan-mode exploration, keep a list of "this changes what I build" forks and
ask them together before `ExitPlanMode`. Questions are welcome; status updates are
not. Mechanism — whether to spawn reviewers, which regex, how to build a fixture — is
never a question (§6, "Spawning is your call"), and anything with a conventional
default is not one either: pick it, say so, move on.

### Never post outside our own repos without approval

Never post to a venue outside NGE's own repositories without the user's explicit
approval for that specific post — upstream GitHub issues and PR comments, mailing
lists, forums, third-party trackers. **Drafting is welcome and expected**: write the
comment, show it, wait. It is the sending that needs the word. *"Never post things
upstream without my explicit approval"* (airvine, 2026-09-02, after an offer to draft
comments on two of a vendor's upstream issues).

**Why:** an upstream comment is published under the organisation's name to a venue we
do not control, is indexed immediately, and cannot be unpublished. It is a
communications act, not an engineering one, and the judgement about tone, timing and
what we are willing to say in public is the user's.

- Our own repos are unaffected; filing and editing issues there is the standing
  disposition and needs no asking.
- **Reading upstream is unrestricted and worth doing.** Checking issue state before
  filing ours has caught a wrong citation in our own roxygen and found an upstream
  issue already proposing the feature we were about to request.
- Offer the draft in the reply, not as a fait accompli, and say plainly that nothing
  has been posted when the work obviously produced something postable.

### Hand the user bare commands

When the user must run a command themselves — an interactive login, a
sudo-needs-TTY operation, anything the Bash tool is blocked from running — give the
**bare command**, in a fenced block, ready to paste. Never prefix it with `!`.
*"Give me the cmd without the ! - that never works btw"* (airvine, 2026-08-21);
*"stop giving me the ! at the start. that doesn't work. i need the raw cmd"* (`cd`, 2026-08).

**Why, twice over.** Default session guidance proposes the `!` prefix as a way to run
a command in-session, so this recurs in every repo unless written down. On this
operator's terminals it either does not run at all, or — where it does — **it ran from
`$HOME` rather than the session's working directory** (one measurement, 2026-09-02): a
handed-over `! mkdir -p pursuits/x && cp … pursuits/x/` created `~/pursuits/x` and the
file had to be found and moved. Absolute paths are right whichever directory it
resolves against. So:

- Emit the command plain. Applies to fenced blocks and inline commands alike.
- **Absolute paths** in any handed-over command that touches files
  (`~/Projects/repo/<repo>/…`), whichever form the user ends up running it in.
- Keep it paste-safe: prefer `grep`/`awk` over a nested `python3 -c "…"` inside a
  single-quoted remote command, so the quoting survives the trip.

**A file under `~/Downloads` is unreadable by the agent process, and no retry helps.**
`Read`, `cp` and `pdftotext` on `~/Downloads/*` all fail with `Operation not permitted`
(measured 2026-09-02). It is macOS folder protection (TCC) on the process, not a
Claude Code permission mode, so `/permissions` does not change it; Desktop and
Documents behave the same. Do not retry variants — ask for **one** copy into the repo,
with absolute source and destination paths, then continue from the copy. (Granting
the terminal app Full Disk Access removes it on one machine; the fallback stays for
the next machine.)

### Link every issue and PR you name to the user

When a message to the user names an issue or a PR, make the number a link the user can
click: `[soul#191](https://github.com/NewGraphEnvironment/soul/issues/191)`,
`[soul PR #192](https://github.com/NewGraphEnvironment/soul/pull/192)`. Terminal output
renders markdown, so a bare `#191` costs the user a browser, a repo, and a click through
several pages to learn what it was — for every number in a report that may carry a
dozen. *"want to be able to follow up without opening new browser and clicking through
mult pages to find"* (airvine, 2026-09-05).

- **Issues under `/issues/N`, pull requests under `/pull/N`.** They are different paths,
  and the type is not always obvious from a number. When unsure, ask `gh` rather than
  guess — it returns the canonical URL for either:
  ```bash
  gh issue view 192 --repo NewGraphEnvironment/soul --json url -q .url \
    || gh pr view 192 --repo NewGraphEnvironment/soul --json url -q .url
  ```
- **Cross-repo references carry the repo**: `rfp#268`, never a bare `#268` from inside
  soul.
- **Spot-check a subset, not every link.** Before sending a report with many numbers,
  resolve two or three through `gh` — the ones you typed from memory or whose type you
  inferred — and let the rest ride. Checking all of them would slow every message; checking
  none is how a wrong repo or an issue-path link to a PR ships. Measured 2026-09-05: three
  constructed links checked against `gh`, two matched, one was a PR filed under the issue
  path.
- **Scope is messages to the user** — terminal replies, the compact-prep report, PR and
  issue bodies where a reader lands from outside the repo. Commit messages and issue bodies
  read *on* GitHub autolink `#N` already; do not bloat those.

### Surface upstream defects; do not work around them

When a dependency or an external API misbehaves, surface it and ask rather than
coding around it. *"dont' do workarounds for things like zotero api problems. surface
and ask as there may be simple solution"* (airvine, 2026-09-03).

**Why:** a workaround hides the defect from whoever could fix it properly, and the user
often has upstream context or a simple fix the session lacks. Most of the dependencies
in question are **first-party** — an upstream bug is usually ours — so a local patch
is strictly worse than an issue: it leaves the bug in place for every other consumer
while making this repo look fine. Same instinct as `newgraph.md`'s "install missing
packages, don't workaround", applied to a *broken* dependency rather than a *missing*
one.

**How to apply:** reproduce it minimally, file an issue in the owning repo with the
repro and the exact lines, report it, and carry on if it is not blocking. The rule is
*do not hide it*, not *do not continue*: the day it was recorded, a search function
failed on a list column and broke a documented pipeline step; the local guard would
have taken minutes and hidden a bug affecting every consumer, so it was filed with a
three-line repro and the pipeline continued, since its data path did not use search.

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.


# pkgdown Publishing

What a pkgdown deploy puts on the public internet, and the two ways that has
already gone wrong.

## A pkgdown site publishes every root-level markdown file

`pkgdown:::package_mds()` renders **every** `.md` in the package root except a
hardcoded allowlist — `README`, `LICENSE`, `NEWS`, and two GitHub templates.
There is **no config option to exclude a file**.

So `CLAUDE.md` gets published. So would `INTERNAL.md`, `NOTES.md`, or a PWF
`task_plan.md` left at the root.

**Repo visibility does not protect you.** GitHub Pages serves publicly
regardless of whether the repo is private, and there is no private Pages mode
below Enterprise Cloud. A private repo with a pkgdown deploy has public docs.

Measured 2026-08-23: `CLAUDE.html` was live on six NGE sites. On `rfp` and `gq` —
both private repos, so their `CLAUDE.md` legitimately carried the internal-only
conventions — that put the SR&ED section on the public web: claim structure,
field code, fiscal year, and the consultant by name.

The visibility filter was working correctly the whole time. It rests on an
assumption pkgdown breaks: that a private repo's `CLAUDE.md` stays private.

### Remove it before the build, not after

There are three copies, not one:

| file | what it is |
|---|---|
| `CLAUDE.html` | the rendered page |
| `CLAUDE.md` | a **verbatim copy of the source**, served as-is |
| `search.json` | the full-text index, containing the text |

Deleting `docs/CLAUDE.html` after the build leaves the other two. It looks like a
fix and achieves nothing. Remove the file from the CI checkout **before**
`build_site()` runs:

```yaml
- name: Keep internal notes out of the published site
  run: rm -f CLAUDE.md
```

### Gate on a declared allowlist

Each repo states which extra root pages it *intends* to publish. Anything else
fails the build, so a new root markdown file cannot leak silently:

```yaml
- name: Fail if an unexpected page reached the site
  run: |
    allowed="404 authors index LICENSE LICENSE-text"   # + declared extras
    ...
```

Add to `allowed` only after deciding the page should be public. `link` publishes
`NOTICE` and `RUNBOOK` deliberately — it is a public repo and both are genuine
documentation. That is the decision the allowlist is meant to record.

Test the gate against **both** known answers before shipping it: it must exit
non-zero on a site that does contain the file, and zero on one that does not. A
guard that only ever returns one value is indistinguishable from a broken one.

## Deploy with `clean: true`

`JamesIves/github-pages-deploy-action` defaults matter here. With
`clean: false`, the action **never deletes** — every file ever deployed stays on
`gh-pages` forever, whether or not the source still produces it.

Two consequences, both observed:

- Removing a file from the repo does **not** unpublish it. Measured on `gq`:
  `task_plan.html`, `progress.html` and `findings.html` were still returning 200
  long after the PWF documents had been moved out of the root.
- A leak cannot be fixed by fixing the build. The stale copies need a separate
  explicit purge, which is a step people forget.

`clean: true` makes the deployed site equal to what the build produced, so
removing a file from source removes it from the web on the next deploy. That is
the property you want, and it makes the site auditable.

### Check before flipping it

`clean: true` deletes anything on `gh-pages` not present in `docs/`. Confirm
none of these exist first:

- **`CNAME`** — a custom domain file would be deleted and the domain would break.
  (NGE repos have none; the domain comes from the org site repo, and project
  sites inherit it as subpaths.)
- **`dev/`** — versioned docs from `development: mode: devel`, if the deploying
  build is not the dev one.
- **hand-added assets** not produced by the build. Favicons and web manifests
  under `pkgdown/favicon/` *are* produced by the build and are safe.

Use `clean-exclude` for anything that must survive.

```bash
gh api "repos/OWNER/REPO/contents?ref=gh-pages" --jq '.[] | "\(.type) \(.name)"'
```

## Removing something already published

1. **Stop generating it** — the pre-build removal above.
2. **Remove the deployed copy** — automatic once `clean: true` is in; otherwise
   an explicit purge.
3. **De-index** — a Search Console removal request per property, *after* the URL
   404s.

Do **not** add a `robots.txt` block first. Blocking crawl prevents crawlers from
seeing the 404, which keeps stale search entries alive longer than doing
nothing.

`gh-pages` history is not a problem the way normal git history is: on a private
repo the branch is not publicly browsable, and only the currently-served content
is public. Deleting the file genuinely ends the exposure — no history rewriting.

## pkgdown drops a footnote's body and keeps its marker

A pandoc footnote — `text[^k]` with a `[^k]: …` block — renders in an article as a
**superscript marker with no footnote section under it**. The marker is emitted
(`class="footnote-ref"`), the content is not, and nothing warns.

So the failure is silent and lands on exactly the material a footnote is for: the caveat, the
definition, the reconciliation. Measured 2026-09-06 in drift#66, where a footnote carrying the
reconciliation of two circulating hectare totals — the sentence that stops a reader treating them
as a disagreement — was absent from the published page while `rmarkdown::render()` of the same
source showed it fine.

- **Do not write footnotes in a pkgdown article.** Promote the content to a block quote, a
  parenthetical, or its own short paragraph. If it is worth a footnote it is usually worth being
  visible.
- **Check the rendered HTML, not the source.** The tell is a marker with nothing to jump to:

  ```bash
  grep -c 'footnote-ref' docs/articles/<name>.html     # markers emitted
  grep -c 'class="footnotes' docs/articles/<name>.html # section emitted — expect these to agree
  ```

Same family as the cross-reference gotcha already noted for vignettes (`\@ref(fig:…)` compiling
to a literal): bookdown output formats do not carry all of bookdown's machinery through pkgdown,
and each missing piece fails quietly in its own way. Verify anything structural — footnotes,
cross-references, numbered captions — against the built page the first time you use it.


# Planning Conventions

How Claude manages structured planning for complex tasks using planning-with-files (PWF).

## When to Plan

Use PWF when a task has multiple phases, requires research, or involves more than ~5 tool calls. Triggers:
- User says "let's plan this", "plan mode", "use planning", or invokes `/planning-init`
- Complex issue work begins (multi-step, uncertain approach)
- Claude judges the task warrants structured tracking

Skip planning for single-file edits, quick fixes, or tasks with obvious next steps.

## The Workflow

1. **Explore first** — Enter plan mode (read-only). Read code, trace paths, understand the problem before proposing anything. When the work codifies a pattern that already exists in multiple places (reference implementations across repos), read **every** reference in full, not just the canonical one — variation across references surfaces patches before v0.1 instead of as churn later (soul#52: reading all 4 references preempted 5 of the 7 fixes a dry-run would have found). Don't substitute Explore-agent summaries for direct reads; agents sometimes report existing files as absent.
2. **Plan to files** — Write the plan into 3 files in `planning/active/`:
   - `task_plan.md` — Phases with checkbox tasks
   - `findings.md` — Research, discoveries, technical analysis
   - `progress.md` — Session log with timestamps and commit refs
3. **Plan-review with the Plan agent — concurrently, not as a gate** — Once `task_plan.md` is scaffolded, spawn the Plan subagent (`Agent({subagent_type: "Plan", prompt: "..."}`) and ask it to critically review the task_plan against the issue body + actual codebase. Categorize findings as Blocker / Gap / Ordering / Assumption / Scope / Acceptance. The agent reads files fresh — it catches what you miss when you've been thinking about the design too long. Real example: caught 21 issues including hardcoded literals across 4 files not listed in the plan, untested DB column mismatches, and a baseline-cache-shadow that would have produced a 6-second no-op run.

   **Do not wait for it.** Spawn, then start the lowest-risk phase. Background agents have repeatedly returned late — in one case after the entire issue had shipped — so treating the review as a precondition stalls the work for as long as the agent takes (see `karpathy.md` §6). Fold findings in whenever they land: pre-baseline they edit the plan; mid-implementation they become follow-up commits — unless the finding is a stored-data fork of the kind `karpathy.md` §8 reserves for the user. A review that arrives after the code is written is not wasted — the reviewer reads real code instead of a plan, which is how one late review still contributed three fixes that no earlier reading had found. If you genuinely cannot proceed without the result, run it with `run_in_background: false` so the blocking is explicit.

   Verify before acting, in both directions. Findings have been confidently wrong (a "BLOCKER" disproved by a 30-second probe) and confidently right about things nobody suspected. Reproduce the claim first.

   **"Both directions" includes the reviewer's conclusions, not just its findings.**
   A review is wrong in the *alarming* direction loudly — a BLOCKER you probe and
   disprove costs one round-trip. It is wrong in the *reassuring* direction
   silently, because nothing prompts you to check a sentence telling you that you
   are finished. Measured 2026-08-30 in gq#77: round 4 fixed its own finding and
   characterised the residual as "definitional". Two commands showed it was not —
   the leftover axis had exactly one member and no margin, the same shape as the
   instance that reviewer had just fixed. Treat *"this is now terminal / complete /
   definitional"* as a claim with an author, exactly like an issue asserting a
   question can only be answered by testing.

   Corollary on when to stop: **convergence is not a reviewer saying you have
   converged.** Across four rounds on that PR, five instances of one defect class
   were found, and three separate "this is terminal now" claims — two of them mine
   — were wrong. What ended it was enumerating the complete candidate set and
   showing nothing sat above its source, not another round.

   **Spawn review agents UNNAMED.** Passing `name` to the `Agent` tool changes what you get: a named spawn becomes a persistent *teammate* that goes **idle** rather than completing, so there is no final report to auto-deliver and its output must be pulled with `SendMessage`. An unnamed spawn is a fire-and-return subagent whose report arrives on its own in the completion notification. Measured 2026-08-25 on one machine, one session, unchanged settings: the unnamed spawn returned in **6.4s**; three named reviewers returned nothing at all, sending only empty idle pings. Pass `name` only for a collaborator you intend to keep messaging, and shut it down when done — it pings indefinitely otherwise.

   That mis-spawn is what produced the silent-delivery failures below, so check `name` before suspecting settings. Teammate mode (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` + `teammateMode`, merged globally from `soul/settings/defaults.json`) shapes what a *named* spawn becomes; it is not by itself why findings go missing, and an unnamed spawn delivers fine with it enabled.

   **Get the findings into a file — but check who is doing the writing.** Message delivery has silently failed twice: one review arrived as idle notifications with no content, and one was routed to a different session on the user's phone, surfacing only because the user mentioned it. From this side an idle ping is indistinguishable from an agent that had nothing to say, so the loss is invisible. A file (`planning/active/review-<N>.md`) survives routing, survives the agent exiting, and is greppable later.

   **The `Plan` and `Explore` agent types have no Write tool, so they cannot write that file.** Both plan reviews on 2026-08-26 (gq#61, gq#40) were instructed to and were structurally unable to; one said so outright — *"I have no Write/Edit tools and am explicitly barred from creating files; an agent instruction can't lift that"* — and returned the full review as reply text instead. Both arrived intact, ~26 findings each. So:

   - **Read-only agent** (`Plan`, `Explore`): ask for the findings **in the reply**, then write them to `planning/active/review-<N>.md` yourself. The file is still the deliverable; you are just the one creating it.
   - **Agent type that can write**: put the file-path instruction in the first prompt, not as a follow-up.

   Asking for a file the agent cannot produce costs a round-trip, and — worse — sets you up to read an absent file as an absent review. Check the agent type's tools before writing the instruction.

   **Review the fixes, not just the code.** The second pass is where the value concentrates, because a fix written under a wrong assumption reproduces the same defect. Measured on gq#52: pass 1 found 13 defects, pass 2 found 7 more — including a blocker sitting *inside the fix* for pass 1's blocker, the same class twice (`lty`, then `fill_alpha`) because completeness was reasoned about rather than computed. Pass 3, scoped narrowly to the file edited most, found no new instances; **convergence is the signal to stop, not a fixed number of rounds.**

   Convergence is measured, not felt — a quiet round and an exhausted reviewer look
   identical. The rule that terminated trap#28 (five rounds; each of the first four
   found its best defect *inside the previous round's fix*) was to **enumerate the
   candidate set mechanically and show nothing sits above its source of truth**: parse
   the files and walk every `cli_abort`/`warning`/`stop` rather than recalling them, so
   "all of them are pinned" is a count. `code-check.md` states it under "A guard's
   scope, escape hatches, and remedies" — terminate by enumeration, not by a reviewer
   saying you have converged. `/code-check` treats three rounds as the floor and keeps
   going while a round finds a defect inside the previous fix.

   Ask for the **mechanism**, not more instances. Pass 3's best finding was that an invariant was enforced by two lists happening to agree — which is what had produced instances two and three.

   The thing reviewers catch that self-probing does not is **interop**: 18 tests inspected a legend object and none handed it to the renderer, which rejected it outright. Ask the consumer.
4. **Lock naming before the baseline** — If naming feedback surfaces during planning (legacy filename, inconsistency with an existing file family), fold the rename into the convention + task_plan BEFORE the baseline commit, not as a follow-up. Pre-baseline it's free; retrofitting after implementation cascades (soul#52: `build_exec_pdf.R` → `run_pagedown_exec_summary.R` locked in pre-baseline meant zero downstream rework).
5. **Commit the plan** — After Plan-agent review + fixes. This is the baseline.
6. **Work in atomic commits** — Each commit bundles code changes WITH checkbox updates in the planning files. The diff shows both what was done and the checkbox marking it done.
7. **Code check before commit** — Run `/code-check` on staged diffs before committing. Don't mark a task done until the diff passes review.
8. **Archive when complete** — Move `planning/active/` to `planning/archive/` via `/planning-archive`. Write a README.md in the archive directory with a one-paragraph outcome summary and closing commit/PR ref — future sessions scan these to catch up fast. Where the work produced measurements, that README is also the evidence record; see below.

## The archive README is the measurement record

Debugging and benchmarking sessions are systematic investigation: a stated unknown, an
experiment, a number, a conclusion, and usually two or three informative dead ends. That
is SRED evidence, and it scatters — into PR bodies, issue comments, and log files whose
names encode a timestamp and nothing else. In six months the chain *we did not know X,
we measured Y, therefore Z* survives only in a chat transcript.

**The archive README is where that chain lives.** Not a separate run record: the PWF
triple already holds every part of it — the question in `task_plan.md`'s frame, the
method in `progress.md`, the numbers in `findings.md`, the dead ends in its "Errors
Encountered" table. A second document would restate all of it and be half-populated.
The README is the index over them.

So an archive README for work that produced measurements carries two more sections:

```markdown
## Measurement

m1 0.0391 vs cypher 0.0872 min/1k segments — hosts are 2.23x apart.
Moved the provincial estimate 5.0 h -> 4.3 h and changed how work packs across machines.

## Evidence

`data-raw/logs/study_area_run/20260831_19*` — four spins, one defect each.
```

Three rules on those sections:

- **Numbers carry units, and say what changed because of them.** A measurement nobody
  acted on is still worth recording if it turned an assumption into a number — say that
  too. "Confirmed the expected" is a real outcome.
- **Cite a prefix or glob, never a file list.** A list rots the moment a run is re-run;
  a prefix survives. This is why campaign subdirectories exist (`newgraph.md`, "Which
  logs to commit").
- **Keep the wrong turns.** A diagnosis made, retracted on a bad inference, then
  confirmed by measurement *is* the evidence of systematic investigation. Sanitising it
  into a tidy conclusion destroys exactly what makes the record worth keeping.

**The case this does not cover.** Measurement that predates an issue has no PWF to
attach to — `/planning-init` takes an issue number, and exploratory runs often *produce*
the issues rather than follow them. That measurement belongs in the issue or PR it
spawned, with the log directory's own README as the index. Do not build a third system
to close this gap. The *finding* it settles goes where every settled finding goes —
`research/`, next section — which is not a third record of the run but the one place its
verdict is kept current.

## `research/` — what is known, outliving the issue that found it

Three homes, one job each: **the PWF archive is the story, committed logs are the
measurements, `research/` is the durable verdict** — floodplains' `research/README.md`
had that framing before this section existed. A research file holds what is now *known*: a
settled method, a measured fact about an external system, a search that established an
absence — so that someone picking the work up months later does not re-derive it.
`planning/archive/<issue>/` holds what was *done*, in order, for one issue, and is rarely
opened by anyone who never saw that issue. The research file is the one they will look for.

What does **not** go there: a work log; a run record (Run / Hardware / Software /
Configuration blocks — that is the archive README's `Measurement` and `Evidence`, above);
the raw numbers (committed logs). Measured 2026-09-06 across the seven repos carrying a
`research/`, 40 topic files: link's `provincial_parity_2026_05_*.md` are four run records in
25 days, each dated by the run it records and carrying that run's setup and metrics, while
its living documents, `bcfishpass_methodology.md`,
`study_area_run.md` and `provincial_run_runbook.md`, are single files revised as the
knowledge moved. The second shape is the one that moves the state of knowledge; the first
duplicates the archive.

### One topic file, revised in place — git is the version record

`research/<topic>.md`, noun-first, **no date in the filename**. A new measurement that
changes what is known revises the topic file; it does not add a dated sibling.
`git log --follow research/<topic>.md` is the dated history, the archive README it cites
is the *why*, and the logs are the numbers — everything an R&D claim needs, with no second
copy of any of it.

Existing dated files — `20260711_…`, `…_2026_05_25.md` — are **not renamed**. They are
cited by path from `CLAUDE.md` files and from other conventions (`bookdown.md`,
`karpathy.md` §7), and a rename breaks the citation the way it breaks log evidence
(`newgraph.md`, "Which logs to commit"). Convergence is forward-only, and the README says
when.

### The header is the provenance, in prose

No research file in any repo carries YAML frontmatter and nothing consumes it, so
provenance is one line under the H1. floodplains' is the shape to adapt — it already carries
the date and the issues, and names its log prefix in the body:

```markdown
**Date opened:** 2026-07-11 · **Issue:** #8 · **drift:** 0.6.0 (`dft_stac_fetch(tile_size=)`,
drift#36) · **Status:** OPEN — design set, runs pending.
```

Three things the line must carry — `**Verified:** <date> · **Issues:** … · **Produced by:** …`
is the minimal form:

- **When it was last true.** The file's date, and a section-level date wherever one
  section is re-verified alone. A research file whose numbers cannot be re-derived ages
  into folklore, and one that states a scope or a quantity drifts silently when the code
  moves — three link documents, two of them research files, asserted a recompute "runs over
  every WSG in the schema" after two commits had changed it (`karpathy.md` §7, "Documents
  that share an ancestor corroborate nothing"). When code changes a behaviour a research
  file describes, grep `research/` for the sentence. Files written before 2026-09-06 gain
  the line when next revised; no fleet sweep is required.
- **What produced it.** The script path or log prefix for a measurement; the source list or
  reference-manager collection for a literature review. Never a number without its producer.
- **Which issues it came from and which it spawned.** The issue body links the research
  file (`feature-workflow.md`, "Issue bodies get edited, not appended"); the research file
  names its issues; and an archive README whose `Measurement` was distilled into a research
  file links it. Both ways, every time — one direction leaves the other end unfindable.

### The directory carries a README

An index: one row per file, what it covers — rfp's is the model. Where other repos hold
related work, a "Related work" list of links. Where two naming patterns coexist, the
cutover line in the form `newgraph.md` uses for logs:

```markdown
Naming: `<topic>.md`, revised in place, from 2026-09-06.
Files dated before that carry a `yyyymmdd_` prefix; they are not being renamed.
```

The README is the index. `CLAUDE.md` links the README once and cites an individual file
only where a rule depends on it. Twenty-three topic files with no README and a `CLAUDE.md`
citing four of them by path — link, measured 2026-09-06 — is the state this prevents.

### R packages and public repos

`research/` is top-level and excluded from the tarball: `^research$` in `.Rbuildignore`
(`code-check-r.md`, "`R CMD build` ships every top-level directory not in
`.Rbuildignore`"). Not `inst/notes/` or `inst/research/`, which ship inside the installed
package — the three packages carrying those (eight files, 2026-09-06) migrate by issue,
forward-only. In a package, `research/` is also where durable reference notes go, because
`docs/` belongs to pkgdown and `inst/` ships. And a public tool repo's `research/` is
public: report findings from internal work aggregated, never by the names of who it was for.

## Atomic Commits (Critical)

Every commit that completes a planned task MUST include:
- The code/script changes
- The checkbox update in `task_plan.md` (`- [ ]` -> `- [x]`)
- A progress entry in `progress.md` if meaningful

This creates a git audit trail where `git log -- planning/` tells the full story. Each commit is self-documenting — you can backtrack with git and understand everything that happened.

## File Formats

### task_plan.md

Phases with checkboxes. This is the core tracking file.

```markdown
# Task: <issue title> (#<N>)

<issue body — Problem section if present, otherwise first paragraph>

## Phase 1: [Name]
- [ ] Task description
- [ ] Another task

## Phase 2: [Name]
- [ ] Task description
```

Mark tasks done as they're completed: `- [x] Task description`

### findings.md

Append-only research log. Discoveries, technical analysis, things learned.

```markdown
# Findings

## [Topic]
[What was found, with source/date]

## Errors Encountered

| Error | Resolution |
|-------|------------|
```

### progress.md

Session entries with commit references.

```markdown
# Progress

## Session YYYY-MM-DD
- Completed: [items]
- Commits: [refs]
- Next: [items]
```

<!-- The Reboot Test and the error ledger below are adapted from -->
<!-- OthmanAdi/planning-with-files (MIT). Soul does not install or invoke that -->
<!-- plugin — the useful parts are carried here as text. Adapted 2026-08-26. -->
<!-- Same precedent as the attribution header in karpathy.md. -->

## The Reboot Test

The planning files exist so the work survives an interruption. Whether they
actually do is checkable: at any point mid-task, these five questions must be
answerable from the files alone, without the conversation.

| Question | Answer source |
|----------|---------------|
| Where am I? | Current phase in `task_plan.md` |
| Where am I going? | Remaining phases in `task_plan.md` |
| What's the goal? | The `# Task: <title> (#N)` frame and problem statement at the top of `task_plan.md` |
| What have I learned? | `findings.md` |
| What have I done? | `progress.md` |

If an answer lives only in the session, **write it down and commit it**. Written
is not sufficient: an uncommitted `findings.md` does not move between machines,
and a repo whose `planning/` is gitignored accepts `git add planning/` with exit
0 while tracking nothing — see Directory Structure below.

This is the operational check for the rule that every interruption should be a
resume point: a session death, sleep, or machine swap should cost a re-run at
most, never lost context. That rule states the goal; this tests it.

Run it before any long wait, before compaction, and before switching machines —
the moments that take a session without warning. `/compact-prep` and
`/planning-update` are where it gets run; this section is what it asks.

## Directory Structure

```
planning/
  active/          <- Current work (3 PWF files)
  archive/         <- Completed issues
    YYYY-MM-issue-N-slug/
```

If `planning/` doesn't exist in the repo, run `/planning-init` first.

**`planning/active/` must be tracked, not gitignored.** The atomic-commit rule
above requires each commit to carry its own checkbox flip in `task_plan.md`; an
ignored `active/` drops it silently, so `git log -- planning/` shows archives
appearing fully-formed with no history behind them. In-flight PWF also stops
surviving a move between machines.

The failure is quiet in both directions. `git add planning/` reports nothing and
exits 0 on an ignored path, and files tracked *before* the rule existed keep
being tracked — including through a `git mv` into the ignored directory. So a
repo can look like it is working right up until the first genuinely new PWF file,
which simply never appears in a commit.

Check rather than assume:

```bash
git check-ignore -v planning/active/task_plan.md   # expect no output
```

Found 2026-08-24 in gq, where the rule dated from the scaffold commit and the
#17 files had only survived because they predated their move into that
directory. gq and roli were the only 2 of 32 repos carrying it; roli still does.

## When Something Keeps Failing

Before a second attempt, name the failure class. A **deterministic** failure
returns the same result to the same inputs, so re-running unchanged only spends a
turn — change the inputs or change the approach. A **transient** failure
(network, a provider read, a rate limit, a resource still settling) is the case
where a re-run *is* the attempt: `code-check-infra.md` prescribes exactly that for a
tofu plan that falsely reports a resource deleted. The rule is not "never retry";
it is never retry unchanged while expecting a different answer.

Escalate rather than iterate once the approach itself is in question. Report what
was tried and the exact error, and hand over the commands to run — the user is
assumed to be away, so a question answerable from a phone beats a retry loop they
cannot see. Escalating is not stopping: commit the current state, then move to
the lowest-risk independent part of the plan while the question is outstanding.

Two classes escalate immediately rather than after retries, because further
attempts make them worse:

- **A clamped session.** Once a live credential has been read, later
  system-mutating commands are refused regardless of route — seven consecutive
  refusals across unrelated routes is the documented case (`newgraph.md`,
  "Reading a secret clamps the rest of the session"). Trying more phrasings is
  the failure mode, not the remedy, and `/permissions` does not clear it.
- **Rate limits.** Retrying extends the block (`ci-monitoring.md`).

### Log the errors that cost a retry

An error that took more than one attempt to get past goes in `findings.md`, so
one task does not hit the same wall twice:

```markdown
## Errors Encountered

| Error | Resolution |
|-------|------------|
| `fatal: Unimplemented pathspec magic '_'` | Long-form `:(exclude)path` |
```

That row is also what graduation looks like: it began as one task's blocker and
now lives in `code-check-shell.md` as a general rule about pathspec magic. Most rows
never make that trip and should not — the ledger's job is to stop one task
repeating itself.

When a failure does generalize, it graduates to the convention that owns its
class: the `code-check*.md` family for a bug class in a diff — `code-check.md` for a
mechanism, `-shell`, `-r`, `-spatial` or `-infra` for a tool quirk — `ci-monitoring.md` for CI
behaviour, the domain convention otherwise.

## Skills

| Skill | When to use |
|-------|-------------|
| `/planning-init` | First time in a repo — creates directory structure |
| `/planning-update` | Mid-session — sync checkboxes and progress |
| `/planning-archive` | Issue complete — archive and create fresh active/ |


# R Package Development Conventions

Standards for R package development across New Graph Environment repositories.
Based on [R Packages (2e)](https://r-pkgs.org/) by Hadley Wickham and Jenny Bryan.

**Reference packages:** When starting a new package, study these existing
packages for patterns: `flooded`, `gq`. They demonstrate the conventions below
in practice (DESCRIPTION fields, README layout, NEWS.md style, pkgdown setup,
test structure, hex sticker, etc.).

## Style

- tidyverse style guide: snake_case, pipe operators (`|>` or `%>%`)
- Match existing patterns in each codebase
- Use `pak` for package installation (not `install.packages`)
- Prefer `fs::` helpers over base R for filesystem path operations in build
  scripts and scaffolds: `fs::dir_create()` (creates parents by default, no
  `recursive`/`showWarnings` fiddliness), `fs::path()`, `fs::file_delete()`,
  `fs::file_exists()`, `fs::path_file()`. Avoids cross-platform separator
  issues and silent no-ops on empty paths.
- Prefix column name vectors with `cols_` for discoverability in the
  environment pane: `cols_all`, `cols_carry`, `cols_split`, `cols_writable`.
  Same principle for other grouped vectors (`params_`, `tbl_`, etc.)
- For SQL DDL+INSERT pairs that share a schema, use a single named
  vector as the source of truth. Both `CREATE TABLE` and
  `INSERT (cols) SELECT cols` derive their column lists from the same
  `cols_*` vector. Avoids drift between table shape and write
  projection — when columns change, you edit one place. Example:
  ```r
  cols_streams <- c(
    id_segment           = "integer NOT NULL",
    watershed_group_code = "varchar(4) NOT NULL",
    geom                 = "geometry(MultiLineStringZM, 3005)"
    # …
  )
  # CREATE TABLE consumes both names + types
  ddl_body <- paste(names(cols_streams), unname(cols_streams), sep = " ",
                    collapse = ", ")
  # INSERT consumes names only
  proj <- paste(names(cols_streams), collapse = ", ")
  ```

## Package Structure

Follow R Packages (2e) conventions:
- `R/` for functions, `tests/testthat/` for tests, `man/` for docs
- `DESCRIPTION` with proper fields (Title, Description, Authors@R)
- `DESCRIPTION` URL field: include both the GitHub repo and the pkgdown site
  so pkgdown links correctly (e.g., `URL: https://github.com/OWNER/PKG,
  https://owner.github.io/PKG/`)
- `NAMESPACE` managed by roxygen2 (`#' @export`, `#' @import`, `#' @importFrom`)
- Never edit `NAMESPACE` or `man/` by hand

## One Function, One File

Each exported function gets its own R file and its own test file:
- `R/fl_mask.R` → `tests/testthat/test-fl_mask.R`
- Commit the function and its tests together
- Use `Fixes #N` in the commit message to close the corresponding issue

## GitHub Issues and SRED Tracking

### Issue-per-function workflow

File a GitHub issue for each function before building it. This creates a
traceable record of what was planned, built, and verified.

### Branching for SRED

For new packages or major features, work on a branch and merge via PR:

```
main ← scaffold-branch (PR closes with "Relates to NewGraphEnvironment/sred#N")
```

This gives one PR that contains all commits — a single SRED cross-reference
covers the entire body of work. Individual commits within the branch close
their respective function issues with `Fixes #N`.

### Closing issues

Close function issues via commit messages — see Closing Issues in newgraph conventions.

## Testing

- Use testthat 3e (`Config/testthat/edition: 3` in DESCRIPTION)
- Run `devtools::test()` before committing
- Test files mirror source: `R/utils.R` -> `tests/testthat/test-utils.R`
- Test for edge cases and potential failures, not just happy paths
- Tests must pass before closing the function's issue
- Always grep for errors in the same command as the test run to avoid
  running twice:
  ```bash
  Rscript -e 'devtools::test()' 2>&1 | grep -E "(FAIL|ERROR|PASS)" | tail -5
  ```
  For error context: `grep -E "(ERROR:|FAIL )" -A 10 | head -25`

### Common pitfalls

- **`cli::cli_alert_warning()` is not `warning()`.** It's visual only —
  callers can't catch it with `withCallingHandlers(warning = ...)` and
  testthat's `expect_warning()` won't fire. When a function offers a
  `warn` mode that callers may want to react to programmatically, use
  `warning()`. Reserve `cli_alert_warning()` for FYI messages with no
  programmatic contract.

- **`expect_match(x, ..., all = FALSE)` passes silently on `character(0)`.**
  If the input is empty (e.g. no warnings fired), the assertion succeeds
  vacuously and defeats the test. Always pair with
  `expect_gt(length(x), 0)` first when input may be empty.

- **`skip_on_cran()` does not skip on GitHub Actions.** It skips when
  `NOT_CRAN` is unset — and `devtools`, `usethis`'s check workflow and
  `r-lib/actions` all set `NOT_CRAN=true`, precisely so your tests *do* run in
  CI. So a network test guarded only by `skip_on_cran()` runs on every push,
  and any upstream hiccup reddens the build for a reason unrelated to the
  change under review.
  - Use **`skip_on_ci()`** for a test that is meant for a human's machine — a
    live canary against a third-party service, something slow, anything whose
    failure needs a person to interpret it.
  - `skip_if_offline()` is not a substitute: it tests whether the network is
    reachable, not whether the *service* is behaving, and it calls
    `skip_if_not_installed("curl")`, so add `curl` to Suggests or the guard
    itself is what breaks.
  - Caught 2026-08 in gq#57 by self-review: a comment claiming "skipped off-CI"
    sat directly above code that did not skip off-CI. Read the guard, not the
    comment above it.

- **`testthat::test_file()` does NOT set `NOT_CRAN`, so re-running one file to
  diagnose a failure can execute none of it.** The mirror of the rule above, and
  the more dangerous direction: `devtools::test()` sets `NOT_CRAN=true`, so a
  `skip_on_cran()`-guarded test runs there and fails; re-running that same file
  with `testthat::test_file()` to investigate reports `SKIP` and looks like
  exoneration.

  ```
  devtools::test()                 -> [ FAIL 1 | PASS 4495 ]
  testthat::test_file("that.R")    -> [ FAIL 0 | SKIP 6 ]   Reason: On CRAN
  NOT_CRAN=true testthat::test_file("that.R") -> [ FAIL 0 | PASS 259 ]
  ```

  Only the third line is evidence. Measured twice on 2026-09-01 in rfp, both
  times while confirming whether a Docker-gated failure was a real regression —
  which is exactly when a false "it passes now" is most expensive. Prefix
  `NOT_CRAN=true` on any single-file re-run, or read the SKIP count rather than
  the FAIL count.

- **`local_mocked_bindings(.package = )` needs testthat >= 3.2.0.** A package
  pinned at `testthat (>= 3.0.0)` errors rather than skipping on an older
  install. Bump the pin when you first mock another package's binding.

## Examples and Vignettes

### Runnable examples on every exported function

Examples are how users discover what a function does. They must:
- **Actually run** — no `\dontrun{}` unless external resources are required
- **Use bundled test data** via `system.file()` so they work for anyone
- **Show why the function is useful** — not just that it runs, but what it
  produces and why you'd use it
- **Use qualified names** for non-exported dependencies (`terra::rast()`,
  `sf::st_read()`) since examples run in the user's environment

### Vignettes

At least one vignette showing the full pipeline on real data:
- Demonstrates the package solving an actual problem end-to-end
- Uses bundled test data (committed to `inst/testdata/`)
- Hosted on pkgdown so users can read it without installing

**Output format:** Use `bookdown::html_vignette2` (not
`rmarkdown::html_vignette`) for figure numbering. Requires `bookdown` in
Suggests and chunks must have `fig.cap` / `caption =` for numbered
figures and tables.

**Gotcha — cross-references don't resolve in vignettes.** `Table \@ref(tab:foo)`
and `Figure \@ref(fig:foo)` markers compile to a literal `\@ref(...)` in
the rendered HTML rather than a numbered link. Bookdown's cross-ref
machinery isn't fully wired through `html_vignette2` under pkgdown.
Use natural language instead — "the table below", "the floodplain map",
"the parameter table" — and let the captions speak for themselves. If
you need real numbered cross-refs, use `bookdown::html_document2`
(matches the cd-style report-appendix pattern) and accept that the
output is no longer a true package vignette.

**Vignettes that need external resources (DB, API, STAC):** Do NOT use
the `.Rmd.orig` pre-knit pattern — it breaks `bookdown` figure numbering
because knitr evaluates chunks during pre-knit and emits `![](path)`
markdown that bookdown can't number.

Instead, separate data generation from presentation:
1. `data-raw/vignette_data.R` — runs the queries, saves results as `.rds`
   to `inst/testdata/` (or `inst/vignette-data/`)
2. Vignette loads `.rds` files, all chunks run live during pkgdown build
3. Note at top of vignette: "Data generated by `data-raw/script.R`"
4. bookdown controls all chunks — figure numbers, cross-refs work

This is the same pattern as test data: `data-raw/` documents how the data
was produced, committed artifacts make vignettes reproducible without the
external resource.

### Test data

- Created via a script in `data-raw/` that documents exactly how the data
  was produced (database queries, spatial crops, etc.)
- Committed to `inst/testdata/` — small enough to ship with the package
- Used by tests, examples, and vignettes — one dataset, three purposes

## Documentation

- roxygen2 for all exported functions
- `@import` or `@importFrom` in the package-level doc (`R/<pkg>-package.R`)
  to populate NAMESPACE — don't rely on `::` everywhere in function bodies
- pkgdown site for public packages with `_pkgdown.yml` (bootstrap 5)
- GitHub Action for pkgdown (`usethis::use_github_action("pkgdown")`)

## lintr

Run `lintr::lint_package()` before committing R package code. Fix all warnings — every lint should be worth fixing.

### Recommended .lintr config

```r
linters: linters_with_defaults(
    line_length_linter(120),
    object_name_linter(styles = c("snake_case", "dotted.case")),
    commented_code_linter = NULL
  )
exclusions: list(
    "renv" = list(linters = "all")
  )
```

- 120 char line length (default 80 is too strict for data pipelines)
- Allow dotted.case (common in base R and legacy code)
- Suppress commented code lints (exploratory R scripts often have commented alternatives)
- Exclude renv directory entirely

## Dependencies

- Minimize Imports — use `Suggests` for packages only needed in tests/vignettes
- Pin versions only when breaking changes are known
- Prefer packages already in the tidyverse ecosystem

## Releasing

1. Update `NEWS.md` — keep it concise:
   - First release: one line (e.g., "Initial release. Brief description.")
   - Later releases: describe what changed and why, not function-by-function.
     Link to the pkgdown reference page for details — don't duplicate it.
   - Don't list every function; the pkgdown reference page is the single
     source of truth for what's in the package.
2. Bump version in `DESCRIPTION` (e.g., `0.0.0.9000` → `0.1.0`) — as the **final** commit of the branch, after verification numbers/tests are final. Mid-branch bumps are premature and churn: additional code changes end up bundled inside a "release" that already claimed the version.
3. Commit as "Release vX.Y.Z"
4. Tag: `git tag vX.Y.Z && git push && git push --tags`

## Repository Setup

### Branch protection

Protect main from deletion and force pushes:

```bash
gh api repos/OWNER/REPO/rulesets --method POST --input - <<'EOF'
{
  "name": "Protect main",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [
    { "actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always" }
  ],
  "conditions": { "ref_name": { "include": ["refs/heads/main"], "exclude": [] } },
  "rules": [ { "type": "deletion" }, { "type": "non_fast_forward" } ]
}
EOF
```

### Scaffold checklist

- `usethis::create_package(".")`
- `usethis::use_mit_license("New Graph Environment Ltd.")`
- `usethis::use_testthat(edition = 3)`
- `usethis::use_pkgdown()`
- `usethis::use_github_action("pkgdown")`
- `usethis::use_directory("dev")` — reproducible setup script
- `usethis::use_directory("data-raw")` — data generation scripts
- Hex sticker via `hexSticker` (see `data-raw/make_hexsticker.R`)
- Set GitHub Pages to serve from `gh-pages` branch

### dev/dev.R

Keep a `dev/dev.R` file that documents every setup step. Not idempotent —
run interactively. This is the reproducible recipe for the package scaffold.

## README

Keep the README lean:
- Hex sticker, one-line description, install, example showing *why* it's
  useful
- Link to pkgdown vignette and function reference — don't duplicate them
- Don't maintain a function table — it's just another thing to keep updated
  and pkgdown's reference page is the single source of truth

## LLM Workflow

When an LLM assistant modifies R package code:
1. Run `lintr::lint_package()` — fix issues before committing
2. Run `devtools::test()` with error grep — ensure tests pass in one call:
   ```bash
   Rscript -e 'devtools::test()' 2>&1 | grep -E "(FAIL|ERROR|PASS)" | tail -5
   ```
3. Run `devtools::document()` and grep for results:
   ```bash
   Rscript -e 'devtools::document()' 2>&1 | grep -E "(Writing|Updating|warning)" | tail -10
   ```
4. If the repo has a `_pkgdown.yml`, run `Rscript -e 'pkgdown::check_pkgdown()'`
   after adding or removing an export. A new export missing from the reference
   index is an **error**, not a note, so it reddens the pkgdown workflow after
   the PR is already open — the check costs a second locally and saves the round
   trip. (Adding to the index is usually right; `@keywords internal` is the
   alternative it names.)
5. Check `devtools::check()` passes for releases — capture results in one call:
   ```bash
   Rscript -e 'devtools::check()' 2>&1 | grep -E "(ERROR|WARNING|NOTE|errors|warnings|notes)" | tail -10
   ```


# Reference Management Conventions

How references flow between Claude Code, Zotero, and technical writing at New Graph Environment.

## Tool Routing

Three tools, different purposes. Use the right one.

| Need | Tool | Why |
|------|------|-----|
| Search by keyword, read metadata/fulltext, semantic search | **MCP `zotero_*` tools** | pyzotero, works with Zotero item keys |
| Look up by citation key (e.g., `irvine2020ParsnipRiver`) | **`/zotero-lookup` skill** | Citation keys are a BBT feature — pyzotero can't resolve them |
| Create items, attach PDFs, deduplicate | **`/zotero-api` skill** | Connector API for writes, JS console for attachments |

**Citation keys vs item keys:** Citation keys (like `irvine2020ParsnipRiver`) come from Better BibTeX. Item keys (like `K7WALMSY`) are native Zotero. The MCP works with item keys. `/zotero-lookup` bridges citation keys to item data.

**BBT citation key storage:** As of Feb 2025+, BBT stores citation keys as a `citationKey` field directly in `zotero.sqlite` (via Zotero's item data system), not in a separate BBT database. The old `better-bibtex.sqlite` and `better-bibtex.migrated` files are stale and no longer updated. Query citation keys with: `SELECT idv.value FROM items i JOIN itemData id ON i.itemID = id.itemID JOIN itemDataValues idv ON id.valueID = idv.valueID JOIN fields f ON id.fieldID = f.fieldID WHERE f.fieldName = 'citationKey'`.

**BBT citekey format is locally patched to strip `&`:** the `citekeyFormat` pref (`extensions.zotero.translators.better-bibtex.citekeyFormat` in `~/Library/Application Support/Zotero/Profiles/*/prefs.js`) has a `.replace(find = "&", replace = "")` segment added by hand. Without it, institutional authors containing `&` (e.g. "BC Species & Ecosystem Explorer", "WA Dept of Fish & Wildlife") leak `&` into the citekey, and pandoc's `@key` parser stops at `&` — so cites render broken in any bookdown/quarto build even though biblatex accepts the key. Reapply via Zotero → Tools → Run JavaScript: `Zotero.Prefs.set("translators.better-bibtex.citekeyFormat", val)` (also patch `citekeyFormatEditing` to match). Survives Zotero/BBT auto-updates; reverts only on a profile reset or a manual edit via the BBT preferences UI. Detect drift: `grep citekeyFormat ~/Library/Application\ Support/Zotero/Profiles/*/prefs.js` should show the `.replace(find = "&", ...)` chain. Teammates on Skeena/Fraser/restoration machines that hit the same `@key`-breaks-at-`&` drift should run the same `Zotero.Prefs.set`.

## Which routes are live by default

Measured 2026-09-04 on a freshly provisioned machine. Four of the six routes below were
dead, and each dead end costs a session time it has no reason to expect:

| route | state on a default setup |
|---|---|
| **Web API** | **works** — the route to use for writes; targets a collection directly via `"collections": [...]` and needs Zotero neither open nor restarted for the write itself |
| **read-only SQLite** | works, and remains the best route for *searching* (`/zotero-lookup`) |
| MCP `zotero_*` | unavailable until an API key is configured — the install script registers the server but never configures a key |
| Local API | `403 Local API is not enabled`, with and without the `Zotero-Allowed-Request` header |
| Connector `saveItems` | HTTP 500 on a minimal item with exactly the documented headers — a defect, not a permission; reads on the same port (`ping`, `getSelectedCollection`) are fine, and `getSelectedCollection` returns the whole collection tree in one call |
| JS runner (`zotero_run_js.sh`) | `osascript is not allowed assistive access` until the terminal has Accessibility |

**Zotero's server takes about 30 s after launch to respond.** An early failure does not
mean it is not running, which is exactly the wrong conclusion to draw at that moment —
wait and retry once before diagnosing.

The key's location, the password-manager item that holds it and the local port are
infrastructure identity and stay in machine-local memory, not here (soul#177).

## Citation keys are BBT-auto-derived

**Never set `Citation Key:` in the `extra` field.** BBT honours it as a manual override,
and that breaks the convention that every key follows one formula: stable, reproducible,
the same key for the same paper on every collaborator's machine. Leave `extra` empty, or
use it only for other Zotero-supported fields (`Original Date:`, `tex.shorttitle:`).
Ten items created with hand-set keys in one lit review (cd#58, 2026-05-05) had to be
PATCHed clean after the user caught it.

- **Web API-created items get no key until Zotero restarts.** Sync alone does not trigger
  BBT. On macOS:
  ```bash
  osascript -e 'tell application "Zotero" to quit'; sleep 3; open -a Zotero; sleep 30
  ```
  Thirty seconds covered seven fresh items (cd#61); scale the wait with the batch.
- **Corporate-author guard.** CrossRef sometimes returns no individual authors (a paper
  bylined to a working group), so the POST lands with empty `creators` and BBT falls back
  to a `<title-prefix><year>` key. PATCH the individual authors from the paper's roster
  into `creators` before triggering the restart.
- **BBT and Zotero version lines are paired** — BBT 8.x for Zotero 7, 9.x for Zotero 8/9.
  If Zotero auto-disables BBT after an update, keys silently stop generating for new
  items; reinstall the matching line via Plugin Manager → gear → "Install Plugin From
  File…" from the BBT releases page.

`/lit-search` and `/zotero-api` point here; this is the authority (soul#43).

## Adding References Workflow

### 1. Search and flag

When research turns up a reference:
- **DOI available:** Tell the user — Zotero's magic wand (DOI lookup) is the fastest path
- **ResearchGate link:** Flag to user for manual check — programmatic fetch is blocked (403), but full text is often there
- **BC gov report:** Search [ACAT](https://a100.gov.bc.ca/pub/acat/), for.gov.bc.ca library, EIRS viewer
- **Paywalled:** Note it, move on. Don't waste time trying to bypass.

### 2. Add to Zotero

**Preferred order:**
1. DOI magic wand in Zotero UI (fastest, most complete metadata)
2. Web API POST with `collections` array (grey literature, local PDFs — targets collection directly, no UI interaction needed)
3. `saveItems` via `/zotero-api` (batch creation from structured data — requires UI collection selection)
4. JS console script for group library (when connector can't target the right collection)

**Collection targeting:** `saveItems` drops items into whatever collection is selected in Zotero's UI. Always confirm with the user before calling it. **Web API bypasses this** — include `"collections": ["KEY"]` in the POST body. Find collection keys with `?q=name` search on the collections endpoint.

### 3. Attach PDFs

`saveItems` attachments silently fail. Don't use them. Instead:

1. **Web API S3 upload (preferred):** Create attachment item → get upload auth → build S3 body (Python: prefix + file bytes + suffix) → POST to S3 → register with uploadKey. Works without Zotero running. See `/zotero-api` skill section 4.
2. **JS console fallback:** Download with `curl`, attach via `item_attach_pdf.js` in Zotero JS console.
3. Verify attachment exists via MCP: `zotero_get_item_children`

### 4. Verify

After manual adds, confirm via MCP:
- `zotero_search_items` — find by title
- `zotero_get_item_metadata` — check fields are complete
- `zotero_get_item_children` — confirm PDF attached

### 5. Clean up

If duplicates were created (common with `saveItems` retries):
- Run `collection_dedup.js` via Zotero JS console
- It keeps the copy with the most attachments, trashes the rest

## In Reports (bookdown)

### Bibliography generation

```yaml
# index.Rmd — dynamic bib from Zotero via Better BibTeX
bibliography: "`r rbbt::bbt_write_bib('references.bib', overwrite = TRUE)`"
```

`rbbt` pulls from BBT, which syncs with Zotero. Edit references in Zotero → rebuild report → bibliography updates.

**Library targeting:** rbbt must know which Zotero library to search. This is set globally in `~/.Rprofile`:

```r
# default library — NewGraphEnvironment group (libraryID 9, group 4733734)
options(rbbt.default.library_id = 9)
```

Without this option, rbbt searches only the personal library (libraryID 1) and won't find group library references. The library IDs map to Zotero's internal numbering — use `/zotero-lookup` with `SELECT DISTINCT libraryID FROM citationkey` against the BBT database to discover available libraries.

### Citation syntax

- `[@key2020]` — parenthetical: (Author 2020)
- `@key2020` — narrative: Author (2020)
- `[@key1; @key2]` — multiple
- `nocite:` in YAML — include uncited references

### Cite primary sources

When a review paper references an older study, trace back to the original and cite it. Don't attribute findings to the review when the original exists. (See LLM Agent Conventions in `newgraph.md`.)

**When the original is unavailable** (paywalled, out of print, can't locate): use secondary citation format in the prose and include bib entries for both sources:

> Smith et al. (2003; as cited in Doctor 2022) found that...

Both `@smith2003` and `@doctor2022` go in the `.bib` file. The reader can then track down the original themselves. Flag incomplete metadata on the primary entry — it's better to have a partial reference than none at all.

## PDF Fallback Chain

When you need a PDF and the obvious URL doesn't work:

1. DOI resolver → publisher site (often has OA link)
2. Europe PMC (`europepmc.org/backend/ptpmcrender.fcgi?accid=PMC{ID}&blobtype=pdf`) — ncbi blocks curl
3. SciELO — needs `User-Agent: Mozilla/5.0` header
4. ResearchGate — flag to user for manual download
5. Semantic Scholar — sometimes has OA links
6. Ask user for institutional access

Always verify downloads: `file paper.pdf` should say "PDF document", not HTML.

## Searching Paper Content (ragnar)

### Setup (per project)
- `scripts/rag_build.R` — maps citation keys to Zotero PDF attachment keys, builds DuckDB
- `data/rag/` gitignored — store is local, not committed
- Dependencies: ragnar, Ollama with nomic-embed-text model
- See `/lit-search` skill for full recipe

### Query
`ragnar_store_connect()` then `ragnar_retrieve()` — returns chunks with source file attribution.

### Anti-patterns
- NEVER write abstracts manually — if CrossRef has no abstract, leave blank
- NEVER cite specific numbers without verifying from the source PDF via ragnar search
- NEVER paraphrase equations — copy exact notation and cite page/section
