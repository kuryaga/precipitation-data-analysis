setwd("C:/Users/evgts/Downloads/thesis/")

library(dplyr)
library(tibble)

process_csv <- function(file_path) {
  print(paste("Processing file:", file_path))  # Debugging: print the file being processed
  
  # Read all lines from the file
  lines <- readLines(file_path, encoding = "ISO-8859-1")
  
  # Find the line number where "METADATA" section starts
  metadata_start <- grep("^METADATA", lines)
  print(paste("Metadata start at line:", metadata_start))  # Debugging
  
  # Find the line number where "PØÍSTROJE" section starts
  postroje_start <- grep("^P\xd8\xcdSTROJE", lines)
  print(paste("PØÍSTROJE start at line:", postroje_start))  # Debugging
  
  # Find the line number where "DATA" section starts
  data_start <- grep("^DATA", lines)
  print(paste("DATA start at line:", data_start))  # Debugging

  
  # Extract the metadata section (excluding the first metadata line)
  metadata_lines <- lines[(metadata_start + 1):(postroje_start - 1)]
  
  # Create a data frame from the metadata lines, skipping the first row
  metadata_df <- read.csv(text = paste(metadata_lines, collapse = "\n"), sep = ";", header = FALSE, stringsAsFactors = FALSE)
  
  # Remove the first row of metadata (the column headers)
  metadata_df <- metadata_df[-1, ]
  
  print(metadata_df)  # Debugging: print the dataframe to check its contents
  
  # Proceed with extracting the relevant information
  station_info <- list()
  
  # Extracting the required columns from metadata_df
  station_info$Station_ID <- metadata_df[1, 1]
  station_info$Station_Name <- metadata_df[1, 2]
  station_info$Start_Date <- metadata_df[1, 3]
  
  # Extract the End Date from the second-to-last row of the metadata section
  station_info$End_Date <- metadata_df[nrow(metadata_df), 4]  # "End Date" is in the 4th column
  
  # Extract the coordinates and elevation
  station_info$Longitude <- mean(as.numeric(metadata_df[, 5]), na.rm = TRUE)
  station_info$Latitude <- mean(as.numeric(metadata_df[, 6]), na.rm = TRUE)
  station_info$Elevation <- mean(as.numeric(metadata_df[, 7]), na.rm = TRUE)
  
  # Process precipitation data (assuming the DATA section is in 'data_start' position)
  data_lines <- lines[(data_start + 1):length(lines)]  # Extract the data lines
  
  # Assuming the precipitation data is in the DATA section and in a proper format
  precipitation_df <- read.csv(text = paste(data_lines, collapse = "\n"), sep = ";", header = TRUE, stringsAsFactors = FALSE)

  precipitation_df <- precipitation_df[, -ncol(precipitation_df)]
  
  colnames(precipitation_df) <- c("year", "month", "day", "pre")
  
  precipitation_df$date <- as.Date(paste(precipitation_df$year, precipitation_df$month, precipitation_df$day, sep = "-"))
  
  
  # Optionally, filter and process the precipitation data if needed
  # For example, remove NA values or calculate daily totals
  
  # Return a tibble with the station info and the precipitation data as a list column
  station_tibble <- tibble(
    Station_ID = station_info$Station_ID,
    Station_Name = station_info$Station_Name,
    Start_Date = station_info$Start_Date,
    End_Date = station_info$End_Date,
    Longitude = station_info$Longitude,
    Latitude = station_info$Latitude,
    Elevation = station_info$Elevation,
    Precipitation_Data = list(precipitation_df)  # Store precipitation data as a list
  )
  
  return(station_tibble)
}


csv_files <- list.files(path = "C:/Users/evgts/Downloads/thesis/", pattern = "\\.csv$", full.names = TRUE)

# Loop through each CSV file and apply the process_csv function
station_list <- lapply(csv_files, process_csv)

all_station_info <- bind_rows(station_list)

print(all_station_info)


sapply(all_station_info, class)

