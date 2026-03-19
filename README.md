# Reef Check Kelp — dbt Pipeline

## Overview
ELT pipeline for Reef Check California (RCCA) kelp transect data.
Transforms raw survey data into site-level Giant Kelp population metrics
for visualization in Tableau. Received from kelpdata@reefcheck.org.

**Stack**: BigQuery · dbt Core · Git

**Data source**: Reef Check California data request, February 2026.
Data spans 2006–2025. See [data.reefcheck.org](https://data.reefcheck.org)
for terms of use.

## Pipeline Structure
```
raw.algae_CA_2025
    └── stg_algae_CA_2025 (view)
            ├── int_giant_kelp_CA_2025 (view)
            │       └── mart_giant_kelp_CA_site_year (table)
            └── int_survey_sites (view)
                    └── mart_giant_kelp_CA_site_year (table)
```

## Models

**Staging** — `stg_algae_CA_2025`
Renames columns, casts types, adds `is_presence_record` and `is_subsampled`
flags. All species retained for future expansion.

**Intermediate** — `int_giant_kelp_CA_2025`
Filters to Giant Kelp presence records only. Aggregates stipe counts and
calculates density metrics per transect per survey date.

**Intermediate** — `int_survey_sites`
Distinct site reference table with averaged coordinates and survey history.
Reusable across future species models.

**Mart** — `mart_giant_kelp_CA_site_year`
Final aggregated table by site and year. Primary Tableau data source.

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