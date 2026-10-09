#!/usr/bin/env Rscript
#
# Offline tests for scripts/_lib.R. No network, no EDH token — every case is a
# plain function call, so this is safe to run anywhere.
#
# Usage:
#   Rscript scripts/test_lib.R

source("scripts/_lib.R")

failures <- 0L
checks <- 0L
check <- function(ok, what) {
  checks <<- checks + 1L
  failures <<- failures + as.integer(!ok)
  cat(sprintf("  %s  %s\n", if (ok) "ok  " else "FAIL", what))
}

# -- edh_retryable -------------------------------------------------------------
# Both answers, and the two that must be FALSE are the ones that matter: a
# retried 401 just delays a report, and a retried 404 hammers a dead URL.
for (s in c(0L, 403L, 408L, 429L, 500L, 503L)) {
  check(edh_retryable(s), sprintf("retryable(%d) is TRUE", s))
}
# 410, 451 and 499 pin the 5xx boundary from BELOW. Without them, lowering
# edh_retryable's threshold into the 4xx range survives: at >= 405 a 410 Gone
# or a 451 would be retried -- 3 fetches, 2 retries, 15s of backoff -- which is
# exactly what the 404 case exists to prevent. edh_diagnosis is pinned the same
# way below; the two encode one boundary and both ends of it need holding.
for (s in c(200L, 400L, 401L, 404L, 410L, 451L, 499L)) {
  check(!edh_retryable(s), sprintf("retryable(%d) is FALSE", s))
}

# -- edh_diagnosis -------------------------------------------------------------
# The point of #83 is that these three must not read the same. Asserting each
# message separately would still pass if all three were identical, so assert
# the distinctness itself.
d0   <- edh_diagnosis(0L)
d401 <- edh_diagnosis(401L)
d403 <- edh_diagnosis(403L)
d404 <- edh_diagnosis(404L)
# Status 0 belongs in the distinctness set: it is the connection-failure path
# (pipeline_update_edh.R sets edh_status <- 0L when the request returns NULL),
# and it is the status most likely to fire in CI. Left out, a diagnosis that
# collided with 401's would send an operator to rotate a healthy secret on a
# DNS timeout -- the precise regression this file exists to prevent.
check(length(unique(c(d0, d401, d403, d404))) == 4L,
      "0, 401, 403 and 404 give four distinct diagnoses")
check(grepl("reach the host", d0, fixed = TRUE), "0 says the host was unreachable")

check(grepl("Rotate", d401, fixed = TRUE), "401 says to rotate the secret")
check(grepl("NOT a bad token", d403, fixed = TRUE), "403 says it is not the token")
# Two assertions, and they are NOT independent. The regex matches the fixed
# needle itself -- grepl("[Rr]otate (the|your)", "Rotate the EDH_TOKEN secret")
# is TRUE -- so the fixed check cannot fail unless the regex already has. It is
# kept for its failure message, which localises the regression faster than a
# generic regex miss, NOT for coverage. If you are ever trimming these, delete
# the FIXED line; deleting the regex one loses everything.
#
# What the regex actually catches: [Rr]otate, one literal space, lowercase
# "the" or "your". "Rotate The", "rotate  the", "rotates the", "rotate our" and
# "You should rotate it" all escape it. That covers the realistic regression --
# a lowercase mid-sentence "rotate the/your" -- and no substring rule does much
# better, because "before you rotate the secret" is a legitimate reword that
# WOULD fail this assertion. The shipped text's "before rotating anything" and
# a reword to "before you rotate anything" both pass.
check(!grepl("Rotate the EDH_TOKEN secret", d403, fixed = TRUE),
      "403 does not carry 401's exact rotate-the-secret sentence")
check(!grepl("[Rr]otate (the|your)", d403),
      "403 does not tell the reader to rotate anything")
