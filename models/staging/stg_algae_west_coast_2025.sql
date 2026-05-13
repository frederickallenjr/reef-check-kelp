-- stg_algae_west_coast_2025.sql
-- Staging model: unions CA, OR, and WA raw algae tables
-- Filters to 2025 survey year only
-- Derives species from classcode, collapsing Southern Sea Palm size bins
-- Adds classification flags for downstream exclusion logic
-- Note: invasive species (Sargassum muticum, Sargassum horneri, Undaria, Caulerpa)
-- are not present in raw algae classcodes and are excluded from this pipeline.
-- Invasive presence data was unavailable in this data delivery.

with ca as (
    select
        Site                                            as site_name,
        Year                                            as year,
        Classcode                                       as classcode,
        Amount                                          as amount,
        Stipes                                          as stipes,
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
        Amount                                          as amount,
        Stipes                                          as stipes,
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
        Amount                                          as amount,
        Stipes                                          as stipes,
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
        amount,
        stipes,
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
    amount,
    stipes,
    latitude,
    longitude,
    state,

    -- Canopy kelp: abundance proxy uses stipes in normalization layer
    case when species in ('Giant Kelp', 'Feather Boa Kelp')
        then true else false end                        as is_canopy_kelp,

    -- No taxonomic resolution: excluded from Shannon Index
    case when species = 'No Blade Kelp'
        then true else false end                        as is_no_blade_kelp

from with_species
