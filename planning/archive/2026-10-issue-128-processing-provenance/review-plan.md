# Plan review (#128) — Plan agent, 2026-10-11

Findings in brief, with disposition. Full text was returned as the agent's reply.

| id | finding | disposition |
|---|---|---|
| B1 | `catalog_repair_hint()` now points at `catalog_publish.R`, which takes its item set and span from the live catalog, so it refuses the cases the hint fires for (COGs a year ahead of the catalog, a catalog missing an item) | Hint reverted to its old recipe; script scoped to metadata republish when the catalog and COGs agree |
| G1 | No missed reader/writer of `cd:*` provenance; NEWS needs a #128 line | NEWS written by `/gh-pr-merge` |
| G2 | Writer shape matches #126's reader; `manifest_problems()` should also require a `processing:datetime` (`Z`/`+00:00`), the field #126 depends on | Added |
| G3 | Script lacks a conditional upload (`s3_put_if()`), a merged-code check (`publish_sha_problems()`), and an enforced checksum comparison; duplicates the pipelines' STEP 5 tail | First three added; pipeline STEP 5 refactor out of scope |
| G4 | STAC core validation fails every item (`geometry: null` + `bbox`), predating #128 | Validate against processing v1.2.0 + file v2.1.0 schemas only; noted |
| O1 | Between merge and manifest republish every CI run fails at STEP D | Republish right after merge; timing in PR body |
| O2 | `daily_publish --dry-run` overwrites `data/backfill/daily_manifest.json` | Compare against `data/backfill/pre_128/` copies of the live docs |
| A1 | A re-upload of identical bytes can change a multipart ETag and so trigger consumer re-downloads | `daily_publish(sync = FALSE)` / `--manifest-only`: no sync, ETags of every entry checked |
| A2 | `cd:::stac_provenance` needs the checkout or a cd >= this release | Comment added |
| A3 | `manifest_entries()` tag lookup ignores domain, `cd_stac_item()` filters `""` | Pre-existing; noted, not changed |
| AC1 | Check the republished docs differ from the old only by the rename | Full comparison script in verification, both documents |