check(grepl("quota", d403, fixed = TRUE), "403 names the quota as a candidate")
check(grepl("moved", d404, fixed = TRUE), "404 points at the endpoint")
check(grepl("server error", edh_diagnosis(500L), fixed = TRUE), "500 blames EDH (boundary)")
# Pinned from below as well. With only the >= side asserted, lowering the
# boundary in either function survives — and at 405 the two statuses
# edh_retryable explicitly enumerates as expected EDH behaviour, 408 and 429,
# would both be diagnosed "EDH server error" with nothing to notice.
check(!grepl("server error", edh_diagnosis(408L), fixed = TRUE), "408 is not a server error")
check(!grepl("server error", edh_diagnosis(429L), fixed = TRUE), "429 is not a server error")
check(!grepl("server error", edh_diagnosis(404L), fixed = TRUE), "404 is not a server error")
check(!grepl("server error", edh_diagnosis(499L), fixed = TRUE), "499 is not a server error (boundary from below)")
check(grepl("server error", edh_diagnosis(503L), fixed = TRUE), "5xx blames EDH")
check(nzchar(edh_diagnosis(418L)), "an unmapped status still says something")

# -- cog_expected / publish_problems (#89) -----------------------------------
# The production config, restated as a known answer: 11 monthly natives x 5
# periods + 4 annual-derived = 59. If either pipeline's config changes, this
# number is the thing to re-derive, not to copy.
agg <- c(tmean = "mean", tmax = "mean", tmin = "mean", prcp = "sum",
         vpd = "mean", rh = "mean", soil_moisture = "mean", swe = "mean",
         snowfall = "sum", snowmelt = "sum", snow_cover = "mean")
seas <- list(winter = c(12, 1, 2), spring = 3:5, summer = 6:8, fall = 9:11)
ann <- c("swe_max", "snowfall_fraction", "snowmelt_doy_50", "snowmelt_rate_peak")
exp59 <- cog_expected(agg, seas, ann)
check(length(exp59) == 59L && !anyDuplicated(exp59), "cog_expected gives 59 distinct names")
check(all(c("tmean_annual.tif", "tmax_winter.tif", "swe_max_annual.tif") %in% exp59),
      "cog_expected names {var}_{period}.tif")
check(!"swe_max_winter.tif" %in% exp59, "annual-derived vars get no seasonal COG")

live_years <- 1950:2025
new_span <- as.character(1950:2026)
full <- stats::setNames(rep(list(new_span), 59), exp59)
live_keys <- sub("\\.tif$", "", exp59)
pp <- function(written = full, on_disk = names(written), keys = live_keys,
               required = c(live_years, 2026L)) {
  publish_problems(written, exp59, on_disk, keys, required)
}
# Each case asserts it yields exactly ONE problem as well as which one, so a
# guard that fires for the wrong reason (or for every reason) fails here.
one <- function(p, needle) length(p) == 1L && grepl(needle, p, fixed = TRUE)

check(identical(pp(), character(0)), "a complete run with the new year publishes")

# The issue's scenario: one variable skipped, the rest appended.
# A skipped COG is neither recorded nor on disk, so both checks name it.
two <- function(p, n1, n2) {
  length(p) == 2L && grepl(n1, p[1], fixed = TRUE) && grepl(n2, p[2], fixed = TRUE)
}
p <- pp(written = full[-which(exp59 == "swe_winter.tif")])
check(two(p, "1 of 59 COGs not written", "1 expected COG(s) not in the COG directory") &&
        all(grepl("swe_winter.tif", p, fixed = TRUE)),
      "58 of 59 written is refused, naming the missing COG")
check(two(pp(written = list()), "59 of 59", "59 expected COG(s)"),
      "nothing written is refused")

extra <- c(full, list(tmean_monthly.tif = new_span))
check(one(pp(written = extra), "does not expect"), "an unexpected COG is refused")

check(one(pp(on_disk = c(exp59, "old_name_annual.tif")), "not written by this run would be"),
      "a stale .tif left in the COG directory is refused")

# A write recorded but not on disk: `written` is a record, the directory is
# what gets catalogued.
check(one(pp(on_disk = exp59[-1]), "not in the COG directory"),
      "a COG recorded as written but absent from the directory is refused")

check(one(pp(keys = c(live_keys, "tmean_monthly")), "live catalog lists"),
      "a live item outside the expected set is refused")

