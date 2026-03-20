with all_transects as (
    select distinct
        site_name,
        latitude,
        longitude,
        survey_year,
        survey_date,
        transect_number,
        depth_ft
    from {{ ref('stg_algae_CA_2025') }}
    where survey_year >= 2018
),

kelp_transects as (
    select distinct
        site_name,
        survey_year,
        survey_date,
        transect_number
    from {{ ref('int_giant_kelp_CA_2025') }}
),

absences as (
    select
        a.site_name,
        a.latitude,
        a.longitude,
        a.survey_year,
        a.survey_date,
        a.transect_number,
        a.depth_ft,
        0                   as plant_count,
        0                   as total_stipes,
        a.depth_ft          as distance_surveyed_m,
        false               as is_subsampled,
        0.0                 as stipes_per_meter,
        0.0                 as stipes_per_30m_extrapolated,
        true                as is_absence_record
    from all_transects a
    left join kelp_transects k
        on  a.site_name       = k.site_name
        and a.survey_year     = k.survey_year
        and a.survey_date     = k.survey_date
        and a.transect_number = k.transect_number
    where k.site_name is null
)

select * from absences