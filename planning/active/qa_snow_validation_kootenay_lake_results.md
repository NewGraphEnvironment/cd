# ASWS QA cross-check (Kootenay Lake AOI) — ERA5-Land swe_max vs station daily peak

Generated: 2026-05-04 22:29:35

Companion to the FWCP Peace QA from #48. Same questions:

1. **Magnitude of the bias** at our 5 Kootenay-region sites?
2. **Stability of the bias over time** — needed for the trend-
   defensibility argument in vignettes/kootenay-lake.Rmd.

## Per-site stats

|location_id |name           | elevation|  n| yr_min| yr_max| asws_mean| era5_mean| bias_mm| bias_pct|   cor|
|:-----------|:--------------|---------:|--:|------:|------:|---------:|---------:|-------:|--------:|-----:|
|2B02AP      |Farron         |      1230|  2|   2024|   2025|     377.5|     410.7|    33.2|      8.8| 1.000|
|2C10P       |Moyie Mountain |      1835| 47|   1972|   2025|     448.6|     270.6|  -178.0|    -39.7| 0.607|
|2D14P       |Redfish Creek  |      2100| 25|   2001|   2025|    1477.2|     550.0|  -927.1|    -62.8| 0.808|

## Overall

- Paired site-years: 74
- Correlation (ERA5 vs ASWS, all sites pooled): r = 0.899
- Mean bias (ERA5 - ASWS): -425.4 mm (-53.6%)

## Bias-trend stability (per site)

Regression of (ERA5 - ASWS) on year. A slope near zero with
high p means the bias is stable — the trend-defensibility
argument in the vignette holds.

|location_id |name           | bias_slope| bias_slope_p|
|:-----------|:--------------|----------:|------------:|
|2C10P       |Moyie Mountain |      -1.31|        0.153|
|2D14P       |Redfish Creek  |     -12.24|        0.070|