write.table(all_station_info[, -ncol(all_station_info)], "all_station_info.csv", sep = ";", row.names = FALSE, quote = FALSE)









# FOR YEARSUM

process_yearsum <- function(directory) {
  
  library(ncdf4)
  library(tidyverse)
  library(lubridate)
  
  # List all files in the directory
  nc_files <- list.files(directory, pattern = "\\yearsum.nc$", full.names = TRUE)
  
  # Initialize an empty list to store results
  results <- list()
  
  # Loop through each file
  for (file in nc_files) {
    
    # Extract station name and resolution from file name
    station_and_res <- basename(file)
    
    nc_data <- nc_open(file)
    
    # Extract variables
    rr <- ncvar_get(nc_data, "pre")
    lat <- ncvar_get(nc_data, "lat")
    lon <- ncvar_get(nc_data, "lon")
    time <- ncvar_get(nc_data, "time")
    
    # Extract the station and resolution, handling both "_eobsdeg" and standard "_deg"
    station <- gsub("pre_(.*?)_\\d+p\\d+(?:_eobs)?deg.*", "\\1", basename(file))
    resolution <- gsub(".*_(\\d+p\\d+(?:_eobs)?)deg.*", "\\1", basename(file))
    
    # Determine reference time and units based on file type
    if (grepl("eobs", basename(file))) {
      ref_time <- "1920-01-01"  # Reference time for eobs files
      time_units <- "days"      # Time units for eobs files
    } else {
      ref_time <- "1990-01-01 12:00:00"  # Reference time for other files
      time_units <- "hours"    # Time units for other files
    }
    
    # Convert time based on units
    if (time_units == "days") {
      # For eobs files (time is in days)
      date <- as.POSIXct(time * 86400, origin = ref_time)  # Multiply by 86400 to convert days to seconds
    } else {
      # For other files (time is in hours)
      date <- as.POSIXct(time * 3600, origin = ref_time)  # Multiply by 3600 to convert hours to seconds
    }
    
    date <- as.Date(date)
    year <- year(date)
    month <- month(date)
    day <- day(date)
    
    # Store the data
    data <- tibble(
      date = date,
      year = year,
      month = month,
      day = day,
      lat = lat,
      lon = lon,
      pre = rr,
      station = station,
      resolution = resolution
    )
    
    results[[station_and_res]] <- data
    
    nc_close(nc_data)
  }
  
  # Combine all data into a single tibble
  combined_data <- bind_rows(results, .id = "station_res")
  
  return(combined_data)
}


yearsum <- process_yearsum("//wsl.localhost/Ubuntu/home/tsavelidzevg/processed/")

tail(yearsum) 


# FOR DAILY

process_daily <- function(directory) {
 
  
  # List all files in the directory
  nc_files <- list.files(directory, pattern = "(?i)daily\\.nc$", full.names = TRUE)
  
  # Initialize an empty list to store results
  results <- list()
  
  # Loop through each file
  for (file in nc_files) {
    cat("Processing:", file, "\n")
    
    # Extract station name and resolution from file name
    station_and_res <- basename(file)
    
    
    nc_data <- nc_open(file)
    
    # Extract variables
    rr <- ncvar_get(nc_data, "pre")
    lat <- ncvar_get(nc_data, "lat")
    lon <- ncvar_get(nc_data, "lon")
    time <- ncvar_get(nc_data, "time")
    
    # Extract the station and resolution, handling both "_eobsdeg" and standard "_deg"
    station <- gsub("pre_(.*?)_\\d+p\\d+(?:_eobs)?deg.*", "\\1", basename(file))
    resolution <- gsub(".*_(\\d+p\\d+(?:_eobs)?)deg.*", "\\1", basename(file))
    
    # Determine reference time and units based on file type
    if (grepl("eobs", basename(file))) {
      ref_time <- "1920-01-01"  # Reference time for eobs files
      time_units <- "days"      # Time units for eobs files
    } else {
      ref_time <- "1990-01-01 12:00:00"  # Reference time for other files
      time_units <- "hours"    # Time units for other files
    }
    
    # Convert time based on units
    if (time_units == "days") {
      # For eobs files (time is in days)
      date <- as.POSIXct(time * 86400, origin = ref_time)  # Multiply by 86400 to convert days to seconds
    } else {
      # For other files (time is in hours)
      date <- as.POSIXct(time * 3600, origin = ref_time)  # Multiply by 3600 to convert hours to seconds
    }
    
    date <- as.Date(date)
    year <- year(date)
    month <- month(date)
    day <- day(date)
    
    # Store the data
    data <- tibble(
      date = date,
      year = year,
      month = month,
      day = day,
      lat = lat,
      lon = lon,
      pre = rr,
      station = station,
      resolution = resolution
    )
    
    
    results[[station_and_res]] <- data
    
    nc_close(nc_data)
  }
  
  # Combine all data into a single tibble
  combined_data <- bind_rows(results, .id = "station_res")
  
  return(combined_data)
}

