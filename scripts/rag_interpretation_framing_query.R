#!/usr/bin/env Rscript
#
# rag_interpretation_framing_query.R
#
# Mine the interpretation_framing.duckdb store for methodology quotes
# indexed by topic. Outputs
# planning/active/interpretation_framing_quotes.md.
#
# Filed against #63 — feeds the vignette framing interp paragraphs
# (downstream consumer branch).
#
# Usage: Rscript scripts/rag_interpretation_framing_query.R
#
# Output: planning/active/interpretation_framing_quotes.md

library(ragnar)

store_path <- here::here("data", "rag", "interpretation_framing.duckdb")
out_path   <- here::here("planning", "active", "interpretation_framing_quotes.md")

stopifnot(file.exists(store_path))

store <- ragnar_store_connect(store_path)

queries <- list(
  baseline_window_methodology = c(
    "WMO climate normal definition baseline period 30 years",
    "alternative climate normals 1961 1990 reference period selection",
    "five attributes climate normal averaging window length"
  ),
  normals_when_trends_exist = c(
    "estimating climate normals nontrivial trends changing climate",
    "extrapolation hinge fit climate normal warming trend",
    "current climate mean trend-adjusted normal vs 30-year average"
  ),
  time_of_emergence = c(
    "time of emergence signal-to-noise climate change regional",
    "emergence climate signal natural variability noise",
    "ToE surface air temperature CMIP regional emergence"
  ),
  cumulative_impact_loaded_dice = c(
    "loaded dice perception climate change extreme summer heat",
    "three sigma extreme outlier base period 1951 1980",
    "cumulative warming public perception detection"
  ),
  shifting_baseline_climate = c(
    "shifting baseline syndrome climate normal generational forgetting",
    "reference state historical climate human perception shift"
  ),
  departure_recent_variability = c(
    "departure from recent variability climate index emergence",
    "novel climate continuous beyond historical analog"
  )
)

top_k <- 5
cat("Querying", length(unlist(queries)), "queries (top", top_k, "chunks each)...\n")

n_chunks  <- DBI::dbGetQuery(store@con, "SELECT COUNT(*) AS n FROM chunks")$n
n_origins <- DBI::dbGetQuery(store@con, "SELECT COUNT(DISTINCT origin) AS n FROM chunks")$n

md <- c(
  "# Interpretation framing methodology — RAG retrieval results",
  "",
  paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  paste0("Store: ", store_path, " (", n_chunks, " chunks, ", n_origins, " sources)"),
  "",
  "Each section contains top-5 chunks (cosine similarity) for the",
  "queries below. Use these to extract exact-page quotes for the",
  "vignette framing interp paragraphs (downstream consumer branch).",
  ""
)

format_chunk <- function(row) {
  origin <- gsub(".*/(.+)\\.pdf$", "\\1", row$origin)
  text <- gsub("\\s+", " ", row$text)
  if (nchar(text) > 1200) text <- paste0(substr(text, 1, 1200), "...")
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
