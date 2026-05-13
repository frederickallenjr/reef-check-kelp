-- int_algae_shannon_2025.sql
-- Calculates Shannon Index H' and species richness per site
-- H' = -SUM(p * LN(p)) where p = species proportion of total site abundance
-- Species richness = count of distinct species per site
-- Input: one normalized_amount per site per species from abundance normalization layer

with site_totals as (
    select
        site_name,
        year,
        state,
        species,
        normalized_amount,
        -- Calculate total abundance per site using window function
        sum(normalized_amount) over (
            partition by site_name, year, state
        )                                               as site_total
    from {{ ref('int_algae_abundance_normalized_2025') }}
),

proportions as (
    select
        site_name,
        year,
        state,
        species,
        normalized_amount,
        site_total,
        -- p: this species as proportion of total site abundance
        normalized_amount / site_total                  as p
    from site_totals
    where site_total > 0
),

shannon as (
    select
        site_name,
        year,
        state,
        -- Shannon Index H'
        -sum(p * LN(p))                                 as shannon_index,
        -- Species richness
        count(distinct species)                         as species_richness
    from proportions
    group by site_name, year, state
)

select
    site_name,
    year,
    state,
    round(shannon_index, 4)                             as shannon_index,
    species_richness
from shannon
