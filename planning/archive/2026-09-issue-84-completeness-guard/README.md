## Outcome

All three EDH backfillers checked year completeness *after* `.compute()` — the
point where the lazy xarray graph actually pulls from the Zarr store — so every
monthly cron run downloaded a full partial year across 15 variables and threw it
away, against a metered free tier. Added `months_available()` to `scripts/_lib.py`,
which answers the same question from the time coordinate alone (Zarr materialises
coordinates on open, so no data moves), and guarded all three scripts before their
first fetch.

Two things came out of it that the issue did not anticipate. The defect was in
**three** scripts, not the two named — `backfill_edh_tmax_tmin.py` writes its guard
as `n_months != 12`, which is why the original grep missed it. And the four
annual-derived snow variables had **no completeness guard at all**, so a partial
year wrote wrong rasters that the `if not p.exists()` idempotency check then
preserved permanently; guarding at the top of `process_year` closes that too, which
is a deliberate behaviour change.

Verification was metadata-only and cost no quota. The two EDH stores turned out to
be two months apart (hourly ends 2026-05-31, daily 2026-07-31) — direct evidence
for checking per store rather than pooling, and visible in the output as
`SKIP rh: got 5 months` beside `SKIP prcp: got 7 months` in the same year. The
out-of-scope partial-trailing-month question was measured and closed: both stores
publish whole months, so the hazard is not currently realised, and the case is
pinned in `scripts/test_lib.py` rather than left to chance.

Closed by: PR (see below), commits fbfe84a..HEAD
