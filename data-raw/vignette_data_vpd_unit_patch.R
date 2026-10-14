# One-off patch: the vignette data's vpd unit, "Pa" -> "hPa" (#96).
#
# cd_variables() gave vpd the unit "Pa" until #96, but the data is hPa. The
# precomputed tables in inst/vignette-data/*.rds were written by
# cd_anomaly() / cd_trend() under the old registry, so they carry "Pa" on
# every vpd row, and a carried unit wins over the registry. This rewrites
# that one column on vpd rows and nothing else: values, rows, other columns
# and attributes are checked unchanged before anything is written.
#
# A full regen (data-raw/*_vignette_data.R) takes units from cd_variables(),
# but through library(cd), so it writes "hPa" only once a cd from after #96 is
# installed; under an older one it writes "Pa" back, which the bundled-data
# test in test-cd_variables.R fails on. The regen is pending for other reasons
# (#123's grid, #126's columns), and this patch keeps the vignette numbers as
# they are until then. Re-running finds nothing to change and writes nothing.
#
# Run from the package root:  Rscript data-raw/vignette_data_vpd_unit_patch.R

pkgload::load_all(quiet = TRUE)

unit_relabel <- function(x, from, to) {
  if (is.data.frame(x)) {
    if (all(c("variable", "unit") %in% names(x))) {
      hit <- x$variable %in% "vpd" & x$unit %in% from
      x$unit[hit] <- to
    }
    return(x)
  }
  if (is.list(x)) {
    for (i in seq_along(x)) x[[i]] <- unit_relabel(x[[i]], from, to)
  }
  x
}

unit_count <- function(x, unit) {
  if (is.data.frame(x)) {
    if (!all(c("variable", "unit") %in% names(x))) return(0L)
    return(sum(x$variable %in% "vpd" & x$unit %in% unit))
  }
  if (is.list(x)) return(sum(vapply(x, unit_count, integer(1), unit = unit)))
  0L
}

new_unit <- cd_variables()$unit[cd_variables()$variable == "vpd"]
stopifnot(identical(new_unit, "hPa"))

files <- list.files("inst/vignette-data", pattern = "\\.rds$", full.names = TRUE)
stopifnot(length(files) > 0)

for (f in files) {
  old <- readRDS(f)
  n_old <- unit_count(old, "Pa")
  if (n_old == 0L) {
    message(f, ": no vpd rows labelled Pa, nothing to do")
    next
  }
  # The round trip below is exact only if no vpd row already says hPa
  stopifnot(unit_count(old, new_unit) == 0L)

  new <- unit_relabel(old, "Pa", new_unit)
  stopifnot(
    unit_count(new, "Pa") == 0L,
    unit_count(new, new_unit) == n_old,
    identical(unit_relabel(new, new_unit, "Pa"), old)
  )
  saveRDS(new, f, compress = "xz")
  stopifnot(identical(readRDS(f), new))
  message(f, ": ", n_old, " vpd rows relabelled Pa -> ", new_unit)
}
