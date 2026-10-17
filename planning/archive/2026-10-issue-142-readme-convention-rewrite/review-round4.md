# Review round 4 — HEAD f6c4a21 (Title / tagline / About, #142)

Reviewed 2026-10-17. Scope: is "How far any BC watershed's climate has shifted from your
chosen baseline" true against the code, and does the new Title break anything mechanical.

## Findings

**[Low]** DESCRIPTION:2, README.md:7 — "any BC watershed" does not hold for a watershed on a
small offshore island. `cd_crop()` (R/cd_crop.R:36) is `terra::crop(snap = "out", mask = TRUE)`
and `cd_extract()` (R/cd_extract.R:77) takes `global(mean, na.rm = TRUE)`; ERA5-Land is
land-only, so 10,835 of the 31,581 cells in the live `tmean_annual` COG are NA. Measured:
a 0.01° polygon inland near Squamish (-123.01, 49.61) returns 1.76 °C for 1950 (sub-cell
inland watersheds are fine, the touched cell counts), while a 0.02° polygon on Triangle
Island (-129.08, 50.86) returns `NaN`, silently, with no warning. Not new to this commit:
the DESCRIPTION `Description` and the README opening already say "any area", so the Title
inherits the same overstatement. Whether a watershed in the Freshwater Atlas sits entirely
on sea cells was not checked. Acceptable as is for a one-line tagline; noted so the
silent `NaN` is a known limit, not a surprise.

## Checked and clean

- `cd_extract()`: takes any `sf`/`sfc`/`SpatVector` polygon, reprojects if the CRS differs
  (R/cd_crop.R:30-35). True for any polygon on land.
- `cd_baseline()`: any `baseline_years` vector; years outside the data warn, not error
  (R/cd_baseline.R:31-40). "your chosen baseline" holds.
- Extent: grid 47.95–60.05 N, 140.05–113.95 W covers all of BC. "climate" = temperature,
  precipitation, humidity (rh, vpd), soil moisture and snow, per `cd_variables()`.
- `read.dcf("DESCRIPTION")` parses; `tools:::.check_package_description()` returns no
  problems; `tools::checkRd("man/cd-package.Rd")` is silent (an apostrophe is not special in Rd).
- `inst/CITATION` evaluates to title "cd: How far any BC watershed's climate has shifted
  from your chosen baseline"; BibTeX output well formed.
- cffr (the workflow's own recipe, written to a scratch path): YAML writes `''` for the
  apostrophe, `yaml::read_yaml()` round-trips it, `cff_validate()` TRUE for both `title`
  and `preferred-citation$title`. The committed CITATION.cff still carries an older title
  ("Climate Departure Analysis…"), which predates this commit and the workflow regenerates
  on the next push to main touching DESCRIPTION.
- pkgdown home (built to a scratch destination): `<title>… • cd</title>` and `og:title`
  carry the new Title, apostrophe intact inside double-quoted attributes.
- GitHub About matches the Title exactly (`gh repo view`).
- No stale copy of the previous Title outside `planning/archive/` and `docs/`.
