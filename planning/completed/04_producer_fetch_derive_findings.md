# Findings

## CDS API (tested 2026-04-04)

- ecmwfr v2.0.3: `wf_set_key(key = "...")` — no `service` param
- macOS keyring errors unless key is set before `wf_request()`
- CDS renames `.grib` → `.zip` — actual file is a zip containing `data.grib`
- Queue time: ~2 min for small BC bbox request
- BC bbox in CDS format: `area = c(60, -140, 48, -114)` (N, W, S, E)
- Downloaded 0.1° resolution (121x261 grid for BC)
- Temperature in Kelvin (250-280K for January BC)

## Upstream processing

- All done externally, not in bc_climate_anomaly repo
- Uses ERA5-Land HOURLY data, aggregates to monthly
- Resamples to 0.25° (~30km) — we keep native 0.1° (~9km)
- Pre-computes VPD, RH, soil moisture, tmax, tmin before committing NCs

## Open questions — RESOLVED

**Precipitation units:** m/day average rate in monthly means product. Convert: × 1000 × days_in_month → mm/month.

**Soil moisture weighting:** Simple mean of 4 layers tested, produces 0.07-0.73 range. Upstream range is 0.04-0.65 (at coarser resolution). Close enough — simple mean is the starting point, can refine later.

**VPD units:** hPa, confirmed. Tetens formula produces hPa natively (6.1078 × ...). January BC range 0.2-2.1 hPa, annual would go up to ~13 hPa in summer. Matches upstream.

## Derivation math verified (2024-01 test)

| Variable | Our range (Jan 2024) | Upstream annual clim | Match? |
|----------|---------------------|---------------------|--------|
| tmean | -23 to 6°C | -7 to 18°C | Yes (Jan is colder) |
| VPD | 0.2-2.1 hPa | 0.5-13.2 hPa | Yes (Jan is low VPD) |
| RH | 66-94% | 40-87% | Yes (Jan is wetter) |
| soil_moisture | 0.07-0.73 m³/m³ | 0.04-0.65 m³/m³ | Close (resolution diff) |

## Multi-variable requests

CDS accepts multiple variables in one request — got 5 layers (dewpoint + 4 soil) in one GRIB. Efficient for batching.

## GRIB metadata lies

GRIB says units are "C" for temperature but values are in Kelvin. Always convert regardless of metadata.
