# Progress — Snow vars for hydrology departure (#48)

## Session 2026-05-03

- Plan-mode exploration with three Explore agents in parallel:
  producer pipeline + accum handling, consumer registry +
  aggregation, BC manual snow survey + ASWS data sources.
- Two scope decisions raised by user pushback during planning:
  (1) include `snow_cover` (snowc) as a 4th monthly native — the
  cleanest melt-timing visualization at regional scale; (2) ship
  both layers (monthly natives + annual derived), not annual only.
  Final scope: 8 new vars, single hourly fetch.
- Architecture pinned: hourly-only EDH source, 00:00 UTC reset trick
  for accum vars, ASWS-primary QA, producer-side aggregation for
  annuals.
- Created branch `48-snow-vars` off main (post v0.1.6 release).
- Scaffolded PWF baseline.
- Next: Phase 1 — write `scripts/backfill_edh_snow.py` with hourly
  accum handling and one-year smoke test.
