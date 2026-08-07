# Findings — Monthly Climate Data Update workflow fails every scheduled run (#78)

## Issue context

The **Monthly Climate Data Update** workflow (`.github/workflows/climate-update.yml`)
has failed on **every scheduled run** (2026-05-01, 06-01, 07-01, 08-01). The only
green runs were manual `workflow_dispatch` back in April. So the automated producer
pipeline has effectively never worked on schedule, and the S3 climate data has not
been auto-updated since April.

This is **not** the benign "no new data this month" case — the job dies at package
load, before it ever checks for new data.

### Bug 1 — `devtools` is not installed on the runner

`scripts/pipeline_update_edh.R:31`:

```r
if (requireNamespace("cd", quietly = TRUE)) library(cd) else devtools::load_all()
```

CI installs cd's *dependencies* but not cd itself, so the `else` branch runs →
`devtools::load_all()` →

```
Error in loadNamespace(x) : there is no package called 'devtools'
Execution halted
```

The pipeline halts immediately; no EDH fetch, no catalog read, nothing.

### Bug 2 — the workflow token is read-only

The `Commit log` step (`if: always()`) then runs and cannot push:

```
remote: Permission to NewGraphEnvironment/cd.git denied to github-actions[bot].
fatal: ... The requested URL returned error: 403   (exit code 128)
```

There is no `permissions:` block, so the default `GITHUB_TOKEN` is read-only. This
would fail **even on a legitimate no-op month**, so the job can never go green as
written.

### QA / monitoring — dry-run + auto-file-issue-on-failure

Two complementary mechanisms: a **dry-run mode** to actively confirm the plumbing
(now and on a weekly heartbeat), and an **auto-filed GitHub issue on failure** as
the durable, team-visible alarm. We want to confirm the fix works **without**
waiting for the Sept 1 cron and **without** a full S3 write (which incurs the EDH
pull + COG rebuild + egress this producer is meant to minimize).

A weekly dry-run cron also keeps the scheduled workflow active so GitHub does not
auto-disable it after 60 days of repo inactivity — a silent-failure mode that
failure emails never catch.

### References

