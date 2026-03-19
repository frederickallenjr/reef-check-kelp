with all_observations as (
    select * from {{ ref('stg_algae_CA_2025') }}
),

sites as (
    select distinct
        site_name,
        round(avg(latitude), 6)     as latitude,
        round(avg(longitude), 6)    as longitude,
        min(survey_year)            as first_survey_year,
        max(survey_year)            as last_survey_year,
        count(distinct survey_year) as years_surveyed
    from all_observations
    group by site_name
)

select * from sites