# Plan review (Plan agent, read-only; written here by the parent) — 2026-10-16

Reviewed task_plan.md and the in-progress diff against the rds. All plan numbers reproduce; all 12 claims TRUE offline.

## Blocker (false sentences not listed)
1. Seasonal snow table caption carries Peace's −75 % / +37 %; Kootenay −72.9 / +12.1 (spring p 0.158). — already fixed in f89edbc
2. Prose above that table: "four monthly-native snow variables … snow cover" (table shows three; cmp_pct has no snow_cover); "headline numbers above" (Kootenay text states neither — Peace copy). — second half fixed in f89edbc; first half open
3. "1.6 to 1.8 °C warmer … mean, max, min": window Δ 1.654 / 1.557 / 1.664 → 1.6 to 1.7.

Soft: "arriving weeks earlier" (12.6 d); summer snowpack "no longer does" (27 % remains); "no warming hot-spot" / "roughly the same rate" beside a printed 0.23–0.30 °C/dec range (SBF 1.3× PTR); snow-station numbers come from the QA script, not the rds; `per-ecoregion-reshape` comment "already by area_km2 desc on disk" is false (gpkg order TOP, SBF, NCM, PTR; harmless).

## Gap
1. Phase 6 cites a grep list not in findings.md.
2. "Ecoregions under 100 km²" in prose is static and unguarded; `shown_are_ncm_sbf_ptr` passes at 50 and 100 alike.
3. Per-ecoregion tmean window Δ is not in the rds; needs cd_compare on $ts (diff does this).
4. Prcp window range "down between X and Y %" has no claim (trend-slope claims do not cover window Δ).
5. Patch scripts (vignette_data_swe_max_type_patch.R) write the rds without running the claims.
6. Old "cumulative" meant window Δ, while the article defines Total Change as slope × years; Peace's "between +1.7 and +1.9 °C cumulative since 1951" has the same mislabel (window Δ 1.71–1.92 vs slope×75 2.14–2.39) — out of #146's scope.

## Assumption
1. Threshold 50→100 breaks nothing (regex, assignment counts, map subtitle 3 at both, overlap table unfiltered).
2. Inline `r` placement is fine as built; hidden chunks precede first use.
3. Omitting `[ecoregions$code]` would include TOP silently (its values sit inside every range).
4. fp() = signif(p, 1) would print "≈ 0.05" for p 0.046–0.049 beside "significant".
5. WSG sentence: static names + claim (fine).

## Ordering / Acceptance / Scope
Promote the known false sentences; run the harness once after all claims; perturbations per claim; check caption numbers vs table; no stray "four ecoregions"; static true numbers stay static (record as deliberate); optional note that TOP appears only in the overlap table.
