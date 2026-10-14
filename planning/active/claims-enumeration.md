# Claims enumeration — vignettes/northern-bc.Rmd (#137, code-check round 2)

Mechanism found by rounds 1–2: the vignette's sentences and the data script's `claims` block are two hand-kept lists, which agreed only where someone had thought to write both. To end the loop by enumeration rather than by a quiet round, I split every sentence of the rendered article (`docs/articles/northern-bc.html`, 48 sentences plus the scorecard and figure subtitles; script in progress.md) and mapped each to what backs it. Kinds: **claim** = a named check in `data-raw/northern_bc_vignette_data.R` that stops the regen; **stopifnot** = an assertion earlier in that script; **inline** = the number is computed from the rds at render; **static** = geography or definition that no regen changes; **cited** = sourced to a reference checked in `review-references.md`.

| # | Sentence (short) | Backed by |
|---|---|---|
| 1 | two run to the Pacific, one to the Arctic | static (`aoi$drains_to`) |
| 2 | compares last 10 / last 3 with 1951–1980 | inline windows |
| 3 | clearly warmer / less snow / melts sooner / summers thirstier | claims warmer_both, smaller_snowpack, melt_earlier, drier_summer_air, drier_summer_soil |
| 4 | total moved little over ten years; last three drier | claims prcp_moved_little, last3_drier |
| 5–6 | ten years vs three; each year shown | definitional |
| 7–8 | map caption | static |
| scorecard caption | warmer, smaller snowpack sooner, drier summer air and soil; total moved little, last three drier | the same claims as 3–4; tint rule definitional |
| 9 | almost every recent year warmer than normal | claim every_recent_year_warm (≥ 9 of 10) |
| 9 | warmer than any 1951–1980 year "is now common": 7 / 5 / 4 | claim warmer_than_any_common (≥ 3 each); numbers inline |
| 10–11 | bar and dashed-line definitions | definitional |
| 12 heading | every season warmer; last three summers drier on average | claims every_season_warmer, spring_summer_drier_last3 (average; heading now says "on average": PARS 2023 summer was +6 %) |
| 12 | last 3 yr: winters warmed most, were wetter; springs and summers drier | claims winter_warmed_most_last3, winter_wetter_last3, spring_summer_drier_last3 |
| 13–15 | marker and winter definitions | definitional |
| 16 | peak snowpack smaller; melts 9 to 13 days sooner | claims smaller_snowpack, melt_earlier; range inline |
| 16 | so the spring rise comes earlier … | cited in the watershed-health table (Stewart 2005, Kang 2016) |
| 17–19 | panel and marker definitions | definitional |
| 20 | no recent year below the smallest normal snowpack | stopifnot (snow_low) |
| 21 | upper starts with far less snow; both warmed about the same | claim bulkley_far_less_snow_upstream (< 75 %); stopifnot \|Δ tmean\| < 0.2 °C |
| 22–25 | panel, grid size, split definitions | definitional / static |
| 26 | 758 vs 1,055 mm; 55 % as deep | inline; stopifnot upper < lower |
| 27 | warmed by 1.9 and 2.0 °C; both lost about the same share (9 %, 8 %) | inline; claims bulkley_both_warmed, bulkley_both_lost_snow; stopifnot \|Δ\| < 3 points |
| 28 | summer rain fell further upstream, 25 % vs 14 % less | inline, with "further"/"less" chosen at render; claim bulkley_summer_rain_less |
| 29 | same warming and same loss of snow on a drier upper watershed | stopifnot (tmean, swe share, prcp and swe normals) |
| 30–31 | framing | definitional |
| 32–40 | watershed-health table and dryness paragraph | cited (`review-references.md`); row labels backed by claims melt_earlier, smaller_snowpack, every_season_warmer, drier_summer_air, drier_summer_soil |
| 41–43 | next steps, wet | static |
| 44–47 | data source, grid size, baseline caveat, windows, regional vignettes use 2015–2025 | static; windows inline; 2015–2025 is `cd_compare()`'s fixed default (#139) |
| figures | temperature-change map scale | limits now extend to the raster's maximum, so no cell is censored |

Result: every data-dependent sentence maps to a claim, an assertion or an inline value. The one gap the enumeration found (the summers heading) is fixed in the same commit.
