## Outcome

Monthly `tmax`/`tmin` now average **local days** at a fixed UTC−8, the same days as the daily cube (#116), instead of UTC days.
- **CI path.** `backfill_edh_all.py` computes new years through `local_daily()` → `monthly_from_daily()`, gated on the local year being complete. `pipeline_update_edh.R` caps STEP 2 at the latest complete local year, so all 15 variables now publish together about one month later than before. It also refuses to append until the live tmax/tmin history is confirmed local-day.
- **History.** `backfill_edh_tmax_tmin.py` rebuilds 1950-2025 from the cube on disk (no EDH fetch, about 40 s). For 2002 it agrees with the EDH path to 1.3e-5 °C.
- **Publish.** `scripts/tmax_tmin_republish.R` replaces the 10 live COGs and backs up the UTC-day originals. It is **left for merge time**, so this archive's live-publish checkbox is deliberately open.

The main lesson: **#37's premise had the direction backwards.** UTC days bias tmax **high**, not low:
- A UTC day runs 16:00-16:00 PST, from one afternoon peak to the next, so a hot afternoon counts toward two days.
- A local midnight day holds two partial nights, so local-day tmin is the lower of the two.

The dry run measured this before anything was published. An EDH probe then reproduced the live values exactly under UTC days, which proved the gap is entirely the day boundary.

Local days were kept for tmin too, decided 2026-10-06. The alternative, tmin on UTC days, would have been physically cleaner (one night per day) but inconsistent with the cube and with station days.

The plan review (`review-plan.md`) independently found the same sign. It also moved the publish from before the PR to merge time.

Four code-check rounds (`review-round1..4.md`) hardened every guard on the irreversible writes; bucket versioning is suspended. Rounds 2 and 3 each found a defect inside the previous round's fix, so the loop ran past three rounds. Round 3 named the mechanism: guards checked a stand-in, not the live target at the moment of the write. Round 4 ended the loop by re-walking a 33-row enumeration.

## Measurement

Local minus UTC, BC mean of each year's band, 1950-2025 (`republish_diff_summary.csv`):

| | annual | winter | spring | summer | fall |
|---|---|---|---|---|---|
| tmax °C | −0.64 | −0.51 | −0.63 | −0.77 | −0.65 |
| tmin °C | −0.31 | −0.42 | −0.27 | −0.15 | −0.40 |

- **Diurnal peak.** BC's July mean peak is at 23-00 UTC and its minimum at 13 UTC (EDH hourly, Prince George and Kamloops, 2002).
- **Provenance of the old values.** Live UTC values reproduce exactly: Prince George 2002 annual tmax 9.182 °C, Kamloops 11.846 °C. Local days give 8.466 and 11.119.
- **Effect on regional trends.** Small, because the bias is nearly constant through time. Two 45-year (1981-) results cross a threshold:
  - Peace tmax p goes from 0.045 to 0.056.
  - Kootenay's tmax slope drops below tmin (0.0301 vs 0.0319 °C/yr).

  Both appear only in live-rendered figures; every hard-coded vignette claim still holds.
- **Wrong turn kept.** The plan expected "tmax up, tmin down, largest in summer", inherited from the issue. The dry run said both go down. It was checked before any publish rather than explained away.

The durable verdict is in `research/tmax_tmin_day_boundary.md`; the full narrative is in `findings.md`.

## Evidence

- `republish_diff_summary.csv` in this directory: per-COG shifts from `tmax_tmin_republish.R --dry-run`.
- Local, uncommitted: `data/backfill/republish_37/` (`local_day/` built COGs, `utc_day_backup/` live originals).

Closed by: PR (opened from branch `37-tmax-tmin-daily-aggregation-uses-utc-day`)