ragged <- full
ragged[["prcp_summer.tif"]] <- as.character(1950:2025)
p <- pp(written = ragged)
check(length(p) == 1L && grepl("one span", p, fixed = TRUE),
      "one COG missing the new year is refused (spans differ)")

gap <- lapply(full, function(x) setdiff(x, "1990"))
check(one(pp(written = gap, required = c(setdiff(live_years, 1990L), 2026L)), "contiguous"),
      "a skipped year inside the span is refused")
check(one(pp(written = lapply(full, rev)), "contiguous"), "a descending span is refused")
check(one(pp(written = lapply(full, function(x) c(x, "lyr1"))), "contiguous"),
      "a non-year band name is refused")

short <- lapply(full, function(x) setdiff(x, "1950"))
p <- pp(written = short)
check(one(p, "lack 1 required year") && grepl("1950", p, fixed = TRUE),
      "a span starting after the live data is refused")
p <- pp(written = lapply(full, function(x) setdiff(x, "2026")))
check(one(p, "lack 1 required year") && grepl("2026", p, fixed = TRUE),
      "a span missing the appended year is refused")

# -- catalog_problems / catalog_item_years (#89) ------------------------------
keys59 <- sub("\\.tif$", "", exp59)
yrs <- 1950:2026
cp <- function(keys = keys59, start = rep(1950L, length(keys)),
               end = rep(2026L, length(keys)), years = yrs) {
  catalog_problems(keys, keys59, start, end, years)
}
check(identical(cp(), character(0)), "a complete catalog spanning the years passes")
check(identical(catalog_problems(keys59, keys59), character(0)),
      "keys alone (no years) pass when complete")
check(one(cp(keys = keys59[-3], start = rep(1950L, 58), end = rep(2026L, 58)), "1 of 59"),
      "a catalog missing an item is refused")
check(one(cp(keys = c(keys59, "tmean_unknown"), start = rep(1950L, 60),
             end = rep(2026L, 60)), "outside the expected set"),
      "an item outside the expected set (period 'unknown') is refused")
dupk <- c(keys59, keys59[1])
check(one(cp(keys = dupk, start = rep(1950L, 60), end = rep(2026L, 60)), "duplicate"),
      "a duplicated item is refused")
check(one(cp(end = replace(rep(2026L, 59), 7, 2025L)), "do not span 1950-2026"),
      "an item ending a year early is refused (the stale end_datetime)")
check(one(cp(start = replace(rep(1950L, 59), 2, NA)), "do not span"),
      "an item with no start_datetime is refused")
check(one(cp(end = rep(2026L, 58)), "line up"), "a years vector of the wrong length is refused")

cj <- list(items = list(
  list(properties = list(`cd:variable` = "tmean", `cd:period` = "annual",
                         start_datetime = "1950-01-01T00:00:00Z",
                         end_datetime = "2026-12-31T23:59:59Z")),
  list(properties = list(`cd:variable` = "swe_max", `cd:period` = "annual"))
))
iy <- catalog_item_years(cj)
check(identical(iy$keys, c("tmean_annual", "swe_max_annual")) &&
        identical(iy$start, c(1950L, NA)) && identical(iy$end, c(2026L, NA)),
      "catalog_item_years reads keys and years, NA where a date is absent")

h <- catalog_repair_hint("stac-era5-land")
check(grepl("s3://stac-era5-land/catalog.json", h, fixed = TRUE) &&
        grepl("--exclude 'daily/*'", h, fixed = TRUE) &&
        grepl("pipeline_stage3_edh.R", h, fixed = TRUE),
      "catalog_repair_hint names the target key, skips daily/, and the stage 3 fallback")
# Rebuilt from COGs a partial sync left out of step, the catalog lists mixed
# spans (#119), so the hint must say when it applies.
check(grepl("ends in the same year", h, fixed = TRUE) &&
        grepl("end in different years", h, fixed = TRUE),
      "catalog_repair_hint applies only when every COG ends in the same year")

