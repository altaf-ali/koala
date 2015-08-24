library(stringr)
library(lubridate)
library(dplyr)

rm(list = ls())

# configure the year
TARGET_YEAR <- 2014

# use these settings for publishing - make sure .ssh/config is set up to use public key authentication
PUBLISH_HOST <- "ucl"
PUBLISH_DIRECTORY <- "html.pub/wfp"

events_filename <- sprintf("./results/DatasetCollectorPipeline/events/events.%d.csv", TARGET_YEAR)

events <- read.csv(events_filename)
events_df <- tbl_df(events)
events_df["EventDate"] <- as.Date(events$EventDate)

# CAMEO behavior levels
verbal_conflict <- seq(9, 13)  
material_conflict <- seq(14, 20)  

cameo_codes <- function(start) {
  seq(start*10, ((start+1)*10)-1)
}

conflict_events <- sapply(c(verbal_conflict, material_conflict), function(x) c(cameo_codes(x), cameo_codes(x*10)))

write_monthly_data <- function(target_month) {
  
  print(paste("writing monthly data for", month(target_month, label = TRUE), year(target_month)))
  
  # filter criteria
  event_filter <- function(EventDate, CAMEOCode, Country, SourceName, SourceSectors, TargetName, TargetSectors) {
    actors = "rebel|insurgent"
    (Country != "") & 
      (CAMEOCode %in% conflict_events) &
      (month(EventDate) == month(target_month) & (year(EventDate) == year(target_month))) &
      (str_detect(tolower(SourceName), actors) |
         str_detect(tolower(SourceSectors), actors) |
         str_detect(tolower(TargetName), actors) |
         str_detect(tolower(TargetSectors), actors))
  }
  
  # active days transformation
  active_days <- events_df %>%
    filter(event_filter(EventDate, CAMEOCode, Country, SourceName, SourceSectors, TargetName, TargetSectors)) %>%
    group_by(Country, year(EventDate), month(EventDate)) %>%
    summarise(ACTIVEDAYS = n_distinct(EventDate))
  
  # get the country code
  active_days["CountryCode"] <- countrycode::countrycode(active_days$Country, "country.name", "cown", warn = TRUE)
  
  # extract the latest cshape dataframe 
  shapes <- cshapes::cshp(date=as.Date("2012-6-30")) # last available dataset
  shapes_df <- tbl_df(shapes@data)
  
  # merge the active_days dataframe to cshapes dataframe
  merged_df <- shapes_df %>%
    left_join(active_days, by=c("GWCODE" = "CountryCode"))
  
  # add the activity column
  shapes@data["ACTIVEDAYS"] <- merged_df['ACTIVEDAYS']
  
  # create a temp folder
  output_dir <- file.path(tempdir(), sprintf("eventdata-%02d-%4d-%s", month(target_month), year(target_month), month(target_month, label = TRUE)))
  if (dir.exists(output_dir))
    unlink(output_dir, recursive = TRUE)
  
  # write out the shapefile
  rgdal::writeOGR(shapes, output_dir, "cshapes", driver="ESRI Shapefile")
  
  # compress zip file
  zipfile <- paste0(output_dir, ".zip")
  if (file.exists(zipfile))
    unlink(zipfile)  
  
  print(paste("compressing", basename(zipfile)))
  zip(zipfile, sapply(list.files(output_dir), function(x) file.path(output_dir, x)), flags = "-j")
  
  remote_path <- file.path(PUBLISH_DIRECTORY, basename(zipfile))
  if (!ssh.utils::file.exists.remote(remote_path, remote = PUBLISH_HOST)) {
    print(sprintf("transfering to %s:%s", PUBLISH_HOST, PUBLISH_DIRECTORY))
    ssh.utils::cp.remote(remote.src = "", path.src = zipfile, remote.dest = PUBLISH_HOST, path.dest = PUBLISH_DIRECTORY)
    
    # make it read-only
    ssh.utils::run.remote(sprintf("chmod -w %s", remote_path), remote = PUBLISH_HOST)
  }
}

months <- events_df %>%
  mutate(YearMonth = ISOdate(year(EventDate), month(EventDate), 1)) %>%
  select(YearMonth) %>%
  distinct(YearMonth)

apply(months, 1, write_monthly_data)

