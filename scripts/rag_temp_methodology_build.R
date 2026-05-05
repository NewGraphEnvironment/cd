#!/usr/bin/env Rscript
#
# rag_temp_methodology_build.R
#
# Build a ragnar DuckDB store from Zotero PDFs for researching
# temperature-departure methodology — the citation backbone for the
# vignette interpretation paragraphs that currently make claims
# about warming trends, day-night asymmetry, and salmonid thermal
# stress with zero peer-reviewed citations.
#
# Mines for:
#   - DTR / day-night asymmetry methodology (Karl 1993, Easterling 1997, Vose 2005)
#   - Tmax vs tmin trends globally (Easterling 1997, Vose 2005)
#   - Canadian / BC temperature trends (Vincent 2018)
#   - BC-specific climate downscaling (Wang 2012 ClimateWNA)
#   - Elevation-dependent warming (Pepin 2015, Rangwala & Miller 2012)
#   - Climate -> stream-temperature bridge (Mantua 2010)
#   - Salmonid thermal envelope (Eaton & Scheller 1996, Richter & Kolmes 2005)
#
# Filed against #58 (Issue 1 of the climate-departure 3-split lit reviews).
#
# Prerequisites:
#   - R packages: ragnar, DBI
#   - Ollama running with nomic-embed-text model:
#       ollama serve
#       ollama pull nomic-embed-text
#   - PDFs in data/rag/temp_methodology_pdfs/ (gitignored, populated
#     by user RG downloads + curl + OCR — see planning archive for the
#     per-paper recipe). Web-API download avoids the dependency on
#     Zotero desktop "download files at sync time" being enabled.
#
# Usage:
#   Rscript scripts/rag_temp_methodology_build.R
#
# Output:
#   data/rag/temp_methodology.duckdb   (gitignored)

library(ragnar)

# --- Configuration ---
pdf_dir    <- here::here("data", "rag", "temp_methodology_pdfs")
store_path <- here::here("data", "rag", "temp_methodology.duckdb")

# Local labels follow the firstauthor[_etal]year convention. The actual
# Zotero BBT citation keys (auto-derived per NGE convention) get captured
# in planning/active/findings.md once Zotero desktop is restarted to
# trigger BBT key generation for the Web-API-created items. The Zotero
# attachKey is documented for downstream auditing; the script reads PDFs
# by `<label>.pdf` filename out of pdf_dir.
pdf_specs <- list(
  list(label = "karl_etal1993",        attach = "X2UMWNUB", note = "Asymmetric trends DTR (BAMS)"),
  list(label = "easterling_etal1997",  attach = "MI3CH39H", note = "Tmax vs tmin globe (Science)"),
  list(label = "vose_etal2005",        attach = "SIAFNGKV", note = "DTR update through 2004 (GRL)"),
  list(label = "vincent_etal2018",     attach = "P7QHP3BJ", note = "Canada climate trends (Atmos-Ocean)"),
  list(label = "pepin_etal2015",       attach = "UJVF9IFP", note = "Elevation-dependent warming (Nat Clim Chg)"),
  list(label = "rangwala_miller2012",  attach = "GR9S4I3F", note = "Mountain climate review (Clim Change)"),
  list(label = "wang_etal2012",        attach = "5V7E4CWX", note = "ClimateWNA BC downscaling (JAMC)"),
  list(label = "mantua_etal2010",      attach = "E5DWJAGA", note = "Climate-fish bridge PNW (Clim Change)"),
  list(label = "eaton_scheller1996",   attach = "72R34DQB", note = "Fish thermal habitat (L&O)"),
  list(label = "richter_kolmes2005",   attach = "RTU4TMRG", note = "Salmonid thermal limits PNW (Rev Fish Sci)")
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
  message("Run the user-provided RG-download recipe (see archive) to populate.")
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
