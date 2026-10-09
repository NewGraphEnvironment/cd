## Outcome

The daily air-temperature cube and every monthly layer stopped at 59.95 N and 139.95 W because EDH's coordinates are not exact multiples of 0.1: latitude 60.00000000000142 and longitude 219.9999999999918 fall just outside a slice ending on 60.0 / 220.0. So the 60.0 N row and the −140.0 column had been missing since the EDH migration (#36). That surfaced as wet#40's border station 10DA001 being rejected by a message whose stated extent said it should have worked. The fix is one `bc_slice()` in `scripts/_lib.py`, padded half a cell and shared by all backfillers. Guards now refuse any other grid before a fetch (`bc_grid_check()`), on disk (`bc_file_check()` / `bc_files_check()`, including the skip paths) and before a publish (`grid_problems()` in `scripts/_lib.R`, stage 3 and STEP 5). Both products were rebuilt on 121 × 261 and republished. Separately, `cd_extract_daily()` now gives a point outside the cube NA rows and a warning stating the cube's own extent, instead of aborting the call for every point. The plan gate chose the full rebuild (daily + all 59) and an in-run publish with no backup. Hashing went to #124.

Code-check took four rounds on the producer diff, and each round found something real. Round 1 found that snowfall_fraction joins the hourly and daily stores on labels. Round 3 found that a guard failure inside `process_year()` was swallowed by the per-year `except`, exited 0, and would have shown in CI as a green run blamed on EDH latency; the fix made both backfillers exit 1 on a failed year. Round 4 enumerated all 18 guard sites through to the CI outcome and found an older form of the same gap: `any_fetch_errored` was read only when no year wrote, and `finish()` now reads it. The R diff took three Clean rounds; round 3 enumerated every consumer of the old abort.

## Measurement

- Root cause: coordinate probe on both live stores (hourly, `era5-land-daily-utc-v1`), identical drifted values. The exact slice gives 120 × 260; the padded slice gives 121 × 261.
- Rebuild wall time:
  - daily: 3 h 10 m (111–207 s per year)
  - snow: 7 h 21 m
  - core monthly: 9 h 55 m (~430 s per year while snow ran, ~265 s after)
  - all concurrent, 2026-10-08
  - Five transient EDH errors (502 ×3, ClientPayloadError ×3 counting 2001's two attempts), all recovered by `with_retry`.
- Identity check on the old 120 × 260 block, taken by index (`[:, 1:, 1:]`): all **228/228 daily files** and **152/152 monthly tmax/tmin** are bit-identical, and **56 of 59 COGs** are bit-identical in every band. The other three, `prcp_annual`, `prcp_winter` and `snowfall_fraction`, differ only in band 2025: prcp mean 773.24 → 774.20 mm, max 71 mm. The differences go both ways and correlate with January (r = 0.67). Spring, summer and fall are identical, and hourly-derived snowfall is identical. So the daily store's 2025 `tp` changed upstream after the live band was built on 2026-04-12. That is an inference: no revision log was found.
- Live read-back, uncached, from a fresh process: 59 COGs and 228 daily files all 121 × 261; catalog bbox `[-140.05, 47.95, -113.95, 60.05]`. 10DA001 is in cell 171, centred on (−123, 60), and non-NA. CI dry run: success.
- Reviewer spend: 1 plan review + 4 + 3 code-check rounds = 8 agents. That is over the usual ~5, and justified by three real defects in rounds 1, 3 and 4.
- Durable fact: [`research/edh_era5_land_store.md`](../../../research/edh_era5_land_store.md), section "Coordinates are not exact multiples of 0.1".

## Evidence

`logs/*_123_2026100*` (local, gitignored; the numbers above are copied into `findings.md`). Comparison scripts and the probe ran from the session scratchpad. `data/backfill/_grid_120x260/` holds the old daily files, the old monthly tmax/tmin and the 59 old live COGs.

Closed by: PR for #123
