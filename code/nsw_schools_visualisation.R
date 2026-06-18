# ============================================================================
# A Visual Analysis of NSW Public School Enrolments and Distribution
# Unit: BUSA8090 Data and Visualisation for Business
# Author: Huynh Thien Luan (Ethan) Dang
#
# Produces five visualisations of the NSW Department of Education master
# dataset (school locations and student enrolment numbers) using ggplot2.
#
# Data source: NSW Department of Education (2026), Data.NSW
# https://data.nsw.gov.au/data/dataset/nsw-education-nsw-public-schools-master-dataset
# ============================================================================

# ---- Setup -----------------------------------------------------------------

# Check if 'ozmaps' is missing from the system's installed packages
if (!"ozmaps" %in% installed.packages()) {
  # If it is missing, install it
  install.packages("ozmaps")
}

# Check if 'patchwork' is missing from the system's installed packages
if (!"patchwork" %in% installed.packages()) {
  # If it is missing, install it
  install.packages("patchwork")
}

# Load the Tidyverse
library(tidyverse)

# Import CSV files with readr::read_csv() from tidyverse
(df <- read_csv("NSW government school locations and student enrolment numbers.csv"))

# Take a look at the data
summary(df)

# ---- Data preparation, transformation and cleaning -------------------------

# Convert text columns to factors
df <- df %>%
  mutate(Level_of_schooling=as.factor(Level_of_schooling), Selective_school=as.factor(Selective_school),
         Opportunity_class=as.factor(Opportunity_class), School_specialty_type=as.factor(School_specialty_type),
         School_subtype=as.factor(School_subtype), Preschool_ind=as.factor(Preschool_ind),
         Distance_education=as.factor(Distance_education), Intensive_english_centre=as.factor(Intensive_english_centre),
         School_gender=as.factor(School_gender), Late_opening_school=as.factor(Late_opening_school),
         LGA=as.factor(LGA), electorate_from_2023=as.factor(electorate_from_2023),
         electorate_2015_2022=as.factor(electorate_2015_2022), fed_electorate_from_2025=as.factor(fed_electorate_from_2025),
         fed_electorate_2016_2024=as.factor(fed_electorate_2016_2024), Operational_directorate=as.factor(Operational_directorate),
         Principal_network=as.factor(Principal_network), Operational_directorate_office=as.factor(Operational_directorate_office),
         FACS_district=as.factor(FACS_district), Local_health_district=as.factor(Local_health_district),
         AECG_region=as.factor(AECG_region), ASGS_remoteness=as.factor(ASGS_remoteness),
         `Assets unit`=as.factor(`Assets unit`), SA4=as.factor(SA4))

# Convert date columns to dates
df <- df %>%
  mutate(Date_1st_teacher=ymd(Date_1st_teacher), Date_extracted=ymd(Date_extracted))

# Take a look at the data
summary(df)

# Show missing values per column
colSums(is.na(df))

# Drop the entirely empty Support_classes column
df <- df %>%
  select(-Support_classes)

# Show the unique values of column Indigenous_pct
unique(df$Indigenous_pct)

# Let's just force that to numeric and the "np" will convert to N/A
df <- df %>%
  mutate(Indigenous_pct=as.numeric(Indigenous_pct))

# Show the unique values of column LBOTE_pct
unique(df$LBOTE_pct)

# Let's just force that to numeric and the "np" will convert to N/A
df <- df %>%
  mutate(LBOTE_pct=as.numeric(LBOTE_pct))

# Take a look at the data
summary(df)

# Drop factor/character rows with missing values
df <- df %>%
  drop_na(where(is.factor) | where(is.character))

# Impute numeric columns with the column's median
df <- df %>%
  mutate(across(where(is.numeric),
                ~ replace_na(., median(., na.rm = TRUE))))

# Show the number of duplicate rows
sum(duplicated(df))

# Take a look at the data again
summary(df)

