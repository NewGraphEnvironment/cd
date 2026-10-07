#!/usr/bin/env bash
# Dry runs of pipeline_update_edh.R against a local fixture bucket (#119 review
# AC3): a copy of the script with catalog_url and cog_base pointed at a local
# http.server, so no production knob is needed. STEP 0, STEP D and the tmax/tmin
# check still run against the real bucket, read-only apart from STEP 0's
# sentinel, exactly as the weekly heartbeat does. Run from the repo root.
#
#   planning/archive/2026-10-issue-119-partial-sync/fixture_dryrun_119.sh <state>
#     partial  1950-2024 common, 20 COGs ahead by 2025 -> warn, exit 0
#     beyond   1950-2025 common, 20 COGs ahead by 2026 -> unfetched, exit 1
#     missing  1950-2025, one COG absent               -> re-run hint, exit 1
set -euo pipefail
state="$1"
work=$(mktemp -d -t fixture119XXXXXX)
port=$((8000 + RANDOM % 999))
base="http://127.0.0.1:${port}"

Rscript - "$work" "$state" "$base" <<'EOF'
suppressMessages({library(cd); library(terra)})
source("scripts/_lib.R")
a <- commandArgs(trailingOnly = TRUE); dir <- a[1]; state <- a[2]; base <- a[3]
agg <- c(tmean = "mean", tmax = "mean", tmin = "mean", prcp = "sum",
         vpd = "mean", rh = "mean", soil_moisture = "mean", swe = "mean",
         snowfall = "sum", snowmelt = "sum", snow_cover = "mean")
ann <- c("swe_max", "snowfall_fraction", "snowmelt_doy_50", "snowmelt_rate_peak")
expected <- cog_expected(agg, cd_seasons(), ann)
g <- rast(nrows = 2, ncols = 2, xmin = -140, xmax = -114, ymin = 48, ymax = 60, crs = "EPSG:4326")
mk <- function(yrs, f) {
  r <- rast(lapply(yrs, function(y) { x <- g; values(x) <- y; names(x) <- y; x }))
  cd_cog_write(r, file.path(dir, f), overwrite = TRUE)
}
common <- if (state == "partial") 1950:2024 else 1950:2025
for (f in expected) mk(common, f)
# The catalog as the last good publish left it: spanning `common`.
invisible(capture.output(cd_stac_catalog(dir, output_path = file.path(dir, "catalog.json"),
                                         base_url = base)))
ahead <- setdiff(expected, "tmean_annual.tif")[1:20]
if (state %in% c("partial", "beyond")) for (f in ahead) mk(c(common, max(common) + 1L), f)
if (state == "missing") file.remove(file.path(dir, "rh_fall.tif"))
EOF

copy="$work/pipeline_fixture.R"
sed -e "s#^catalog_url <- .*#catalog_url <- \"${base}/catalog.json\"#" \
    -e "s#^cog_base <- .*#cog_base <- \"${base}\"#" \
    scripts/pipeline_update_edh.R > "$copy"
[ "$(grep -c "${base}" "$copy")" -eq 2 ] || { echo "FAIL: sed did not point both URLs at the fixture"; exit 1; }

python3 -m http.server "$port" --directory "$work" --bind 127.0.0.1 >/dev/null 2>&1 &
srv=$!
trap 'kill "$srv" 2>/dev/null; rm -rf "$work"' EXIT
sleep 1.5
set +e
Rscript "$copy" --dry-run 2>&1 | sed -n '/=== STEP 1/,$p'
echo "exit ${PIPESTATUS[0]}"
