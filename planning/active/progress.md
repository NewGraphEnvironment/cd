# Progress — Surface checksums and run provenance in cd_catalog() and the extract functions (#126)

## Session 2026-10-10

- Plan-mode exploration — phases approved by user (crate#23 question resolved at the gate:
  provenance to `processing:*` in a separate prerequisite issue; extract outputs get columns)
- Created branch `126-surface-checksums-and-run-provenance-in` off main
- Scaffolded PWF baseline from issue #126 with approved phases
- Next: Phase 0 (file the prerequisite issue), then Phase 1
- Phase 0: filed #128 (provenance keys to `processing:*`, blocks #126); #126 body edited
  with the decided shape and the dependency
- Phase 1: `cd_catalog()` gains checksum/size/cd_version/cd_sha/run_time/run_url (NA when absent); exact `[["cd"]]` lookup, guarded by a test proven red against `$cd`
- Plan review returned (planning/active/review-plan.md): B1 accepted (verify the build read), B2/G5/A1 folded into #128's body
- Phase 2: `cd_extract()` gains `checksum`/`cd_sha`, verified against the file's own tags; typed empty return
- Phase 3: `cd_extract_daily()` gains `checksum`/`cd_sha` per file, manifest read once (`daily_manifest()` / mockable `daily_manifest_fetch()`); guard proven (manifest checksum unverified → 2 tests red). Live canary skips until #128's republish
- code-check round 1 (planning/active/review-round1.md): 2 fragile (malformed manifest stops the read; `%||%` needs R 4.4), both fixed. Plus the live 60 N test failure: warn only on a stale copy, NA silently when the entry has no run time
