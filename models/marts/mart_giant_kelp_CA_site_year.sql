with transects as (
    select * from {{ ref('int_giant_kelp_CA_2025') }}
),

absences as (
    select * from {{ ref('int_giant_kelp_absences_CA') }}
),

sites as (
    select * from {{ ref('int_survey_sites') }}
),

presence_by_site_year as (
    select
        site_name,
        survey_year,

        count(distinct transect_number)                     as transects_surveyed,
        count(distinct case when is_subsampled = true
              then transect_number end)                     as transects_subsampled,

        sum(total_stipes)                                   as total_stipes_site,
        round(avg(stipes_per_meter), 4)                     as avg_stipes_per_meter,
        round(sum(stipes_per_30m_extrapolated), 1)          as total_stipes_extrapolated,

        sum(plant_count)                                    as total_plants_site,
        round(avg(plant_count), 1)                          as avg_plants_per_transect,

        cast(max(cast(is_subsampled as int64)) as bool)     as any_transects_subsampled,
        min(survey_date)                                    as earliest_survey_date,
        max(survey_date)                                    as latest_survey_date,

        false                                               as is_absence_record

    from transects
    group by site_name, survey_year
),

absence_by_site_year as (
    select
        site_name,
        survey_year,

        count(distinct transect_number)                     as transects_surveyed,
        0                                                   as transects_subsampled,
        0                                                   as total_stipes_site,
        0.0                                                 as avg_stipes_per_meter,
        0.0                                                 as total_stipes_extrapolated,
        0                                                   as total_plants_site,
        0.0                                                 as avg_plants_per_transect,
        false                                               as any_transects_subsampled,
        min(survey_date)                                    as earliest_survey_date,
        max(survey_date)                                    as latest_survey_date,

        true                                                as is_absence_record

    from absences
    group by site_name, survey_year
),

combined as (
    select * from presence_by_site_year
    union all
    select * from absence_by_site_year
),

final as (
    select
        c.site_name,
        s.latitude,
        s.longitude,
        c.survey_year,
        c.transects_surveyed,
        c.transects_subsampled,
        c.total_stipes_site,
        c.avg_stipes_per_meter,
        c.total_stipes_extrapolated,
        c.total_plants_site,
        c.avg_plants_per_transect,
        c.any_transects_subsampled,
        c.earliest_survey_date,
        c.latest_survey_date,
        c.is_absence_record
    from combined c
    left join sites s using (site_name)
)

select * from final