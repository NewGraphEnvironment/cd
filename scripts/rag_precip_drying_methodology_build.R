#!/usr/bin/env Rscript
#
# rag_precip_drying_methodology_build.R
#
# Build a ragnar DuckDB store from Zotero PDFs for researching
# precipitation + drying departure methodology — the citation
# backbone for vignette interpretation paragraphs that currently
# make claims about falling precipitation, rising VPD/ET, and
# soil-moisture decline with zero peer-reviewed citations.
#
# Mines for:
#   - Anthropogenic precip-extremes attribution (Min 2011)
#   - Canadian / BC adjusted precip dataset methodology
#     (Mekis & Vincent 2011)
#   - VPD continental-scale drying (Ficklin & Novick 2017)
#   - VPD ecosystem responses (Grossiord 2020)
#   - Drought attribution + framework (Trenberth 2014, Williams 2020,
#     Marvel 2019)
#
# Filed against #61 (Issue 2 of the climate-departure 3-split lit reviews).
#
# Prerequisites:
#   - R packages: ragnar, DBI
#   - Ollama running with nomic-embed-text model:
#       ollama serve
#       ollama pull nomic-embed-text
#   - PDFs in data/rag/precip_drying_methodology_pdfs/ (gitignored,
#     populated by user RG downloads + curl + OCR)
#
# Usage:
#   Rscript scripts/rag_precip_drying_methodology_build.R
#
# Output:
#   data/rag/precip_drying_methodology.duckdb   (gitignored)

library(ragnar)

# --- Configuration ---
pdf_dir    <- here::here("data", "rag", "precip_drying_methodology_pdfs")
store_path <- here::here("data", "rag", "precip_drying_methodology.duckdb")

# Local labels match the file basenames; the actual BBT-auto-derived
# Zotero citation keys (which is what lands in vignette [@key] markers
# downstream) are documented in planning/active/findings.md Phase 2
# table.
pdf_specs <- list(
  list(label = "williams_etal2020",   attach = "SBSHUENU", note = "NA megadrought attribution (Science)"),
  list(label = "ficklin_novick2017",  attach = "XT4HG85Q", note = "VPD US continental-scale drying (JGR)"),
  list(label = "grossiord_etal2020",  attach = "SGEP5ZVA", note = "Plant responses to rising VPD (New Phytol)"),
  list(label = "trenberth_etal2014",  attach = "Z8PQRGCS", note = "Global warming + drought changes (Nat Clim Chg)"),
  list(label = "min_etal2011",        attach = "X9QN8MPI", note = "Anthropogenic precip extremes (Nature)"),
  list(label = "mekis_vincent2011",   attach = "89KJ9JEE", note = "Adjusted Canadian precip dataset (Atmos-Ocean)"),
  list(label = "marvel_etal2019",     attach = "9XCZKTWD", note = "20th-century hydroclimate human signal (Nature)")
)

# --- Find PDFs ---
pdf_paths <- character()
missing <- character()
for (spec in pdf_specs) {
  path <- file.path(pdf_dir, paste0(spec$label, ".pdf"))
  if (file.exists(path)) {
    pdf_paths <- c(pdf_paths, path)
  } else {
    missing <- c(missing, spec$label)
  }
}

if (length(missing) > 0) {
  message("MISSING PDFs in ", pdf_dir, ":")
  for (m in missing) message("  ", m)
}
message("Found ", length(pdf_paths), " / ", length(pdf_specs), " PDFs")

if (length(pdf_paths) == 0) {
  stop("No PDFs found in ", pdf_dir)
}

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
n_chunks  <- DBI::dbGetQuery(store@con, "SELECT COUNT(*) AS n FROM chunks")$n
n_origins <- DBI::dbGetQuery(store@con, "SELECT COUNT(DISTINCT origin) AS n FROM chunks")$n

DBI::dbDisconnect(store@con)

message("\nStore built: ", store_path)
message("Chunks: ", n_chunks)
message("Sources: ", n_origins)
