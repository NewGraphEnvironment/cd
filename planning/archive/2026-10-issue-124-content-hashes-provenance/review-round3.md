# Code-check round 3: branch 124 (3c19b71...HEAD, at 2c9a07c)

## Mechanism

**A fact is established in one place and relied on in another, and only the author's
intent keeps the two in agreement.** Nothing re-derives the fact at the point where it is
used. Every earlier finding has this shape:

- **Time of hash vs time of upload (R1).** The ETag was compared with the disk at check time, not with the bytes that were hashed.
- **Time of read vs time of write (R1).** The manifest was merged from a read taken at start.
- **The producer's acceptance vs the publisher's (R1).** `--rewrite` stamped SHAs that `daily_publish()` refuses.
- **A failed command read as an answer (R1).** A failed `git status` produced empty output, which read as a clean tree.
- **The environment the code was tested on vs the one DESCRIPTION admits (R2).**
- **A remedy string vs the guard that would run on it (R2).**

The R2 terra fix is itself an instance, one axis over. The floor was taken from the terra call that failed visibly (the `metags()` getter's shape). It was not taken from every terra call the code depends on, which also includes `metags<-` with a named vector and with `NULL`. The same mechanism also reaches the provenance itself. `CD_SHA` and `CD_VERSION` are read from the checkout, while the code that writes the bytes is the installed package.

Where it reaches in this diff, and the verdict for each:

| # | fact, and where it is set vs where it is relied on | verdict |
|---|---|---|
| 1 | Hash vs S3 bytes (stage3 STEP 3, update STEP 5, `daily_publish`) | **sound**: re-hashed after the ETag check (R1 fix) |
| 2 | Manifest read at start vs `s3_put_if` | **sound**. Its "re-run to merge" text is wrong for a CI loser (note) |
| 3 | Live catalog vs catalog upload | **sound**: a full rebuild, not a merge, and a race window of seconds |
| 4 | R `CD_SHA` vs the Python child's `CD_SHA` (only `CD_RUN_TIME` crosses via env) | **sound in CI** (both read `GITHUB_SHA`). Locally they can diverge if the tree changes mid-run (note) |
| 5 | `CD_SHA`/`CD_VERSION` (checkout) vs the code that ran (installed `cd`) | **finding 2** |
| 6 | "Clean SHA" vs "a SHA a consumer can resolve" | **finding 3** |
| 7 | terra floor vs every terra API `cd_cog_write()` calls | **finding 1** |
| 8 | Three tag readers (`cd_stac_item` takes domain `""` with exactly one value, `manifest_entries` takes any domain with exactly one, `provenance_problems` takes the first match in any domain) | **sound** for today's writers: default domain, unique keys (note) |
| 9 | Sync excludes (`.*`, `*.aux.json`) vs `stray_problems` (`list.files(all.files = FALSE)`, `\.aux\.json$`) | **sound in practice**. They agree at top level but disagree on `sub/.x`, which the sync uploads and stray skips. No producer writes subdirectories |
| 10 | Remedy strings vs the guards they lead to | gap hint **sound** (traced below); absent-manifest hint **sound**; `catalog_repair_hint()` after an ETag failure **sound** (it re-hashes the live COGs); STEP 1 "republish with stage3" **sound**; `s3_put_if` hint (note); gap hint when `last > newest` (note) |
| 11 | `head_object()` retry (R2) vs the other single-shot reads after a write (`readback_problems`, `daily_manifest_live`) | **sound**: those fail loud, the live state is already correct, and the next run is green |

The gap hint traced through: run the `aws s3 cp ... --include '*_daily_Y.tif'` step, then `daily_publish()`. After that, `after = listing ∪ local` equals `names(merged)` (the live keys plus Y). The sync re-puts the same bytes, the ETags match, and the manifest goes up. This holds both with and without a local cube.

## Findings

- **[severity: bug]** DESCRIPTION:51 (`terra (>= 1.8-42)`), which breaks R/cd_cog_write.R:63-66
  The R2 floor makes `metags()` return a data.frame. It does not make `metags<-` work, and `cd_cog_write()` depends on the setter twice. In terra's own R code:
  - **1.8-42.** `parse_tags()` builds a named vector as `cbind(value, domain)`, which gives (name, value, domain). The setter calls `addTag(value[i,2], value[i,3], value[i,1])`, so it passes the domain as the value. `addTag` reads an empty value as "remove", so `metags(x) <- c(CD_SHA = ...)` is a no-op.
  - **1.8-50.** The set is fixed (`cbind(domain, value)`). `metags(x) <- NULL` still passes the columns in the wrong order and clears nothing.
  - **1.8-54.** Both work.

  Measured by running each version's shipped R-level setter (CRAN archive `R/tags.R`) over the installed 1.9.50 C++. `SpatRaster::addTag(name, value, domain)` is identical in 1.8-42's `spatRaster.cpp`. I then ran `cd_cog_write()` with its setter swapped for each version's, on a STEP 4 input: a published COG tagged by run 111, `c()`'d with a new year, `tags =` run 222.
  - **1.8-42.** The file is written with `CD_RUN_ID=111`, `CD_SHA=aaaa…` and `CD_RUN_TIME=2026-01-01…`. That is the previous run's provenance on new bytes. `provenance_problems()` returns none, because all four tags are present and non-empty. The guard fails toward pass, and the catalog would publish `cd:sha`/`cd:run_time` naming a run that did not make the file.
  - **1.8-50.** Run 222's tags land correctly. But `cd_cog_write(x)` with `tags = NULL` on a tagged input keeps all four stale `CD_*` tags, contrary to the roxygen ("dropped first") and to `test-cd_cog_write.R:1894-1897`.
  - **1.8-54.** Correct.

  CI installs a current terra, so the exposure is a local run or a user's library pinned in [1.8-42, 1.8-54).
  Fix: `terra (>= 1.8-54)`. Before settling it, enumerate every terra call the changed code makes (`metags()`, `metags<-` named, `metags<-` NULL, `writeRaster` COG tags). The R2 floor came from one of them.

- **[severity: fragile]** scripts/_lib.R:367-401 (`run_provenance()`) together with how the pipelines load `cd` (scripts/pipeline_stage3_edh.R:25-26, pipeline_update_edh.R:62-63, daily_publish.R:20-21)
  `CD_SHA` and `CD_VERSION` describe the checkout: `git rev-parse HEAD`, `git status`, `./DESCRIPTION`. The R code that writes and hashes the bytes is whatever `cd` is installed (`requireNamespace("cd")` then `library(cd)`): `cd_aggregate`, `cd_cog_write`, `cd_stac_catalog`.
  - **Locally nothing ties the two together.** The installed cd here reports `Version 0.6.2` with no `RemoteSha`, and the version is the same for every commit until release. So a live stage3 run can stamp a clean HEAD on COGs built by a `cd` installed from another branch, or by `devtools::install()` from an edited tree that has since been stashed.
  - **`sha_problems()` exists for exactly that case**, "the published files name the commit that made them". It checks the tree, which is clean, so it passes. This is "a wrong SHA satisfies every guard built to catch its absence" (code-check.md, Written data outlives the fix), and the same trap as code-check-r's "`data-raw/` script must load the source tree, not the installed package".
  - **CI is consistent**: `extra-packages: local::.` installs from the checkout that `GITHUB_SHA` names.

  The post-merge republish that `task_plan.md` defers is a local stage3 run, so this is the path that matters next.
  Fix: off CI, `pkgload::load_all()` the checkout rather than preferring the installed package. Alternatively, refuse a live publish unless the loaded `cd` is the checkout, for example `pkgload::is_dev_package("cd")` or an installed `RemoteSha` equal to `CD_SHA`.

- **[severity: fragile]** scripts/_lib.R:502-509 (`sha_problems()`), as applied to file SHAs in scripts/_publish.R:184-187
  "Not `-dirty` and not `unknown`" stands in for "a commit a consumer can resolve", and they are not the same.
  - **Measured now.** The 228 local daily files carry `CD_SHA` 39390af (findings.md, the `--rewrite` run). `git ls-remote origin 'refs/heads/124*'` is empty and `git branch -r --contains 39390af` is empty: the commit exists only on this machine. A live `Rscript scripts/daily_publish.R` today would pass `sha_problems()` and publish 228 files whose provenance names an unreachable commit.
  - **The same holds for stage3** run from any local or unpushed commit.

  The plan's "re-run `--rewrite` from clean main after merge" is enforced only by memory.
  Fix: for a live publish off CI, `git fetch` and then require `git merge-base --is-ancestor <sha> origin/main`. Apply it to the run's SHA in the pipelines and to each distinct file SHA in `daily_publish()`.

## Notes (not defects, or latent with no current instance)

- scripts/_publish.R:100-103 (`s3_put_if`). "Re-run to merge onto the new one" is right for a hand-run `daily_publish.R`. It is wrong for CI. CI's year Y is already on S3, so the re-run's STEP D stops at `daily_manifest_problems()` (published through Y, manifest ends Y-1) and never reaches `daily_publish()`. That message carries the correct remedy, so the cost is one misleading sentence. The race is also narrow: a loser has usually been refused already by the pre- or post-sync listing check.
- scripts/_publish.R:261 (gap hint). When `last > newest` the hint downloads `newest`, which repairs nothing. A manifest naming a year whose files are gone, or EDH's `latest_complete` regressing below a published year, both reach it. Before #124 the second case read as "current"; now STEP D goes red with a wrong remedy. Rare.
- scripts/_publish.R:163-166. If `pgrep` is missing, `system2` returns status 127, which is read as "not busy" (fails toward pass). macOS ships `pgrep`, so this is latent.
- scripts/_publish.R:185. `%||%` is base R only from 4.4.0, and neither `_lib.R` nor the attached `cd` exports it. On R 4.1-4.3 (which DESCRIPTION admits for the package) a live `daily_publish()` errors with "could not find function". It is loud, and CI uses R release.
- R vs Python `CD_SHA` (row 4). Only `CD_RUN_TIME` is handed to the child. Passing `CD_SHA` through the environment as well (`Sys.setenv(CD_SHA = prov[["CD_SHA"]])`, read first by `_lib.py`) would make "one env contract" true for both keys, and remove the local divergence.

## Round-1 and round-2 fixes: re-checked

- **R1 re-hash after the ETag check (all three publishers).** Sound, as R2 found. Equal re-hashes imply equal tags, because the tags are in the bytes. So `provenance_problems`/`sha_problems`, evaluated earlier, still describe what went up.
- **R1 `s3_put_if`.** Sound for the merge race. It does not protect the objects themselves against a second writer between the ETag check and the put, but that window is seconds.
- **R1 R `run_provenance` failed-status, and R1 Python `rewrite()` refusal.** Sound. Both read once, at start.
- **R2 terra floor.** **Insufficient**: finding 1.
- **R2 `head_object` retry.** Sound: it breaks on any status other than 0 and below 500, and returns the last code.
- **R2 gap hint.** Sound for `last < newest` (traced above). Wrong for `last > newest` (note).
- **R2 STEP 2 message, and the `catalog.json` unlink moved before `stray_problems`.** Sound in both pipelines.
