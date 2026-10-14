# Code-check round 3 — #96 (vpd unit Pa -> hPa)

Base 2f50385, HEAD ed731e1 (origin/main still at the base after `git fetch`). Scope:
`git diff 2f50385...HEAD -- . ':(exclude)planning'`. Rounds 1-2 and the plan review not repeated.
Measurements in a `git archive HEAD` copy in the scratchpad; the repo was not modified.

## Mechanism behind round 2's finding

A sentence describing what code *does* when the answer depends on **which copy of cd is
resolved at run time**: the installed library copy (`library(cd)`, `cd::`, `system.file()` in a
fresh R) or the source tree (`pkgload::load_all()`, whose attached namespace and `system.file`
shim on the search path win over the library for the rest of the session). Round 2's sentence
assumed the source tree; the generators resolve whatever is attached.

## Findings

- **[severity: fragile]** data-raw/vignette_data_vpd_unit_patch.R:10-12 — the qualified sentence
  is still not true as written. "it writes "hPa" only once a cd from after #96 is installed"
  makes the install the sole condition, but `library(cd)` is a no-op when cd is already attached,
  and the generators say "Run interactively" (kootenay_lake_vignette_data.R:10, the peace twin
  likewise), where a prior `devtools::load_all()` is the normal state. Measured in the copy with
  installed cd 0.6.3: fresh `Rscript -e 'cd::cd_variables()$unit[5]'` gives `"Pa"`;
  `pkgload::load_all(); library(cd); cd_variables()$unit[5]` gives `"hPa"`, with the namespace
  path the source tree and `system.file("vignette-data", package = "cd")` the source `inst/`.
  So the regen writes hPa from a load_all'd session whatever is installed, and (the harmful
  direction) writes Pa from a session that load_all'd an older checkout even with a post-#96 cd
  installed. The consequence is bounded, because the agreement test catches a Pa write under
  every runner (below); the defect is the sentence, which states an install as the condition
  when the condition is the attached copy. Suggested wording: "...takes units from
  cd_variables() of whichever cd is attached — the installed one in a fresh session, the source
  tree after load_all() — so it writes "Pa" back under a cd from before #96, which the
  bundled-data test fails on."

## Every other reach of the mechanism in this diff, with verdict

| place | claim / behaviour | copy it depends on | verdict |
|---|---|---|---|
| patch script :8-9, "a carried unit wins over the registry" | `meta_resolve()` coalesces the carried `unit` first (R/cd_anomaly.R:178) | same in every copy since before the base | true |
| patch script :4-6, tables "written by cd_anomaly()/cd_trend() under the old registry" | `cd_anomaly()` sets `x$unit <- meta_resolve(x)$unit` (R/cd_anomaly.R:93-95) from `cd_variables()`; any copy that wrote them predates #96 | either copy | true |
| patch script :19, `pkgload::load_all(quiet = TRUE)` | loads `.` (the root it is told to run from), and `stopifnot(identical(new_unit, "hPa"))` refuses a pre-#96 tree before any write; `list.files("inst/vignette-data")` reads the same tree | source tree, guarded | sound |
| patch script :15, "Re-running finds nothing to change and writes nothing" | `n_old == 0L` -> `next` before `saveRDS` | n/a | true |
| test comment :48-49, "Tetens ... both produce hPa" | checked in round 2 | n/a | true |
| test comment :51-52, carried unit wins in `meta_resolve()` | as above | n/a | true |
| agreement test, `system.file()` vs `cd_variables()` | under `devtools::test()` both resolve to the source tree (namespace path and the pkgload `system.file` shim, measured); under `R CMD check` both to the check library built from the same tarball (`inst/vignette-data` not build-ignored, round 1). The registry and the data always come from one copy, so it never compares a source registry with installed data or the reverse | one copy, always | sound |
| first new test, `"hPa"` literal | fails if run against an installed pre-#96 cd, as intended | whichever is under test | sound |
| vignettes, `library(cd)` + `readRDS(system.file(..., package = "cd"))` | pkgdown CI installs `local::.`; `R CMD build`/check build vignettes from an install of the same source; a local render under a stale install shows that install's data, the same as for any data change | one copy, always | sound; no claim in the diff about it |
| roxygen `@return` unit list | describes the source registry it sits beside | n/a | true |

No other sentence in the non-planning diff describes run-time behaviour.

## Triage (session) — fix and enumeration

Finding reproduced: fresh `Rscript` gives `cd::cd_variables()` vpd "Pa" (installed 0.6.3); after `pkgload::load_all()` then `library(cd)`, "hPa". Fixed by naming no copy: a regen "writes whatever unit the cd it runs against gives vpd, so a cd from before #96 (an older install, or an older checkout under load_all()) writes "Pa" back".

Terminal enumeration — every prose/comment line the branch adds outside planning/ (`git diff 2f50385 -- . ':(exclude)planning' | grep -E '^\+[^+]'` filtered to comments, roxygen, messages, `info =`): 26 lines, each checked:

| Lines | Claim | Verdict |
|---|---|---|
| roxygen + Rd `\item{unit}` | unit list °C, %, hPa, mm, day, mm/wk | matches the registry's distinct units |
| patch header 4-9 | old registry wrote "Pa" on every vpd row; carried unit wins; only that column changes | counts 3510/2340; `R/cd_anomaly.R:178`; round-trip `identical()` |
| patch header 11-14 | a regen writes the running cd's unit; pre-#96 writes "Pa"; test fails on it | true for installed and load_all copies (probe above); test failure shown in round 1 |
| patch header 14-16 | regen pending for #123 grid, #126 columns; rerun writes nothing | data refreshed 2026-10-06, #123 merged 2026-10-09; #126 NEWS; second run measured |
| patch header 18, messages, round-trip comment | run from root; messages; exactness precondition | paths are root-relative; precondition is what `stopifnot(unit_count(old, new_unit) == 0L)` enforces |
| test comments | `cd_derive_vpd()` and the EDH backfiller produce hPa; carried unit outlives a registry fix | `R/cd_derive.R:95`; `scripts/backfill_edh_all.py:88`; `meta_resolve()` |

No other sentence depends on which copy of cd runs. Loop ends on this enumeration.
