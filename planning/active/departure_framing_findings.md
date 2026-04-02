# Climate Departure Comparison Framing — Literature Findings

Research for cd issue #20. Each claim has a source, location, and verbatim quote.
A review agent can verify every quote by querying the ragnar store at
`data/rag/departure_framing.duckdb` or reading the PDF via Zotero MCP.

---

## 1. Climate departure = year when climate permanently exits historical bounds

**Source:** Mora et al. 2013, item key CPJDEZE6
**Location:** Abstract and Methods
**Verbatim:** "Here we present a new index of the year when the projected mean climate of a given location moves to a state continuously outside the bounds of historical variability under alternative greenhouse gas emissions scenarios. Using 1860 to 2005 as the historical period, this index has a global mean of 2069 (±18 years s.d.) for near-surface air temperature under an emissions stabilization scenario and 2047 (±14 years s.d.) under a 'business-as-usual' scenario."

**Implication for cd_compare():** Mora's framing is binary — inside or outside bounds. Our package needs a more nuanced approach (how much has it shifted, not just whether it has).

---

## 2. Historical reference period length has minimal effect on departure timing

**Source:** Mora et al. 2013, item key CPJDEZE6
**Location:** Sensitivity of the index section
**Verbatim:** "We found that the year in which the climate exceeded the bounds of historical variability changed minimally when using historical time bins ranging from 20 to 140 years"

**Implication for cd_compare():** The choice between a 30-year vs 75-year baseline matters less than you'd think for detecting departure. This supports offering flexible baselines — the conclusions are robust.

---

## 3. Absolute change is computed as recent vs contemporary averages

**Source:** Mora et al. 2013, item key CPJDEZE6
**Location:** Methods
**Verbatim:** "Absolute climate change (Fig. 2c and Extended Data Figs 3c and 4) was calculated by subtracting contemporary averages (1996 to 2005) from future averages (2091 to 2100). Decadal averages were chosen to minimize aliasing by inter-annual variability."

**Implication for cd_compare():** Mora uses decadal averages for the comparison windows to smooth interannual noise. This supports a "recent decade vs historical" framing. The `cd_compare()` function already does this — mean of window_a vs mean of window_b.

---

## 4. Shifting baseline syndrome: each generation accepts degraded state as normal

**Source:** Alleway et al. 2023, item key 3R4A3VTH
**Location:** Introduction
**Verbatim:** "In its original framing, the shifting baseline syndrome describes the ongoing deterioration of fisheries scientists' expectations for the health and productivity of the marine environment. If each new generation of scientists sets their expectations according to their own observations of ecosystem and resource health, this framing can dis[tort understanding]"

**Original concept:** Pauly 1995, item key I9D4ZW68 (PDF extraction poor due to table formatting, but the concept is well-documented in Alleway's review).

**Implication for cd_compare():** This is the strongest argument FOR using a pre-warming baseline (1951-1980) rather than a recent 30-year normal (1991-2020). A 1991-2020 baseline has significant warming already baked in — anomalies against it look smaller, masking cumulative change. The WMO 1991-2020 normal is designed for weather forecasting ("what's normal now?"), not for communicating climate departure ("how much has it shifted?").

---

## 5. Define baseline as a conceptual reference state, not a date

**Source:** Rodrigues et al. 2019, item key L6L6A7Y4
**Location:** Section 2. Defining the baseline
**Verbatim:** "Here, we define the baseline not as a date, but as a conceptual reference state: the population size expected today in the absence of human actions."

**Implication for cd_compare():** For climate departure, the conceptual reference is "climate before significant anthropogenic warming." ERA5-Land goes back to 1950 — the earliest decades (1951-1980) represent this best for our data. A user should be able to set any baseline, but the package should nudge toward a pre-warming reference by default.

---

## 6. Placing baseline in eras with non-analogous conditions creates challenges

**Source:** Rodrigues et al. 2019, item key L6L6A7Y4
**Location:** Section 2. Defining the baseline
**Verbatim:** "given that impacts started millennia ago, this creates two challenges: it places the baseline in eras with non-analogous environmental conditions, meaning that contrast with the baseline reflects not only human impacts but also natural change; and it reduces the likelihood that there will be adequate data on which to base the assessments."

**Implication for cd_compare():** For ERA5-Land (1950-present), the data quality concern is minimal — reanalysis is consistent across the full period. But the "non-analogous conditions" warning is relevant: a 1951-1980 baseline for BC still includes some anthropogenic warming. The package should document this caveat.

---

## 7. ERA5-Land provides consistent reanalysis from 1950 to present

**Source:** Muñoz-Sabater et al. 2021, item key AIR5D4QW
**Location:** Abstract
**Verbatim (from Zotero metadata):** "Framed within the Copernicus Climate Change Service (C3S) of the European Commission, the European Centre for Medium-Range Weather Forecasts (ECMWF) is producing an enhanced global dataset for the land component: ERA5-Land."

**Note:** The full paper documents the 1950-present coverage and 0.1° resolution. This confirms our data source provides 75 years of consistent reanalysis for baseline flexibility.

---

## Summary: Recommended defaults for cd_compare()

Based on the literature:

1. **Default baseline for cd_baseline():** Keep `1981:2010` (WMO convention, comparable to published studies), but document that this baseline includes warming.

2. **Recommended comparison for cd_compare():** No hard default — but the vignette should demonstrate `window_a = (last 10 years)`, `window_b = 1951:1980` as the "pre-warming vs recent" comparison. This communicates cumulative change most effectively.

3. **Why not 1991-2020 as default?** Shifting baseline syndrome (Pauly 1995, Alleway et al. 2023) — a recent baseline masks cumulative change. For communication purposes, an earlier reference reveals the full departure.

4. **Why decadal windows?** Mora et al. 2013 use decadal averages to "minimize aliasing by inter-annual variability." Individual years are noisy. `cd_compare()` already computes means over windows, which is the right approach.

5. **The vignette framing:** "The watershed is ~2°C warmer than it was in the mid-20th century" — compare recent decade mean to 1951-1980 mean. This is the punchline. Then show the trend for context (0.03°C/yr × 70 years = 2°C).

---

## Papers not in our store that would strengthen this

- **WMO-No. 1203 (2017):** WMO Guidelines on the Calculation of Climate Normals. Defines the 30-year normal methodology. Not a journal article — available from WMO website.
- **IPCC AR6 WG1 Chapter 1:** Discusses reference periods (1850-1900 pre-industrial, 1995-2014 recent, 1991-2020 WMO normal). PDF available at ipcc.ch but not yet in Zotero.
- **Hawkins & Sutton 2016:** "Connecting Climate Model Projections of Global Temperature Change with the Real World" — discusses communication of warming levels. Would strengthen the framing argument.
