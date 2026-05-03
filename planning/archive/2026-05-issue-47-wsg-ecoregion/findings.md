# Findings

## Source data

- `inst/extdata/context_fwcp_peace.gpkg` ships:
  - Layer `wsgs`: 18 BC FWA watershed groups intersecting the FWCP region
    (CARP, CRKD, FINA, FINL, FIRE, FOXR, INGR, LOMI, MESI, MURR, NATR,
    OSPK, PARA, PARS, PCEA, TOOD, UOMI, UPCE), already simplified to
    200 m tolerance — full WSG extent (not clipped to AOI).
  - Layer `ecoregions`: 6 BC ecoregions intersecting the FWCP region,
    clipped to the AOI. The PRB (Peace River Basin) sliver is
    <100 km² and gets dropped in the vignette filter.

## Geometry note

WSGs are FULL extent, ecoregions are CLIPPED to the FWCP AOI. So the
intersection percentages will reflect *the part of each WSG that
overlaps the FWCP region's ecoregions*, not necessarily 100% of the
WSG's full area. Some WSGs spill outside the FWCP AOI (which is admin,
not hydrologic). That's fine for the report's purposes — readers care
about the climate signal *within the FWCP region* — but the table
caption should note this so it doesn't surprise anyone.

Two ways to read the percentages:
1. As percent of the WSG-inside-FWCP area (denominator = WSG ∩ AOI)
2. As percent of the full WSG area (denominator = full WSG)

For the climate-departure narrative, option 1 is what the reader
wants: "of this WSG inside the FWCP, X% sits in OMM". Option 2 is
distracting because some WSGs only intersect the FWCP at their margin.
Default to option 1, mention the convention in caption.

## Commentary template rules

- WSG ∩ FWCP fully (>95%) in one ecoregion → "Entirely within
  [ecoregion]"
- WSG split, dominant >60% → "Largely [dom] ([n]%), with [secondary]
  ([m]%)"
- Three or more ecoregions, no clear dominant → "Spans [list]"

Plus a hand-curated overrides slot in the data-raw script for
geographic nuance (axis of split, etc.) — apply only where templated
text is genuinely misleading.

## Decisions

- Compute the matrix in the **vignette directly** (read CSV from
  inst/extdata) rather than precompute and ship in vignette-data — the
  intersection is fast and the CSV is small. CSV is the shipped artifact.
- Generate the CSV via `data-raw/` per the bundled-asset convention.
- Section placement: "Watershed Groups Across Ecoregions" goes
  *between* Per-Ecoregion Variation and Interpretation. Reader gets
  ecoregions story first (the analytical units), then sees how WSGs
  (the reporting units) overlay onto that.