- Failing runs: [30688521648](https://github.com/NewGraphEnvironment/cd/actions/runs/30688521648) (2026-08-01),
  [28501189058](https://github.com/NewGraphEnvironment/cd/actions/runs/28501189058) (2026-07-01)
- Workflow: `.github/workflows/climate-update.yml`
- Entry point: `scripts/pipeline_update_edh.R`

## Bug 3 (discovered during plan-mode exploration) — `Commit log` is dead code

Not in the issue body. `.gitignore:20` is:

```
# Pipeline run logs (keep .gitkeep so the dir survives)
logs/*.log
```

and the workflow writes `logs/update_$(date +%Y%m%d).log`. Confirmed with
`git check-ignore -v logs/update_20260807.log` → matches `.gitignore:20`.

So in the `Commit log` step:

- `git add logs/` stages **nothing** (the new log is ignored)
- `git diff --cached --quiet` succeeds → the `||` guard short-circuits the commit
- only `git push` remains — and it 403s

`git push` contacts `/info/refs?service=git-receive-pack`, which a read-only token
rejects with 403 **before** git ever determines there is nothing to push. That is
why the step fails even on a no-op month, and it explains why the 403 appeared with
no preceding commit in the log.

**Consequence for the fix:** granting `contents: write` would "repair" a step that
was never going to commit anything. The real pipeline publishes to **S3**, not git.
Nothing in this workflow legitimately needs write access to the repo. Replace the
step with `actions/upload-artifact@v4` and keep `contents: read`.

## Repo state relevant to the fix

- `.github/workflows/` contains only `climate-update.yml` and `pkgdown.yaml`.
  `pkgdown.yaml` already models the right pattern: top-level `permissions: read-all`
  plus a narrower job-level block. `climate-update.yml` has neither.
- `gh label list` → only the 9 GitHub defaults. The `climate-update-failure` label
  used for issue dedup **must be created** as part of this work.
- Some logs are tracked (`logs/backfill_20260405.log` and two others) — committed
  before the ignore rule landed. `logs/.gitkeep` keeps the directory alive.
- `cd_s3_push()` already takes `dry_run` (`R/cd_s3_push.R:32`), used as
  `dry_run = FALSE` at `scripts/pipeline_update_edh.R:241`. Note it maps to
  `aws s3 sync --dryrun`, which is **read-only** — it does not prove the bucket is
  writable. Hence the separate sentinel-key write probe in Phase 2.
- Pipeline exit points: `quit(status = 1)` at lines 71, 79, 152; `quit(status = 0)`
  at lines 94 and 155. Line 94 (`latest_year >= current_year`) fires **before**
  the candidate-year log, so the dry-run auth probes must run before Step 1 to
  execute on every path.

## Dry-run auth probe: libcurl needs `httpauth = 1L` for EDH

First cut of the EDH probe embedded credentials in the URL the way
`scripts/backfill_edh_all.py:70` does (`https://edh:<token>@data...`). That
returned **HTTP 401** from R while plain `curl -u` on the same URL returned 200.
Two separate causes, both worth knowing:

1. The EDH token is 104 characters and is not URL-encoded, so libcurl will not
   reliably accept it in a userinfo field. Credentials belong on the handle
   (`username=`/`password=`), not in the URL — which also keeps the token out of
   any string that could end up in a log.
2. Even on the handle, it still 401'd until `httpauth = 1L` (`CURLAUTH_BASIC`)
   was set. libcurl defaults to waiting for a `WWW-Authenticate` challenge before
   sending credentials, and EDH does not send one — it just 401s. Forcing
   preemptive Basic fixes it.

Verified matrix against
`.../era5/reanalysis-era5-land-no-antartica-v0.zarr/.zmetadata`:

| handle config | result |
|---|---|
| creds in URL, no httpauth | 401 |
| `username`/`password`, no httpauth | 401 |
| `username`/`password` + `httpauth = 1L` | **200** |
| `userpwd=` + `httpauth = 1L` | 200 |

`.zmetadata` and `.zgroup` both HEAD 200; `zarr.json` is 404 (this store is
zarr v2). Used `.zmetadata`.

## Local dry-run verification (2026-08-07)

`Rscript scripts/pipeline_update_edh.R --dry-run` — exit 0 in ~4 s:

```
Mode: DRY RUN (no fetch, no write, no publish)
=== STEP 0: Verify credentials ===
  EDH: OK (HTTP 200)
  AWS identity: arn:aws:iam::414155577829:user/airvine
  AWS write to s3://stac-era5-land: OK
=== STEP 1: Check S3 catalog for latest year ===
Latest year on S3: 2025
Candidate years to fetch: 2026
=== DRY RUN COMPLETE ===
```

`aws s3 ls s3://stac-era5-land/_healthcheck/` returns empty afterwards — the
sentinel round-trip cleans up after itself. `CD_DRY_RUN=true` with no flag takes
the same path.

## Bug 4 (found by the new probe) — the `EDH_TOKEN` repo secret is stale

The acceptance dispatch surfaced a **fourth** independent reason this workflow
could never have succeeded, on top of the three above.

- The EDH probe passes locally with the token in `~/.Renviron` — HTTP 200.
- On the runner it returns **403**. Not 401: the request authenticates, the
  principal is forbidden. That is a revoked or expired token, not a malformed one.
- `gh secret list` → `EDH_TOKEN` last set **2026-04-14T17:04:21Z**, which is
  exactly when the last green run happened. Every run since has been red.

So even with bugs 1–3 fixed, the live monthly run would still have died — just
six hours later, at the EDH fetch, instead of in four seconds at STEP 0. This is
the case for probing credentials up front, and the clearest possible argument for
the dry-run heartbeat: no amount of static review would have found it.

**Action required (repo owner):** `gh secret set EDH_TOKEN` with a current
DestinE token. Not done here — overwriting shared CI credential material is the
owner's call, and the sandbox correctly refused it.

If DestinE tokens are short-lived this will recur. The weekly dry-run cron is
what catches it next time, within days rather than at the next monthly run.

## Acceptance runs (2026-08-07, branch `78-monthly-climate-data-update-workflow-fa`)

Two `workflow_dispatch` runs with `dry_run=true`:

- [31204565836](https://github.com/NewGraphEnvironment/cd/actions/runs/31204565836)
- [31204944259](https://github.com/NewGraphEnvironment/cd/actions/runs/31204944259)

Both red at `Run EDH update pipeline` — and only there, on the stale token.
Everything the issue set out to fix is confirmed working:

| Claim | Evidence |
|---|---|
| Bug 1 fixed — `cd` installs, no `devtools` error | script ran to STEP 0; no `loadNamespace` error |
| Bug 2/3 fixed — no 403 on the log path | `Upload run log` ✓ on both runs |
| Dry-run mode wired | step env shows `CD_DRY_RUN: true`; banner logged "DRY RUN" |
| `Resolve run mode` maps dispatch input | `event=workflow_dispatch schedule='' -> dry_run=true` |
| Failure alarm fires | run 1 opened issue #79 |
| Alarm dedups | run 2 **commented** on #79; still exactly one open issue |
| Issue body renders | table + `<details>` log tail correct, token not leaked |

The "deliberately break something" step in the plan was unnecessary — the stale
token broke it for real, which exercised both the create and the comment path.

Not yet proven end-to-end: the live (non-dry-run) publish path. It is unchanged
by this work, and cannot be exercised until the token is rotated.