# -- live_spans (#119) ---------------------------------------------------------
# Band names as terra reports them: character years.
live59 <- stats::setNames(rep(list(as.character(1950:2025)), 59), exp59)
ls_ok <- function(s, common, ahead = list()) {
  length(s$problems) == 0L && identical(s$common, common) &&
    (if (length(ahead) == 0L) length(s$ahead) == 0L else identical(s$ahead, ahead))
}

check(ls_ok(live_spans(live59), 1950:2025), "59 COGs in step: common span, nothing ahead")

# The issue's shape: a sync that died after tmean_annual went up.
part <- live59
part[["tmean_annual.tif"]] <- as.character(1950:2026)
check(ls_ok(live_spans(part), 1950:2025, list(tmean_annual.tif = 2026L)),
      "tmean_annual ahead: target the year the others hold, tmean_annual listed ahead")

# The shape the tmean_annual-only read could not see: tmean_annual lagging.
lag <- lapply(live59, function(x) as.character(1950:2026))
lag[["tmean_annual.tif"]] <- as.character(1950:2025)
s <- live_spans(lag)
check(length(s$problems) == 0L && identical(s$common, 1950:2025) &&
        length(s$ahead) == 58L && !"tmean_annual.tif" %in% names(s$ahead) &&
        all(vapply(s$ahead, identical, logical(1), 2026L)),
      "tmean_annual lagging: common is its span, the other 58 are ahead by 2026")

two_ahead <- live59
two_ahead[["prcp_summer.tif"]] <- as.character(1950:2026)
two_ahead[["swe_max_annual.tif"]] <- as.character(1950:2027)
check(ls_ok(live_spans(two_ahead), 1950:2025,
            list(prcp_summer.tif = 2026L, swe_max_annual.tif = 2026:2027)),
      "COGs ahead by different amounts each list their own extra years")

lp_one <- function(cogs, needle) {
  s <- live_spans(cogs)
  one(s$problems, needle) && length(s$common) == 0L && length(s$ahead) == 0L
}
late <- live59
late[["rh_fall.tif"]] <- as.character(1951:2025)
check(lp_one(late, "start in a different year") &&
        grepl("rh_fall.tif 1951", live_spans(late)$problems, fixed = TRUE),
      "a COG starting a year late is refused, naming it")
gapped <- live59
gapped[["vpd_spring.tif"]] <- as.character(setdiff(1950:2025, 1990))
check(lp_one(gapped, "contiguous"), "a COG with a year missing inside its span is refused")
# What appending a year a COG already holds produces: the old STEP 4 behaviour.
dup <- live59
dup[["tmax_annual.tif"]] <- as.character(c(1950:2026, 2026))
check(lp_one(dup, "contiguous"), "a COG holding a year twice is refused")
check(lp_one(lapply(live59, rev), "contiguous"), "descending band order is refused")
nonyear <- live59
nonyear[["tmin_winter.tif"]] <- c(as.character(1950:2025), "lyr1")
check(lp_one(nonyear, "contiguous"), "a band that is not a year is refused")
nonyear[["tmin_winter.tif"]] <- c(as.character(1950:2024), "2025.0")
check(lp_one(nonyear, "contiguous"), "a band that only coerces to a year is refused")
nonyear[["tmin_winter.tif"]] <- character(0)
check(lp_one(nonyear, "contiguous"), "a COG with no bands is refused")
unread <- live59
unread["snowmelt_annual.tif"] <- list(NULL)
check(lp_one(unread, "could not read 1 live COG") &&
        grepl("snowmelt_annual.tif", live_spans(unread)$problems, fixed = TRUE),
      "an unreadable COG is refused, naming it")
# Its remedy differs (re-run, not stage 3), so the caller needs it by name.
check(identical(live_spans(unread)$unread, "snowmelt_annual.tif") &&
        identical(live_spans(live59)$unread, character(0)) &&
        identical(live_spans(gapped)$unread, character(0)),
      "unread names the unreadable COGs and nothing else")

# publish_problems() on the repair's output (#119): required_years is every year
# any live COG held, plus what the run appended.
check(identical(pp(required = sort(unique(c(as.integer(unlist(part)), 2026L)))),
                character(0)),
      "a repaired set, all 59 at 1950-2026, publishes")
