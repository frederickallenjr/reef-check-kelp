with kelp as (
    select * from {{ ref('stg_algae_CA_2025') }}
    where species_common_name = 'Giant Kelp'
      and is_presence_record = true
),

by_transect as (
    select
        site_name,
        latitude,
        longitude,
        survey_year,
        survey_date,
        transect_number,
        depth_ft,

        count(*)                                        as plant_count,
        sum(stipe_count)                                as total_stipes,

        max(distance_surveyed_m)                        as distance_surveyed_m,
        cast(max(cast(is_subsampled as int64)) as bool) as is_subsampled,

        round(
            sum(stipe_count) / nullif(max(distance_surveyed_m), 0)
        , 4)                                            as stipes_per_meter,

        round(
            (sum(stipe_count) / nullif(max(distance_surveyed_m), 0)) * 30
        , 1)                                            as stipes_per_30m_extrapolated

    from kelp
    group by
        site_name, latitude, longitude,
        survey_year, survey_date,
        transect_number, depth_ft
)

select * from by_transect