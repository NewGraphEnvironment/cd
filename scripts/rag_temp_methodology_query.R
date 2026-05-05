#!/usr/bin/env Rscript
#
# rag_temp_methodology_query.R
#
# Mine the temp_methodology.duckdb store for methodology quotes
# indexed by topic. Outputs planning/active/temp_methodology_quotes.md
# with the top-k chunks per query.
#
# Filed against #58 — feeds the temperature interpretation paragraphs
# in vignettes/peace-fwcp.Rmd and vignettes/kootenay-lake.Rmd
# (downstream branch consumes the cite-this-for-that map from the
# Phase 5 findings.md).
#
# Usage: Rscript scripts/rag_temp_methodology_query.R
#
# Output: planning/active/temp_methodology_quotes.md

library(ragnar)

store_path <- here::here("data", "rag", "temp_methodology.duckdb")
out_path   <- here::here("planning", "active", "temp_methodology_quotes.md")

stopifnot(file.exists(store_path))

# Connect to the existing store
store <- ragnar_store_connect(store_path)

# Queries grouped by topic. Each query gets top-5 chunks. Coverage
# matrix in findings.md maps each topic to its primary citation key(s).
queries <- list(
  dtr_asymmetry = c(
    "diurnal temperature range minimum maximum asymmetric trends methodology",
    "minimum temperature warming faster than maximum nighttime daytime",
    "DTR decrease causes cloud cover soil moisture aerosols"
  ),
  tmax_tmin_globe = c(
    "global maximum minimum temperature trends globe land area",
    "Tmax versus Tmin per decade rate hemispheric asymmetry",
    "narrowing of diurnal temperature range globally"
  ),
  canadian_bc_trends = c(
    "Canada temperature trends 1948 to 2016 indices warming",
    "British Columbia annual temperature change observed warming",
    "homogenized Canadian climate data adjustment methodology"
  ),
  bc_downscaling = c(
    "ClimateWNA western North America historical temperature downscaling",
    "PRISM gridded climate normals temperature lapse rate elevation",
    "high resolution spatial climate baseline anomaly"
  ),
  elevation_dependent_warming = c(
    "elevation dependent warming mountain regions amplification",
    "high altitude greater warming snow albedo feedback",
    "lapse rate change warming mountain valley contrast"
  ),
  climate_stream_temp_bridge = c(
    "air temperature stream temperature relationship summer maximum",
    "salmon habitat thermal stress climate change Pacific Northwest",
    "summertime stream temperature warming impact freshwater fish"
  ),
  salmonid_thermal_envelope = c(
    "chinook coho steelhead maximum temperature limits thermal tolerance",
    "salmonid critical lethal temperature threshold thermal stress",
    "cold water refugia thermal habitat fish temperature criteria"
  ),
  trend_methodology_cd = c(
    "Mann-Kendall Theil-Sen slope linear trend significance",
    "least squares regression decadal warming rate confidence interval",
    "anomaly relative to baseline reference period climate normal"
  )
)

# --- Run all queries, capture top-5 each ---
top_k <- 5

cat("Querying", length(unlist(queries)), "queries (top", top_k, "chunks each)...\n")

# Connection metadata
n_chunks  <- DBI::dbGetQuery(store@con, "SELECT COUNT(*) AS n FROM chunks")$n
n_origins <- DBI::dbGetQuery(store@con, "SELECT COUNT(DISTINCT origin) AS n FROM chunks")$n

# Build the markdown output
md <- c(
  "# Temperature methodology — RAG retrieval results",
  "",
  paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  paste0("Store: ", store_path, " (", n_chunks, " chunks, ", n_origins, " sources)"),
  "",
  "Each section contains top-5 chunks (cosine similarity) for the",
  "queries below. Use these to extract exact-page quotes for the",
  "vignette temperature interp paragraphs (downstream consumer branch).",
  ""
)

format_chunk <- function(row) {
  origin <- gsub(".*/(.+)\\.pdf$", "\\1", row$origin)
  text <- gsub("\\s+", " ", row$text)
  if (nchar(text) > 1200) text <- paste0(substr(text, 1, 1200), "...")
  # cosine_distance is a list-col with one numeric per row
  cd <- row$cosine_distance
  if (is.list(cd)) cd <- cd[[1]]
  cd_str <- if (length(cd) >= 1 && is.numeric(cd)) sprintf("%.3f", cd[1]) else "?"
  c(
    paste0("**`", origin, "`** (cos_dist=", cd_str, ")"),
    "",
    paste0("> ", text),
    ""
  )
}

for (topic in names(queries)) {
  md <- c(md, paste0("## ", topic), "")
  for (q in queries[[topic]]) {
    md <- c(md, paste0("### Query: \"", q, "\""), "")
    res <- tryCatch(
      ragnar_retrieve(store, q, top_k = top_k),
      error = function(e) {
        cat("  ERROR for query '", q, "': ", conditionMessage(e), "\n", sep = "")
        NULL
      }
    )
    if (is.null(res) || nrow(res) == 0) {
      md <- c(md, "_no chunks returned_", "")
      next
    }
    for (i in seq_len(nrow(res))) {
      md <- c(md, format_chunk(res[i, ]))
    }
  }
}

DBI::dbDisconnect(store@con)
writeLines(md, out_path)
cat("\nWrote: ", out_path, "\n")
cat("Total queries: ", length(unlist(queries)), "\n")
