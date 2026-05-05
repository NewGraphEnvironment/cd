# ASWS QA cross-check — ERA5-Land swe_max vs station daily peak

Generated: 2026-05-04 17:00:04

Filed against #48 Phase 3. Tests two questions:

1. **Magnitude of the bias** — ERA5-Land overestimates mountain SWE by
   150-200% per Kouki et al. 2023; what's the bias at our 5 BC sites?
2. **Stability of the bias over time** — the trend defensibility
   argument in the vignette rests on the bias being approximately stable.

## Per-site stats

|location_id |name        | elevation|  n| yr_min| yr_max| asws_mean| era5_mean| bias_mm| bias_pct|   cor|
|:-----------|:-----------|---------:|--:|------:|------:|---------:|---------:|-------:|--------:|-----:|
|4A02P       |Pine Pass   |      1400| 37|   1989|   2025|    1140.0|     439.4|  -700.7|    -61.5| 0.625|
|4A03P       |Ware Upper  |      1565| 10|   2016|   2025|     250.1|     253.7|     3.6|      1.4| 0.085|
|4A18P       |Mount Sheba |      1490|  7|   2019|   2025|     935.9|     632.7|  -303.2|    -32.4| 0.738|
|4A30P       |Aiken Lake  |      1050| 41|   1985|   2025|     265.3|     407.4|   142.1|     53.5| 0.414|

## Overall

- Paired site-years: 95
- Correlation (ERA5 vs ASWS, all sites pooled): r = 0.505
- Mean bias (ERA5 - ASWS): -233.5 mm (-35.7%)

## Bias-trend stability (per site)

Regression of (ERA5 - ASWS) on year. A slope near zero with
high p means the bias is stable — this is what we want for
the trend-defensibility argument in the vignette.

|location_id |name       | bias_slope| bias_slope_p|
|:-----------|:----------|----------:|------------:|
|4A02P       |Pine Pass  |      -2.36|        0.536|
|4A03P       |Ware Upper |     -11.10|        0.218|
|4A30P       |Aiken Lake |      -0.19|        0.836|
