# Progress

## Status: Complete

### cd_stac_catalog() — Issue #7
- [x] Implementation
- [x] Tests
- [x] Docs
- [x] `/code-check` — fixed geometry/datetime null serialization (NA for JSON null)
- [x] Committed

### cd_s3_push() — Issue #8
- [x] Implementation
- [x] Tests
- [x] Docs
- [x] `/code-check` — fixed command injection via shQuote on s3_target
- [x] Committed

### Final
- [x] `devtools::test()` all pass (142/142)
- [x] `lintr::lint_package()` clean (false positives only)
- [ ] End-to-end with real S3 (after merge)
- [ ] PR created