daily <- process_daily("//wsl.localhost/Ubuntu/home/tsavelidzevg/processed/")

tail(daily) 




# ERRORS   (long term annual sum GRIDDED PRODUCTS - long term annual sum RAINGAUGE) /  long term annual sum RAINGAUGE * 100 [%]


# BOXPLOT

unnested_data <- all_station_info %>%
  unnest(Precipitation_Data)

filtered_data <- unnested_data %>%
  filter(date >= as.Date("1990-01-01") & date <= as.Date("2009-12-31"))

yearly_sums <- filtered_data %>%
  group_by(Station_ID, year) %>%
  summarize(yearly_sums = sum(pre, na.rm = TRUE))

yearly_sums <- yearly_sums %>%
  rename(station = Station_ID, pre = yearly_sums)




# Add a source column to both datasets
yearsum_gridded <- yearsum %>%
  mutate(source = "Gridded")

yearsum_gauge <- yearly_sums %>%
  mutate(source = "Rain Gauge")

yearsum_gauge <- yearsum_gauge %>%
  mutate(resolution = "Rain Gauge")



# Combine the two datasets
combined_data <- bind_rows(yearsum_gauge, yearsum_gridded)

calculate_error <- function(combined_data) {
  
  library(dplyr)
  
  # Filter the Rain Gauge data
  rain_gauge_data <- combined_data %>%
    filter(source == "Rain Gauge") %>%
    group_by(station, year) %>%
    summarise(yearsum_gauge = sum(pre, na.rm = TRUE))
  
  # Filter the Gridded data (remove Rain Gauge and keep only Gridded)
  gridded_data <- combined_data %>%
    filter(source != "Rain Gauge") %>%
    group_by(station, year, resolution) %>%
    summarise(yearsum_gridded = sum(pre, na.rm = TRUE))
  
  
  
  # Merge rain gauge and gridded data by station and year
  merged_data <- left_join(rain_gauge_data, gridded_data, by = c("station", "year"))
  
  merged_data <- merged_data %>%
    mutate(error_percentage = ((yearsum_gridded - yearsum_gauge) / yearsum_gauge) * 100)
  
  return(merged_data)
}

error_results <- calculate_error(combined_data)

head(error_results)


## Mean errors for each resolution

mean_errors <- aggregate(error_results$error_percentage, by = list(error_results$resolution), FUN = mean)

#print(which.max(error_results$error_percentage))
 #print(error_results[605, ])
 
