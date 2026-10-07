# Plan review (#89) — Plan agent, 2026-10-07

Read-only agent; findings relayed here by the parent session. Disposition in brackets.

- **B1** `written[[x]] <- …` inside `append_to_cog()` modifies a local copy, so every healthy run would abort. [Real for the plan text; the draft used `<<-`. Changed to a return value assigned at the call sites.]
- **G1** `cd_s3_push()` syncs `--size-only`; a healthy update changes `catalog.json` only by `2025-12-31` -> `2026-12-31`, same byte length, so the new catalog is never uploaded. [Real. Upload `catalog.json` explicitly with `aws s3 cp` after the COG sync, in both pipelines.]
- **G2** stale-file check must be in the helper and in stage 3. [Already: `on_disk` argument.]
- **G3** readback should check the artifact's years, duplicates, `unknown` period. [Adopted: `catalog_problems()` reads keys + start/end years from the written JSON.]
- **G4** non-year band names. [Covered: `anyNA()` branch, `lyr1` test.]
- **O1** check live keys against the expected 59 in STEP 1, before the fetch and before the dry-run exit. [Adopted.]
- **O2** delete the built `catalog.json` when the readback fails. [Adopted.]
- **A1** integer/double years. [Helper coerces with `as.integer()`; spans come from `as.integer()` of names.]
- **A2** `expected` carries `.tif`, `live_keys` does not. [Helper normalises; tests use the script's forms.]
- **A3** STEP 1 reads `tmean_annual` alone, so a partial sync is never repaired. [Real, out of scope; follow-up issue.]
- **A4** stage 3 becomes stricter, not unchanged. [Say so in PR/NEWS.]
- **S1** "written but not expected" is unreachable in both scripts. [Kept for helper completeness.]
- **S3** STEP 4 lacks stage 3's tmax/tmin `units=degC` check. [Out of scope; CI runner starts empty.]
- **AC2** today's dry-run exits at the local-year cap, so it proves STEP 0-1 only. [Noted in Verification.]
- Live catalog checked: exactly 59 items, 1950-2025, DJF bands named like annual.
