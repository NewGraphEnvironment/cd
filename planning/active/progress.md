# Progress — cd_anomaly() and cd_summary(): accept series outside cd_variables() (#92)

## Session 2026-09-28

- Plan-mode exploration — phases approved by user; two forks settled at the gate (unit = anomaly unit; cd_trend pass-through)
- Created branch `92-cd-anomaly-series-outside-cd-variables` off main
- Scaffolded PWF baseline from issue #92 with approved phases
- Next: start Phase 1
- Phase 1: tests for input-carried `anomaly_type`/`unit`/`long_name`, unresolved-type error, invalid type, row-wise fallback, factor columns, zero rows, cd_trend pass-through, cd_summary fallback, and an end-to-end non-ERA5 chain with `period = "spawn"`. All new expectations fail on main (red confirmed before implementation).
