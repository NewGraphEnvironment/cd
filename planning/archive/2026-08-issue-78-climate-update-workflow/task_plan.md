# Task: Monthly Climate Data Update workflow fails every scheduled run (#78)

The **Monthly Climate Data Update** workflow (`.github/workflows/climate-update.yml`)
has failed on **every scheduled run** (2026-05-01, 06-01, 07-01, 08-01). The only
green runs were manual `workflow_dispatch` back in April. The automated producer
pipeline has effectively never worked on schedule, and the S3 climate data has not
been auto-updated since April.

This is **not** the benign "no new data this month" case — the job dies at package
load, before it ever checks for new data.

Exploration confirmed **three** defects, not the two in the issue body:

1. **`devtools` missing on the runner.** `scripts/pipeline_update_edh.R:31` is
   `if (requireNamespace("cd", ...)) library(cd) else devtools::load_all()`.
   `setup-r-dependencies@v2` installs cd's *dependencies*, not cd, and has no
   `extra-packages:` — so the `else` branch fires and dies with
   `there is no package called 'devtools'`. Nothing downstream ever runs.

2. **Read-only `GITHUB_TOKEN`.** No `permissions:` block anywhere in the file, so
   the `Commit log` step's `git push` gets 403. `git push` always requests
   `git-receive-pack` during ref advertisement, so it 403s *even with nothing to
   push* — the job can never go green as written.

3. **(New — not in the issue) the `Commit log` step is dead code.**
   `.gitignore:20` is `logs/*.log`, and the pipeline writes
   `logs/update_$(date +%Y%m%d).log`. So `git add logs/` stages nothing, the
   `git diff --cached --quiet` guard short-circuits the commit, and only the doomed
   `git push` remains. Granting `contents: write` would "fix" a step that was never
   going to commit anything.

This changes the recommended fix for #2: **delete the git-commit-of-logs and upload
the log as a workflow artifact instead.** The real pipeline writes to S3, not git —
nothing in this workflow legitimately needs `contents: write`.

## Phase 1: Fix the two blocking bugs

- [x] `climate-update.yml`: give `setup-r-dependencies@v2` `extra-packages: local::.`
      so **cd itself** installs and the script takes the `library(cd)` branch.
      Preferred over `any::devtools` — it exercises the installed-package path CI
      should be testing, and avoids pulling the whole dev-tooling tree.
- [x] `pipeline_update_edh.R:31`: make the fallback fail loudly instead of erroring
      inside `loadNamespace` — `library(cd)` / `else if (requireNamespace("devtools"))`
      `load_all()` / `else stop("cd not installed and devtools unavailable ...")`.
      Grep `scripts/` for the same idiom and fix any sibling occurrence.
- [x] Replace the `Commit log` step with `actions/upload-artifact@v4` (`if: always()`,
      path `logs/`, ~30d retention). No `contents: write`.
- [x] Add a minimal job-level `permissions:` block — `contents: read`,
      `issues: write` (needed by Phase 4 only).

## Phase 2: Dry-run mode in `pipeline_update_edh.R`

- [x] Read `CD_DRY_RUN` env var (also accept a `--dry-run` CLI flag for local use);
      `dry_run <- ...` resolved next to the existing config block.
- [x] Add an auth-probe section that runs **before** Step 1 so it executes on every
      path (Step 1/2 can `quit(0)` early when already current):
      - EDH: token present + a cheap authenticated probe
      - AWS: `aws sts get-caller-identity`
      - AWS write proof: PUT then DELETE a sentinel key
        `s3://stac-era5-land/_healthcheck/<run-id>` — creds-valid alone does not
        prove the bucket is writable, and write perms are exactly what broke last
        time this pipeline was touched.
- [x] When `dry_run`: run Step 1 (catalog read) + Step 2 (target year), log what a
      real run *would* fetch, then `quit(status = 0)` **before** Step 3
      (`uv run backfill_edh_*.py`). No EDH pull, no COG rebuild, no S3 push.
- [x] Keep the non-dry-run path byte-identical to today's behaviour.

## Phase 3: Wire dry-run into the workflow

- [x] Add `workflow_dispatch.inputs.dry_run` (boolean, default `true`) — a manual
      trigger is cheap and safe by default.
- [x] Add a second cron `'0 6 * * 1'` (Mondays 06:00 UTC) alongside the existing
      monthly `'0 6 1 * *'`.
- [x] Add a `Resolve run mode` step that writes `CD_DRY_RUN` to `$GITHUB_ENV` via
      plain `if/elif/else` on `github.event_name` / `github.event.schedule` — **not**
      a nested `&&`/`||` expression ternary, which is unreadable and mis-evaluates
      on falsy inputs. Echo the resolved mode into the log.

## Phase 4: Auto-file a GitHub issue on failure

- [x] Create the `climate-update-failure` label (does not exist yet — repo has only
      the 9 GitHub defaults).
- [x] Add a final `if: failure()` step using `gh`: search for an open issue with that
      label; **comment** on it if one exists, otherwise **create** one. Dedup by
      label so a run of red months yields one thread, not four.
- [x] Body carries: run URL, event name, resolved dry-run mode, and the tail of
      `logs/*.log`. Applies to both the monthly real run and the weekly dry-run, so
      a broken dry-run self-reports too.

## Phase 5: Verify + document

- [x] Push the branch, then `gh workflow run climate-update.yml --ref <branch>
      -f dry_run=true` and watch it go green. This is the acceptance test — it
      exercises package load, secrets, catalog read, target-year compute, and
      artifact upload without an S3 write.
- [x] Deliberately break something on the branch (e.g. bad catalog URL) and
      re-dispatch to confirm the auto-file-issue step fires and dedups; close the
      resulting test issue.
- [x] Record both run URLs + outcomes in `planning/active/findings.md`.
- [x] Note in `CLAUDE.md` that gitignored paths cannot be committed by CI — the
      `logs/*.log` + `git add logs/` trap that hid bug #3 for four months.

## Validation

- [x] Tests pass (`devtools::test()`) — 214 PASS / 0 FAIL
- [x] `/code-check` clean — 2 findings, both fixed in ca4e41e..HEAD
- [x] PWF checkboxes match landed work
- [x] `/planning-archive` on completion
