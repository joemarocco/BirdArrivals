# bird_arrivals_climate_analysis_commented.R
# Spring bird arrival phenology + climate for southern Franklin County, NY
# Author: Joe Marocco
#
# This script walks through the full pipeline:
#   1. Filter eBird data for a small set of focal species in Franklin County, NY.
#   2. Derive first spring arrival dates (day-of-year) for each species/year.
#   3. Load daily climate data from the Tupper Lake GHCND station (USC00308631).
#   4. Compute biologically meaningful climate covariates (temp, GDD, snow, thaw).
#   5. Join climate with arrival data.
#   6. Fit single-predictor models per species to see which climate variable
#      best explains arrival timing (variable-importance across species).
#   7. Visualize and inspect key relationships (e.g., snow depth vs arrival).
#
# IMPORTANT: Because pre-2005 eBird data in this region are sparse and biased,
# we explicitly RESTRICT ALL ANALYSES TO YEARS >= 2005. Earlier years are
# discarded for the phenology analysis.

# ---------------------------
# 0) Load packages
# ---------------------------

# tidyverse: data wrangling and plotting (dplyr, ggplot2, readr, etc.)
library(tidyverse)

# lubridate: convenient date handling (ymd, year, month, yday, etc.)
library(lubridate)

# auk: tools for filtering and reading the eBird Basic Dataset (EBD)
library(auk)

# broom: converts model objects (like lm) into tidy data frames (tidy, glance)
library(broom)

# purrr: functional programming helpers (map, map_dfr, etc.)
library(purrr)

# data.table: we only need its rleid() function to label runs of TRUE/FALSE
library(data.table)

# visreg: partial regression / effect plots from linear models
library(visreg)


# ---------------------------
# 1) eBird: filter EBD and compute first arrival dates
# ---------------------------

# The raw EBD text file should be in the working directory.
# This file is the Franklin County export:
#   - downloaded from eBird (region: US-NY-033, release Oct 2025).
ebd_file <- "ebd_US-NY-033_relOct-2025.txt"

# Define the focal migratory species.
# You can add/remove species here and re-run the pipeline; everything downstream
# automatically updates because it groups by common_name.
species_targets <- c(
  "American Robin",
  "Blue-headed Vireo",
  "Hermit Thrush",
  "Yellow-rumped Warbler",
  "Eastern Phoebe"
)

# Use auk to define the EBD filter:
#   - Restrict to our focal species.
#   - Restrict to New York State.
#   - Restrict further to Franklin County (US-NY-033).
# We do *not* actually subset yet; auk_ebd + auk_* just define the pipeline.
ebd_filtered_def <- auk_ebd(ebd_file) %>%
  auk_species(species = species_targets, taxonomy_version = 2025) %>%
  auk_state("US-NY") %>%
  auk_county("US-NY-033")

# This is the output file that auk_filter() will write — a much smaller
# EBD-like text file containing only the selected species and region.
ebd_filtered_file <- "ebd_US-NY-033_relOct-2025_filtered.txt"

# Apply the filter, writing the filtered data to disk.
# This step can take some time for large EBD files, but you only need to
# re-run it if either the input file or your filter definitions change.
ebd_filtered_def %>%
  auk_filter(file = ebd_filtered_file, overwrite = TRUE)

# Read the filtered EBD into R as a tibble.
# read_ebd() understands the EBD format and gives you convenient column names.
ebd <- read_ebd(ebd_filtered_file)

# Compute first spring arrival per species-year.
# Steps:
#   1. Convert observation_date to Date (ymd).
#   2. Derive year and day-of-year (doy).
#   3. Restrict to spring months (here: March–June).
#   4. RESTRICT TO YEARS >= 2005 (drop earlier years with poor sampling).
#   5. Group by species and year.
#   6. Take the minimum date in each group as the first arrival.
arrivals <- ebd %>%
  mutate(
    date = ymd(observation_date),
    year = year(date),
    doy  = yday(date)
  ) %>%
  # Define a "spring arrival window" — this is somewhat arbitrary and you can
  # tune it later. We're capturing the main arrival period.
  filter(
    month(date) %in% 3:6,
    year >= 2005        # <-- key restriction: drop years before 2005
  ) %>%
  group_by(common_name, year) %>%
  summarize(
    first_seen = min(date, na.rm = TRUE),
    doy = yday(first_seen),
    .groups = "drop"
  )

