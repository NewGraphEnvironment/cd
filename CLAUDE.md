# cd — Climate Departure

R package for climate departure analysis from ERA5-Land reanalysis data.
Computes anomalies for custom areas of interest with flexible baselines
and trend statistics.

## Fork / Upstream Status

- **Origin:** `NewGraphEnvironment/cd` (private)
- **No upstream** — this is an original package
- **SRED:** `NewGraphEnvironment/sred-2025-2026#23`

## Repository Context

**Primary Language:** R (consumer-side) + Python (producer-side, EDH
backfillers) **Framework:** R package (devtools, testthat 3e, pkgdown)
**Spatial:** `terra`, `sf` **Data:** ERA5-Land via [DestinE Earth Data
Hub (Zarr)](https://earthdatahub.destine.eu/), served as COGs on S3 via
STAC **S3 Bucket:** `stac-era5-land` (us-west-2) **pkgdown:**
`newgraphenvironment.com/cd/`

## Architecture

**Producer** (GitHub Action, monthly): Python backfillers fetch hourly
Zarr from EDH, aggregate, derive (VPD/RH/soil); R stage 3 writes COGs
and pushes the STAC catalog: `scripts/backfill_edh_*.py` →
`scripts/pipeline_stage3_edh.R` → `scripts/pipeline_update_edh.R` (the
GH Action’s monthly entry point) →
[`cd_cog_write()`](https://newgraphenvironment.github.io/cd/reference/cd_cog_write.md)
→
[`cd_stac_catalog()`](https://newgraphenvironment.github.io/cd/reference/cd_stac_catalog.md)
→
[`cd_s3_push()`](https://newgraphenvironment.github.io/cd/reference/cd_s3_push.md)

The historical
[`cd_fetch()`](https://newgraphenvironment.github.io/cd/reference/cd_fetch.md)
/
[`cd_derive()`](https://newgraphenvironment.github.io/cd/reference/cd_derive.md)
R-side producer functions still ship (with tests) for users who want a
CDS-based fallback, but are not what runs in CI. See v0.1.0 / \#36 for
the migration history.

**Consumer** (user-facing, local R):
[`cd_catalog()`](https://newgraphenvironment.github.io/cd/reference/cd_catalog.md)
→
[`cd_crop()`](https://newgraphenvironment.github.io/cd/reference/cd_crop.md)
→
[`cd_extract()`](https://newgraphenvironment.github.io/cd/reference/cd_extract.md)
→
[`cd_baseline()`](https://newgraphenvironment.github.io/cd/reference/cd_baseline.md)
/
[`cd_anomaly()`](https://newgraphenvironment.github.io/cd/reference/cd_anomaly.md)
/
[`cd_compare()`](https://newgraphenvironment.github.io/cd/reference/cd_compare.md)
→
[`cd_trend()`](https://newgraphenvironment.github.io/cd/reference/cd_trend.md)
→
[`cd_summary()`](https://newgraphenvironment.github.io/cd/reference/cd_summary.md)

**Key design decision:** Raw climate values on STAC (not pre-computed
anomalies). All baseline/anomaly/trend computation consumer-side for
maximum flexibility over reference periods and comparison windows.

## Function Prefix

All functions use `cd_*` prefix. Naming convention: `noun_verb` (e.g.,
`cd_cog_write` not `cd_write_cog`).

## EDH (DestinE Earth Data Hub)

Producer pulls hourly ERA5-Land Zarr from EDH for the BC bbox (~48-60°
N, 114-140° W) and aggregates to monthly / seasonal / annual on a single
EPSG:4326 grid. Python only on the producer side (Zarr ecosystem
maturity); R consumer-side reads the COGs over `/vsicurl/`.

Token lookup order: `EDH_TOKEN` env var, then `~/.Renviron`. Configured
in CI via secret.

Key gotchas: - Temperature in Kelvin (subtract 273.15) - Precipitation
in m/day (× 1000 × days_in_month → mm/month) - Snow accumulation
variables (`snowfall`, `snowmelt`) reset at 06:00 UTC each day —
diff-and-clamp logic lives in `scripts/backfill_edh_snow.py` (#48) -
tmax/tmin daily aggregation currently uses UTC-day boundaries, not
local-time — known limitation tracked at \#37

## Climate Variables (15 total since v0.2.0)

**Core climate (7):** all monthly natives, also seasonal + annual

| Variable      | Units                     | Anomaly Type |
|---------------|---------------------------|--------------|
| tmean         | °C                        | absolute     |
| tmax          | °C                        | absolute     |
| tmin          | °C                        | absolute     |
| prcp          | mm                        | pct_normal   |
| vpd           | hPa (Tetens-derived)      | absolute     |
| rh            | % (temp+dewpoint-derived) | absolute     |
| soil_moisture | m³/m³ (4-layer mean)      | pct_normal   |

**Snow monthly natives (4):** also seasonal + annual

| Variable   | Units   | Anomaly Type   |
|------------|---------|----------------|
| swe        | mm      | pct_normal     |
| snowfall   | mm w.e. | pct_normal     |
| snowmelt   | mm w.e. | pct_normal     |
| snow_cover | %       | pct_point_diff |

**Snow annual derived (4):** annual only

| Variable           | Units       | Anomaly Type   |
|--------------------|-------------|----------------|
| swe_max            | mm          | pct_normal     |
| snowfall_fraction  | %           | pct_point_diff |
| snowmelt_doy_50    | day-of-year | absolute       |
| snowmelt_rate_peak | mm/day      | absolute       |

The `pct_point_diff` anomaly type is for already-percentage variables
(treats anomaly as percentage-point difference, not relative percent).

## Season Definitions

Configurable via
[`cd_seasons()`](https://newgraphenvironment.github.io/cd/reference/cd_seasons.md).
Default: standard meteorological (DJF, MAM, JJA, SON). Override for
custom seasons (e.g., wet/dry, growing season).

## Development Workflow

1.  Branch per issue (or group): `N-description` (use
    `/planning-init <N>`)
2.  PWF baseline (task_plan.md / findings.md / progress.md) committed
    first
3.  Build → test → `/code-check` → atomic commits with `Fixes #N` (each
    commit updates the matching task_plan checkbox)
4.  PR (`/gh-pr-push`) — SRED tag
    (`Relates to NewGraphEnvironment/sred-2025-2026#23`) goes in the PR
    body, not on issues
5.  Merge + release (`/gh-pr-merge`) — bumps DESCRIPTION + NEWS, tags,
    watches CI
6.  Archive — `planning/active/` →
    `planning/archive/<YYYY-MM-issue-N-slug>/` with a one-paragraph
    README per directory

## Scripts (current)

**Producer (EDH):** - `scripts/backfill_edh_all.py` — all 7 core climate
variables (tmean, tmax, tmin, prcp, dewpoint→VPD/RH, soil moisture) -
`scripts/backfill_edh_tmax_tmin.py` — separate tmax/tmin path (hourly →
UTC-day max/min); see \#37 - `scripts/backfill_edh_snow.py` — 4 snow
natives + 4 derived (#48); handles ECMWF accumulation reset -
`scripts/_lib.py` — shared safeguards (single-instance pgrep guard,
exponential backoff, atomic write, timestamped logging, EDH token
loader) - `scripts/pipeline_stage3_edh.R` — monthly TIFs → COGs + STAC +
S3 push - `scripts/pipeline_update_edh.R` — monthly GH Action entry
point (incremental) - `scripts/qa_monthly.R` — month-end QA cross-check

**Misc:** - `scripts/rag_snow_methodology_build.R` /
`rag_snow_methodology_query.R` — ragnar lit review (#54) -
`scripts/rag_departure_framing_build.R` — ragnar store for departure
framing - Naming: `rag_<topic>_<verb>.R` (`noun_verb`, mirrors the
`cd_*` function convention) - `data-raw/make_hexsticker.R` — hex sticker
(reads from DESCRIPTION) - `data-raw/example_*.R` — bundled AOIs +
context geodata for vignettes

## Vignettes

Two regional reporting vignettes in `vignettes/`: - `peace-fwcp.Rmd` —
FWCP Peace Region (~73,000 km², 16 WSGs across 5 ecoregions) -
`kootenay-lake.Rmd` — southern Kootenays (~24,200 km², 4 WSGs across 4
ecoregions; sharp east-west precip gradient)

Both share the same structure (Area of Interest → Trends → Snowpack →
Spatial Pattern → Per-Ecoregion → WSGs Across Ecoregions →
Interpretation). Heavy data is precomputed by
`data-raw/<vignette>_vignette_data.R` into
`inst/vignette-data/<vignette>.{rds,tif}` so pkgdown CI doesn’t re-fetch
from S3 on every render. ASWS QA cross-checks are in
`data-raw/qa_snow_validation*.R` — run locally only, results land in
`planning/archive/<issue>/`.

The two-vignette template is the foundation for additional regional
reporting appendices (cf \#47) — port directly to a
`fish_passage_<region>_<year>` reporting context.

## Data Directories (gitignored)

- `data/backfill/` — overnight backfill working data
- `data/rag/` — ragnar DuckDB stores

## CI considerations

- `data-raw/*.R` runs **locally only** — never on CI. Outputs land in
  `inst/extdata/` or `inst/vignette-data/` and are committed.
- `bcsnowdata` (used by ASWS QA scripts) is GitHub-only — **never** add
  it to DESCRIPTION Suggests; pak can’t resolve it on the pkgdown
  runner. Same for any other GitHub-only package.

# Code Check Conventions

Structured checklist for reviewing diffs before commit. Used by
`/code-check`. Add new checks here when a bug class is discovered — they
compound over time.

## Shell Scripts

### Quoting

- Variables in double-quoted strings containing single quotes break if
  value has `'`
- `"echo '${VAR}'"` — if VAR contains `'`, shell syntax breaks
- Use `printf '%s\n' "$VAR" | command` to pipe values safely
- Heredocs: unquoted `<<EOF` expands variables locally, `<<'EOF'` does
  not — know which you need

### Paths

- Hardcoded absolute paths (`/Users/airvine/...`) break for other users
- Use `REPO_ROOT="$(cd "$(dirname "$0")/<relative>" && pwd)"`
- After moving scripts, verify `../` depth still resolves correctly
- Usage comments should match actual script location

### Silent Failures

- `|| true` hides real errors — is the failure actually safe to ignore?
- Empty variable before destructive operation (rm, destroy) — add guard:
  `[ -n "$VAR" ] || exit 1`
- `grep` returning empty silently — downstream commands get empty input

### Process Visibility

- Secrets passed as command-line args are visible in `ps aux`
- Use env files, stdin pipes, or temp files with `chmod 600` instead

## Cloud-Init (YAML)

### ASCII

- Must be pure ASCII — em dashes, curly quotes, arrows cause silent
  parse failure
- Check with: `perl -ne 'print "$.: $_" if /[^\x00-\x7F]/' file.yaml`

### State

- `cloud-init clean` causes full re-provisioning on next boot — almost
  never what you want before snapshot
- Use `tailscale logout` not `tailscale down` before snapshot
  (deregister vs disconnect)

### Template Variables

- Secrets rendered via `templatefile()` are readable at
  `169.254.169.254` metadata endpoint
- Acceptable for ephemeral machines, document the tradeoff

## OpenTofu / Terraform

### State

- Parsing `tofu state show` text output is fragile — use `tofu output`
  instead
- Missing outputs that scripts need — add them to main.tf
- Snapshot/image IDs in tfvars after deleting the snapshot — stale
  reference

### Destructive Operations

- Validate resource IDs before destroy: `[ -n "$ID" ] || exit 1`
- `tofu destroy` without `-target` destroys everything including
  reserved IPs
- Snapshot ID extraction: use `--resource droplet` and `grep -F` for
  exact match

## Security

### Secrets in Committed Files

- `.tfvars` must be gitignored (contains tokens, passwords)
- `.tfvars.example` should have all variables with empty/placeholder
  values
- Sensitive variables need `sensitive = true` in variables.tf

### Firewall Defaults

- `0.0.0.0/0` for SSH is world-open — document if intentional
- If access is gated by Tailscale, say so explicitly

### Credentials

- Passwords with special chars (`'`, `"`, `$`, `!`) break naive shell
  quoting
- `printf '%q'` escapes values for shell safety
- Temp files for secrets: create with `chmod 600`, delete after use

## R / Package Installation

### pak Behavior

- pak stops on first unresolvable package — all subsequent packages are
  skipped
- Removed CRAN packages (like `leaflet.extras`) must move to GitHub
  source
- PPPM binaries may lag a few hours behind new CRAN releases

### Reproducibility

- Branch pins (`pkg@branch`) are not reproducible — document why used
- Pinned download URLs (RStudio .deb) go stale — document where to
  update

## General

### Adopting Existing Config

When importing config from one location into a canonical one (legacy
`~/.bash_profile` → dotfiles repo, old script’s env → repo, another
project’s `settings.json` → soul):

- **Verify every referenced path/binary exists.** Dead PATH exports,
  missing interpreters, stale env vars should be cut, not codified.
  Shell paths:
  `for p in $(echo "$PATH" | tr ':' ' '); do [ -d "$p" ] || echo "DEAD: $p"; done`
- **Ask before dropping a reference** — it may be something the user
  forgot to reinstall on this machine, not something to delete.
- **Curated subset, not verbatim copy.** The diff should reflect what
  you verified, not the whole source.

### Documentation Staleness

- Moving/renaming scripts: update CLAUDE.md, READMEs, usage comments
- New variables: update .tfvars.example
- New workflows: update relevant README

# LLM Behavioral Guidelines

Behavioral guidelines to reduce common LLM coding mistakes. Merge with
project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For
trivial tasks, use judgment.

## 1. Think Before Coding

**Don’t assume. Don’t hide confusion. Surface tradeoffs.**

Before implementing: - State your assumptions explicitly. If uncertain,
ask. - If multiple interpretations exist, present them - don’t pick
silently. - If a simpler approach exists, say so. Push back when
warranted. - If something is unclear, stop. Name what’s confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No “flexibility” or “configurability” that wasn’t requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: “Would a senior engineer say this is overcomplicated?” If
yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code: - Don’t “improve” adjacent code, comments,
or formatting. - Don’t refactor things that aren’t broken. - Match
existing style, even if you’d do it differently. - If you notice
unrelated dead code, mention it - don’t delete it.

When your changes create orphans: - Remove imports/variables/functions
that YOUR changes made unused. - Don’t remove pre-existing dead code
unless asked.

The test: Every changed line should trace directly to the user’s
request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals: - “Add validation” → “Write tests
for invalid inputs, then make them pass” - “Fix the bug” → “Write a test
that reproduces it, then make it pass” - “Refactor X” → “Ensure tests
pass before and after”

For multi-step tasks, state a brief plan:

    1. [Step] → verify: [check]
    2. [Step] → verify: [check]
    3. [Step] → verify: [check]

Strong success criteria let you loop independently. Weak criteria (“make
it work”) require constant clarification.

**These guidelines are working if:** fewer unnecessary changes in diffs,
fewer rewrites due to overcomplication, and clarifying questions come
before implementation rather than after mistakes.

# Planning Conventions

How Claude manages structured planning for complex tasks using
planning-with-files (PWF).

## When to Plan

Use PWF when a task has multiple phases, requires research, or involves
more than ~5 tool calls. Triggers: - User says “let’s plan this”, “plan
mode”, “use planning”, or invokes `/planning-init` - Complex issue work
begins (multi-step, uncertain approach) - Claude judges the task
warrants structured tracking

Skip planning for single-file edits, quick fixes, or tasks with obvious
next steps.

## The Workflow

1.  **Explore first** — Enter plan mode (read-only). Read code, trace
    paths, understand the problem before proposing anything.
2.  **Plan to files** — Write the plan into 3 files in
    `planning/active/`:
    - `task_plan.md` — Phases with checkbox tasks
    - `findings.md` — Research, discoveries, technical analysis
    - `progress.md` — Session log with timestamps and commit refs
3.  **Commit the plan** — Commit the planning files before starting
    implementation. This is the baseline.
4.  **Work in atomic commits** — Each commit bundles code changes WITH
    checkbox updates in the planning files. The diff shows both what was
    done and the checkbox marking it done.
5.  **Code check before commit** — Run `/code-check` on staged diffs
    before committing. Don’t mark a task done until the diff passes
    review.
6.  **Archive when complete** — Move `planning/active/` to
    `planning/archive/` via `/planning-archive`. Write a README.md in
    the archive directory with a one-paragraph outcome summary and
    closing commit/PR ref — future sessions scan these to catch up fast.

## Atomic Commits (Critical)

Every commit that completes a planned task MUST include: - The
code/script changes - The checkbox update in `task_plan.md` (`- [ ]` -\>
`- [x]`) - A progress entry in `progress.md` if meaningful

This creates a git audit trail where `git log -- planning/` tells the
full story. Each commit is self-documenting — you can backtrack with git
and understand everything that happened.

## File Formats

### task_plan.md

Phases with checkboxes. This is the core tracking file.

``` markdown
# Task Plan

## Phase 1: [Name]
- [ ] Task description
- [ ] Another task

## Phase 2: [Name]
- [ ] Task description
```

Mark tasks done as they’re completed: `- [x] Task description`

### findings.md

Append-only research log. Discoveries, technical analysis, things
learned.

``` markdown
# Findings

## [Topic]
[What was found, with source/date]
```

### progress.md

Session entries with commit references.

``` markdown
# Progress

## Session YYYY-MM-DD
- Completed: [items]
- Commits: [refs]
- Next: [items]
```

## Directory Structure

    planning/
      active/          <- Current work (3 PWF files)
      archive/         <- Completed issues
        YYYY-MM-issue-N-slug/

If `planning/` doesn’t exist in the repo, run `/planning-init` first.

## Skills

| Skill               | When to use                                        |
|---------------------|----------------------------------------------------|
| `/planning-init`    | First time in a repo — creates directory structure |
| `/planning-update`  | Mid-session — sync checkboxes and progress         |
| `/planning-archive` | Issue complete — archive and create fresh active/  |

# R Package Development Conventions

Standards for R package development across New Graph Environment
repositories. Based on [R Packages (2e)](https://r-pkgs.org/) by Hadley
Wickham and Jenny Bryan.

**Reference packages:** When starting a new package, study these
existing packages for patterns: `flooded`, `gq`. They demonstrate the
conventions below in practice (DESCRIPTION fields, README layout,
NEWS.md style, pkgdown setup, test structure, hex sticker, etc.).

## Style

- tidyverse style guide: snake_case, pipe operators (`|>` or `%>%`)
- Match existing patterns in each codebase
- Use `pak` for package installation (not `install.packages`)
- Prefix column name vectors with `cols_` for discoverability in the
  environment pane: `cols_all`, `cols_carry`, `cols_split`,
  `cols_writable`. Same principle for other grouped vectors (`params_`,
  `tbl_`, etc.)

## Package Structure

Follow R Packages (2e) conventions: - `R/` for functions,
`tests/testthat/` for tests, `man/` for docs - `DESCRIPTION` with proper
fields (Title, Description, <Authors@R>) - `DESCRIPTION` URL field:
include both the GitHub repo and the pkgdown site so pkgdown links
correctly (e.g.,
`URL: https://github.com/OWNER/PKG, https://owner.github.io/PKG/`) -
`NAMESPACE` managed by roxygen2 (`#' @export`, `#' @import`,
`#' @importFrom`) - Never edit `NAMESPACE` or `man/` by hand

## One Function, One File

Each exported function gets its own R file and its own test file: -
`R/fl_mask.R` → `tests/testthat/test-fl_mask.R` - Commit the function
and its tests together - Use `Fixes #N` in the commit message to close
the corresponding issue

## GitHub Issues and SRED Tracking

### Issue-per-function workflow

File a GitHub issue for each function before building it. This creates a
traceable record of what was planned, built, and verified.

### Branching for SRED

For new packages or major features, work on a branch and merge via PR:

    main ← scaffold-branch (PR closes with "Relates to NewGraphEnvironment/sred-2025-2026#N")

This gives one PR that contains all commits — a single SRED
cross-reference covers the entire body of work. Individual commits
within the branch close their respective function issues with
`Fixes #N`.

### Closing issues

Close function issues via commit messages — see Closing Issues in
newgraph conventions.

## Testing

- Use testthat 3e (`Config/testthat/edition: 3` in DESCRIPTION)

- Run `devtools::test()` before committing

- Test files mirror source: `R/utils.R` -\>
  `tests/testthat/test-utils.R`

- Test for edge cases and potential failures, not just happy paths

- Tests must pass before closing the function’s issue

- Always grep for errors in the same command as the test run to avoid
  running twice:

  ``` bash
  Rscript -e 'devtools::test()' 2>&1 | grep -E "(FAIL|ERROR|PASS)" | tail -5
  ```

  For error context: `grep -E "(ERROR:|FAIL )" -A 10 | head -25`

## Examples and Vignettes

### Runnable examples on every exported function

Examples are how users discover what a function does. They must: -
**Actually run** — no `\dontrun{}` unless external resources are
required - **Use bundled test data** via
[`system.file()`](https://rdrr.io/r/base/system.file.html) so they work
for anyone - **Show why the function is useful** — not just that it
runs, but what it produces and why you’d use it - **Use qualified
names** for non-exported dependencies
([`terra::rast()`](https://rspatial.github.io/terra/reference/rast.html),
[`sf::st_read()`](https://r-spatial.github.io/sf/reference/st_read.html))
since examples run in the user’s environment

### Vignettes

At least one vignette showing the full pipeline on real data: -
Demonstrates the package solving an actual problem end-to-end - Uses
bundled test data (committed to `inst/testdata/`) - Hosted on pkgdown so
users can read it without installing

**Output format:** Use
[`bookdown::html_vignette2`](https://pkgs.rstudio.com/bookdown/reference/html_document2.html)
(not
[`rmarkdown::html_vignette`](https://pkgs.rstudio.com/rmarkdown/reference/html_vignette.html))
for figure numbering and cross-references. Requires `bookdown` in
Suggests and chunks must have `fig.cap` for numbered figures.
Cross-reference with `Figure \@ref(fig:chunk-name)`.

**Vignettes that need external resources (DB, API, STAC):** Do NOT use
the `.Rmd.orig` pre-knit pattern — it breaks `bookdown` figure numbering
because knitr evaluates chunks during pre-knit and emits `![](path)`
markdown that bookdown can’t number.

Instead, separate data generation from presentation: 1.
`data-raw/vignette_data.R` — runs the queries, saves results as `.rds`
to `inst/testdata/` (or `inst/vignette-data/`) 2. Vignette loads `.rds`
files, all chunks run live during pkgdown build 3. Note at top of
vignette: “Data generated by `data-raw/script.R`” 4. bookdown controls
all chunks — figure numbers, cross-refs work

This is the same pattern as test data: `data-raw/` documents how the
data was produced, committed artifacts make vignettes reproducible
without the external resource.

### Test data

- Created via a script in `data-raw/` that documents exactly how the
  data was produced (database queries, spatial crops, etc.)
- Committed to `inst/testdata/` — small enough to ship with the package
- Used by tests, examples, and vignettes — one dataset, three purposes

## Documentation

- roxygen2 for all exported functions
- `@import` or `@importFrom` in the package-level doc
  (`R/<pkg>-package.R`) to populate NAMESPACE — don’t rely on `::`
  everywhere in function bodies
- pkgdown site for public packages with `_pkgdown.yml` (bootstrap 5)
- GitHub Action for pkgdown (`usethis::use_github_action("pkgdown")`)

## lintr

Run `lintr::lint_package()` before committing R package code. Fix all
warnings — every lint should be worth fixing.

### Recommended .lintr config

``` r

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
- Suppress commented code lints (exploratory R scripts often have
  commented alternatives)
- Exclude renv directory entirely

## Dependencies

- Minimize Imports — use `Suggests` for packages only needed in
  tests/vignettes
- Pin versions only when breaking changes are known
- Prefer packages already in the tidyverse ecosystem

## Releasing

1.  Update `NEWS.md` — keep it concise:
    - First release: one line (e.g., “Initial release. Brief
      description.”)
    - Later releases: describe what changed and why, not
      function-by-function. Link to the pkgdown reference page for
      details — don’t duplicate it.
    - Don’t list every function; the pkgdown reference page is the
      single source of truth for what’s in the package.
2.  Bump version in `DESCRIPTION` (e.g., `0.0.0.9000` → `0.1.0`) — as
    the **final** commit of the branch, after verification numbers/tests
    are final. Mid-branch bumps are premature and churn: additional code
    changes end up bundled inside a “release” that already claimed the
    version.
3.  Commit as “Release vX.Y.Z”
4.  Tag: `git tag vX.Y.Z && git push && git push --tags`

## Repository Setup

### Branch protection

Protect main from deletion and force pushes:

``` bash
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

Keep a `dev/dev.R` file that documents every setup step. Not idempotent
— run interactively. This is the reproducible recipe for the package
scaffold.

## README

Keep the README lean: - Hex sticker, one-line description, install,
example showing *why* it’s useful - Link to pkgdown vignette and
function reference — don’t duplicate them - Don’t maintain a function
table — it’s just another thing to keep updated and pkgdown’s reference
page is the single source of truth

## LLM Workflow

When an LLM assistant modifies R package code: 1. Run
`lintr::lint_package()` — fix issues before committing 2. Run
`devtools::test()` with error grep — ensure tests pass in one call:
`bash Rscript -e 'devtools::test()' 2>&1 | grep -E "(FAIL|ERROR|PASS)" | tail -5`
3. Run `devtools::document()` and grep for results:
`bash Rscript -e 'devtools::document()' 2>&1 | grep -E "(Writing|Updating|warning)" | tail -10`
4. Check `devtools::check()` passes for releases — capture results in
one call:
`bash Rscript -e 'devtools::check()' 2>&1 | grep -E "(ERROR|WARNING|NOTE|errors|warnings|notes)" | tail -10`

# Reference Management Conventions

How references flow between Claude Code, Zotero, and technical writing
at New Graph Environment.

## Tool Routing

Three tools, different purposes. Use the right one.

| Need | Tool | Why |
|----|----|----|
| Search by keyword, read metadata/fulltext, semantic search | **MCP `zotero_*` tools** | pyzotero, works with Zotero item keys |
| Look up by citation key (e.g., `irvine2020ParsnipRiver`) | **`/zotero-lookup` skill** | Citation keys are a BBT feature — pyzotero can’t resolve them |
| Create items, attach PDFs, deduplicate | **`/zotero-api` skill** | Connector API for writes, JS console for attachments |

**Citation keys vs item keys:** Citation keys (like
`irvine2020ParsnipRiver`) come from Better BibTeX. Item keys (like
`K7WALMSY`) are native Zotero. The MCP works with item keys.
`/zotero-lookup` bridges citation keys to item data.

**BBT citation key storage:** As of Feb 2025+, BBT stores citation keys
as a `citationKey` field directly in `zotero.sqlite` (via Zotero’s item
data system), not in a separate BBT database. The old
`better-bibtex.sqlite` and `better-bibtex.migrated` files are stale and
no longer updated. Query citation keys with:
`SELECT idv.value FROM items i JOIN itemData id ON i.itemID = id.itemID JOIN itemDataValues idv ON id.valueID = idv.valueID JOIN fields f ON id.fieldID = f.fieldID WHERE f.fieldName = 'citationKey'`.

## Adding References Workflow

### 1. Search and flag

When research turns up a reference: - **DOI available:** Tell the user —
Zotero’s magic wand (DOI lookup) is the fastest path - **ResearchGate
link:** Flag to user for manual check — programmatic fetch is blocked
(403), but full text is often there - **BC gov report:** Search
[ACAT](https://a100.gov.bc.ca/pub/acat/), for.gov.bc.ca library, EIRS
viewer - **Paywalled:** Note it, move on. Don’t waste time trying to
bypass.

### 2. Add to Zotero

**Preferred order:** 1. DOI magic wand in Zotero UI (fastest, most
complete metadata) 2. Web API POST with `collections` array (grey
literature, local PDFs — targets collection directly, no UI interaction
needed) 3. `saveItems` via `/zotero-api` (batch creation from structured
data — requires UI collection selection) 4. JS console script for group
library (when connector can’t target the right collection)

**Collection targeting:** `saveItems` drops items into whatever
collection is selected in Zotero’s UI. Always confirm with the user
before calling it. **Web API bypasses this** — include
`"collections": ["KEY"]` in the POST body. Find collection keys with
`?q=name` search on the collections endpoint.

### 3. Attach PDFs

`saveItems` attachments silently fail. Don’t use them. Instead:

1.  **Web API S3 upload (preferred):** Create attachment item → get
    upload auth → build S3 body (Python: prefix + file bytes + suffix) →
    POST to S3 → register with uploadKey. Works without Zotero running.
    See `/zotero-api` skill section 4.
2.  **JS console fallback:** Download with `curl`, attach via
    `item_attach_pdf.js` in Zotero JS console.
3.  Verify attachment exists via MCP: `zotero_get_item_children`

### 4. Verify

After manual adds, confirm via MCP: - `zotero_search_items` — find by
title - `zotero_get_item_metadata` — check fields are complete -
`zotero_get_item_children` — confirm PDF attached

### 5. Clean up

If duplicates were created (common with `saveItems` retries): - Run
`collection_dedup.js` via Zotero JS console - It keeps the copy with the
most attachments, trashes the rest

## In Reports (bookdown)

### Bibliography generation

``` yaml
# index.Rmd — dynamic bib from Zotero via Better BibTeX
bibliography: "`r rbbt::bbt_write_bib('references.bib', overwrite = TRUE)`"
```

`rbbt` pulls from BBT, which syncs with Zotero. Edit references in
Zotero → rebuild report → bibliography updates.

**Library targeting:** rbbt must know which Zotero library to search.
This is set globally in `~/.Rprofile`:

``` r

# default library — NewGraphEnvironment group (libraryID 9, group 4733734)
options(rbbt.default.library_id = 9)
```

Without this option, rbbt searches only the personal library
(libraryID 1) and won’t find group library references. The library IDs
map to Zotero’s internal numbering — use `/zotero-lookup` with
`SELECT DISTINCT libraryID FROM citationkey` against the BBT database to
discover available libraries.

### Citation syntax

- `[@key2020]` — parenthetical: (Author 2020)
- `@key2020` — narrative: Author (2020)
- `[@key1; @key2]` — multiple
- `nocite:` in YAML — include uncited references

### Cite primary sources

When a review paper references an older study, trace back to the
original and cite it. Don’t attribute findings to the review when the
original exists. (See LLM Agent Conventions in `newgraph.md`.)

**When the original is unavailable** (paywalled, out of print, can’t
locate): use secondary citation format in the prose and include bib
entries for both sources:

> Smith et al. (2003; as cited in Doctor 2022) found that…

Both `@smith2003` and `@doctor2022` go in the `.bib` file. The reader
can then track down the original themselves. Flag incomplete metadata on
the primary entry — it’s better to have a partial reference than none at
all.

## PDF Fallback Chain

When you need a PDF and the obvious URL doesn’t work:

1.  DOI resolver → publisher site (often has OA link)
2.  Europe PMC
    (`europepmc.org/backend/ptpmcrender.fcgi?accid=PMC{ID}&blobtype=pdf`)
    — ncbi blocks curl
3.  SciELO — needs `User-Agent: Mozilla/5.0` header
4.  ResearchGate — flag to user for manual download
5.  Semantic Scholar — sometimes has OA links
6.  Ask user for institutional access

Always verify downloads: `file paper.pdf` should say “PDF document”, not
HTML.

## Searching Paper Content (ragnar)

### Setup (per project)

- `scripts/rag_build.R` — maps citation keys to Zotero PDF attachment
  keys, builds DuckDB
- `data/rag/` gitignored — store is local, not committed
- Dependencies: ragnar, Ollama with nomic-embed-text model
- See `/lit-search` skill for full recipe

### Query

`ragnar_store_connect()` then `ragnar_retrieve()` — returns chunks with
source file attribution.

### Anti-patterns

- NEVER write abstracts manually — if CrossRef has no abstract, leave
  blank
- NEVER cite specific numbers without verifying from the source PDF via
  ragnar search
- NEVER paraphrase equations — copy exact notation and cite page/section
