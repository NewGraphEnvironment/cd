# Plan review — #119 (Plan agent, 2026-10-07)

Ran concurrently; it reviewed the code as committed through `1fb926e`. Verdict: no
Blockers. Every bad combination it built (ahead year not fetched, a COG two years
ahead with one fetched, tmean lagging with 58 ahead, the ahead year's fetch failing
while a later one succeeds) was refused before publish. The weak spots are wasted
hours, misleading messages, unbounded network waits, and one proxy check.

Triage, after probing each claim:

| id | finding | decision |
|---|---|---|
| G1 | the 59 `/vsicurl/` reads have no total timeout or retry; a transient 503 gets the stage-3 hint | **fix**: GDAL HTTP timeout/retry + `GDAL_DISABLE_READDIR_ON_OPEN=EMPTY_DIR`; an unreadable COG gets a re-run hint, not stage 3 |
| G2 | `partial_live` is cleared on the catalog read-back, a proxy for the COGs being in step | **fix**: re-read the 59 band names after the push (with `CPL_VSIL_CURL_NON_CACHED`, as `tmax_tmin_republish.R:276` does); clear only when nothing is ahead and `common` = `required_years` |
| G3 | nothing checks after STEP 3 that the ahead years were fetched; the "latency is normal" message is misleading in a partial state | **fix**: an ahead year missing from `new_years_written` → `finish(1L)` before STEP 4 |
| G4 | stage 3 still reads `tmean_annual` alone (`pipeline_stage3_edh.R:198-204`, confirmed) | **follow-up issue**: stage 3 is the manual fallback and either refuses or publishes a span no wider than the catalog's; out of this plan's file list |
| G5 | `catalog_repair_hint()` rebuilds the catalog from live COGs, which gives a mixed catalog if they are out of step | **fix (minimum)**: the hint says it applies only when every COG ends in the same year |
| O1 | the unfetched-ahead check sits after STEP 2's early exits, so the cap-empties case reads "Nothing to do" then "out of step" | **fix**: move it before the empty-candidates exit |
| O2 | phases 2 and 3 must ship together | already so: one PR |
| A1 | a held year is kept, not recomputed; a method change between runs would mix methods within year N | **fix**: compare the held band with the freshly computed layer, refuse on mismatch |
| A2 | an unchanged rewrite through `cd_cog_write()` re-encodes; `snowmelt_doy_50_annual` is Float64 | **fix**: fetch the unchanged COG byte-for-byte instead of rewriting it |
| A3 | STEP 1 reads `cog_base/<name>`, STEP 4 the catalog href, with only a comment saying they agree | **fix**: STEP 4 reads `cog_base` too |
| A4 | one shared start year relies on DJF winter being named for its January year | **fix**: comment by the start check |
| S1 | `climate-update.yml` has no `concurrency:` key (confirmed, L116); a dispatch during a live STEP 5 would now see a partial state | **fix**: workflow-level `concurrency` group, `cancel-in-progress: false` |
| AC1 | the append filter is inline, so `test_lib.R` cannot reach it; "interop must have used a copy" | **partly wrong**: the interop run lifts `append_to_cog()` from the script by `parse()`, recorded in findings.md. No extraction |
| AC2 | `publish_problems()` cases for the repair shape | **add** |
| AC3 | the partial path's control flow (`finish()` × `dry_run`, the exits) is untested | **fix**: dry run of a copy of the script pointed at a local fixture bucket, no production knob |
| AC4 | `scripts/test_lib.R` runs in no workflow | **note** in the PR; out of scope |
| docs | header "exits 0 if nothing new" no longer true; CLAUDE.md L25 target sentence; "This run appends" printed on a dry run; `publish_problems()` `required_years` doc | **fix** |
