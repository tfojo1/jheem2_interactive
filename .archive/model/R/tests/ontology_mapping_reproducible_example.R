source('R/ONTOLOGY_ontology_mappings.R')
source('R/HELPERS_misc_helpers.R')

register.ontology.mapping('lump.other.risk.and.heterosexual',
                          from.dimensions = 'risk',
                          to.dimensions = 'risk',
                          mappings = rbind(c('msm', 'msm'),
                                           c('idu', 'idu'),
                                           c('msm_idu', 'msm_idu'),
                                           c('heterosexual', 'heterosexual'),
                                           c('other', 'heterosexual'))
)

register.ontology.mapping('jheem.to.cdc.sex.risk',
                          from.dimensions = c('sex', 'risk'),
                          to.dimensions = c('sex', 'risk'),
                          mappings = rbind(c('msm', 'never_IDU', 'male', 'msm'),
                                           c('msm', 'active_IDU', 'male', 'msm_idu'),
                                           c('msm', 'IDU_in_remission', 'male', 'msm_idu'),
                                           c('heterosexual_male', 'never_IDU', 'male', 'heterosexual'),
                                           c('heterosexual_male', 'active_IDU', 'male', 'idu'),
                                           c('heterosexual_male', 'IDU_in_remission', 'male', 'idu'),
                                           c('female', 'never_IDU', 'female', 'heterosexual'),
                                           c('female', 'active_IDU', 'female', 'idu'),
                                           c('female', 'IDU_in_remission', 'female', 'idu'))
)

register.ontology.mapping('cdc.to.jheem.race',
                          from.dimensions = 'race',
                          to.dimensions = 'race',
                          mappings = rbind(c('American Indian/Alaska Native', 'other'),
                                           c('Asian', 'other'),
                                           c('Black/African American', 'black'),
                                           c('Hispanic/Latino', 'hispanic'),
                                           c('Multiracial', 'other'),
                                           c('Native Hawaiian/Other Pacific Islander', 'other'),
                                           c('White', 'other')) # is this really what the jheem race categories are?
)

map.lump = ONTOLOGY.MAPPING.MANAGER$mappings$lump.other.risk.and.heterosexual
map.sex.risk = ONTOLOGY.MAPPING.MANAGER$mappings$jheem.to.cdc.sex.risk
map.race = ONTOLOGY.MAPPING.MANAGER$mappings$cdc.to.jheem.race

# All three are 'basic.ontology.mapping' objects
# But only map.race can access the method "get.required.from.dimensions"

map.lump$get.required.from.dimensions('race')