# Mean errors for each station
 
 errors_by_station <- aggregate(error_results$error_percentage, by = list(station = error_results$station, resolution = error_results$resolution), FUN = mean)
 
 
 
 
 
 
 yearsum_plot <- function(yearsum_gridded) {
   
   library(ggplot2)
   library(dplyr)
   
   stations <- unique(yearsum_gridded$station)
   
   # A list to store plots
   plot_list <- list()
   
   for (station_name in stations) {
     
     station_gridded <- yearsum_gridded %>%
       filter(station == station_name)
     
     station_gauge <- yearsum_gauge %>%
       filter(station == station_name)
     
     
     # Combine the data frames
     combined_data <- bind_rows(station_gauge, station_gridded)
     
     
     station_plot <- ggplot(combined_data, aes(x = reorder(resolution, resolution == "0p125_eobs"), y = pre, fill = resolution)) +
       geom_boxplot() +
       labs(
         x = "Resolution",
         y = "Yearly Sum"
       ) +
       theme_minimal()+
       theme(
         axis.title.x = element_text(size = 14, face = "bold", color = "black"),  # X-axis title
         axis.title.y = element_text(size = 14, face = "bold", color = "black"),
         axis.text.x = element_text(size = 12, face = "bold", color = "black", angle = 45, hjust = 1),   # X-axis text
         axis.text.y = element_text(size = 12, face = "bold", color = "black"),   # Y-axis text
         legend.position = "none"
       )
     
     plot_list[[station_name]] <- station_plot
   }
   
   return(plot_list)
 }
 
 
 plots <- yearsum_plot(yearsum_gridded)
 
 for (station_name in names(plots)) {
   ggsave(
     filename = paste0("boxplot_", station_name, ".png"),
     plot = plots[[station_name]],
     width = 8,
     height = 6,
     bg = 'white'
   )
 }
 
 
