with source as (
    select * from {{ source('raw', 'algae_CA_2025') }}
),

renamed as (
    select
        Site                                    as site_name,
        cast(Latitude  as float64)              as latitude,
        cast(Longitude as float64)              as longitude,
        cast(Year      as int64)                as survey_year,
        cast(Date      as date)                 as survey_date,
        cast(Depth_ft  as float64)              as depth_ft,
        cast(Transect  as int64)                as transect_number,
        trim(Classcode)                         as species_common_name,
        cast(Amount    as int64)                as amount,
        cast(Stipes    as int64)                as stipe_count,
        cast(Distance  as float64)              as distance_surveyed_m,

        case when cast(Amount as int64) = 1
             then true else false
        end                                     as is_presence_record,

        case when cast(Distance as float64) < 30
             then true else false
        end                                     as is_subsampled

    from source
)

select * from renamed