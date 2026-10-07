# Interop check for #119: a partial-sync state, served over HTTP and read through
# /vsicurl/ the way STEP 1 and STEP 4 read S3, through the real append_to_cog()
# lifted from the pipeline, publish_problems(), cd_stac_catalog() and
# catalog_problems(). Run from the repo root:
#   Rscript <this> [path-to-pipeline-script]
suppressMessages({library(cd); library(terra)})
source("scripts/_lib.R")
args <- commandArgs(trailingOnly = TRUE)
pipeline <- if (length(args)) args[1] else "scripts/pipeline_update_edh.R"

root <- tempfile("interop119_")
live_dir <- file.path(root, "live"); cog_dir <- file.path(root, "cogs")
dir.create(live_dir, recursive = TRUE); dir.create(cog_dir)

agg <- c(tmean = "mean", tmax = "mean", tmin = "mean", prcp = "sum",
         vpd = "mean", rh = "mean", soil_moisture = "mean", swe = "mean",
         snowfall = "sum", snowmelt = "sum", snow_cover = "mean")
seas <- cd_seasons()
ann <- c("swe_max", "snowfall_fraction", "snowmelt_doy_50", "snowmelt_rate_peak")
expected <- cog_expected(agg, seas, ann)

grid <- rast(nrows = 4, ncols = 4, xmin = -140, xmax = -114, ymin = 48, ymax = 60,
             crs = "EPSG:4326")
layer <- function(yr) { r <- grid; values(r) <- yr + seq_len(16) / 100; names(r) <- yr; r }
old_years <- 1950:1955; new_year <- 1956L
# The partial sync: tmean_annual did NOT go up, 20 others did.
ahead_cogs <- setdiff(expected, "tmean_annual.tif")[1:20]
for (f in expected) {
  yrs <- if (f %in% ahead_cogs) c(old_years, new_year) else old_years
  cd_cog_write(rast(lapply(yrs, layer)), file.path(live_dir, f))
}

port <- 8000L + sample.int(999, 1)
srv <- processx::process$new("python3", c("-m", "http.server", port, "--directory", live_dir,
                                          "--bind", "127.0.0.1"), stdout = NULL, stderr = NULL)
on.exit(srv$kill(), add = TRUE)
Sys.sleep(1.5)
base <- paste0("http://127.0.0.1:", port)

# STEP 1, as the pipeline does it.
live_years <- lapply(stats::setNames(nm = expected), function(f) {
  tryCatch(names(rast(paste0("/vsicurl/", base, "/", f))), error = function(e) NULL)
})
spans <- live_spans(live_years)
cat("STEP 1: problems", length(spans$problems), "| common", range(spans$common),
    "| ahead", length(spans$ahead), "\n")
stopifnot(length(spans$problems) == 0, identical(spans$common, old_years),
          length(spans$ahead) == 20)

# STEP 4 with the pipeline's own append_to_cog().
exprs <- parse(pipeline)
is_def <- vapply(exprs, function(e) {
  is.call(e) && identical(e[[1]], as.name("<-")) && identical(e[[2]], as.name("append_to_cog"))
}, logical(1))
env <- new.env()
env$log_msg <- function(...) cat("   ", ..., "\n", sep = "")
env$cog_dir <- cog_dir
env$cog_base <- base
eval(exprs[[which(is_def)]], env)
# append_to_cog(var, period, ...) reads and writes <var>_<period>.tif, so split
# each expected name at its last underscore.
split_name <- function(f) {
  k <- sub("\\.tif$", "", f)
  c(sub("_[^_]+$", "", k), sub("^.*_", "", k))
}
call_append <- function(f, layers) {
  vp <- split_name(f)
  tryCatch(env$append_to_cog(vp[1], vp[2], layers),
           error = function(e) { cat("   ERROR ", conditionMessage(e), "\n"); NULL })
}
written <- list()
for (f in expected) {
  b <- call_append(f, list(`1956` = layer(new_year)))
  if (!is.null(b)) written[[f]] <- b
}

# STEP 5.
required <- sort(unique(c(as.integer(unlist(live_years)), new_year)))
pp <- publish_problems(written, expected, list.files(cog_dir, pattern = "\\.tif$"),
                       sub("\\.tif$", "", expected), required)
cat("STEP 5 publish_problems:", if (length(pp)) paste(pp, collapse = " | ") else "none", "\n")
if (length(pp) == 0) {
  cat_path <- file.path(root, "catalog.json")
  invisible(capture.output(cd_stac_catalog(cog_dir, output_path = cat_path, base_url = base)))
  built <- catalog_item_years(jsonlite::read_json(cat_path))
  cp <- catalog_problems(built$keys, sub("\\.tif$", "", expected), built$start, built$end, required)
  cat("catalog_problems:", if (length(cp)) paste(cp, collapse = " | ") else "none",
      "| items", length(built$keys), "span", unique(built$start), "-", unique(built$end), "\n")
  # Values survive the rewrite: an ahead COG's 1956 is its live 1956, a lagging one's
  # 1956 is the appended layer, and both match layer(1956) here by construction.
  a <- rast(file.path(cog_dir, ahead_cogs[1])); l <- rast(file.path(cog_dir, "tmean_annual.tif"))
  stopifnot(identical(names(a), as.character(1950:1956)), identical(names(l), names(a)),
            isTRUE(all.equal(values(a), values(rast(file.path(live_dir, ahead_cogs[1]))))),
            isTRUE(all.equal(values(l[["1955"]]), values(layer(1955L)), tolerance = 1e-6)))
  cat("RESULT: repaired, all 59 span 1950-1956\n")
} else {
  cat("RESULT: refused\n")
}

# A held year that differs from this run's (a method change between the dead
# run and the repair) must stop the run, not be kept (review A1).
other <- layer(new_year); values(other) <- values(other) + 1
held_err <- tryCatch({ env$append_to_cog(split_name(ahead_cogs[1])[1],
                                         split_name(ahead_cogs[1])[2],
                                         list(`1956` = other)); "no error" },
                     error = function(e) conditionMessage(e))
cat("held band differs:", held_err, "\n")
stopifnot(grepl("differs from the 1956 computed this run", held_err, fixed = TRUE))
# An unchanged COG is a byte copy of the live one, not a re-encode (review A2).
stopifnot(identical(unname(tools::md5sum(file.path(cog_dir, ahead_cogs[2]))),
                    unname(tools::md5sum(file.path(live_dir, ahead_cogs[2])))))
cat("unchanged COG: byte-identical to the live one\n")