rep27 <- full
rep27[["prcp_summer.tif"]] <- as.character(1950:2027)
check(one(pp(written = rep27, required = 1950:2027), "one span"),
      "a COG left at 2027 by the partial sync, the rest only brought to 2026, is refused")
p <- pp(required = 1950:2027)
check(one(p, "lack 1 required year") && grepl("2027", p, fixed = TRUE),
      "a live year no written COG holds (an ahead year never fetched) is refused")
check(lp_one(list(), "no live COGs"), "no COGs read is refused")

# -- grid_problems (#123) -----------------------------------------------------
grid_tif <- function(nrow, ncol, xmin, xmax, ymin, ymax) {
  f <- tempfile(fileext = ".tif")
  r <- terra::rast(nrows = nrow, ncols = ncol, xmin = xmin, xmax = xmax,
                   ymin = ymin, ymax = ymax, crs = "EPSG:4326", vals = 1)
  terra::writeRaster(r, f)
  f
}
g_new <- grid_tif(121, 261, -140.05, -113.95, 47.95, 60.05)
g_new2 <- grid_tif(121, 261, -140.05 - 8e-12, -113.95 - 8e-12, 47.95 + 1e-12, 60.05 + 1e-12)
g_old <- grid_tif(120, 260, -139.95, -113.95, 47.95, 59.95)
check(identical(grid_problems(c(g_new, g_new2)), character(0)),
      "COGs on the BC grid (within float drift) pass")
p <- grid_problems(c(g_new, g_old))
check(length(p) == 1L && grepl("1 COG(s)", p, fixed = TRUE) &&
        grepl(basename(g_old), p, fixed = TRUE),
      "a 120 x 260 COG from before #123 is refused, by name")
check(grepl("could not be opened", grid_problems(tempfile(fileext = ".tif")), fixed = TRUE),
      "a missing COG is refused")

# -- run_provenance (#124) ------------------------------------------------------
prov_keys <- c("CD_VERSION", "CD_SHA", "CD_RUN_TIME", "CD_RUN_ID")
withr_env <- function(vars, code) {
  old <- Sys.getenv(names(vars), unset = NA)
  do.call(Sys.setenv, as.list(vars))
  on.exit({
    for (n in names(old)) if (is.na(old[[n]])) Sys.unsetenv(n) else
      do.call(Sys.setenv, stats::setNames(list(old[[n]]), n))
  })
  code
}
p <- withr_env(c(GITHUB_SHA = "f00", GITHUB_RUN_ID = "77",
                 CD_RUN_TIME = "2026-01-02T03:04:05Z"), run_provenance())
check(identical(names(p), prov_keys) && p[["CD_SHA"]] == "f00" &&
        p[["CD_RUN_ID"]] == "77" && p[["CD_RUN_TIME"]] == "2026-01-02T03:04:05Z" &&
        p[["CD_VERSION"]] == read.dcf("DESCRIPTION", fields = "Version")[1, 1],
      "CI provenance comes from GITHUB_SHA, GITHUB_RUN_ID and CD_RUN_TIME")
old_ci <- Sys.getenv(c("GITHUB_SHA", "GITHUB_RUN_ID", "CD_RUN_TIME"), unset = NA)
Sys.unsetenv(c("GITHUB_SHA", "GITHUB_RUN_ID", "CD_RUN_TIME"))
p <- run_provenance()
for (n in names(old_ci)) if (!is.na(old_ci[[n]])) do.call(Sys.setenv, stats::setNames(list(old_ci[[n]]), n))
check(grepl("^[0-9a-f]{40}(-dirty)?$", p[["CD_SHA"]]) && p[["CD_RUN_ID"]] == "local" &&
        grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$", p[["CD_RUN_TIME"]]),
      "local provenance reads the git HEAD and stamps now, in UTC")
check(!any(grepl(":", names(p), fixed = TRUE)) && !anyNA(p),
      "provenance keys carry no ':' and no value is NA, so cd_cog_write() accepts them")

cat(sprintf("\n%d/%d passed\n", checks - failures, checks))
quit(status = if (failures > 0L) 1L else 0L)
