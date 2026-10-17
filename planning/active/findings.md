# Findings — README: add daily point temperatures and any-series consumers; drop internal function (#142)

## Issue context

## Problem

The architecture and data sections are accurate (v0.6.7), but recent consumer capabilities are missing, and one function listed as part of the API is internal.

## Findings

**Shipped but not in the README (underselling)**
- Daily point temperatures, `cd_extract_daily()` (v0.6.0), for stream-temperature and degree-day work
- Consumer functions accept any annual series, such as streamflow and stream temperature (v0.5.0)
- Per-file checksums and run provenance (v0.6.3 to v0.6.5)

**Stale**
- README.md:105 lists `cd_stac_item()` as a producer function; it is internal and not exported
- The quick start uses a toy `1951:1955` baseline (README.md:31); the vignettes use `1951:1980`
- The VPD unit fix (Pa to hPa, v0.6.7) is not mentioned

## Tasks

- [ ] Add the shipped capabilities above
- [ ] Remove `cd_stac_item()` from the function list
- [ ] Use a realistic baseline in the quick start
- [ ] Group the `_pkgdown.yml` reference index by purpose. It has no `reference:` sections today, so the docs site shows a flat alphabetical list.

## Context

Audited 2026-10-14 against `origin/main` @ `5611c59`, from README, DESCRIPTION, NEWS, NAMESPACE and vignettes. Verify each item against the code before acting. Versions cited are where a capability landed.

The New Graph website will describe this package from its README (NewGraphEnvironment/newgraphenvironment.github.io#53), so the README is the source of truth for the public one-liner. Plain language in the opening paragraph: what it does today, and what restoration planning, implementation or monitoring decision it informs.

## Plan-gate notes (2026-10-17)

- README on main: 962 words (`wc -w`), sections Overview, Installation, Quick start, Caching, Data, Architecture, Roadmap, Links, Acknowledgements.
- `cd_stac_item()` is not in NAMESPACE (confirmed); it appears only in the Architecture table, which the rewrite removes.
- `_pkgdown.yml` has `url` and `template` only, no `reference:`.
- DESCRIPTION `Description` says producer functions "download ERA5-Land monthly means": true of the legacy `cd_fetch()` (CDS), not of the EDH pipeline CI runs.
- `update-citation-cff.yaml` calls `cffr::cff_create()` with default roles, so New Graph Environment Ltd. (`cph`, `fnd`) is not a citation author.
- `example_aoi_kotl.gpkg` is the KOTL watershed group, ~9,339 km².
