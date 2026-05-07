#!/usr/bin/env Rscript
#
# data-raw/regenerate_bib.R
#
# Regenerate vignettes/references.bib from the union of [@key] markers
# used in the regional vignettes (kootenay-lake.Rmd, peace-fwcp.Rmd).
# Pulls source records from Zotero via Better BibTeX (rbbt → BBT).
#
# Run after adding/removing [@key] markers in either vignette:
#   Rscript data-raw/regenerate_bib.R
#
# Prerequisites:
#   - Zotero desktop running with BBT plugin enabled
#       BBT 9.x for Zotero 8/9; BBT 8.x for Zotero 7
#       (if BBT shows "disabled by Zotero" in the plugin manager,
#       reinstall the matching version per soul#43)
#   - All [@key] markers in either vignette must resolve to items
#     in the NewGraphEnvironment Zotero library
#
# CI does not run this script — vignettes/references.bib is committed
# and pkgdown reads the static file. Re-run + commit whenever cites
# change. Keys not used in the vignettes are dropped automatically.

vignettes <- c(
  here::here("vignettes", "kootenay-lake.Rmd"),
  here::here("vignettes", "peace-fwcp.Rmd")
)
out_path <- here::here("vignettes", "references.bib")

# --- Detect citation keys per vignette ---
keys_per_rmd <- lapply(vignettes, function(rmd) {
  rbbt::bbt_detect_citations(paste(readLines(rmd), collapse = "\n"))
})
names(keys_per_rmd) <- basename(vignettes)

for (rmd in names(keys_per_rmd)) {
  message("  ", rmd, ": ", length(keys_per_rmd[[rmd]]), " keys")
}

# Note any keys that appear in only one vignette (informational —
# the union still gets written, no manual reconciliation needed)
all_keys <- sort(unique(unlist(keys_per_rmd)))
for (rmd in names(keys_per_rmd)) {
  rmd_only <- setdiff(keys_per_rmd[[rmd]], unlist(keys_per_rmd[setdiff(names(keys_per_rmd), rmd)]))
  if (length(rmd_only) > 0) {
    message("  Note: ", length(rmd_only), " key(s) appear only in ",
            rmd, ": ", paste(rmd_only, collapse = ", "))
  }
}

message("\nUnion: ", length(all_keys), " unique keys across ",
        length(vignettes), " vignettes")

# --- Fetch bib entries for the full union via BBT ---
bib_text <- rbbt::bbt_bib(all_keys, .action = rbbt::bbt_return)

writeLines(bib_text, out_path)

n_entries <- length(grep("^@", readLines(out_path)))
message("Wrote ", n_entries, " entries to ", out_path)

if (n_entries != length(all_keys)) {
  warning("Entry count (", n_entries, ") differs from detected key ",
          "count (", length(all_keys), "). Check that BBT is reachable ",
          "and all keys exist in Zotero.")
}
