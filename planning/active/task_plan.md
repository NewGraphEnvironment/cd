# Task: Bulk data fetch safeguards — fix gaps, extract as soul convention (#38)

## Problem

Three safeguards were filed as missing in `scripts/backfill_edh_all.py`:
single-instance pgrep guard, retry-with-backoff, backup-before-delete.
On exploration, (1) and (2) are already implemented (commits `5bf1b34`,
`6f66a01`) but the issue checklist is stale. The `_cds_backup/`
directory on disk (375 files) shows backup-before-delete is in
operational use but never codified. Sibling script
`backfill_edh_tmax_tmin.py` is missing all three safeguards.

Goal: extract the three safeguards (plus shared `log` helper and
`MONTH_NAMES`) into a new `scripts/_lib.py`, refactor both production
bulk-fetch scripts to import from it, and add a `backup_before_delete()`
helper that codifies the on-disk pattern. Soul convention extraction
(Layer 2) is a follow-up issue once this lands.

## Phase 1 — Extract `scripts/_lib.py`

- [ ] Create `scripts/_lib.py` with helpers parameterized for reuse:
      `preflight_single_instance(name)`, `with_retry(fn, ...)`,
      `write_geotiff(da, out_path, month_names)`, `log(msg)`,
      `MONTH_NAMES`. Hoist `get_token()` too — both scripts duplicate it.
- [ ] Refactor `backfill_edh_all.py` to `from _lib import (...)`. Drop
      the now-redundant local copies (lines 69-94, 97-115, 118-127,
      153-178, 181-182).
- [ ] Smoke test on one year:
      `uv run scripts/backfill_edh_all.py --year 1950`. Outputs match
      pre-refactor.

## Phase 2 — Port safeguards to `backfill_edh_tmax_tmin.py`

- [ ] `from _lib import (...)` at top.
- [ ] `preflight_single_instance("backfill_edh_tmax_tmin")` at top of
      `main()`.
- [ ] Wrap `xr.open_dataset(zarr_url, ...)` (line 96) in `with_retry`.
- [ ] Wrap each `.compute()` call (lines 132-133) in `with_retry`.
- [ ] Replace inline `to_geotiff_raster` (lines 141-155) with
      `write_geotiff` from `_lib.py`.
- [ ] Replace ad-hoc `print(...)` with `log(...)`.
- [ ] Smoke test:
      `uv run scripts/backfill_edh_tmax_tmin.py --year 1950`.

## Phase 3 — Add `backup_before_delete()` helper

- [ ] Add `backup_before_delete(files, backup_subdir="_backup")` to
      `_lib.py`. Each file moves to `file.parent/backup_subdir/file.name`.
      No overwrite (skip with warning if backup target exists).
- [ ] Module docstring documents intended use during regenerations and
      points at `data/backfill/monthly/_cds_backup/` as the worked
      example.
- [ ] No call sites added now — both current scripts are pure-write,
      protected by idempotency. Helper exists for #48 if its
      aggregation method requires re-running existing years.

## Phase 4 — Verify safeguard behaviors

- [ ] Pgrep guard fires: start one
      `backfill_edh_tmax_tmin --year 1950` in background, immediately
      try to start a second; second ABORTs.
- [ ] Output equivalence: byte-compare a re-rendered year file from
      both scripts against the pre-refactor file.

## Phase 5 — File soul-convention follow-up

- [ ] After this PR merges, file an issue in
      `NewGraphEnvironment/soul` referencing #38, scoping a
      `bulk-fetch-safeguards.md` convention file with `scripts/_lib.py`
      as the canonical worked example.

## Phase 6 — Code-check, commit, PR

- [ ] `/code-check` on staged diff before each commit.
- [ ] Atomic commits: `_lib.py` + `backfill_edh_all.py` refactor (1),
      `backfill_edh_tmax_tmin.py` port (2), `backup_before_delete` (3).
- [ ] PR with `Fixes #38`, SRED ref in body
      (`Relates to NewGraphEnvironment/sred-2025-2026#23`).

## Validation

- [ ] Single-year smoke test on `backfill_edh_all.py` succeeds.
- [ ] Single-year smoke test on `backfill_edh_tmax_tmin.py` succeeds.
- [ ] Pgrep guard refuses second concurrent instance of each script.
- [ ] No new dependencies in either script's PEP 723 inline deps.
- [ ] `/code-check` clean on each commit.
- [ ] PWF checkboxes match landed work.
- [ ] `/planning-archive` on completion.

## Out of scope

- Python lint config (ruff, black) — `cd` is R-first.
- Pytest test runner.
- Soul PR itself (deferred).
- `probe_edh_vars.py` and `test_edh_era5_land.py` (one-shot validation
  scripts; safeguards target production bulk-fetch).
- A `--regen` flag wiring `backup_before_delete` into either script;
  helper ships unused, first real call site lands with #48 if needed.
