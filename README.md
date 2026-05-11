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
the staging layer and site reference table require no changes. Planned
additions include fish transect data and additional algae species.

### Fish transect pipeline
A parallel pipeline for RCCA fish transect data (~1.5M rows) is planned
using the same BigQuery + dbt architecture. The `int_survey_sites` model
will serve as a shared site reference across both pipelines.

### Regional expansion
Current data covers California survey sites only. Reef Check operates
monitoring programs in Oregon and Washington with comparable transect
methodology. Expanding the pipeline to include Pacific Northwest data
would require only new source tables and staging models — the
intermediate and mart layer logic is transferable with minimal
modification. A unified Pacific Coast view would enable longitudinal
analysis of algae distributions across a fuller extent of their
North American range.

## Retired Components

### int_giant_kelp_absences_CA

Built to support a Tableau visualization distinguishing surveyed-but-absent
sites from unsurveyed sites. Logic performs a left join from all surveyed
transects against confirmed Giant Kelp presence records, returning unmatched
rows as explicit zero-stipe records (2018–2025 only; pre-2018 excluded due
to zero-population recording convention artifacts).

The visualization was retired after the absence layer revealed inconsistent
survey frequency across sites — gaps that appeared to show population
disappearance were more likely the result of irregular survey coverage than
true absence. The model logic is sound; the underlying data lacks the
temporal consistency required to make absence records analytically meaningful
at the site+year level.

Model and corresponding BigQuery table are preserved for methodology reference.
The mart_giant_kelp_CA_site_year union logic and is_absence_record flag remain
in place but the absence-driven outputs are not currently used in any
visualization.
