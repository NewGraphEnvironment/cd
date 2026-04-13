#!/usr/bin/env Rscript
#
# QA: check all monthly GeoTIFFs in data/backfill/monthly/ for alignment
# and sanity before Stage 3 COG/STAC/S3.
#
# Checks:
#   1. Grid alignment — extent, resolution, CRS, origin identical across
#      all variables for a sample year (2000)
#   2. Time coverage per variable
#   3. Physical sanity — tmin <= tmean <= tmax at each pixel/month, for
#      a handful of sample years
#   4. Value ranges per variable stay within plausible bounds
#   5. CDS vs EDH comparison — mean of monthly climate for a shared variable
#      (if any CDS-era file still exists) to spot obvious shifts

suppressMessages(library(terra))

monthly_dir <- "data/backfill/monthly"
log_msg <- function(...) cat(sprintf("[%s] %s\n", format(Sys.time(), "%H:%M:%S"), paste0(...)))

# -- 1. Grid alignment across variables (sample year 2000) --------------------
log_msg("=== 1. GRID ALIGNMENT (year 2000) ===")
vars <- c("tmax", "tmin", "tmean", "prcp", "vpd", "rh", "soil_moisture")
ref <- NULL
for (v in vars) {
  f <- file.path(monthly_dir, paste0(v, "_2000.tif"))
  if (!file.exists(f)) {
    log_msg("  ", v, ": MISSING")
    next
  }
  r <- rast(f)
  e <- as.vector(ext(r))
  res_r <- res(r)
  crs_code <- crs(r, describe = TRUE)$code
  if (is.na(crs_code) || length(crs_code) == 0) crs_code <- "UNKNOWN"
  if (is.null(ref)) {
    ref <- list(ext = e, res = res_r, crs = crs_code, ncell = ncell(r))
    log_msg("  ", v, ": [REF] ext=", paste(round(e, 3), collapse = ","),
            " res=", paste(round(res_r, 4), collapse = ","),
            " crs=", crs_code, " ncell=", ncell(r), " nlyr=", nlyr(r))
  } else {
    same_ext <- isTRUE(all.equal(e, ref$ext, tolerance = 1e-6))
    same_res <- isTRUE(all.equal(res_r, ref$res, tolerance = 1e-6))
    same_crs <- identical(crs_code, ref$crs)
    same_ncell <- ncell(r) == ref$ncell
    status <- if (same_ext && same_res && same_crs && same_ncell) "OK" else "MISALIGNED"
    log_msg("  ", v, ": ", status,
            if (!same_ext) paste0(" ext_diff=", paste(round(e - ref$ext, 5), collapse = ",")) else "",
            if (!same_res) paste0(" res_diff=", paste(round(res_r - ref$res, 6), collapse = ",")) else "",
            if (!same_crs) paste0(" crs=", crs_code) else "",
            if (!same_ncell) paste0(" ncell=", ncell(r)) else "",
            " nlyr=", nlyr(r))
  }
}

# -- 2. Time coverage per variable --------------------------------------------
log_msg("")
log_msg("=== 2. TIME COVERAGE ===")
for (v in vars) {
  files <- list.files(monthly_dir, pattern = paste0("^", v, "_\\d{4}\\.tif$"), full.names = FALSE)
  years <- sort(as.integer(sub(paste0(v, "_(\\d{4})\\.tif"), "\\1", files)))
  if (length(years) == 0) {
    log_msg("  ", v, ": no files")
    next
  }
  gaps <- setdiff(seq(min(years), max(years)), years)
  log_msg("  ", v, ": ", length(years), " years, ", min(years), " to ", max(years),
          if (length(gaps) > 0) paste0(", GAPS: ", paste(gaps, collapse = ",")) else ", no gaps")
}

