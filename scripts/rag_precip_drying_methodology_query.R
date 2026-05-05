#!/usr/bin/env Rscript
#
# rag_precip_drying_methodology_query.R
#
# Mine the precip_drying_methodology.duckdb store for methodology
# quotes indexed by topic. Outputs
# planning/active/precip_drying_methodology_quotes.md with the top-k
# chunks per query.
#
# Filed against #61 — feeds the precipitation + drying interpretation
# paragraphs in vignettes/peace-fwcp.Rmd and
# vignettes/kootenay-lake.Rmd (downstream consumer branch).
#
# Usage: Rscript scripts/rag_precip_drying_methodology_query.R
#
# Output: planning/active/precip_drying_methodology_quotes.md

library(ragnar)

store_path <- here::here("data", "rag", "precip_drying_methodology.duckdb")
out_path   <- here::here("planning", "active", "precip_drying_methodology_quotes.md")

stopifnot(file.exists(store_path))

store <- ragnar_store_connect(store_path)

# Queries grouped by topic. Each query gets top-5 chunks. Coverage
# matrix in findings.md maps each topic to its primary citation key(s).
queries <- list(
  precip_trend_methodology = c(
    "precipitation trend long-record homogenization adjustment Canada",
    "daily precipitation gauge undercatch wind bias correction",
    "annual precipitation trend Sen Mann-Kendall significance"
  ),
  extreme_precip_attribution = c(
    "anthropogenic contribution intensification extreme precipitation",
    "heavy precipitation greenhouse gas climate change attribution",
    "precipitation extremes optimal fingerprinting human signal"
  ),
  vpd_drying_continental = c(
    "vapor pressure deficit increase historical projected United States",
    "atmospheric drying continental scale temperature relative humidity",
    "VPD trends summer growing season warming"
  ),
  vpd_ecosystem_response = c(
    "plant stomatal closure rising vapor pressure deficit",
    "VPD effects ecosystem productivity drought stress mortality",
    "evaporative demand atmospheric water demand vegetation"
  ),
  drought_attribution_megadrought = c(
    "anthropogenic warming megadrought soil moisture North America",
    "southwestern United States drought severity attribution",
    "human-caused drying soil water balance climate model"
  ),
  drought_framework = c(
    "Palmer drought severity index PDSI evapotranspiration",
    "global warming drought definition methodology debate",
    "potential evapotranspiration temperature radiation Penman"
  ),
  hydroclimate_century_pattern = c(
    "twentieth century hydroclimate emerging signal forced",
    "tree-ring drought reconstruction last millennium attribution",
    "global drying pattern detection consistent human influence"
  ),
  bc_pnw_summer_flow = c(
    "British Columbia summer low flow salmon productivity",
    "Fraser River flow regime climate change projection",
    "Pacific Northwest stream flow drought thermal habitat"
  )
)

top_k <- 5
cat("Querying", length(unlist(queries)), "queries (top", top_k, "chunks each)...\n")

n_chunks  <- DBI::dbGetQuery(store@con, "SELECT COUNT(*) AS n FROM chunks")$n
n_origins <- DBI::dbGetQuery(store@con, "SELECT COUNT(DISTINCT origin) AS n FROM chunks")$n

md <- c(
  "# Precipitation + drying methodology — RAG retrieval results",
  "",
  paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  paste0("Store: ", store_path, " (", n_chunks, " chunks, ", n_origins, " sources)"),
  "",
  "Each section contains top-5 chunks (cosine similarity) for the",
  "queries below. Use these to extract exact-page quotes for the",
  "vignette precip + drying interp paragraphs (downstream consumer",
  "branch).",
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
