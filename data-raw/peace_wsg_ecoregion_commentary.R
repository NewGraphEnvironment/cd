# Compute per-WSG x ecoregion overlap for the FWCP Peace Region and
# generate plain-language commentary. Ships as
# inst/extdata/peace_wsg_ecoregion_commentary.csv for the peace-fwcp
# vignette.
#
# Convention: percentages are computed against the part of each WSG
# inside the FWCP AOI (the union of all 5 ecoregions, which tile the
# AOI by construction), not against the full WSG extent. Some WSGs
# spill outside the FWCP admin boundary; the report only cares about
# the portion inside.
#
# Run interactively when bundled WSG or ecoregion polygons change.

library(sf)
library(dplyr)
sf_use_s2(FALSE)

ctx <- system.file("extdata", "context_fwcp_peace.gpkg", package = "cd")
if (!nzchar(ctx)) {
  stop("context_fwcp_peace.gpkg not found — install cd from source first.")
}
wsgs       <- st_read(ctx, layer = "wsgs",       quiet = TRUE)
ecoregions <- st_read(ctx, layer = "ecoregions", quiet = TRUE)
ecoregions <- ecoregions[ecoregions$area_km2 > 100, ]  # drop PRB sliver

wsgs_3005       <- st_transform(wsgs, 3005)
ecoregions_3005 <- st_transform(ecoregions, 3005)

# -- Per-WSG x ecoregion intersection area ------------------------------------
overlap <- lapply(seq_len(nrow(wsgs_3005)), function(i) {
  w <- wsgs_3005[i, ]
  inter <- suppressWarnings(st_intersection(ecoregions_3005, w))
  if (nrow(inter) == 0) return(NULL)
  inter$area_km2 <- as.numeric(st_area(inter)) / 1e6
  data.frame(
    wsg_code = w$code,
    wsg_name = w$name,
    ecoregion_code = inter$code,
    ecoregion_name = inter$name,
    area_km2 = inter$area_km2
  )
})
overlap_df <- do.call(rbind, overlap)

# Pivot wide: rows = WSG, cols = ecoregion code, values = area_km2
ecoregion_codes <- unique(ecoregions$code)
wide <- overlap_df |>
  group_by(wsg_code, wsg_name, ecoregion_code) |>
  summarise(area_km2 = sum(area_km2), .groups = "drop") |>
  tidyr::pivot_wider(
    id_cols = c(wsg_code, wsg_name),
    names_from = ecoregion_code,
    values_from = area_km2,
    values_fill = 0
  )

# Ensure all ecoregion columns exist even if a WSG has zero in some
for (ec in ecoregion_codes) if (!ec %in% names(wide)) wide[[ec]] <- 0
wide <- wide[, c("wsg_code", "wsg_name", ecoregion_codes)]

# Per-WSG total inside FWCP (denominator) and percentages
wide$total_km2 <- rowSums(wide[, ecoregion_codes])
pct_cols <- paste0(ecoregion_codes, "_pct")
for (i in seq_along(ecoregion_codes)) {
  wide[[pct_cols[i]]] <- round(100 * wide[[ecoregion_codes[i]]] / wide$total_km2, 1)
}

# -- Generate templated commentary --------------------------------------------
generate_commentary <- function(pcts) {
  pcts <- pcts[order(-pcts)]
  pcts <- pcts[pcts > 0.5]
  if (length(pcts) == 0) return("(no overlap)")
  if (length(pcts) == 1) {
    return(sprintf("Entirely within %s.", names(pcts)[1]))
  }
  if (pcts[1] > 95) {
    return(sprintf("Almost entirely within %s (%.0f%%).", names(pcts)[1], pcts[1]))
  }
  if (pcts[1] > 60) {
    others <- paste(
      sprintf("%s (%.0f%%)", names(pcts)[-1], pcts[-1]),
      collapse = ", "
    )
    return(sprintf("Largely %s (%.0f%%) with %s.", names(pcts)[1], pcts[1], others))
  }
  paste0(
    "Spans ",
    paste(sprintf("%s (%.0f%%)", names(pcts), pcts), collapse = ", "),
    "."
  )
}

wide$commentary <- vapply(seq_len(nrow(wide)), function(i) {
  pcts <- as.numeric(wide[i, pct_cols])
  names(pcts) <- ecoregion_codes
  generate_commentary(pcts)
}, character(1))

# -- Final ordering and write -------------------------------------------------
out <- wide |>
  select(
    wsg_code, wsg_name,
    total_km2,
    all_of(pct_cols),
    commentary
  ) |>
  mutate(total_km2 = round(total_km2, 0)) |>
  arrange(wsg_code)

out_path <- "inst/extdata/peace_wsg_ecoregion_commentary.csv"
write.csv(out, out_path, row.names = FALSE)

cat("\nWrote:", out_path, "\n")
cat("Rows:", nrow(out), "\n")
cat("Size:", round(file.size(out_path) / 1024, 1), "KB\n\n")
print(out, row.names = FALSE)
