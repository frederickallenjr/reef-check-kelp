-- int_survey_sites_west_coast.sql
-- Site reference table for all west coast states: CA, OR, WA
-- Anchors mart to full 2025 survey site list including sites with no recorded algae
-- Coordinates averaged across transects per site -- source GPS points to site centroid
-- Replaces int_survey_sites which covers CA only (retained for reference)

select
    site_name,
    state,
    avg(latitude)                                       as latitude,
    avg(longitude)                                      as longitude
from {{ ref('stg_algae_west_coast_2025') }}
group by site_name, state

