with transects as (
    select * from {{ ref('int_giant_kelp_CA_2025') }}
),

sites as (
    select * from {{ ref('int_survey_sites') }}
),

by_site_year as (
    select
        t.site_name,
        s.latitude,
        s.longitude,
        t.survey_year,

        count(distinct t.transect_number)               as transects_surveyed,
        count(distinct case when t.is_subsampled = true
              then t.transect_number end)               as transects_subsampled,

        sum(t.total_stipes)                             as total_stipes_site,
        round(avg(t.stipes_per_meter), 4)               as avg_stipes_per_meter,
        round(sum(t.stipes_per_30m_extrapolated), 1)    as total_stipes_extrapolated,

        sum(t.plant_count)                              as total_plants_site,
        round(avg(t.plant_count), 1)                    as avg_plants_per_transect,

        cast(max(cast(t.is_subsampled as int64)) as bool) as any_transects_subsampled,
        min(t.survey_date)                              as earliest_survey_date,
        max(t.survey_date)                              as latest_survey_date

    from transects t
    left join sites s using (site_name)
    group by
        t.site_name, s.latitude, s.longitude, t.survey_year
)

select * from by_site_year