# Archive: Bulk data fetch safeguards (#38)

## Outcome

Extracted bulk-fetch safeguards (pgrep guard, retry-with-backoff,
atomic write, log, get_token, MONTH_NAMES) from
`scripts/backfill_edh_all.py` into a new shared `scripts/_lib.py`,
and ported them to the sibling `scripts/backfill_edh_tmax_tmin.py`
(which previously had none of the three). Added a new
`backup_before_delete()` helper codifying the on-disk pattern from
`data/backfill/monthly/_cds_backup/` (375 hand-moved CDS-era TIFs from
the EDH migration). Released as **v0.1.6** (patch).

Sets up the snow-vars backfill script (#48) to import the same
helpers without re-implementing — a `from _lib import …` away.

## Key findings worth remembering

- **Issue checklists go stale.** Plan-mode exploration found 2 of 3
  named "missing" safeguards already implemented (commits `5bf1b34`,
  `6f66a01`) in `backfill_edh_all.py`. Always verify the issue body
  against the code before sizing the work.
- **Backup-before-delete pattern is on disk, not in code.**
  `data/backfill/monthly/_cds_backup/` (375 files) is the worked
  example, hand-moved during the EDH migration. The
  `backup_before_delete()` helper now codifies it; first real call
  site lands with #48 if its aggregation method requires re-running
  existing year files.
- **PEP 723 inline-deps shebang scripts can import a sibling module.**
  `_lib.py` is a plain importable module (no shebang); each calling
  script's `# /// script` block already pulls `xarray`, `rasterio`,
  `rioxarray`, so the shared module imports them at top level
  without adding new deps.
- **pgrep guard is parameterized as `preflight_single_instance(name)`** —
  each script passes its own basename so the guard applies per-script,
  not globally across all backfills.
- **Layer 2 (soul convention extraction)** is a follow-up, not blocking:
  open issue in `NewGraphEnvironment/soul` for `bulk-fetch-safeguards.md`
  with `scripts/_lib.py` as the canonical worked example.

## Closing ref

- Issue: NewGraphEnvironment/cd#38
- PR: NewGraphEnvironment/cd#52 (merged 2026-05-03, squash e8584c9)
