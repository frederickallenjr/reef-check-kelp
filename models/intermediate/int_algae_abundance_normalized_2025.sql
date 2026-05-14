-- int_algae_abundance_normalized_2025.sql
-- Normalizes abundance across species using appropriate proxy per species type:
--   Canopy kelp (Giant Kelp, Feather Boa Kelp): SUM(stipes_extrapolated)
--   All other species: SUM(amount_extrapolated)
-- Extrapolation to full 30m transect equivalent applied in staging layer
-- Southern Sea Palm size bins already collapsed in staging
-- No Blade Kelp excluded -- no taxonomic resolution, would corrupt Shannon H'
-- Output: one normalized_amount per site per species

with canopy as (
    select
        site_name,
        year,
        state,
        species,
        sum(stipes_extrapolated)                        as normalized_amount
    from {{ ref('stg_algae_west_coast_2025') }}
    where is_canopy_kelp = true
      and stipes_extrapolated is not null
    group by site_name, year, state, species
),

standard as (
    select
        site_name,
        year,
        state,
        species,
        sum(amount_extrapolated)                        as normalized_amount
    from {{ ref('stg_algae_west_coast_2025') }}
    where is_canopy_kelp = false
      and is_no_blade_kelp = false
    group by site_name, year, state, species
),

unioned as (
    select * from canopy
    union all
    select * from standard
)

select
    site_name,
    year,
    state,
    species,
    normalized_amount
from unioned
where normalized_amount > 0
