# Findings — Bulk data fetch safeguards (#38)

## Issue context (verbatim from #38)

The EDH migration surfaced a reusable pattern: "what safeguards does a
bulk data fetch script need to be polite AND safe against its own
failure modes?"

Born from painful experience on CDS (#33: rate-limited, orphan jobs,
zombie processes) and the EDH migration QA (#36: atomic writes,
partial writes, silent skips).

### Layer 1: fix the gaps in this project's script

`scripts/backfill_edh_all.py` already has:

- [x] Idempotency per output file (skip if exists)
- [x] Atomic writes (.tif.tmp + os.replace) so a killed run doesn't
      leave truncated files that fool the idempotency check
- [x] Explicit SKIP logging when source data is incomplete

Missing safeguards to add on this branch:

- [ ] Single-instance pgrep pre-flight check
- [ ] Retry-with-backoff on transient HTTP errors from EDH
- [ ] Backup-before-delete when regenerating from a new source

### Layer 2: extract as a soul convention

Once Layer 1 lands, propagate the pattern to the
[soul](https://github.com/NewGraphEnvironment/soul) repo as a
convention.

## State found during plan-mode exploration

**Layer 1 is partially already done.** The issue checklist above is
stale.

Commits already on main:

- `5bf1b34` Add single-instance guard and retry-with-backoff to EDH
  backfill — closed safeguards 1 and 2 in `backfill_edh_all.py`.
- `6f66a01` Skip pgrep single-instance check on GHA — fixed CI false
  positive.

So `backfill_edh_all.py` already has:
- `preflight_single_instance()` at lines 69-94 (with `GITHUB_ACTIONS`
  bypass)
- `with_retry(fn, ...)` at lines 97-115 (4 attempts, exponential
  backoff, retries on `OSError`/`ConnectionError`/`TimeoutError`)
- Atomic write via `.tmp` + `os.replace` at lines 153-178
  (`write_geotiff`)

Backup-before-delete (3rd safeguard) is **in operational use on disk**
but never codified: `data/backfill/monthly/_cds_backup/` holds 375
CDS-era TIFs, hand-managed before the EDH backfill overwrote them.

**Sibling script `backfill_edh_tmax_tmin.py` is missing all three
safeguards.** Same shape as `backfill_edh_all.py` (year loop,
idempotency, monthly aggregation, GeoTIFF write) but no pgrep guard,
no retry, no atomic write. One-shot scripts (`probe_edh_vars.py`,
`test_edh_era5_land.py`) are not in scope.

## Architecture decisions taken (user-confirmed)

1. **Extract to `scripts/_lib.py`** rather than copy-paste between the
   two scripts. One source of truth, well-positioned for the eventual
   snow-backfill script (#48). Module is plain importable Python; both
   scripts retain their PEP 723 inline-deps shebang.
2. **Soul convention extraction is a follow-up.** This branch closes
   Layer 1; Layer 2 ships as a separate soul-repo PR after merge.
3. **Hoist `get_token()` into `_lib.py`** while refactoring — both
   scripts already duplicate it.
4. **Keep `bc_slice`, `tetens_es` in-script** — they are
   pipeline-specific to the EDH all-vars pipeline, not bulk-fetch
   safeguards.
5. **Ship `backup_before_delete()` helper unused.** First real call
   site lands with #48 if its aggregation method requires re-running
   existing years.

## Inventory of bulk-fetch scripts in `scripts/`

| Script | Pgrep | Retry | Atomic Write | Notes |
|---|---|---|---|---|
| `backfill_edh_all.py` | done (69-94) | done (97-115) | done (153-178) | All 7 cd vars, 1950-2025 |
| `backfill_edh_tmax_tmin.py` | missing | missing | missing | tmax/tmin only |
| `probe_edh_vars.py` | n/a | n/a | n/a | One-shot validation; out of scope |
| `test_edh_era5_land.py` | n/a | n/a | n/a | Benchmark; out of scope |

## Python tooling (none configured)

- No `pyproject.toml`, no `ruff.toml`, no `pytest` config in repo.
- All scripts use PEP 723 inline deps with
  `#!/usr/bin/env -S uv run --script` shebang — self-contained.
- CLAUDE.md documents R conventions only; Python is utility-tier.

## Anchors for the soul convention follow-up

When the soul-repo issue lands, the body cribs from #38's "Layer 2"
checklist (politeness / self-safety / data integrity / performance
sanity). Pin the new `scripts/_lib.py` as the canonical worked example.
