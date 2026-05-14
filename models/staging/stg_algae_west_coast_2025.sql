-- stg_algae_west_coast_2025.sql
-- Staging model: unions CA, OR, and WA raw algae tables
-- Filters to 2025 survey year only
-- Derives species from classcode, collapsing Southern Sea Palm size bins
-- Extrapolates amount and stipes to full 30m transect equivalent
--   extrapolated = (raw / distance) * 30
--   applies universally -- if distance = 30 multiplier is 1, no change
--   if distance < 30 subsampling occurred and count is scaled accordingly
-- Raw amount, stipes, and distance retained for reference
-- Adds classification flags for downstream exclusion logic
-- Note: invasive species (Sargassum muticum, Sargassum horneri, Undaria, Caulerpa)
-- are not present in raw algae classcodes and are excluded from this pipeline.
-- Invasive presence data was unavailable in this data delivery.

with ca as (
    select
        Site                                            as site_name,
        Year                                            as year,
        Classcode                                       as classcode,
        Amount                                          as amount_raw,
        Stipes                                          as stipes_raw,
        Distance                                        as distance,
        SAFE_CAST(Amount AS FLOAT64)
            / SAFE_CAST(Distance AS FLOAT64) * 30      as amount_extrapolated,
        SAFE_CAST(Stipes AS FLOAT64)
            / SAFE_CAST(Distance AS FLOAT64) * 30      as stipes_extrapolated,
        Latitude                                        as latitude,
        Longitude                                       as longitude,
        'CA'                                            as state
    from {{ source('raw', 'algae_CA_2025') }}
    where Year = 2025
),

or_ as (
    select
        Site                                            as site_name,
        Year                                            as year,
        Classcode                                       as classcode,
        Amount                                          as amount_raw,
        Stipes                                          as stipes_raw,
        Distance                                        as distance,
        SAFE_CAST(Amount AS FLOAT64)
            / SAFE_CAST(Distance AS FLOAT64) * 30      as amount_extrapolated,
        SAFE_CAST(Stipes AS FLOAT64)
            / SAFE_CAST(Distance AS FLOAT64) * 30      as stipes_extrapolated,
        Latitude                                        as latitude,
        Longitude                                       as longitude,
        'OR'                                            as state
    from {{ source('raw', 'algae_OR_2025') }}
    where Year = 2025
),

wa as (
    select
        Site                                            as site_name,
        Year                                            as year,
        Classcode                                       as classcode,
        Amount                                          as amount_raw,
        Stipes                                          as stipes_raw,
        Distance                                        as distance,
        SAFE_CAST(Amount AS FLOAT64)
            / SAFE_CAST(Distance AS FLOAT64) * 30      as amount_extrapolated,
        SAFE_CAST(Stipes AS FLOAT64)
            / SAFE_CAST(Distance AS FLOAT64) * 30      as stipes_extrapolated,
        Latitude                                        as latitude,
        Longitude                                       as longitude,
        'WA'                                            as state
    from {{ source('raw', 'algae_WA_2025') }}
    where Year = 2025
),

unioned as (
    select * from ca
    union all
    select * from or_
    union all
    select * from wa
),

with_species as (
    select
        site_name,
        year,
        classcode,
        -- Derive species from classcode
        -- Southern Sea Palm size bins collapsed to single species entry
        -- Torn Kelp = Laminaria setchellii, overlaps with Laminaria Spp
        -- (Laminaria Spp = L. farlowii / L. setchellii) -- kept as distinct entries
        case
            when classcode = 'Southern Sea Palm (<30)' then 'Southern Sea Palm'
            when classcode = 'Southern Sea Palm (>30)' then 'Southern Sea Palm'
            else classcode
        end                                             as species,
        amount_raw,
        stipes_raw,
        distance,
        amount_extrapolated,
        stipes_extrapolated,
        latitude,
        longitude,
        state
    from unioned
)

select
    site_name,
    year,
    classcode,
    species,
    amount_raw,
    stipes_raw,
    distance,
    amount_extrapolated,
    stipes_extrapolated,
    latitude,
    longitude,
    state,

    -- Canopy kelp: abundance proxy uses stipes_extrapolated in normalization layer
    case when species in ('Giant Kelp', 'Feather Boa Kelp')
        then true else false end                        as is_canopy_kelp,

    -- No taxonomic resolution: excluded from Shannon Index
    case when species = 'No Blade Kelp'
        then true else false end                        as is_no_blade_kelp

from with_species
