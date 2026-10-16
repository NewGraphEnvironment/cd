# One-off patch: the vignette data's swe_max anomalies, mm -> percent of
# normal (#139).
#
# cd_variables() gave swe_max the anomaly type "absolute" (mm) until #139,
# which made it "pct_normal" (%), as swe is. The precomputed tables in
# inst/vignette-data/{peace_fwcp,kootenay_lake}.rds were written by
# cd_anomaly() / cd_trend() under the old registry, and a carried
# anomaly_type wins over the registry, so they would keep reporting mm.
#
# Every group in those files (regional, each ecoregion, each wsg) stores the
# series it was built from (`ts`), and the data-raw scripts built `ano` and
# `trn` from it as cd_baseline(1951:1980) -> cd_anomaly() -> cd_trend(c(1951,
# 1981)). This rebuilds the swe_max rows of `ano` and `trn` that way and
# replaces nothing else. Before writing it proves the inputs are the ones the
# stored rows came from: the same chain run with swe_max as "absolute" must
# reproduce the stored swe_max rows, and every other row, element and
# attribute is checked unchanged. A full regen is still pending for other
# reasons (see vignette_data_vpd_unit_patch.R), and this keeps every other
# vignette number as it is until then. Re-running finds nothing to change.
#
# Run from the package root:  Rscript data-raw/vignette_data_swe_max_type_patch.R

pkgload::load_all(quiet = TRUE)

vars <- cd_variables()
new_type <- vars$anomaly_type[vars$variable == "swe_max"]
new_unit <- vars$unit[vars$variable == "swe_max"]
stopifnot(identical(new_type, "pct_normal"), identical(new_unit, "%"))

# The swe_max rows of `ano` and `trn` for one group, built from its `ts` the
# way the data-raw scripts did, with swe_max given `type`
swe_rebuild <- function(ts, type) {
  s <- ts[ts$variable == "swe_max", ]
  stopifnot(nrow(s) > 0)
  s$anomaly_type <- type
  s$unit <- if (type == "absolute") "mm" else new_unit
  ano <- cd_anomaly(s, cd_baseline(s, baseline_years = 1951:1980))
  trn <- cd_trend(ano, trend_start = c(1951, 1981))
  list(ano = ano, trn = trn)
}

# Replace the swe_max rows of `old` with `new`, in the stored column order
# and at the stored row positions
swe_splice <- function(old, new) {
  hit <- which(old$variable == "swe_max")
  stopifnot(length(hit) == nrow(new), all(names(old) %in% names(new)))
  new <- as.data.frame(new)[, names(old)]
  key <- intersect(c("variable", "period", "year", "trend_start"), names(old))
  ord <- match(
    do.call(paste, as.data.frame(old[hit, key])),
    do.call(paste, new[, key])
  )
  stopifnot(!anyNA(ord), !anyDuplicated(ord))
  out <- old
  for (col in names(old)) {
    v <- new[[col]][ord]
    stopifnot(identical(class(v), class(old[[col]])))
    out[[col]][hit] <- v
  }
  out
}

# Every list holding ts + ano + trn, with its path
groups <- function(x, path = character()) {
  if (!is.list(x) || is.data.frame(x)) return(list())
  here <- if (all(c("ts", "ano", "trn") %in% names(x))) list(path) else list()
  for (n in names(x)) here <- c(here, groups(x[[n]], c(path, n)))
  here
}

files <- file.path("inst/vignette-data", c("peace_fwcp.rds", "kootenay_lake.rds"))
stopifnot(all(file.exists(files)))

for (f in files) {
  old <- readRDS(f)
  paths <- groups(old)
  stopifnot(length(paths) > 0)
  types <- unlist(lapply(paths, function(p) {
    g <- old[[p]]
    c(g$ano$anomaly_type[g$ano$variable == "swe_max"],
      g$trn$anomaly_type[g$trn$variable == "swe_max"])
  }))
  if (all(types == new_type)) {
    message(f, ": swe_max already ", new_type, ", nothing to do")
    next
  }
  stopifnot(all(types == "absolute"))

  new <- old
  for (p in paths) {
    g <- old[[p]]
    # The stored rows are the old chain's output, or the inputs differ
    was <- swe_rebuild(g$ts, "absolute")
    stopifnot(
      identical(swe_splice(g$ano, was$ano), g$ano),
      identical(swe_splice(g$trn, was$trn), g$trn)
    )
    now <- swe_rebuild(g$ts, new_type)
    new[[p]]$ano <- swe_splice(g$ano, now$ano)
    new[[p]]$trn <- swe_splice(g$trn, now$trn)
  }

  # Nothing but swe_max rows of ano / trn moved
  strip <- function(x) {
    for (p in paths) {
      x[[p]]$ano <- x[[p]]$ano[x[[p]]$ano$variable != "swe_max", ]
      x[[p]]$trn <- x[[p]]$trn[x[[p]]$trn$variable != "swe_max", ]
    }
    x
  }
  stopifnot(identical(strip(new), strip(old)))

  saveRDS(new, f, compress = "xz")
  stopifnot(identical(readRDS(f), new))
  message(f, ": swe_max rows of ", length(paths), " groups rebuilt as ", new_type)
}
