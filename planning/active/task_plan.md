# Task: Backfillers fetch a full partial year before checking it has 12 months (#84)

The monthly `climate-update` cron polls for a new year of ERA5-Land. Because the
unit of publication is a **whole calendar year**, ~11 runs a year correctly produce
nothing. They are not cheap, though: in all three backfillers `.compute()` — where
the lazy xarray graph actually pulls data from the EDH Zarr store — runs *before*
the 12-month completeness check. Every monthly run downloads and aggregates a full
partial year across 15 variables, then discards it, against a metered free tier.

Exploration found the defect in **three** scripts, not the two named in the issue,
and surfaced a second consequence that raises the stakes: in `backfill_edh_snow.py`
the four annual-derived variables have **no completeness guard at all**, so a
partial year writes wrong rasters that the `if not p.exists()` idempotency check
then preserves forever.

## Phase 1: The helper

- [x] Add `months_available(ds, year)` to `scripts/_lib.py`, returning `0` for a
      year absent from the store.
- [x] Docstring states the no-fetch guarantee, since that is the whole point.

## Phase 2: `backfill_edh_all.py`

- [x] In `process_year()`, after the `needed` dict is built: compute
      `months_available()` once per store.
- [x] Drop hourly-derived entries from `needed` when the hourly store is short;
      drop `prcp` when the daily store is short. Preserve the existing
      `SKIP <var>: got N months, expected 12` wording.
- [x] Return early when `needed` is empty — before `bc_slice`/`.sel()`.
- [x] Leave the existing post-compute `== 12` checks in place as a backstop.

## Phase 3: `backfill_edh_snow.py`

- [x] In `process_year()`, bail before `state_box`/`accum_box` when the hourly
      store has fewer than 12 months for the year.
- [x] Intentional behaviour change: the four annual-derived variables are no
      longer written from a partial year.
- [x] Guard `snowfall_fraction`'s separate daily-store read on the daily store's
      own count.

## Phase 4: `backfill_edh_tmax_tmin.py`

- [x] Guard in `main()` before the `ds["t2m"].sel(...)`, after the existing
      output-exists check.

## Phase 5: Verify and document

- [x] Acceptance test — metadata only, no data fetch, no quota spend: probe both
      Zarrs for `months_available()` on a known-complete year and the in-progress
      year. Both known answers must be right.
- [x] Confirm an incomplete year returns in seconds having logged the skip.
- [x] Do not run a complete year end-to-end — that is a full fetch.
- [x] Update the now-stale comment in `scripts/pipeline_update_edh.R`.
- [x] Record measurements in `findings.md`.

## Validation

- [ ] `/code-check` clean on each commit
- [ ] `devtools::test()` still green
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
