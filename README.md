# Reef Check Kelp — dbt Pipeline

## Overview
ELT pipeline for Reef Check California (RCCA) kelp transect data.
Transforms raw survey data into site-level Giant Kelp population metrics
for visualization in Tableau.

**Stack**: BigQuery · dbt Core · Git

**Data source**: Reef Check California data request, February 2026.
Data spans 2006–2025. See [data.reefcheck.org](https://data.reefcheck.org)
for terms of use.

Raw data and mart tables reside in BigQuery; this repository contains the dbt transformation logic, model definitions, and schema documentation only. Mart tables are the designated handoff point for downstream visualization.


## Pipeline Structure

### Algae Biodiversity — West Coast (new)

```
raw.algae_CA_2025
raw.algae_OR_2025
raw.algae_WA_2025
    └── stg_algae_west_coast_2025 (view)
           ├── int_algae_abundance_normalized_2025 (view)
           │       └── int_algae_shannon_2025 (view)
           │               └── mart_algae_biodiversity_west_coast_2025 (table)
           └── int_survey_sites_west_coast (view)
                    └── mart_algae_biodiversity_west_coast_2025 (table)
```


### Giant Kelp — California (existing)

```
raw.algae_CA_2025
    └── stg_algae_CA_2025 (view)
            ├── int_giant_kelp_CA_2025 (view)
            │       └── mart_giant_kelp_CA_site_year (table)
            ├── int_giant_kelp_absences_CA (view)
            │       └── mart_giant_kelp_CA_site_year (table)
            └── int_survey_sites (view)
                    └── mart_giant_kelp_CA_site_year (table)
```

## Models

### Algae Biodiversity — West Coast

**Staging** — `stg_algae_west_coast_2025`
Unions CA, OR, and WA raw algae tables. Filters to 2025 survey year. Adds `state` column.
Derives `species` from `classcode`, collapsing Southern Sea Palm size bins
(`<30cm` and `>30cm`) into a single species entry. Adds `is_canopy_kelp` flag
(Giant Kelp, Feather Boa Kelp) and `is_no_blade_kelp` flag for downstream exclusion logic.
One row per organism observation per transect.

Note: Invasive species (Sargassum muticum, Sargassum horneri, Undaria, Caulerpa) are not
tracked as classcodes in the raw algae tables and do not appear in this pipeline. Invasive
presence data was unavailable in this data delivery.

**Intermediate** — `int_algae_abundance_normalized_2025`
Normalizes abundance across species using the appropriate proxy per species type:
canopy kelp (Giant Kelp, Feather Boa Kelp) uses SUM(stipes) as abundance proxy;
all other species use SUM(amount). No Blade Kelp excluded — no taxonomic resolution.
Output: one normalized_amount per site per species, zero rows excluded.

**Intermediate** — `int_survey_sites_west_coast`
Distinct site reference table for all three states with averaged coordinates.
Anchors the mart to the full 2025 survey site list, including sites where no
indicator species were recorded. Supersedes `int_survey_sites` for the west coast pipeline.

**Intermediate** — `int_algae_shannon_2025`
Calculates Shannon Index H' per site using window functions and LN() in BigQuery SQL.
H' = -SUM(p * LN(p)) where p = each species' proportion of total site abundance.
Also calculates species_richness as count of distinct species per site.

**Mart** — `mart_algae_biodiversity_west_coast_2025`
Joins Shannon Index and species richness to site coordinates from
`int_survey_sites_west_coast`. All 172 surveyed sites included. Sites with no recorded
indicator species return shannon_index = 0 and species_richness = 0 via COALESCE.
Adds `ca_region` for California sites using the Reef Check 3-region statewide framework.
One row per site. Primary data source for West Coast Biodiversity Tableau dashboard.

### Giant Kelp — California

**Staging** — `stg_algae_CA_2025`
Renames columns, casts types, and adds `is_presence_record` and `is_subsampled`
flags. All species retained for future expansion. One row per organism observation
per transect.

**Intermediate** — `int_giant_kelp_CA_2025`
Filters to Giant Kelp presence records only (`is_presence_record = true`).
Aggregates stipe counts and calculates density metrics per transect per survey date,
including raw stipe totals, stipes per meter, and extrapolated full-transect equivalents.

**Intermediate** — `int_giant_kelp_absences_CA`
Identifies post-2018 site+transect+date combinations where a survey was conducted
but no Giant Kelp presence records exist in `int_giant_kelp_CA_2025`. Created to
solve a visualization problem: without explicit absence records, surveyed-but-absent
sites are indistinguishable from unsurveyed sites in Tableau. Logic performs a left
join from all surveyed transects (`stg_algae_CA_2025`) against confirmed Giant Kelp
transects (`int_giant_kelp_CA_2025`), returning only the unmatched rows as zero-stipe
records. Limited to 2018–2025 because pre-2018 zero-population rows cannot reliably
distinguish true absence from recording convention artifacts.

**Intermediate** — `int_survey_sites`
Distinct site reference table with averaged coordinates and survey history. Coordinates
are averaged across all surveys to smooth minor GPS drift. Reusable across all future
species models without modification.

**Mart** — `mart_giant_kelp_CA_site_year`
Unions presence records from `int_giant_kelp_CA_2025` and absence records from
`int_giant_kelp_absences_CA`, then joins to `int_survey_sites` for enriched coordinates.
Produces one row per site per survey year. The `is_absence_record` boolean flag
distinguishes surveyed-but-absent sites (true, 2018–2025 only) from sites with confirmed
Giant Kelp presence (false, 2006–2025). Primary data source for Tableau dashboard.


## Shannon Index

Shannon Index H' measures species diversity within a sampled community. It does not
require a complete species inventory — it measures diversity within whatever community
is being sampled. Reef Check's protocol tracks ecologically significant canopy and
understory indicator species using consistent methodology across all sites, making
cross-site Shannon comparison valid.

Shannon Index H' calculated from Reef Check kelp forest monitoring indicator species.
Reflects relative algal diversity among ecologically significant canopy and understory
species. Does not represent total site biodiversity.

**Typical ranges in marine ecosystems:**
- Below 1.0 — low diversity, community dominated by one or two species
- 1.0–2.0 — moderate diversity, reasonable evenness among a limited set of species
- 2.0–3.0 — good diversity, more species with relatively even distribution
- Above 3.0 — high diversity, rare in kelp forest contexts given the indicator species constraint

**For this dataset:** with 4–13 indicator species per site across the west coast survey,
most values fall between 0.5 and 1.8. Values above 1.5 represent notably diverse
and even communities. Species richness and Shannon Index should be read together —
H' alone without richness context is misleading due to the theoretical ceiling effect
(maximum H' = LN(species_richness)).

**Note on zero values:** Sites returning H' = 0 fall into two categories: sites where
only one species was recorded (mathematically valid zero), and sites where no indicator
species were recorded at all (species_richness = 0). Both are ecologically meaningful
and are retained in the mart. Zero or near-zero values in Northern California are
consistent with documented urchin barren conditions following sea star wasting disease
and subsequent urchin population expansion.


## California Regions

California sites are assigned to one of three regions using the Reef Check statewide
reporting framework, which consolidates the California Marine Life Protection Act (MLPA)
Study Regions for macro-level analysis and long-term reporting.

| Region | Boundary | Approximate Latitude |
|---|---|---|
| Northern | Oregon Border to Golden Gate | Above 37.83°N |
| Central | Golden Gate to Point Conception | 34.45°N – 37.83°N |
| Southern | Point Conception to US-Mexico Border | Below 34.45°N |

Regions are assigned in the mart layer via CASE statement on site latitude. The Golden
Gate (~37.83°N) is used as the Northern/Central break per the Reef Check statewide
framework. Note: the MLPA 4-region baseline framework uses Pigeon Point (~37.18°N)
as this boundary instead — the two frameworks are not interchangeable. Oregon and
Washington sites return NULL for ca_region.


## Data Provenance
Raw data received as CSV via Reef Check California data request.
Original collection method: volunteer diver transects recorded on
waterproof datasheets, photographed, and hand-entered into Google Sheets.

Pre-2018 data is zero-populated — absent species appear as rows with
Amount = 0. Post-2018 data is not zero-populated. NA values in source
file are stored as NULL in BigQuery (applied at load time via null marker).


## Known Data Quality Issues

### Null distance_surveyed_m values
10 rows in `raw.algae_CA_2025` contain null values in the `Distance` field.
All 10 are zero-population placeholder rows (Amount = 0) from pre-2018
surveys at Cathedral Cove, Mendocino Headlands, and Paradise Point
(2006–2010). These rows are excluded from all Giant Kelp aggregations
by the `is_presence_record` filter and have no impact on pipeline output.
Documented as a warning-level test in `models/staging/schema.yml`.

### Invasive species data unavailable
Invasive algae (Sargassum muticum, Sargassum horneri, Undaria pinnatifida, Caulerpa spp.)
are tracked by Reef Check in a separate invasives file not included in this data delivery.
Horn Weed and Wire Weed appear as standard classcode entries in CA and WA raw tables and
are included in Shannon calculations as community members. Their ecological status as
invasives is noted but presence/absence tracking is outside the scope of this pipeline.


## Running the Pipeline
```bash
dbt run        # run all models
dbt test       # run all tests
dbt docs generate && dbt docs serve  # view lineage graph
```

## Future Enhancements

### Automated pipeline updates
Currently the pipeline requires a manual `dbt run` after new data is loaded.
Full automation is planned using Google Cloud Storage as a landing zone for
new CSV uploads, with a Cloud Run job triggering `dbt run` automatically when
new data arrives. This would allow collaborators to upload new survey data
directly to a GCS bucket and have the mart update without any manual
intervention.

### Multi-species expansion
The staging model retains all species observed in RCCA surveys. Adding new
species to the pipeline requires only a new intermediate model and mart —
the staging layer and site reference table require no changes.

### Fish transect pipeline
A parallel pipeline for RCCA fish transect data (~1.5M rows) is planned
using the same BigQuery + dbt architecture. The `int_survey_sites` model
will serve as a shared site reference across both pipelines.

### Regional expansion
Current data covers exististing sites in California, Oregon, and Washington. 
Expanding the pipeline to include future sites would require only new 
source tables and staging models — the intermediate and mart layer logic is 
transferable with minimal modification.

## Retired Components

### int_survey_sites
CA-only site reference table. Superseded by `int_survey_sites_west_coast` for the
west coast biodiversity pipeline. Retained in the CA Giant Kelp pipeline without modification.

### int_giant_kelp_absences_CA
Built to support a Tableau visualization distinguishing surveyed-but-absent sites from
unsurveyed sites. Logic performs a left join from all surveyed transects against confirmed
Giant Kelp presence records, returning unmatched rows as explicit zero-stipe records
(2018–2025 only; pre-2018 excluded due to zero-population recording convention artifacts).

The visualization was retired after the absence layer revealed inconsistent survey frequency
across sites — gaps that appeared to show population disappearance were more likely the
result of irregular survey coverage than true absence. The model logic is sound; the
underlying data lacks the temporal consistency required to make absence records analytically
meaningful at the site+year level.

Model and corresponding BigQuery view are preserved for methodology reference.