##BOXPLOT OF ERRORS FOR EACH STATION
 
 error_boxplot_by_station_resolution <- function(error_results) {
   library(ggplot2)
   library(dplyr)
   
   # Get unique station names
   stations <- unique(error_results$station)
   
   # Create a list to store plots
   plot_list <- list()
   
   # Generate a boxplot for each station
   for (station_name in stations) {
     station_data <- error_results %>%
       filter(station == station_name)
     
     station_plot <- ggplot(station_data, aes(x = resolution, y = error_percentage, fill = resolution)) +
       geom_boxplot() +
       geom_hline(yintercept = 0, linetype = "dashed", color = "black") +
       labs(
         x = "Resolution",
         y = "Error Percentage"
       ) +
       theme_minimal() +
       theme(
         axis.title.x = element_text(size = 14, face = "bold", color = "black"),  # X-axis title
         axis.title.y = element_text(size = 14, face = "bold", color = "black"),
         axis.text.x = element_text(size = 12, face = "bold", color = "black", angle = 45, hjust = 1),   # X-axis text
         axis.text.y = element_text(size = 12, face = "bold", color = "black"),
         legend.position = "none"  # Hide legend for cleaner plots
       )
     
     # Save the plot to the list
     plot_list[[station_name]] <- station_plot
   }
   
   return(plot_list)
 }
 
 # Generate the plots
 station_plots <- error_boxplot_by_station_resolution(error_results)
 
 # Save the plots as separate files
 for (station_name in names(station_plots)) {
   ggsave(
     filename = paste0("boxplot_errors_", station_name, ".png"),
     plot = station_plots[[station_name]],
     width = 8,
     height = 6,
     bg = 'white'
   )
 }
 
 
 
 
 
 # ANNUAL RELATIVE BIAS
 
 # Updated error calculation to annual relative bias
 calculate_annual_relative_bias <- function(combined_data) {
   
   library(dplyr)
   
   # Filter the Rain Gauge data
   rain_gauge_data <- combined_data %>%
     filter(source == "Rain Gauge") %>%
     group_by(station, year) %>%
     summarise(yearsum_gauge = sum(pre, na.rm = TRUE))
   
   # Filter the Gridded data (remove Rain Gauge and keep only Gridded)
   gridded_data <- combined_data %>%
     filter(source != "Rain Gauge") %>%
     group_by(station, year, resolution) %>%
     summarise(yearsum_gridded = sum(pre, na.rm = TRUE))
   
   # Merge rain gauge and gridded data by station and year
   merged_data <- left_join(rain_gauge_data, gridded_data, by = c("station", "year"))
   
   # Calculate annual relative bias
   merged_data <- merged_data %>%
     mutate((relative_bias = (yearsum_gridded - yearsum_gauge) / yearsum_gauge)*100) 
   
   return(merged_data)
 }
 
 # Apply the function
 relative_bias_results <- calculate_annual_relative_bias(combined_data)
 
 head(relative_bias_results)
 
 colnames(relative_bias_results)
 
 relative_bias_results <- relative_bias_results %>%
   rename(relative_bias = '*...')
 
 # Mean relative bias for each resolution
 mean_relative_bias <- aggregate(relative_bias_results$relative_bias, 
                                 by = list(relative_bias_results$resolution), 
                                 FUN = mean)
 
 # Mean relative bias for each station
 relative_bias_by_station <- aggregate(relative_bias_results$relative_bias, 
                                       by = list(station = relative_bias_results$station, 
                                                 resolution = relative_bias_results$resolution), 
                                       FUN = mean)

 
 head(relative_bias_by_station)
 
 head(relative_bias_results)
 
 
 
 
 relative_bias_boxplot <- function(relative_bias_results) {
   library(ggplot2)
   library(dplyr)
   
   # Get unique station names
   stations <- unique(relative_bias_results$station)
   
   # Create a list to store plots
   plot_list <- list()
   
   # Generate a boxplot for each station
   for (station_name in stations) {
     station_data <- relative_bias_results %>%
       filter(station == station_name)
     
     station_plot <- ggplot(station_data, aes(x = resolution, y = relative_bias, fill = resolution)) +
       geom_boxplot() +
       geom_hline(yintercept = 0, linetype = "dashed", color = "black") +
       labs(
         title = paste("Boxplot of Annual Relative Bias for Station", station_name, "(1990-2009)"),
         x = "Resolution",
         y = "Annual Relative Bias (%)"
       ) +
       theme_minimal() +
       theme(
         axis.text.x = element_text(angle = 45, hjust = 1),
         legend.position = "none" 
       )
     
     # Save the plot to the list
     plot_list[[station_name]] <- station_plot
   }
   
   return(plot_list)
 }
 
 # Generate the plots for relative bias
 station_plots <- relative_bias_boxplot(relative_bias_results)
 
 # Save the plots 
 for (station_name in names(station_plots)) {
   ggsave(
     filename = paste0("boxplot_relative_bias_", station_name, ".png"),
     plot = station_plots[[station_name]],
     width = 8,
     height = 6,
     bg = 'white'
   )
 }
 
 
 
 ## OVERLAYED BOXPLOTs
 
 relative_bias_grand_boxplot <- function(relative_bias_results) {
   library(ggplot2)
   library(dplyr)
   
   # Combine all the station data into one dataset
   combined_data <- relative_bias_results
   
   # Create a boxplot for all stations
   grand_plot <- ggplot(combined_data, aes(x = reorder(resolution, resolution == "0p125_eobs"), 
                                           y = relative_bias, fill = resolution)) +
     geom_boxplot() +
     geom_hline(yintercept = 0, linetype = "dashed", color = "black") +
     labs(
       x = "Resolution",
       y = "Annual Relative Bias (%)"
     ) +
     theme_minimal() +
     theme(
       axis.title.x = element_text(size = 14, face = "bold", color = "black"),  # X-axis title
       axis.title.y = element_text(size = 14, face = "bold", color = "black"),
       axis.text.x = element_text(size = 12, face = "bold", color = "black", angle = 45, hjust = 1),   # X-axis text
       axis.text.y = element_text(size = 12, face = "bold", color = "black"),
       legend.position = "none"
     )+
     ylim(-75, 100)
   
   # Return the plot
   return(grand_plot)
 }
 
 # Generate the plot
 grand_boxplot <- relative_bias_grand_boxplot(relative_bias_results)
 
 # Save the plot
 ggsave(
   filename = "grand_boxplot_relative_bias.png",
   plot = grand_boxplot,
   width = 10,
   height = 8,
   bg = 'white'
 )
 
 
 
 
 
 ## DIVIDE BY ELEVATION (MEDIAN)
 
 med_elev <- median(all_station_info$Elevation) # ~435
 
 over_med_elev <- all_station_info %>%
   filter(Elevation > med_elev)
 
 under_med_elev <- all_station_info %>%
   filter(Elevation < med_elev)
 
 equal_med_elev <- all_station_info %>%
   filter(Elevation == med_elev)
 
 # Randomly distribute the stations with exactly the median elevation
 set.seed(123)
 equal_shuffled <- equal_med_elev %>% sample_n(nrow(equal_med_elev))
 
 # Split median stations
 equal_half1 <- equal_shuffled[1:floor(nrow(equal_med_elev)/2), ]
 equal_half2 <- equal_shuffled[(floor(nrow(equal_med_elev)/2) + 1):nrow(equal_med_elev), ]
 
 # Merge the groups 
 over_med_elev <- bind_rows(over_med_elev, equal_half1)
 under_med_elev <- bind_rows(under_med_elev, equal_half2)
 
 
 
 
 ## DIVIDED BY ELEVATION
 
 
 relative_bias_elev_boxplot <- function(relative_bias_results, station_group, group_name) {
   # Ensure column names match
   filtered_data <- relative_bias_results %>%
     filter(station %in% station_group$Station_ID)
   
   # Create the boxplot
   plot <- ggplot(filtered_data, aes(
     x = reorder(resolution, resolution == "0p125_eobs"),
     y = relative_bias,
     fill = resolution
   )) +
     geom_boxplot() +
     geom_hline(yintercept = 0, linetype = "dashed", color = "black") +
     labs(
       x = "Resolution",
       y = "Annual Relative Bias (%)"
     ) +
     theme_minimal() +
     theme(
       axis.title.x = element_text(size = 14, face = "bold", color = "black"),  # X-axis title
       axis.title.y = element_text(size = 14, face = "bold", color = "black"),
       axis.text.x = element_text(size = 12, face = "bold", color = "black", angle = 45, hjust = 1),   # X-axis text
       axis.text.y = element_text(size = 12, face = "bold", color = "black"),
       legend.position = "none"
     )+
     ylim(-75, 100)
   
   return(plot)
 }
 
 # Generate boxplots for each elevation group
 over_med_plot <- relative_bias_elev_boxplot(relative_bias_results, over_med_elev, "Over Median Elevation")
 under_med_plot <- relative_bias_elev_boxplot(relative_bias_results, under_med_elev, "Under Median Elevation")

 
 # Save the plots separately
 ggsave(
   filename = "over_median_elevation_boxplot.png",
   plot = over_med_plot,
   width = 10,
   height = 8,
   bg = 'white'
 )
 
 ggsave(
   filename = "under_median_elevation_boxplot.png",
   plot = under_med_plot,
   width = 10,
   height = 8,
   bg = 'white'
 )
 
 
 ## BOXPLOTS BY YEARS (1990-1999/2000-2009)

 
 relative_bias_by_year <- function(relative_bias_results, year_range, group_name) {
   # Filter data by year range inside the function
   filtered_data <- relative_bias_results %>%
     filter(year >= year_range[1] & year <= year_range[2])  # Filter based on the passed year range
   
   # Create the boxplot
   plot <- ggplot(filtered_data, aes(
     x = reorder(resolution, resolution == "0p125_eobs"),
     y = relative_bias,
     fill = resolution
   )) +
     geom_boxplot() +
     geom_hline(yintercept = 0, linetype = "dashed", color = "black") +
     labs(
       x = "Resolution",
       y = "Annual Relative Bias (%)"
     ) +
     theme_minimal() +
     theme(
       axis.title.x = element_text(size = 14, face = "bold", color = "black"),  # X-axis title
       axis.title.y = element_text(size = 14, face = "bold", color = "black"),
       axis.text.x = element_text(size = 12, face = "bold", color = "black", angle = 45, hjust = 1),   # X-axis text
       axis.text.y = element_text(size = 12, face = "bold", color = "black"),
       legend.position = "none"
     ) +
     ylim(-75, 100)
   
   return(plot)
 }
 
 # Generate boxplots for each time period
 till1999_plot <- relative_bias_by_year(relative_bias_results, c(1990, 1999), "From 1990 To 1999")
 from2000_plot <- relative_bias_by_year(relative_bias_results, c(2000, 2009), "From 2000 To 2009")
 
 # Save the plots separately
 ggsave(
   filename = "till1999_boxplot.png",
   plot = till1999_plot,
   width = 10,
   height = 8,
   bg = 'white'
 )
 
 ggsave(
   filename = "from2000_boxplot.png",
   plot = from2000_plot,
   width = 10,
   height = 8,
   bg = 'white'
 )
 
 
 
 ## FOUR SEASONS

 
 # Aggregate rain gauge data by station and season
 filtered_data_seasonal <- filtered_data %>%
   mutate(season = case_when(
     month %in% c(6, 7, 8) ~ "JJA",
     month %in% c(9, 10, 11) ~ "SON",
     month %in% c(12, 1, 2) ~ "DJF",
     month %in% c(3, 4, 5) ~ "MAM",
     TRUE ~ "Unknown"
   )) %>%
   group_by(Station_ID, season) %>%  
   summarise(total_precipitation = sum(pre, na.rm = TRUE)) %>%
   rename(station = Station_ID) %>%
   ungroup()
 
 
 # Aggregate gridded data by station, resolution, and season
 daily_seasonal <- daily %>%
   mutate(season = case_when(
     month %in% c(6, 7, 8) ~ "JJA",
     month %in% c(9, 10, 11) ~ "SON",
     month %in% c(12, 1, 2) ~ "DJF",
     month %in% c(3, 4, 5) ~ "MAM",
     TRUE ~ "Unknown"
   )) %>%
   group_by(station, resolution, season) %>%  
   summarise(total_precipitation_grid = sum(pre, na.rm = TRUE)) %>%
   ungroup()
 
 
 
 relative_bias_season <- daily_seasonal %>%
   left_join(filtered_data_seasonal, by = c("station", "season")) %>% 
   mutate(
     relative_bias = ((total_precipitation_grid - total_precipitation) / total_precipitation) * 100  
   ) %>%
   select(station, season, resolution, relative_bias) 
 
 
 
 
 relative_bias_boxplot <- function(data, season) {
   ggplot(data, aes(x = resolution, y = relative_bias, fill = resolution)) +
     geom_boxplot() +
     geom_hline(yintercept = 0, linetype = "dashed", color = "black") +
     facet_wrap(~ season) +  
     labs(
       x = "Resolution",
       y = "Relative Bias (%)"
     ) +
     theme_minimal() +
     theme(
       axis.title.x = element_text(size = 14, face = "bold", color = "black"),  # X-axis title
       axis.title.y = element_text(size = 14, face = "bold", color = "black"),
       axis.text.x = element_text(size = 12, face = "bold", color = "black", angle = 45, hjust = 1),   # X-axis text
       axis.text.y = element_text(size = 12, face = "bold", color = "black"),
       legend.position = "none") +
         ylim(-50, 150)
 }
 
 seasons <- unique(relative_bias_season$season)
 
 
 for (season_name in seasons) {
   season_data <- filter(relative_bias_season, season == season_name)
   
   season_plot <- relative_bias_boxplot(season_data, season_name)
   
   ggsave(
     filename = paste0("boxplot_relative_bias_", season_name, ".png"),
     plot = season_plot,
     width = 8,
     height = 6,
     bg = "white"
   )
 }
 
 
 
 
 
 
 ## ANNUAL MAXIMA FUNCTION
 
 combined_data_max <- bind_rows(yearsum_gauge, yearsum_gridded)
 

 calculate_annual_maxima <- function(combined_data_max) {
   
   library(dplyr)
   
     rain_gauge_data <- combined_data_max %>%
     filter(source == "Rain Gauge") %>%
     group_by(station, year) %>%
     summarise(yearsum_gauge = max(pre, na.rm = TRUE))
   
   gridded_data <- combined_data_max %>%
     filter(source != "Rain Gauge") %>%
     group_by(station, year, resolution) %>%
     summarise(yearsum_gridded = max(pre, na.rm = TRUE))
   
   merged_data <- left_join(rain_gauge_data, gridded_data, by = c("station", "year"))
   
   merged_data <- merged_data %>%
     mutate(relative_bias = ((yearsum_gridded - yearsum_gauge) / yearsum_gauge) * 100)
   
   
   return(merged_data)
 }
 
 
 # Apply the function
 annual_maxima <- calculate_annual_maxima(combined_data_max)
 
 head(annual_maxima)
 
 summary(annual_maxima)
 
 sum(is.na(annual_maxima))
 
 summary(annual_maxima$relative_bias)
 
 
 filter(annual_maxima, relative_bias > 500)
 
 filter(annual_maxima, yearsum_gauge < 10)
 
 annual_maxima_plot <- ggplot(annual_maxima, aes(x = factor(resolution), y = yearsum_gridded, fill = resolution)) +
   geom_boxplot() +
   geom_hline(yintercept = 0, linetype = "dashed", color = "black")+
   labs(title = "Annual Maximum Precipitation (Gridded Data)",
        x = "Grid Resolution",
        y = "Annual Maximum Precipitation [mm]") +
   theme_minimal()
 
 
 annual_max_time <- ggplot(annual_maxima, aes(x = year, y = relative_bias, color = factor(resolution))) +
   geom_line() +
   geom_point() +
   geom_hline(yintercept = 0, linetype = "dashed", color = "black")+
   labs(title = "Bias in Annual Maxima Over Time",
        x = "Year",
        y = "Bias [%]") +
   theme_minimal()
 
 
 ggsave("annual_maxima_plot.png", plot = annual_maxima_plot, width = 8, height = 6, bg = "white")
 
 ggsave("annual_max_time.png", plot = annual_max_time, width = 8, height = 6, bg = "white")
 
 
 
 ## T-TEST (???)
 
 # t-test of annual maxima over all resolutions 
 
 t_test_result <- t.test(annual_maxima$yearsum_gauge, annual_maxima$yearsum_gridded, paired = FALSE)
 
 print(t_test_result)
 
 
 
 
