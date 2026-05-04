# cd 0.1.7 (2026-05-04)

* Snow-methodology literature review for the upcoming "Snowpack" vignette section. Adds `scripts/rag_build_snow_methodology.R` and `scripts/rag_query_snow_methodology.R`, builds a local ragnar DuckDB from 11 peer-reviewed papers (now in the `NewGraphEnvironment/hydrology` Zotero collection), and ships the methodology synthesis + 15-row "cite this for that" citation map at `planning/archive/2026-05-issue-53-snow-lit-review/findings.md`. Headline finding: `cd_trend()`'s raw Mann-Kendall + Theil-Sen (no prewhitening) is methodologically correct for our 76-year series with strong trends per [Yue & Wang 2002](https://doi.org/10.1029/2001WR000861) — prewhitening would *underestimate* slope when a real trend exists. ([#54](https://github.com/NewGraphEnvironment/cd/pull/54))

# cd 0.1.6 (2026-05-03)

* Producer-side refactor. Extracted shared safeguards (single-instance pgrep guard, exponential-backoff retry, atomic GeoTIFF write, timestamped logging, EDH token loader) from `scripts/backfill_edh_all.py` into a new `scripts/_lib.py`, and ported them to the sibling `scripts/backfill_edh_tmax_tmin.py` (which previously had none). Adds a `backup_before_delete()` helper codifying the on-disk pattern at `data/backfill/monthly/_cds_backup/`. No consumer-side changes; sets up the planned snow-variables backfill ([#48](https://github.com/NewGraphEnvironment/cd/issues/48)) to inherit the safeguards via a single import. ([#52](https://github.com/NewGraphEnvironment/cd/pull/52))

# cd 0.1.5 (2026-05-02)

* Adds a "Watershed Groups Across Ecoregions" section to the `peace-fwcp` vignette: a map of the 16 canonical FWCP Peace watershed groups labelled with codes on top of ecoregion fills, plus a table showing the percent of each watershed group's area falling in each of the five ecoregions. Lets readers map per-ecoregion climate departure findings (precipitation up only in BMP and NRM) onto the watershed-group reporting unit. Canonical 16-WSG list (CARP, CRKD, FINA, FINL, FIRE, FOXR, INGR, LOMI, MESI, NATR, OSPK, PARA, PARS, PCEA, TOOD, UOMI) hardcoded in `data-raw/example_context_fwcp_peace.R` for reuse — UPCE and MURR dropped because they sit mostly outside the FWCP boundary. Recent vs Pre-warming consolidated into one table. All six vignette tables now render with single, clean bookdown captions (`label = NA` + `caption = "..."` pattern). ([#47](https://github.com/NewGraphEnvironment/cd/issues/47))

# cd 0.1.4 (2026-05-01)

KOTL vignette removed. `peace-fwcp` is now the canonical worked example — it covers everything KOTL did at higher fidelity (regional + per-ecoregion + day-night asymmetry + plain-language explainers + interpretation), and dropping the second live-S3 vignette saves ~60 s per pkgdown render and removes the last `/vsicurl/` flake surface from the doc build. KOTL polygon assets stay in `inst/extdata/` because the README quick-start still uses them. Future direction (single-vignette snowpack story or split vignettes by AOI scale) deferred until snow-pack variables land — see [#49](https://github.com/NewGraphEnvironment/cd/issues/49). ([#50](https://github.com/NewGraphEnvironment/cd/pull/50))

# cd 0.1.3 (2026-05-01)

CI fragility patch. The `peace-fwcp` vignette previously re-fetched ~144 `/vsicurl/` COG range requests on every pkgdown render; one transient flake failed the whole build. Heavy data is now pre-computed by `data-raw/peace_fwcp_vignette_data.R` and shipped under `inst/vignette-data/` (160 KB rds + 6 KB tif). Vignette loads via `system.file()` and renders in ~10 s instead of ~6 min. Live `cd_catalog()` read kept as the consumer entry-point demonstration. ([#45](https://github.com/NewGraphEnvironment/cd/issues/45))

# cd 0.1.2 (2026-04-30)

Vignette and docs patch. New `peace-fwcp` vignette runs the consumer pipeline on a regional administrative AOI (FWCP Peace Region, ~73,000 km², ~11x KOTL) — catalog → extract → trends → recent vs pre-warming → spatial map → per-ecoregion breakdown across the five BC ecoregions intersecting the region, with faceted time-series carrying both 75-yr and 45-yr Theil-Sen trend lines, a wide roll-up table, day-night asymmetry section (textbook signal does show up here, unlike KOTL), and three-finding interpretation. Plain-language explainers for trend windows, WMO climate normal, and "warming has accelerated/slowed" framing. README gains a Data section with the catalog URL and the `/vsicurl/` direct-read pattern so the COGs are usable outside R (QGIS, gdalcubes, rasterio). Issue [#43](https://github.com/NewGraphEnvironment/cd/issues/43) filed for `cd_compare()` to gain a proper window-vs-window p-value. ([#42](https://github.com/NewGraphEnvironment/cd/issues/42))

# cd 0.1.1 (2026-04-15)

Vignette and docs patch. The `climate-departure` vignette gained a "Daytime Highs and Overnight Lows" section using the tmax/tmin variables now on STAC, with honest framing for the example watershed (the textbook day-night asymmetry doesn't show at Kootenay Lake — the dominant signal is summer daytime maximum, the temperature envelope for salmonid thermal stress in tributaries). Existing maps now clip context layers and mask departure rasters to the watershed group polygon for tighter framing. Interpretation section corrected: precipitation has declined ~10% (statistically significant) and soils are drying due to both falling precipitation and rising evapotranspiration. README quick-start fixed (was referencing files that don't exist) and now links to the live pkgdown vignette. ([#39](https://github.com/NewGraphEnvironment/cd/issues/39))

# cd 0.1.0 (2026-04-14)

First minor release. Producer pipeline migrated from Copernicus CDS to DestinE Earth Data Hub (Zarr). Same ERA5-Land data at the same 9 km native grid, no rate limiting, ~5x faster fetches. All 7 cd variables (tmax, tmin, tmean, prcp, vpd, rh, soil_moisture) regenerated on a single internally-consistent EPSG:4326 BC grid. Monthly GitHub Action rewired to use EDH. Consumer API unchanged — `cd_catalog()` and friends work exactly as before against the refreshed STAC catalog on `s3://stac-era5-land`. See [pkgdown reference](https://newgraphenvironment.com/cd/reference/) for the current function list. ([#36](https://github.com/NewGraphEnvironment/cd/issues/36))

# cd 0.0.0.9000

Initial development version. Consumer and producer pipelines for ERA5-Land climate departure analysis.