# -- 3. Physical sanity tmin <= tmean <= tmax (sample years) -------------------
log_msg("")
log_msg("=== 3. PHYSICAL SANITY tmin <= tmean <= tmax ===")
sample_years <- c(1960, 1990, 2010, 2024)
for (y in sample_years) {
  fx <- file.path(monthly_dir, paste0("tmax_", y, ".tif"))
  fn <- file.path(monthly_dir, paste0("tmin_", y, ".tif"))
  fm <- file.path(monthly_dir, paste0("tmean_", y, ".tif"))
  if (!all(file.exists(fx), file.exists(fn), file.exists(fm))) {
    log_msg("  ", y, ": one or more files missing, skip")
    next
  }
  x <- rast(fx); n <- rast(fn); m <- rast(fm)
  # Check on Jan (layer 1) and Jul (layer 7)
  for (lyr in c(1, 7)) {
    # Cell-wise comparison — count violations
    v_xmin <- values(n[[lyr]] > x[[lyr]], na.rm = TRUE)
    v_mmax <- values(m[[lyr]] > x[[lyr]], na.rm = TRUE)
    v_mmin <- values(m[[lyr]] < n[[lyr]], na.rm = TRUE)
    n_viol_xmin <- sum(v_xmin, na.rm = TRUE)
    n_viol_mmax <- sum(v_mmax, na.rm = TRUE)
    n_viol_mmin <- sum(v_mmin, na.rm = TRUE)
    total <- sum(!is.na(values(x[[lyr]])))
    log_msg(sprintf("  %d %s: tmin>tmax=%d, tmean>tmax=%d, tmean<tmin=%d (of %d land cells)",
                    y, c("Jan", "", "", "", "", "", "Jul")[lyr], n_viol_xmin, n_viol_mmax, n_viol_mmin, total))
  }
}

# -- 4. Value ranges per variable ---------------------------------------------
log_msg("")
log_msg("=== 4. VALUE RANGES (2024) ===")
ranges_expected <- list(
  tmax = c(-60, 50),  tmin = c(-70, 40),  tmean = c(-60, 40),
  prcp = c(0, 2000),  vpd = c(0, 100),    rh = c(0, 100),
  soil_moisture1 = c(0, 1), soil_moisture2 = c(0, 1),
  soil_moisture3 = c(0, 1), soil_moisture4 = c(0, 1)
)
for (v in vars) {
  f <- file.path(monthly_dir, paste0(v, "_2024.tif"))
  if (!file.exists(f)) next
  r <- rast(f)
  stats <- global(r, c("min", "max"), na.rm = TRUE)
  v_min <- min(stats$min, na.rm = TRUE)
  v_max <- max(stats$max, na.rm = TRUE)
  exp <- ranges_expected[[v]]
  in_range <- !is.null(exp) && v_min >= exp[1] && v_max <= exp[2]
  log_msg(sprintf("  %s: [%.2f, %.2f] (expected [%s, %s]) %s",
                  v, v_min, v_max,
                  if (!is.null(exp)) as.character(exp[1]) else "?",
                  if (!is.null(exp)) as.character(exp[2]) else "?",
                  if (in_range) "OK" else "OUT OF RANGE"))
}

# -- 5. CDS vs EDH tmean comparison (if CDS tmean exists) ---------------------
# If our CDS tmean and EDH tmax/tmin cover the same year, we can check that
# (tmax + tmin) / 2 is roughly correlated with tmean. Not strict equality
# because tmean is mean of hourly, while (tmax+tmin)/2 is the old-school
# climatologist's approximation — but they should agree within ~5C.
log_msg("")
log_msg("=== 5. CDS tmean vs EDH (tmax+tmin)/2 — Jan 2000 ===")
fm <- file.path(monthly_dir, "tmean_2000.tif")
fx <- file.path(monthly_dir, "tmax_2000.tif")
fn <- file.path(monthly_dir, "tmin_2000.tif")
if (all(file.exists(fm), file.exists(fx), file.exists(fn))) {
  m <- rast(fm)[[1]]
  approx <- (rast(fx)[[1]] + rast(fn)[[1]]) / 2
  diff_r <- approx - m
  s <- global(diff_r, c("mean", "min", "max"), na.rm = TRUE)
  log_msg(sprintf("  (tmax+tmin)/2 - tmean: mean=%.2f, min=%.2f, max=%.2f C",
                  s$mean, s$min, s$max))
  log_msg("  Expected: mean near 0, typical max/min within ~5 C for most cells")
} else {
  log_msg("  skip: missing files")
}

log_msg("")
log_msg("=== QA DONE ===")
