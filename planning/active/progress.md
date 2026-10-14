# Progress — cd_variables(): vpd unit is Pa but the data is hPa (#96)

## Session 2026-10-14

- Plan-mode exploration — phases approved by user; vignette-data decision: patch unit column in place (no S3 regen)
- Created branch `96-cd-variables-vpd-unit-is-pa-but-the-data` off main
- Scaffolded PWF baseline from issue #96 with approved phases
- Next: start Phase 1
- Phase 1: vpd unit test failed against "Pa" (FAIL 1), passes after the registry fix; full suite FAIL 0 | WARN 6 | PASS 647. The 6 warnings are pre-existing (`test-cd_plot_comparison.R` fixtures, "row names were found from a short variable"), untouched.