# t-test of annual maxima by resolution
 t_test_results_list <- list()
 
 unique_resolutions <- unique(annual_maxima$resolution)
 
 for (res in unique_resolutions) {
 
   rain_gauge_max <- yearsum_gauge %>% 
     select(station, year, pre)
   

   gridded_max <- annual_maxima %>% 
     filter(resolution == res) %>% 
     select(station, year, yearsum_gridded)
   

   merged_max <- left_join(rain_gauge_max, gridded_max, by = c("station", "year"))
   

   t_test_result <- t.test(merged_max$pre, merged_max$yearsum_gridded, paired = TRUE)

   
   t_test_results_list[[res]] <- t_test_result
 }
 
 
 t_test_results_df <- do.call(rbind, lapply(names(t_test_results_list), function(res) {
   x <- t_test_results_list[[res]]
   data.frame(
     resolution = res,
     t_statistic = x$statistic,
     p_value = x$p.value,
     conf_int_lower = x$conf.int[1],
     conf_int_upper = x$conf.int[2],
     mean_difference = x$estimate
   )
 }))
 

 # Round the results
 t_test_results_df_rounded <- t_test_results_df %>%
   mutate(
     t_statistic = round(t_statistic, 6),
     p_value = round(p_value, 6),
     conf_int_lower = round(conf_int_lower, 6),
     conf_int_upper = round(conf_int_upper, 6),
     mean_difference = round(mean_difference, 6)
   )
 
 print(t_test_results_df_rounded)
 
 
 
 