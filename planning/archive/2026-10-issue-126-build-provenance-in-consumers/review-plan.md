# Plan review (Plan agent, 2026-10-10) — summary and dispositions

| # | Finding | Disposition |
|---|---|---|
| B1 | Stale cache (`cd.cache_revalidate = FALSE`, failed HEAD; `R/cd_cache_fetch.R:55,62`) or an old `cd_catalog()` tibble makes a copied checksum name a build other than the one read | **Accepted.** `cd_sha` is taken from the read file's own `CD_SHA` tag; the catalog/manifest checksum is reported only when the file's `CD_RUN_TIME` tag equals the entry's `processing:datetime`, else `NA` + one warning naming the files |
| B2 | A partial daily republish leaves `cd:*` keys on entries it did not rewrite; `manifest_problems()` checks only checksum/size | **Accepted, belongs to #128** — added to #128's body |
| G1 | `expect_named()` in test-cd_catalog.R:6 and test-cd_extract.R:13 | Already updated on purpose (Phase 1/2) |
| G2 | `jsonlite::read_json(url)` not mockable | Accepted: internal `daily_manifest_fetch()` wrapper, mocked in tests |
| G3 | Manifest entries live under `$files` | Accepted: fixtures use `list(files = ...)` |
| G4 | `cd_extract()` on zero matching rows returns 0x0 | Accepted: typed empty return + test |
| G5 | `run_id` `local` is not a URL | Accepted, #128 body: link only for a numeric GitHub run id |
| A1 | `provenance_problems()` checks GDAL tags, not JSON keys | Accepted: removed from #128's list |
| A2 | vignette-data rds lack the new columns | Noted in NEWS; not re-run (needs S3, local-only data-raw) |
| S1 | NEWS cache note belongs to the #124 republish | Accepted: worded as a reminder |
| Acc | old `cd:sha` key gives `NA`; `size` double | Accepted: tests added |
