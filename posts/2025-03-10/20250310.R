
#Where do federal government employees (excluding military personnel and USPS workers) make up the largest share of the 18+ labor force?

# packages ----------------------------------------------------------------

{
  library(tidyverse)
  library(tidycensus)
  library(tigris)
  library(sf)
  library(ggpubr)
  library(patchwork)
  library(here)
  
  setwd(here('20250310'))
}

# functions ---------------------------------------------------------------


ggsave_all <- function(filename, plot = ggplot2::last_plot(), specs = NULL, path = "output", ...) {
  specs <- if (!is.null(specs)) specs else {
    # Create default outputs data.frame rowwise using only base R
    specs <- rbind(
      c("_quart_portrait", "png", 1, (8.5-2)/2, (11-2)/2, "in", 300), # doc > layout > margins
      c("_half_portrait", "png", 1, 8.5-2, (11-2)/2, "in", 300),
      c("_full_portrait", "png", 1, 8.5-2, (11-2), "in", 300),
      c("_full_landscape", "png", 1, 11-2, 8.5-2, "in", 300),
      c("_ppt_title_content", "png", 1, 11.5, 4.76, "in", 300), # ppt > format pane > size
      c("_ppt_full_screen", "png", 1, 13.33, 7.5, "in", 300),   # ppt > design > slide size
      c("_ppt_two_content", "png", 1, 5.76, 4.76, "in", 300)    # ppt > format pane > size
    )
    
    colnames(specs) <- c("suffix", "device", "scale", "width", "height", "units", "dpi")
    specs <- as.data.frame(specs)
  }
  
  dir.create(path, showWarnings = FALSE, recursive = TRUE)
  
  invisible(
    apply(specs, MARGIN = 1, function(...) {
      args <- list(...)[[1]]
      filename <- file.path(paste0(filename, args['suffix'], ".", args['device']))
      message("Saving: ", file.path(path, filename))
      
      ggplot2::ggsave(
        filename = filename,
        plot = ggplot2::last_plot(),
        path = path,
        device = args['device'],
        width = as.numeric(args['width']), height = as.numeric(args['height']), units = args['units'],
        dpi = if (is.na(as.numeric(args['dpi']))) args['dpi'] else as.numeric(args['dpi']),
        bg = 'white'
      )
    })
  )
}


# load --------------------------------------------------------------------
v23 <- load_variables(2023, "acs1", cache = TRUE)

v23 %>%
  filter(name %in% c("B01003_001", "B24080_009","B24080_019"))

raw <- 
  get_acs(
    geography = "county",
    variables = c("B01003_001", "B24080_009","B24080_019"),
    year = 2023,
    survey = "acs1",
    output = "wide", 
    geometry = FALSE
  )

states <- tigris::states(year = 2023, cb = T) %>% 
  filter(STUSPS %in% state.abb) %>% 
  #filter(STUSPS %in% c('OH')) %>% 
  shift_geometry()

counties <- tigris::counties(year = 2023, cb = T) %>% 
  filter(STATEFP %in% states$STATEFP) %>% 
  shift_geometry()

# transform ---------------------------------------------------------------

cleaned <- raw %>% 
  group_by(GEOID) %>% 
  summarize(.,
            percentage = sum(B24080_009E, B24080_019E) / B01003_001E,
            pop_fed = sum(B24080_009E, B24080_019E),
            total = B01003_001E
  )
  
cleaned_geo <- counties %>% 
  left_join(., cleaned, join_by(GEOID))

# plot --------------------------------------------------------------------

p1 <- ggplot() +
  geom_sf(
    data = counties
  ) +
  geom_sf(
    data = cleaned_geo,
    mapping = aes(
      fill = percentage 
    )
  ) + 
  scale_fill_viridis_b(
    name = NULL, 
    option = 'magma',
    na.value = "white",
    n.breaks = 6,
    direction = -1,
    labels = scales::label_percent()
  ) +
  labs(
    title = 'Percentage of federal employees by county',
    subtitle = 'Year: 2023, ACS 1 YR, field codes: B01003_001, B24080_009, B24080_019'
    ) +
  theme_void() +
  theme(
    legend.position = "left"
  )

# table -------------------------------------------------------------------

t1 <- cleaned_geo %>% 
  sf::st_drop_geometry() %>% 
  select(STATE_NAME, NAME, percentage) %>% 
  rename(
    `State Name` = STATE_NAME,
    County = NAME,
    Percentage = percentage
  ) %>% 
  filter(!is.na(Percentage)) %>% 
  group_by(`State Name`) %>%
  slice_max(n = 1, order_by = Percentage) %>%
  arrange(desc(Percentage)) %>% 
  mutate(Percentage = scales::percent(Percentage, accuracy = 3)) %>% 
  ungroup() %>% 
  head(n = 10) %>% 
  ggtexttable(., rows = NULL, theme = ttheme("light")) %>% 
  tab_add_title('Top county from top ten states', face = 'bold') 

subtitle <- str_wrap(
  'By percentage of population that was reported as a federal employee',
  width = 30)
  
t2 <- cleaned_geo %>% 
  sf::st_drop_geometry() %>% 
  select(STATE_NAME, NAME, percentage, total, pop_fed) %>% 
  rename(
    `State Name` = STATE_NAME,
    County = NAME,
    Percentage = percentage
  ) %>% 
  filter(!is.na(Percentage)) %>% 
  group_by(`State Name`) %>% 
  summarize(st_percent = sum(pop_fed)/ sum(total)) %>% 
  mutate(Percentage = scales::percent(st_percent, accuracy = 3)) %>% 
  arrange(desc(Percentage)) %>% 
  head(n = 10) %>% 
  select(-st_percent) %>% 
  ggtexttable(., rows = NULL, theme = ttheme("light")) %>% 
  tab_add_title(text = subtitle, face = "plain", size = 10) %>%
  tab_add_title('Top Ten States', face = 'bold')
  
f1 <- (p1 + t2)

f1
