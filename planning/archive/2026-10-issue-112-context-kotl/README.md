## Outcome

`inst/extdata/context_kotl.gpkg` shipped in every install with no reader. Its only consumer, the KOTL vignette, was removed in #50, and `context_kootenay_lake.gpkg` (#57) holds the same five layer kinds plus wsgs and ecoregions over an area that contains KOTL. The file was deleted. Its producer `data-raw/example_context_kotl.R` was deleted too, rather than marked superseded, so nothing can recreate it; git history keeps the recipe. `example_aoi_kotl.gpkg` and its producer stay because the README quick-start reads them. Three code-check rounds came back Clean: code readers, including an org-wide `gh` code search; the build/publish file set; and the supersession claim and doc truth. One leftover: the two remaining `data-raw/example_context_*` headers now cite each other as "same recipe". Both reviewers who noticed judged it harmless.

## Measurement

R 4.5.2. `R CMD build --no-build-vignettes --no-manual` on `git archive` of `048f93a` vs the change, each installed with `R CMD INSTALL -l` into a scratch library:

- **Tarball:** 7,146,394 → 3,830,880 B (−46%), 101 → 100 files.
- **Installed `cd/`:** 12,776 → 7,948 KB (−38%).

The issue's "loses 4.9 MB" holds for installed size. The gpkg compresses, so the download shrinks by 3.3 MB. After-tarball `R CMD check --no-manual --ignore-vignettes`: Status OK, 0 NOTEs. `devtools::test()`: PASS 436, FAIL 0. The reproduce commands are in `findings.md`.

Closed by: commit 1d17163 / PR #115
