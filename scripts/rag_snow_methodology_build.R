#!/usr/bin/env Rscript
#
# rag_build_snow_methodology.R
#
# Build a ragnar DuckDB store from Zotero PDFs for researching
# snowpack-departure methodology — the citation backbone for #48
# Phase 5 vignette interpretation.
#
# Mines for:
#   - peak SWE / annual snowpack methodology (Mote 2005, 2018; Pederson 2011)
#   - DOY-50 / freshet-timing methodology (Stewart 2005, Cayan 2001, Kang 2016)
#   - snowfall-fraction methodology (Knowles 2006)
#   - BC-specific attribution + impacts (Najafi 2017, Kang 2016)
#   - Mann-Kendall + autocorrelation (Yue & Wang 2002)
#   - ERA5-Land snow biases (Kouki 2023, Muñoz-Sabater 2021)
#
# Filed against #53.
#
# Prerequisites:
#   - R packages: ragnar, DBI
#   - Ollama running with nomic-embed-text model:
#       ollama serve
#       ollama pull nomic-embed-text
#   - PDFs in data/rag/snow_methodology_pdfs/ (gitignored, populated
#     from Zotero Web API by a one-shot bash loop — see #53 archive
#     for the bash recipe). Web-API download avoids the dependency on
#     Zotero desktop "download files at sync time" being enabled.
#
# Usage:
#   Rscript scripts/rag_build_snow_methodology.R
#
# Output:
#   data/rag/snow_methodology.duckdb   (gitignored)

library(ragnar)

# --- Configuration ---
pdf_dir    <- here::here("data", "rag", "snow_methodology_pdfs")
store_path <- here::here("data", "rag", "snow_methodology.duckdb")

# Citation labels follow the BBT firstauthor[_etal]year convention used in
# rag_build_departure_framing.R. The Zotero attachKey is documented for
# downstream auditing; the script reads PDFs by `<label>.pdf` filename out
# of pdf_dir.
pdf_specs <- list(
  list(label = "mote_etal2005",          attach = "G9IRM42Z", note = "PNW snowpack decline (BAMS)"),
  list(label = "stewart_etal2005",       attach = "J8GAR7T7", note = "Streamflow timing / DOY-50 (J Climate)"),
  list(label = "knowles_etal2006",       attach = "I8DV96F4", note = "Snowfall vs rainfall fraction (J Climate)"),
  list(label = "mote_etal2018",          attach = "DEV98ZWA", note = "Dramatic declines (npj)"),
  list(label = "najafi_etal2017",        attach = "G6HTX538", note = "BC SWE attribution (J Climate)"),
  list(label = "cayan_etal2001",         attach = "9R74HB5D", note = "Onset of spring (BAMS)"),
  list(label = "yue_wang2002",           attach = "VSW8UA44", note = "Pre-whitening for MK (WRR)"),
  list(label = "pederson_etal2011",      attach = "6N5KTSRK", note = "Long-record cordillera context (Science)"),
  list(label = "kang_etal2016",          attach = "I6HJU2U9", note = "Fraser River freshet + salmon (Sci Rep)"),
  list(label = "kouki_etal2023",         attach = "XXK3PP36", note = "ERA5-Land snow validation (TC)"),
  list(label = "munoz_sabater_etal2021", attach = "SUS5A57A", note = "ERA5-Land dataset paper (ESSD)")
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
  message("Run the Zotero Web-API download loop (see archive) to populate.")
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