# Quick visual check: do arrivals appear to trend earlier over time?
# (Now only for 2005+)
ggplot(arrivals, aes(x = year, y = doy, color = common_name)) +
  geom_point(alpha = 0.7) +
  geom_smooth(method = "lm", se = FALSE) +
  scale_y_reverse() +
  labs(
    title = "First Spring Arrival (DOY) by Species (Years >= 2005)",
    x = "Year",
    y = "Arrival DOY (lower = earlier)",
    color = "Species"
  )


# ---------------------------
# 2) Climate: Tupper Lake GHCND (USC00308631)
# ---------------------------

# We use daily data from the Tupper Lake station as a representative
# climate record for southern Franklin County. The file should be in the
# working directory, downloaded from the GHCND by-station archives.
#
# The format is the standard GHCND daily format:
#   station, date, element, value, mflag, qflag, sflag, obs_time
#
# - "element" holds codes like TMAX, TMIN, SNWD, etc.
# - "value" is typically in tenths of the physical unit (e.g., tenths °C).
tupper_raw <- read_csv(
  "USC00308631.csv",
  col_names = c("station","date","element","value","mflag","qflag","sflag","obs_time"),
  show_col_types = FALSE
) %>%
  mutate(date = ymd(date))

# For temperature metrics, we want daily TMAX and TMIN in wide format
# with one row per date, and we derive tmean, year, and month.
tupper_w <- tupper_raw %>%
  filter(element %in% c("TMAX", "TMIN")) %>%
  select(date, element, value) %>%
  mutate(value = value / 10) %>%                # tenths of °C -> °C
  pivot_wider(names_from = element, values_from = value) %>%
  mutate(
    tmean = (TMAX + TMIN) / 2,
    year  = year(date),
    month = month(date)
  ) %>%
  # Restrict climate to 2005+ to match the arrival analysis window.
  filter(year >= 2005)


# ---------------------------
# 3) Core climate covariates: temp, GDD, freeze–thaw
# ---------------------------

# 3a) Mean spring temperature (Feb–Apr)
#     This is a coarse measure of how warm each spring is.
clim_temp <- tupper_w %>%
  filter(month %in% 2:4) %>%
  group_by(year) %>%
  summarize(
    spring_mean_temp = mean(tmean, na.rm = TRUE),
    .groups = "drop"
  )

# 3b) Growing Degree Days (GDD) with base 0°C, Feb–Apr
#     This is a crude cumulative warmth metric — useful for migrants that
#     respond to accumulated heat rather than just mean temperature.
tupper_w <- tupper_w %>%
  mutate(gdd = pmax(tmean, 0))  # negative tmean -> 0 GDD

clim_gdd <- tupper_w %>%
  filter(month %in% 2:4) %>%
  group_by(year) %>%
  summarize(
    spring_gdd = sum(gdd, na.rm = TRUE),
    .groups = "drop"
  )

# 3c) Freeze–thaw days (Jan–Apr)
#     Here we mark days where:
#       TMAX >= 1°C AND TMIN <= -1°C.
#     This captures days with freezing nights and thawing days — classic
#     maple-sap and early-season phenology conditions.
tupper_w <- tupper_w %>%
  mutate(freeze_thaw = (TMAX >= 1) & (TMIN <= -1))

clim_ft <- tupper_w %>%
  filter(month %in% 1:4) %>%
  group_by(year) %>%
  summarize(
    freeze_thaw_days = sum(freeze_thaw, na.rm = TRUE),
    .groups = "drop"
  )


# ---------------------------
# 4) Snow metrics (if SNWD is available)
# ---------------------------

# Snow depth is often a very strong predictor of early migrant arrival,
# because birds literally need bare ground to find food.
# We derive three snow metrics:
#   - mean_snwd: mean snow depth in Feb–Mar (late winter snowiness)
#   - first_bare_doy: first day of the year (Jan–May) with SNWD == 0
#   - days_snow_gt10: number of days with > 10 cm snowpack (Jan–Apr)

