#Packages----
{
  packages <- c(
    #"here",
    #"progressr",
    "data.table",
    #"tictoc",
    #"crayon",
    'leaflet',
    'mapview',
    #'leafpop',
    'janitor',
    #'sp',
    'sf',
    #'dplyr',
    'feather',
    "tidyverse",
    "magrittr",
    #"shinyjs",
    #'usmap',
    'readxl',
    'lubridate',
    #'standartox',
    #'rmarkdown',
    #'kableExtra',
    'rio',
    'beepr',
    'openxlsx',
    'plotly',
    'RColorBrewer',
    'tidytuesdayR',
    'tinytiger',
    'tidycensus',
    'leafsync'
  )
  package.check <- lapply(
    packages,
    FUN = function(x) {
      if (!require(x, character.only = TRUE)) {
        install.packages(
          x,
          dependencies = TRUE,
          repos = "http://cran.us.r-project.org"
        )
        library(x, character.only = TRUE)
      }
    }
  )
  rm(package.check)
}
#Read in data----
tuesdata <- tidytuesdayR::tt_load('2022-09-20')
hydro <- tuesdata$HydroWASTE_v10
hydro <- clean_names(hydro)
rm(tuesdata)

#explore----

summ <- hydro %>%
  group_by(country) %>%
  summarize(count = n()) %>%
  arrange(desc(count))
#US data-----
hyd1 <- hydro %>%
  filter(country == 'United States') %>%
  st_as_sf(coords = c('lon_wwtp', 'lat_wwtp'), crs = 4269) #NAD83
#TX data----
tx_counties_shp <- tt_counties('TX')
us_shp <- tt_states(year = 2021)
tx_shp <- us_shp %>%
  filter(NAME == 'Texas')

tx <- st_intersection(hyd1, tx_shp$geometry)
tx$population_served <- tx$pop_served
tx$wastewater_dischage_m3_per_d1 <- tx$waste_dis
tx$dilution_factor <- tx$df

texas <- tx %>%
  select(
    wwtp_name,
    population_served,
    wastewater_dischage_m3_per_d1,
    dilution_factor,
    geometry
  )


##stats----
tx_stats <- tx %>%
  summarize(
    'pop_min' = min(population_served),
    'pop_max' = max(population_served),
    waste_min = min(wastewater_dischage_m3_per_d1),
    waste_max = max(wastewater_dischage_m3_per_d1)
  )

##TX census data----

vars10 <- load_variables(2010, 'sf2')
vars20 <- load_variables(2020, 'acs5')
tx_census <- get_acs(
  geography = 'county',
  variables = c(medincome = 'B19013_001'),
  state = 'TX',
  year = 2020
)

tx_census2 <- get_acs(
  geography = 'county',
  variables = c('plumbing_facilites' = 'B25047_001'),
  state = 'TX',
  year = 2020
)

tx_census2 <- tx_census2 %>%
  as.data.frame() %>%
  mutate(estimate = log(estimate)) %>%
  select(GEOID, estimate)

tx_shp_census <- left_join(
  tx_counties_shp,
  tx_census,
  by = c('GEOID' = 'GEOID')
)
tx_shp_census$median_income_est <- tx_shp_census$estimate
tx_shp_plb <- left_join(tx_counties_shp, tx_census2, by = c('GEOID' = 'GEOID'))
tx_shp_plb <- rename(
  tx_shp_plb,
  'total_number_of_plumbing_facilites_est_log' = 'estimate'
)

#Render map----
m1 <- mapview(
  texas,
  zcol = 'population_served',
  col.regions = brewer.pal(9, "YlOrRd")
)
m2 <- mapview(texas, zcol = c('wastewater_dischage_m3_per_d1'))
m3 <- mapview(
  tx_shp_census,
  zcol = 'median_income_est',
  col.regions = brewer.pal(9, "RdYlBu")
)
m4 <- mapview(tx_shp_plb, zcol = 'total_number_of_plumbing_facilites_est_log')
sync(m1, m2, m3, m4)

m1 + m2 + m3 + m4
