#!/usr/bin/env Rscript
#
# rag_interpretation_framing_build.R
#
# Build a ragnar DuckDB store from Zotero PDFs for researching
# climate-departure interpretation framing methodology — the citation
# backbone for vignette interpretation paragraphs that make framing
# choices (baseline window, time-of-emergence, cumulative-impact vs
# rate, departure-from-recent-variability).
#
# Mines for:
#   - WMO climate normal definition + alternatives (Arguez & Vose 2011)
#   - Estimating normals when trends exist (Livezey 2007)
#   - Time of emergence / signal-to-noise (Hawkins & Sutton 2012)
#   - Cumulative-impact / "loaded dice" framing (Hansen 2012)
#
# Filed against #63 (Issue 3 of the climate-departure 3-split lit reviews).
#
# Prerequisites:
#   - R packages: ragnar, DBI
#   - Ollama running with nomic-embed-text model
#   - PDFs in data/rag/interpretation_framing_pdfs/ (gitignored)
#
# Usage:
#   Rscript scripts/rag_interpretation_framing_build.R
#
# Output:
#   data/rag/interpretation_framing.duckdb   (gitignored)

library(ragnar)

pdf_dir    <- here::here("data", "rag", "interpretation_framing_pdfs")
store_path <- here::here("data", "rag", "interpretation_framing.duckdb")

pdf_specs <- list(
  list(label = "arguez_vose2011",     attach = "PTQ9PAHZ", note = "WMO climate normal + alternatives (BAMS)"),
  list(label = "livezey_etal2007",    attach = "P6KFMRF9", note = "Climate normals + trends (JAMC)"),
  list(label = "hawkins_sutton2012",  attach = "NG4EZK8V", note = "Time of emergence of climate signals (GRL)"),
  list(label = "hansen_etal2012",     attach = "S7JUXCGB", note = "Perception of climate change / loaded dice (PNAS)")
)

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

n_chunks  <- DBI::dbGetQuery(store@con, "SELECT COUNT(*) AS n FROM chunks")$n
n_origins <- DBI::dbGetQuery(store@con, "SELECT COUNT(DISTINCT origin) AS n FROM chunks")$n

DBI::dbDisconnect(store@con)

message("\nStore built: ", store_path)
message("Chunks: ", n_chunks)
message("Sources: ", n_origins)
