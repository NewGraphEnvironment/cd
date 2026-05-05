#!/usr/bin/env Rscript
#
# rag_departure_framing_build.R
#
# Build a ragnar DuckDB store from Zotero PDFs for researching how climate
# departure studies frame baseline comparisons and communicate cumulative change.
#
# Informs cd_compare() defaults and vignette design (issue #20).
#
# Prerequisites:
#   - R packages: ragnar, DBI
#   - Ollama running with nomic-embed-text model pulled:
#       ollama serve
#       ollama pull nomic-embed-text
#   - Zotero with PDFs attached to references
#
# Usage:
#   Rscript scripts/rag_departure_framing_build.R
#
# Output:
#   data/rag/departure_framing.duckdb   (gitignored)

library(ragnar)

# --- Configuration ---
zotero_dir <- path.expand("~/Zotero/storage")
store_path <- here::here("data", "rag", "departure_framing.duckdb")

# Zotero attachment keys for PDFs.
# citationKey -> attachKey (Zotero storage folder name)
pdf_keys <- c(
  mora_etal2013        = "36G25ZK9",   # Climate departure timing
  munoz_sabater2021    = "SUS5A57A",   # ERA5-Land dataset
  hersbach_etal2020    = "IE8SUWCS",   # ERA5 global reanalysis
  pauly1995            = "2WKT2HSW",   # Shifting baseline syndrome (seminal)
  alleway_etal2023     = "NCX8FEXP",   # Shifting baseline as connective concept
  rodrigues_etal2019   = "J8YB9UV7"    # Unshifting the baseline framework
)

# --- Find PDFs ---
pdf_paths <- character()
for (key in pdf_keys) {
  dir_path <- file.path(zotero_dir, key)
  if (dir.exists(dir_path)) {
    pdfs <- list.files(dir_path, pattern = "[.]pdf$", full.names = TRUE)
    if (length(pdfs) > 0) pdf_paths <- c(pdf_paths, pdfs[1])
  } else {
    message("  MISSING: ", names(pdf_keys)[pdf_keys == key], " (", key, ")")
  }
}

message("Found ", length(pdf_paths), " / ", length(pdf_keys), " PDFs")

# --- Build store ---
fs::dir_create(dirname(store_path))

if (file.exists(store_path)) {
  file.remove(store_path)
  wal <- paste0(store_path, ".wal")
  if (file.exists(wal)) file.remove(wal)
}

store <- ragnar_store_create(
  location = store_path,
  embed = embed_ollama(model = "nomic-embed-text"),
  overwrite = TRUE
)

message("Ingesting ", length(pdf_paths), " PDFs into ", store_path)
ragnar_store_ingest(store, pdf_paths, progress = TRUE)

# --- Verify ---
n_chunks <- DBI::dbGetQuery(store@con, "SELECT COUNT(*) AS n FROM chunks")$n
n_origins <- DBI::dbGetQuery(store@con, "SELECT COUNT(DISTINCT origin) AS n FROM chunks")$n

DBI::dbDisconnect(store@con)

message("\nStore built: ", store_path)
message("Chunks: ", n_chunks)
message("Sources: ", n_origins)