if (any(tupper_raw$element == "SNWD")) {
  # Subset to snow depth rows and convert to cm.
  snwd <- tupper_raw %>%
    filter(element == "SNWD") %>%
    select(date, value) %>%
    mutate(
      snwd_cm = value / 10,   # tenths of mm -> cm
      year    = year(date),
      month   = month(date)
    ) %>%
    # Restrict to the analysis window: years >= 2005
    filter(year >= 2005)
  
  # Mean snow depth in late winter (Feb–Mar).
  clim_snow_mean <- snwd %>%
    filter(month %in% 2:3) %>%
    group_by(year) %>%
    summarize(
      mean_snwd = mean(snwd_cm, na.rm = TRUE),
      .groups = "drop"
    )
  
  # Date of first bare ground (SNWD == 0) between Jan and May.
  # This is a proxy for snowmelt timing.
  snowmelt <- snwd %>%
    filter(month %in% 1:5) %>%
    group_by(year) %>%
    summarize(
      # suppressWarnings() is used because min(..., na.rm = TRUE) will complain
      # if all values are NA or there is no 0-snow day in that window.
      first_bare_ground = suppressWarnings(min(date[snwd_cm == 0], na.rm = TRUE)),
      first_bare_doy    = yday(first_bare_ground),
      .groups = "drop"
    )
  
  # Snow persistence: number of days with > 10 cm snowpack between Jan–Apr.
  snow_persistence <- snwd %>%
    filter(month %in% 1:4) %>%
    group_by(year) %>%
    summarize(
      days_snow_gt10 = sum(snwd_cm > 10, na.rm = TRUE),
      .groups = "drop"
    )
} else {
  # If the station has no snow depth records, create empty tibbles so the
  # joins later still work (they just won't add any columns).
  clim_snow_mean   <- tibble(year = integer(), mean_snwd = numeric())
  snowmelt         <- tibble(year = integer(), first_bare_doy = numeric())
  snow_persistence <- tibble(year = integer(), days_snow_gt10 = numeric())
}


# ---------------------------
# 5) First sustained thaw metric (using data.table::rleid)
# ---------------------------

# The idea:
#   - Mark each day as above_freezing if TMIN > 0°C.
#   - Use rleid() within each year to label runs of consecutive TRUE/FALSE.
#   - Summarize each run to get its length and whether it was above_freezing.
#   - Find the first run in each year where:
#         above_freezing == TRUE AND run_length >= 3.
#     This is our "first sustained thaw" date.

tupper_thaw <- tupper_w %>%
  mutate(above_freezing = TMIN > 0) %>%
  arrange(year, date) %>%
  group_by(year) %>%
  mutate(
    # thaw_run is a run ID: 1, 1, 1, 2, 2, 3, 3, ...
    # whenever above_freezing changes (FALSE -> TRUE or TRUE -> FALSE),
    # rleid() increments the run ID.
    thaw_run = data.table::rleid(above_freezing)
  ) %>%
  ungroup()

# Summarize the runs and pick the first sustained thaw per year.
thaw_runs <- tupper_thaw %>%
  group_by(year, thaw_run) %>%
  summarize(
    start_date = first(date),
    run_length = sum(above_freezing, na.rm = TRUE),
    above      = first(above_freezing),
    .groups = "drop"
  ) %>%
  # Keep only runs that are:
  #   - above_freezing (TRUE)
  #   - at least 3 days long (run_length >= 3)
  filter(above, run_length >= 3) %>%
  group_by(year) %>%
  summarize(
    first_thaw     = min(start_date),
    first_thaw_doy = yday(first_thaw),
    .groups = "drop"
  )


# ---------------------------
# 6) Join arrivals with climate covariates
# ---------------------------

# Here we combine all the climate summaries with the arrival table.
# Each row in arrival_climate will represent:
#   (species, year, first arrival DOY, plus climate metrics for that year).
# Because arrivals were already restricted to year >= 2005, this join will
# automatically keep only 2005+ years.

arrival_climate <- arrivals %>%
  left_join(clim_temp, by = "year") %>%
  left_join(clim_gdd,  by = "year") %>%
  left_join(clim_ft,   by = "year") %>%
  left_join(clim_snow_mean,   by = "year") %>%
  left_join(snowmelt %>% select(year, first_bare_doy), by = "year") %>%
  left_join(snow_persistence, by = "year") %>%
  left_join(thaw_runs,        by = "year")

glimpse(arrival_climate)


# ---------------------------
# 7) Variable-importance across species
# ---------------------------

# Now we want to know: for each species, which single climate variable
# best predicts year-to-year variation in arrival DOY?
#
# We'll:
#   - fit a separate linear model for each (species, predictor) pair:
#         doy ~ predictor
#   - record slope, p-value, R^2, AIC.
#   - define the "best" predictor as the one with the lowest AIC per species.
# All of this is now based only on years >= 2005.