# Reorder ASGS_remoteness from most to least urban for visualisations 3, 4, and 5
df <- df %>%
  mutate(ASGS_remoteness = factor(ASGS_remoteness,
                                  levels = c("Major Cities of Australia", "Inner Regional Australia",
                                             "Outer Regional Australia", "Remote Australia", "Very Remote Australia")))

# Save the cleaned CSV file
write_csv(df, "NSW_government_school_locations_cleaned.csv")

# ---- Visualisation 1: Distribution of Student Enrolments -------------------
ggplot(data = df) +
  geom_histogram(mapping=aes(x=latest_year_enrolment_FTE), binwidth = 60, fill="steelblue", color="black") +
  geom_vline(xintercept = median(df$latest_year_enrolment_FTE), color = "#F25C66", linetype = "dashed") +
  annotate("text", label = "Median", x = median(df$latest_year_enrolment_FTE) + 30, y = 220, color = "#F25C66", angle = 90) +
  geom_vline(xintercept = mean(df$latest_year_enrolment_FTE), color = "#2DC653", linetype = "dashed") +
  annotate("text", label = "Mean", x = mean(df$latest_year_enrolment_FTE) + 30, y = 220, color = "#2DC653", angle = 90) +
  scale_x_continuous(name = "Number of Students (FTE)", breaks = seq(0, 2500, by = 250)) +
  theme(panel.background=element_blank()) +
  theme(plot.background=element_blank()) +
  theme(panel.grid.major=element_line(color="grey")) +
  theme(plot.title = element_text(hjust = 0.5),
        plot.subtitle = element_text(hjust = 0.5)) +
  xlab("Number of Students (FTE)") +
  ylab("Number of Schools") +
  ggtitle("Distribution of Student Enrolments in NSW Public Schools", subtitle = "Source: NSW Department of Education (2026)")

# ---- Visualisation 2: Geographic distribution by level and size ------------

# Load the ggmap, ozmaps, patchwork, and sf library
library(ggmap)
library(ozmaps)
library(patchwork)
library(sf)

# Extract the NSW boundary from the ozmaps state database
nsw_boundary <- ozmap_states %>%
  filter(NAME == "New South Wales")

# Bounding box of NSW in c(left, bottom, right, top) format for ggmap
bbox <- st_bbox(nsw_boundary)
nsw_bounds <- c(
  left   = bbox[["xmin"]],
  bottom = bbox[["ymin"]],
  right  = bbox[["xmax"]],
  top    = bbox[["ymax"]]
)

# Register your Google Maps Static API key.
# NEVER hardcode a key in source you commit to version control. Instead set it
# as an environment variable (e.g. in a local .Renviron file that is gitignored):
#   GOOGLE_MAPS_API_KEY=your_key_here
# then restart R so Sys.getenv() can read it.
register_google(key = Sys.getenv("GOOGLE_MAPS_API_KEY"))

# Map A: full extent (zoom level 5) - includes Lord Howe Island
nsw_map_full <- get_map(location = nsw_bounds, zoom = 5, maptype = "terrain", scale = 2)

map_full <- ggmap(nsw_map_full) +
  geom_point(data = df, mapping = aes(x = Longitude, y = Latitude, color = Level_of_schooling, size = latest_year_enrolment_FTE), alpha = 0.6) +
  labs(color = "Level of Schooling", size = "Number of Students (FTE)", subtitle = "Full extent including Lord Howe Island") +
  theme(plot.background = element_blank(),
        panel.background = element_blank(),
        axis.title = element_blank(),
        axis.ticks = element_blank(),
        axis.text = element_blank(),
        plot.subtitle = element_text(hjust = 0.5))

# Map B: mainland detail (zoom level 6) - island falls outside the frame
nsw_map_main <- get_map(location = nsw_bounds, zoom = 6, maptype = "terrain", scale = 2)

map_main <- ggmap(nsw_map_main) +
  geom_point(data = df, mapping = aes(x = Longitude, y = Latitude, color = Level_of_schooling, size = latest_year_enrolment_FTE), alpha = 0.6) +
  labs(color = "Level of Schooling", size = "Number of Students (FTE)", subtitle = "Mainland NSW detail") +
  theme(plot.background = element_blank(),
        panel.background = element_blank(),
        axis.title = element_blank(),
        axis.ticks = element_blank(),
        axis.text = element_blank(),
        plot.subtitle = element_text(hjust = 0.5))

