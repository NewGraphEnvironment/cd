# Progress — Vignette: a plain-language climate story for three northern BC watershed groups (#137)

## Session 2026-10-14

- Plan-mode exploration — phases approved by user; instruction: run all phases to the PR
- Created branch `137-vignette-a-plain-language-climate-story-for` off main
- Scaffolded PWF baseline from issue #137 with approved phases
- Next: start Phase 1
- Phase 1: `cd_compare()` roxygen now calls 1951–1980 the pre-warming reference (GISS base period) and states it is not a WMO standard normal (fixed periods 1901–30, 1931–60, 1961–90). Dropped "earliest 30 years of ERA5-Land": ERA5-Land starts in 1950, so that is 1950–1979. Tests 679 pass, 6 warnings, same as main.
