## Outcome

Rewrote cd's README to soul's `readme.md` convention at the user's direction (simple, plain language, a figure from committed code): a plain opening naming what cd measures and what restoration decision it informs, with daily point temperatures and any-series baselines as one clause each; a figure of the Kootenay Lake watershed group's annual temperature departure from a 1951–1980 baseline, built by `data-raw/readme_figure.R`; one example whose code is that script's marked block and whose output is pasted from the same run. The function table (with the internal `cd_stac_item()`), roadmap, caching section and data inventory came out; the VPD fix stays in NEWS. DESCRIPTION Title/Description, the README tagline and the GitHub About now say the same thing; the citation workflow passes `authors_roles` so New Graph Environment Ltd. becomes a CITATION.cff author; `_pkgdown.yml` groups the reference index in seven sections. Writing attribution for the ERA5-Land data the package ships produced `NOTICE.md`, and reviewing it surfaced bundled data with unconfirmed licences (#151). Learned: a per-file licence list kept failing review because a glob or category stood in for its members (rounds 1–3 each found one inside the previous fix); listing by source, with the unresolved ones pointed at an issue, ended it on an enumeration of the 7 external sources `data-raw/` reads.

## Measurement

README 962 → 626 words (`wc -w`, including the example's code and output). No forecast was set; the floor is the convention's fixed sections. Example result: Kootenay Lake (KOTL) annual mean temperature trend 0.025 °C/yr over 75 years (1951–2025), total change 1.9 °C. Review: plan review + 3 code-check rounds, 1 + 5 + 1 + 2 findings; filed #150 (anomaly axis label) and #151 (bundled data licences).

## Evidence

`planning/archive/2026-10-issue-142-*/review-*.md`

Closed by: PR (see branch `142-readme-add-daily-point-temperatures-and`)
