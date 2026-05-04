# Progress — Bulk data fetch safeguards (#38)

## Session 2026-05-03

- Plan-mode exploration — confirmed 2 of 3 safeguards already in
  `backfill_edh_all.py` (commits `5bf1b34`, `6f66a01`); sibling
  `backfill_edh_tmax_tmin.py` is missing all three. Phases approved
  by user with two scope decisions: extract helpers to
  `scripts/_lib.py`, and defer soul convention to a follow-up.
- Created branch `38-bulk-fetch-safeguards` off main (post v0.1.5
  release).
- Scaffolded PWF baseline.
- Phases 1–3 implemented: `scripts/_lib.py` ships
  `preflight_single_instance(name)`, `with_retry`, `write_geotiff`,
  `log`, `get_token`, `MONTH_NAMES`, and new
  `backup_before_delete()` helper. Both `backfill_edh_all.py` and
  `backfill_edh_tmax_tmin.py` now import from `_lib`. Net
  -156/+41 LOC.
- Phase 4 verification: pgrep guard fires correctly when a second
  instance launches (tested live with both pids reported); both
  scripts idempotent-skip on existing year files; no orphaned
  imports remain.
- Methodology pinned on #48 (snow vars): 7-day rolling sum of daily
  `smlt` for `snowmelt_rate_peak`, daily UTC product preferred over
  hourly to dodge the `stepType=accum` trap (issue comment 4367348096).
- Next: commit, then Phase 5 (file soul-convention follow-up issue)
  + Phase 6 (PR).
