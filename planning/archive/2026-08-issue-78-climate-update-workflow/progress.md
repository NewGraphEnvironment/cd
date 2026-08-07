# Progress — Monthly Climate Data Update workflow fails every scheduled run (#78)

## Session 2026-08-07

- Plan-mode exploration — read `.github/workflows/climate-update.yml` and
  `scripts/pipeline_update_edh.R` in full
- Found a third defect not in the issue body: the `Commit log` step is dead code
  because `logs/*.log` is gitignored — so `contents: write` would fix nothing.
  Recommended `actions/upload-artifact@v4` instead; keeps the token read-only.
- Confirmed `climate-update-failure` label does not exist yet (repo has only the
  9 GitHub defaults) — must be created in Phase 4
- Phases approved by user
- Created branch `78-monthly-climate-data-update-workflow-fa` off main
- Scaffolded PWF baseline from issue #78 with approved phases
- Next: start Phase 1

- Phase 1 (62256d5): extra-packages local::., permissions block, artifact
  upload replacing the dead log-commit step, fail-loud package load in both
  pipeline scripts
- Phase 2 (041f16e): --dry-run / CD_DRY_RUN with STEP 0 credential probes.
  Needed httpauth = 1L for EDH; verified locally, exit 0 in ~4 s
- Phases 3+4 (ca4e41e): weekly dry-run cron, dispatch input, Resolve run mode
  step, auto-file-issue-on-failure; created the climate-update-failure label
- Code check (0f4a3cc): 2 findings, both fixed — misleading "no write" banner,
  and an empty-GITHUB_RUN_ID hole in the sentinel key
- Phase 5: two acceptance dispatches. Everything in scope confirmed working.
  They exposed Bug 4 — the EDH_TOKEN secret has been stale since 2026-04-14,
  which is why the pipeline could never have run even with bugs 1-3 fixed.
  Alarm fired (issue #79) and deduped (comment, not a second issue).
- Blocked, for the repo owner: rotate EDH_TOKEN. The sandbox refused to let me
  overwrite shared CI credential material, which is the right call.
- Next: archive PWF, open PR
