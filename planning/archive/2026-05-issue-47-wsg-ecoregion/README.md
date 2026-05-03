# Archive: WSG x ecoregion overlap (#47)

## Outcome

Added a "Watershed Groups Across Ecoregions" section to the
`peace-fwcp` vignette: a labelled WSG map over ecoregion fills,
plus a per-WSG x ecoregion area-share table that lets readers
map per-ecoregion climate-departure findings (precipitation up
only in BMP and NRM) onto the watershed-group reporting unit
that FWCP funds work in. Released as **v0.1.5** (patch).

Bundled the canonical 16-WSG list in
`data-raw/example_context_fwcp_peace.R` so the boundary set is
reusable across the three reporting climate-departure appendices
and aligns with the shared GIS project. Drops UPCE (only 11.8%
inside FWCP, drains east) and MURR (1% sliver) from the previous
18-WSG intersection result.

Folded in two cleanups while the vignette was open: Recent vs
Pre-warming consolidated to a single table (was two near-redundant
tables), and all six tables now render with single clean bookdown
captions via the `label = NA` + `caption = "..."` kable pattern.

## Key findings worth remembering

- **kable + kable_styling double caption**: `tab.cap` chunk option
  silently drops captions when the table is wrapped in
  `kable_styling()` + `scroll_box()`. The working pattern is
  `knitr::kable(df, label = NA, caption = "...")` on the inner
  call. Saved to feedback memory.
- **WSG canonical list** (CARP, CRKD, FINA, FINL, FIRE, FOXR, INGR,
  LOMI, MESI, NATR, OSPK, PARA, PARS, PCEA, TOOD, UOMI). Each is
  >=99% inside the FWCP polygon. Hardcode this in any future
  generator that needs the FWCP Peace boundary set.
- **No % change for tmax/tmin/tmean/vpd**: absolute degC / hPa
  shifts are the meaningful unit, not pct. Only prcp and soil
  moisture get pct_normal anomaly framing.
- The vignette is the template for the three reporting
  climate-departure appendices and ports directly to
  `fish_passage_peace_reporting_2025`.

## Closing ref

- Issue: NewGraphEnvironment/cd#47
- PR: NewGraphEnvironment/cd#51 (merged 2026-05-02, squash 51aa556)
