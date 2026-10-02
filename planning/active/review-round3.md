# Review round 3 — #112 supersession claim and documentation truth

## Clean
No issues found.

Checked (outside planning/archive/ and docs/):

- (a) Supersession: `context_kootenay_lake.gpkg` writes towns, lakes, rivers, streams,
  highways (the deleted file's five layers) plus wsgs and ecoregions, over an AOI
  (KOTL+LARL+DUNC+SLOC) that contains KOTL. Nothing — README, CLAUDE.md, vignettes,
  data-raw headers, .github, tests, R/, man/, _pkgdown.yml — promises a KOTL context
  layer. No `research/` directory exists.
  NEWS.md:169 ("KOTL polygon assets stay in inst/extdata/ because the README quick-start
  still uses them") is a v0.1.4 release-history entry; its premise still holds for the
  asset the README uses (README.md:23 reads `example_aoi_kotl.gpkg`, which is kept). Not
  made false in any way a reader would act on; history is immutable per repo convention.
- (b) No live doc or comment names `context_kotl.gpkg` or `example_context_kotl.R`
  (only NEWS.md:149 lists `context_kootenay_lake.gpkg`, which exists).
- (c) `example_context_fwcp_peace.R:3` and `example_context_kootenay_lake.R:3` now cite
  each other as "same recipe". Both scripts are self-contained and the comparisons
  ("much larger" Peace, ~73,000 vs ~24,200 km^2) are true; the mutual reference conveys
  a sibling relationship and would not lead a reader into wrong action.
