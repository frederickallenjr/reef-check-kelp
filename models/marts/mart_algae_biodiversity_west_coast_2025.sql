-- mart_algae_biodiversity_west_coast_2025.sql
-- Final Tableau-ready mart: one row per site, all 172 surveyed sites included
-- Sites with no recorded indicator species: shannon_index = 0, species_richness = 0
-- Shannon Index H' and species richness from Shannon layer
-- Pielou's J' (evenness) = shannon_index / LN(species_richness)
--   ranges 0-1 regardless of richness, used for cross-site color encoding
--   0 for sites with species_richness of 0 or 1 -- zero is ecologically meaningful,
--   not missing data. A site with no recorded algae has no evenness by definition.
-- Hill number 1D = EXP(shannon_index)
--   effective number of species equivalent to observed diversity
--   directly interpretable as species count, richness-sensitive
--   preferred ranking metric over J' for naturally stratified communities
-- CA region assigned by latitude using Reef Check 3-region statewide framework:
--   Northern: Oregon Border to Golden Gate (~37.83N)
--   Central: Golden Gate to Point Conception (~34.45N)
--   Southern: Point Conception to US-Mexico Border
-- Source: California Marine Life Protection Act (MLPA) Study Regions
-- as consolidated by Reef Check for statewide reporting
-- OR and WA ca_region is NULL -- no equivalent regional framework applied

with sites as (
    select
        site_name,
        state,
        latitude,
        longitude
    from {{ ref('int_survey_sites_west_coast') }}
),

shannon as (
    select
        site_name,
        year,
        state,
        shannon_index,
        species_richness
    from {{ ref('int_algae_shannon_2025') }}
)

select
    si.site_name,
    coalesce(sh.year, 2025)                             as year,
    si.state,
    si.latitude,
    si.longitude,
    coalesce(sh.shannon_index, 0)                       as shannon_index,
    coalesce(sh.species_richness, 0)                    as species_richness,
    case
        when coalesce(sh.species_richness, 0) <= 1
        then 0
        else round(
            coalesce(sh.shannon_index, 0) / LN(coalesce(sh.species_richness, 0)),
        4)
    end                                                 as pielou_evenness,
    round(EXP(coalesce(sh.shannon_index, 0)), 4)        as hill_1d,
    case
        when si.state = 'CA' and si.latitude >= 37.83 then 'Northern'
        when si.state = 'CA' and si.latitude >= 34.45 then 'Central'
        when si.state = 'CA' then 'Southern'
        else null
    end                                                 as ca_region

from sites si
left join shannon sh
    on si.site_name = sh.site_name
    and si.state = sh.state

order by si.state, si.site_name
