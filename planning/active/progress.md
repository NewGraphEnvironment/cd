# Progress — Wire cd_cache into the COG read path (#76)

## Session 2026-06-23

- Plan-mode exploration of read path, orphaned cache module, STAC
  invalidation signal, HTTP deps, CI safety — phases approved by user
- User chose HEAD-always revalidation + `cd.cache_revalidate` opt-out
- Created branch `76-wire-cd-cache-read-path` off main
- Scaffolded PWF baseline from issue #76 with approved phases
- Next: start Phase 1 — `cd_cache_fetch()` core + curl dep + tests
