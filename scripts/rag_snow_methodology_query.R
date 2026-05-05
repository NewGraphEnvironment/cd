#!/usr/bin/env Rscript
#
# rag_snow_methodology_query.R
#
# Mine the snow_methodology.duckdb store for methodology quotes
# indexed by #48 metric. Outputs findings/snow_methodology_quotes.md
# with the top-k chunks per query.
#
# Filed against #53 — feeds #48 Phase 5 vignette interp.
#
# Usage: Rscript scripts/rag_snow_methodology_query.R
#
# Output: planning/active/snow_methodology_quotes.md

library(ragnar)

store_path <- here::here("data", "rag", "snow_methodology.duckdb")
out_path   <- here::here("planning", "active", "snow_methodology_quotes.md")

stopifnot(file.exists(store_path))

# Connect to the existing store
store <- ragnar_store_connect(store_path)

# Queries grouped by #48 metric / topic. Each query gets top-5 chunks.
queries <- list(
  swe_max = c(
    "annual maximum snow water equivalent peak SWE methodology",
    "April 1 SWE as climate indicator",
    "snowpack decline percent change baseline"
  ),
  snowfall_fraction = c(
    "snowfall water equivalent fraction of total precipitation SFE/P",
    "rain versus snow ratio western United States trend",
    "phase of precipitation methodology"
  ),
  snowmelt_doy_50 = c(
    "centroid timing center mass streamflow date-of-year",
    "DOY 50 percent cumulative discharge melt onset",
    "spring freshet shift earlier days"
  ),
  snowmelt_rate_peak = c(
    "peak weekly snowmelt rate flashiness",
    "freshet pulse intensity rate of melt",
    "rolling sum snowmelt aggregation methodology"
  ),
  baseline_window = c(
    "baseline period 1951-1980 vs 1961-1990 climate normal",
    "reference period selection trend analysis"
  ),
  mk_autocorrelation = c(
    "Mann-Kendall test serial correlation prewhitening",
    "trend-free pre-whitening TFPW autocorrelation snow",
    "Theil-Sen slope hydrological trend"
  ),
  era5_land_bias = c(
    "ERA5-Land snow water equivalent bias overestimate mountain terrain",
    "reanalysis snow validation snow course station",
    "snow density product accuracy elevation"
  ),
  bc_specific = c(
    "British Columbia spring snowpack attribution anthropogenic",
    "Fraser River basin freshet timing salmon",
    "Pacific Northwest mountain snowpack methodology"
  )
)

# --- Run all queries, capture top-5 each ---
top_k <- 5

cat("Querying", length(unlist(queries)), "queries (top", top_k, "chunks each)...\n")

# Build the markdown output
md <- c(
  "# Snow methodology — RAG retrieval results",
  "",
  paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  paste0("Store: ", store_path, " (1006 chunks, 11 sources)"),
  "",
  "Each section contains top-5 chunks (cosine similarity) for the",
  "queries below. Use these to extract exact-page quotes for the",
  "vignette interp paragraph in #48 Phase 5.",
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

writeLines(md, out_path)
cat("\nWrote: ", out_path, "\n")
cat("Total queries: ", length(unlist(queries)), "\n")