# List candidate predictors. We'll restrict this to columns that actually exist
# in arrival_climate (e.g., if snow isn't available, those will drop out).
candidate_predictors <- c(
  "spring_mean_temp",  # mean Feb–Apr temperature
  "spring_gdd",        # cumulative GDD Feb–Apr
  "freeze_thaw_days",  # count of freeze–thaw days Jan–Apr
  "mean_snwd",         # mean snow depth Feb–Mar
  "first_bare_doy",    # first bare ground day-of-year
  "days_snow_gt10",    # snow persistence (days > 10 cm)
  "first_thaw_doy"     # first sustained thaw day-of-year
)

predictors <- candidate_predictors[candidate_predictors %in% names(arrival_climate)]
print(predictors)

# Helper function: fit a single-predictor model for one species.
# df: data for one species
# predictor: character string naming the climate column
fit_model <- function(df, predictor) {
  df2 <- df %>%
    select(doy, all_of(predictor)) %>%
    filter(!is.na(.data[[predictor]]))
  
  # If there are too few years with non-NA predictor values, skip this model.
  if (nrow(df2) < 5) return(NULL)
  
  form <- as.formula(paste("doy ~", predictor))
  mod  <- lm(form, data = df2)
  
  g <- glance(mod)
  
  tibble(
    predictor      = predictor,
    n              = nrow(df2),
    estimate       = coef(mod)[2],                      # slope (days / unit)
    p_value        = summary(mod)$coefficients[2, 4],   # p-value for slope
    r.squared      = g$r.squared,
    adj.r.squared  = g$adj.r.squared,
    AIC            = g$AIC
  )
}

# Split the full table by species.
by_species <- split(arrival_climate, arrival_climate$common_name)

# For each species, fit models for all predictors and stack results into one tibble.
model_results <- map_dfr(
  names(by_species),
  function(sp) {
    df_sp <- by_species[[sp]]
    
    mods <- map_dfr(predictors, ~ fit_model(df_sp, .x))
    
    if (nrow(mods) == 0) return(NULL)
    
    mutate(mods, common_name = sp, .before = 1)
  }
)

print(model_results)

# Identify the best single predictor per species.
# We define "best" as the lowest AIC (Akaike Information Criterion).
best_var <- model_results %>%
  group_by(common_name) %>%
  arrange(AIC) %>%
  slice(1) %>%
  ungroup()

print(best_var)


# ---------------------------
# 8) Optional plots for variable importance
# ---------------------------

# 8a) R^2 per predictor per species
#     This lets you see at a glance which climate variable explains the
#     most variation in arrival DOY for each species.
ggplot(model_results,
       aes(x = predictor, y = r.squared, fill = predictor)) +
  geom_col() +
  facet_wrap(~ common_name) +
  labs(
    title = "Single-predictor model R^2 by species (Years >= 2005)",
    x = "Climate predictor",
    y = "R^2"
  ) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# 8b) Slope per predictor per species
#     Negative slopes mean: as the predictor increases, arrival DOY decreases
#     (i.e., birds arrive earlier). Positive slopes mean later arrival.
ggplot(model_results,
       aes(x = predictor, y = estimate, fill = predictor)) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  geom_col() +
  facet_wrap(~ common_name) +
  labs(
    title = "Effect of climate predictors on arrival DOY (Years >= 2005)",
    x = "Climate predictor",
    y = "Slope (days per unit; negative = earlier)"
  ) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))


# ---------------------------
# 9) Species-specific plots: raw + partial regression with visreg
# ---------------------------

# We'll do two kinds of visuals:
#   (1) Raw scatterplots of arrival vs. mean snow depth, by species.
#   (2) Partial regression plots using visreg, controlling for year.
#
# This section is written as reusable functions so you can quickly
# generate plots for any species and any predictor.

# 9a) Simple raw scatterplot: arrival vs mean snow depth for one species
plot_raw_snow_vs_arrival <- function(arrival_climate, species_name) {
  df_sp <- arrival_climate %>%
    filter(common_name == species_name)
  
  ggplot(df_sp, aes(x = mean_snwd, y = doy)) +
    geom_point(alpha = 0.8) +
    geom_smooth(method = "lm", se = TRUE) +
    scale_y_reverse() +
    labs(
      title = paste0(species_name, ": arrival vs mean late-winter snow depth"),
      x = "Mean snow depth (cm, Feb–Mar)",
      y = "Arrival DOY (lower = earlier)"
    ) +
    theme_minimal(base_size = 14)
}

