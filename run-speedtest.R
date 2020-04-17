# Run an internet speed test and log the results in a Google Sheet.
# This script is intended to be scheduled to run on a recurring schedule so that
# speeds and their variability can be tracked over time.

# Setup. The speedtest package is not on CRAN, and googlesheets4 v0.2.0.9000 or later
# is needed in order to get the 'sheets_append' function.
# devtools::install_github("hrbrmstr/speedtest")
# devtools::install_github("tidyverse/googlesheets4")
library(speedtest)
library(tidyverse)
library(googlesheets4)

# Get the ID for an existing Google Sheet that will have the results logged to it. This should
# be stored in the .Renviron file, or it can be hard-coded below.

##############
# IMPORTANT: This Google Sheet needs to have a sheet named "Download Data" and a sheet named "Upload Data."
# The technique below expects this ID to be recorded in .Renviron more another environment file in a 
# variable called "SPEEDTEST_GSHEET." Alternatively, you can just hardcode the Google Sheets ID in a variable:
# gsheet <- "[sheet ID]"

gsheet <- Sys.getenv("SPEEDTEST_GSHEET")

#############

# Set the number of servers to run on. There will be 10 tests per server run for the download tests
# and 6 tests per server run for the upload tests. So, this really just controls the volume
# of data captured and how long it takes for the script to run.
num_servers = 3

# Set whether you want to store *all* of the data returned for the test or just as subset of columns
# that will be used for subsequent visualization (and a couple extra). TRUE will be the smaller # of 
# columns and FALSE wll be the full set of columns. The reason you may want the smaller set is 
# because, over time, the Google Sheets will grow in size, which will then require more time to
# download when running the Shiny app or Markdown file. The smaller size option is ~1/3 the size.
smaller_file <- TRUE

# Get the client configuration for the test
config <- spd_config()

# Get a a list of SpeedTest servers and then the 5 "best" ones from that list.
servers <- spd_servers(config=config) 
best_servers <- spd_best_servers(servers = servers, config = config, max = num_servers)

# Run the upload and download tests on each of those servers. The test will run 10 tests on
# a single server at a time. I tried and tried to do this through purrr with no luck,
# so cheesing out with a for loop

download_test <- spd_download_test(best_servers[1,], config=config, summarise = FALSE)
upload_test <- spd_upload_test(best_servers[1,], config=config, summarise = FALSE)

for(i in 2:nrow(best_servers)){
  
  download_new <- spd_download_test(best_servers[i, ], config=config, summarise = FALSE)
  upload_new <- spd_upload_test(best_servers[i, ], config=config, summarise = FALSE)

  download_test <- rbind(download_test, download_new)
  upload_test <- rbind(upload_test, upload_new)
}

rm(download_new, upload_new)

# Add a timestamp for when the tests were run
download_test <- download_test %>% mutate(test_time = Sys.time())
upload_test <- upload_test %>% mutate(test_time = Sys.time())

# Select the smaller number of columns if smaller_file is set to true.
if(smaller_file == TRUE){
  download_test <- download_test %>% 
    select(host, test, secs, size, bw, test_time)
  upload_test <- upload_test %>% 
    select(host, test, secs, size, bw, test_time)
}

# Eventually, this should be updated to use error checking to determine if the sheet
# exists AND if there is any data in each one. But, for now, it's counting on a clean
# setup.
download_data_check <- sheets_read(gsheet, "Download Data")
upload_data_check <- sheets_read(gsheet, "Upload Data")

# If this is the first time to add data, then write the data (which will include the columns).; 
# Otherwise, just append the new data to what is already there.
if(nrow(download_data_check) == 0){
  sheet_write(gsheet, download_test, "Download Data")
} else {
  sheet_append(gsheet, download_test, "Download Data")
}

if(nrow(upload_data_check) == 0){
  sheet_write(gsheet, upload_test, "Upload Data")
} else {
  sheet_append(gsheet, upload_test, "Upload Data")
}