# Combine side by side with one shared legend and a single overall title
map_full + map_main +
  plot_layout(guides = "collect") +
  plot_annotation(
    title = "Distribution of Public NSW Schools: Level of Schooling and Student Population",
    subtitle = "Source: NSW Department of Education (2026)",
    theme = theme(plot.title = element_text(hjust = 0.5),
                  plot.subtitle = element_text(hjust = 0.5))
  )

# ---- Visualisation 3: School levels across remoteness areas ----------------
ggplot(data = df) +
  geom_bar(mapping=aes(x=ASGS_remoteness, fill=Level_of_schooling), position = "dodge") +
  theme(panel.background=element_blank()) +
  theme(plot.background=element_blank()) +
  theme(panel.grid.major.y=element_line(color="grey")) +
  theme(plot.title = element_text(hjust = 0.5),
        plot.subtitle = element_text(hjust = 0.5)) +
  scale_x_discrete(name="Remoteness Classification",
                   labels=c("Major Cities", "Inner Regional", "Outer Regional", "Remote", "Very Remote")) +
  scale_y_continuous(name="Number of Schools") +
  scale_fill_manual(values=c("#FF7F51", "#FF4B91", "#E63946", "#06D6A0", "#118AB2", "#FFD166", "#8338EC"), guide=guide_legend(title="School Level", nrow=2)) +
  theme(legend.position="bottom") +
  ggtitle("Distribution of Public NSW School Levels Across Remoteness Areas", subtitle = "Source: NSW Department of Education (2026)")

# ---- Visualisation 4: School size by remoteness classification -------------
ggplot(data = df) +
  geom_boxplot(mapping=aes(x=ASGS_remoteness, y=latest_year_enrolment_FTE, fill=ASGS_remoteness),
               outlier.alpha=0.3) +
  theme(panel.background=element_blank()) +
  theme(plot.background=element_blank()) +
  theme(panel.grid.major.y=element_line(color="grey")) +
  theme(plot.title = element_text(hjust = 0.5),
        plot.subtitle = element_text(hjust = 0.5)) +
  theme(legend.position="none") +
  scale_x_discrete(name="Remoteness Classification",
                   labels=c("Major Cities", "Inner Regional", "Outer Regional", "Remote", "Very Remote")) +
  scale_y_continuous(name="Number of Students (FTE)") +
  scale_fill_brewer(palette="Blues", direction=-1) +
  ggtitle("NSW Public School Size by Remoteness Classification", subtitle = "Source: NSW Department of Education (2026)")

# ---- Visualisation 5: Growth of the school network over time ---------------
df %>%
  group_by(ASGS_remoteness) %>%
  arrange(Date_1st_teacher, .by_group = TRUE) %>%
  mutate(cumulative_schools = row_number()) %>%
  ungroup() %>%
  ggplot(aes(x = Date_1st_teacher, y = cumulative_schools, color = ASGS_remoteness)) +
  geom_line(linewidth = 1) +
  theme(panel.background = element_blank()) +
  theme(plot.background = element_blank()) +
  theme(panel.grid.major.y = element_line(color = "grey")) +
  theme(plot.title = element_text(hjust = 0.5),
        plot.subtitle = element_text(hjust = 0.5)) +
  scale_x_date(name = "Date First Teacher Appointed",
               date_breaks = "20 years",
               date_labels = "%Y") +
  scale_y_continuous(name = "Cumulative Number of Schools") +
  scale_color_manual(name = "Remoteness Classification",
                     values = c("#1A9ED4", "#2DC653", "#FFA726", "#FF4D4D", "#A855F7"),
                     labels = c("Major Cities", "Inner Regional", "Outer Regional", "Remote", "Very Remote")) +
  ggtitle("Growth of NSW Public Schools Over Time by Remoteness Classification", subtitle = "Source: NSW Department of Education (2026)")