# Examples: raw plots for Robin and Phoebe
plot_raw_snow_vs_arrival(arrival_climate, "American Robin")
plot_raw_snow_vs_arrival(arrival_climate, "Eastern Phoebe")


# 9b) Generic partial regression plot using visreg
#
# This:
#   - fits doy ~ covariates + focal_predictor
#   - shows the *partial* effect of focal_predictor, holding others constant

partial_visreg_plot <- function(arrival_climate,
                                species_name,
                                focal_predictor = "mean_snwd",
                                covariates      = c("year")) {
  
  # 1. Filter to species and keep only relevant columns
  vars_needed <- c("doy", focal_predictor, covariates)
  
  df_sp <- arrival_climate %>%
    filter(common_name == species_name) %>%
    select(all_of(vars_needed)) %>%
    drop_na()
  
  # If we don't have enough data, bail out gracefully
  if (nrow(df_sp) < 5) {
    warning("Not enough complete cases for ", species_name,
            " with predictor ", focal_predictor)
    return(NULL)
  }
  
  # 2. Build formula like: doy ~ year + mean_snwd
  rhs <- c(covariates, focal_predictor) %>% paste(collapse = " + ")
  form <- as.formula(paste("doy ~", rhs))
  
  # 3. Fit model
  mod <- lm(form, data = df_sp)
  
  # 4. visreg partial plot for the focal predictor
  p <- visreg(mod, focal_predictor,
              xlab = focal_predictor,
              ylab = "Arrival DOY (partial effect)",
              gg   = TRUE) +
    ggplot2::theme_minimal(base_size = 14) +
    ggplot2::labs(
      title    = paste0("Partial effect of ", focal_predictor,
                        " on ", species_name, " arrival"),
      subtitle = paste(
        "Effect shown independent of",
        paste(covariates, collapse = ", ")
      )
    )
  
  list(model = mod, plot = p)
}

# Example: American Robin, partial effect of snow depth controlling for year
rob_partial <- partial_visreg_plot(
  arrival_climate,
  species_name     = "American Robin",
  focal_predictor  = "mean_snwd",
  covariates       = c("year")
)

rob_partial$plot
summary(rob_partial$model)

# Example: Eastern Phoebe, same structure
phoebe_partial <- partial_visreg_plot(
  arrival_climate,
  species_name     = "Eastern Phoebe",
  focal_predictor  = "mean_snwd",
  covariates       = c("year")
)

phoebe_partial$plot
summary(phoebe_partial$model)


# 9c) Apply the same model/visualization to *all* focal species
#
# Here we loop over your species_targets and build a list of partial plots.
# You can print them one by one or arrange with patchwork/cowplot later.

partial_results_all <- purrr::map(
  species_targets,
  ~ partial_visreg_plot(
    arrival_climate,
    species_name    = .x,
    focal_predictor = "mean_snwd",
    covariates      = c("year")
  )
)

names(partial_results_all) <- species_targets

# Example: view the Yellow-rumped Warbler partial plot
partial_results_all[["Yellow-rumped Warbler"]]$plot
summary(partial_results_all[["Yellow-rumped Warbler"]]$model)



# Make sure folders exist
dir.create("data", showWarnings = FALSE)
dir.create("figs", showWarnings = FALSE)

# Save the main derived data frame
readr::write_csv(arrival_climate, "data/arrival_climate_2005plus.csv")

# Save model summaries
readr::write_csv(model_results, "data/model_results.csv")
readr::write_csv(best_var, "data/best_predictor_by_species.csv")

# Save a few key plots (example objects from your script)
ggplot2::ggsave("figs/rob_partial_snow.png",
                plot = rob_partial$plot,
                width = 6, height = 4, dpi = 300)

ggplot2::ggsave("figs/phoebe_partial_snow.png",
                plot = phoebe_partial$plot,
                width = 6, height = 4, dpi = 300)

# variable-importance R^2 plot (from section 8)
varimp_r2_plot <- ggplot(model_results,
                         aes(x = predictor, y = r.squared, fill = predictor)) +
  geom_col() +
  facet_wrap(~ common_name) +
  labs(
    title = "Single-predictor model R^2 by species (Years >= 2005)",
    x = "Climate predictor",
    y = "R^2"
  ) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggplot2::ggsave("figs/variable_importance_r2.png",
                plot = varimp_r2_plot,
                width = 7, height = 5, dpi = 300)
# test change