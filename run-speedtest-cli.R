# Simplified speedtest runner that just calls Ookla's Speed Test from the command
# line. It requires that the command line interface be installed first.
# See: https://www.speedtest.net/apps/cli

# Load required libraries
if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidyverse,
               lubridate,
               googlesheets4,
               jsonlite)      

# Get the Google Sheet ID to write to
# May need to run gs4_auth() initially to ensure authentication.
gsheet <- Sys.getenv("SPEEDTEST_GSHEET")
google_email <- Sys.getenv("GOOGLE_EMAIL")  # For bypassing prompt for which auth acct to use

# Run Speedtest CLI and capture output. Get the results as JSON and then
# convert to a data fram
df_speedtest_output <- system("/opt/homebrew/bin/speedtest -f json --accept-license", intern = TRUE) |> 
  fromJSON() |> 
  as.data.frame()

# Make a simplified data frame. "bandwidth" is provided in "bytes/sec",
# so divide by 125,000 to get Mbps: 1 byte = 8 bits; 1 Mb = 1,000,000 bits
df_speedtest_output_simple <- df_speedtest_output |> 
  mutate(timestamp_utc = ymd_hms(timestamp),    # Date/time in UTC
         timestamp_local_tz = ymd_hms(as.character(ymd_hms(timestamp, tz = ""))), # Date/time in local timezone
         local_tz = Sys.timezone(), # The local timezone
         download_mbps = download.bandwidth/125000,  # Download bandwidth in Mbps
         upload_mbps = upload.bandwidth/125000       # Upload bandwidth in Mbps
         ) |> 
  select(timestamp_utc,
         timestamp_local_tz,
         local_tz,
         download_mbps,
         # Interquartile mean of download of packets in milliseconds
         download_latency_iqm_ms = download.latency.iqm, 
         # Variation in the latency of the download (higher # is worse) in milliseconds
         download_latency_jitter_ms = download.latency.jitter,
         upload_mbps,
         # Interquartile mean of upload of packets in milliseconds
         upload_latency_iqm_ms = upload.latency.iqm, 
         # Variation in the latency of the upload (higher # is worse) in milliseconds
         upload_latency_jitter_ms = upload.latency.jitter,
         # URL to view the results of the test in a browser
         result.url)

# Append to the Google Sheet. Read the sheet first to determine if it has
# any content in it. If not, then write to the sheet so the headings will
# be inclued. If so, then just append.
gs4_auth(email = google_email)
historical_data <- range_read(gsheet)

if(nrow(historical_data) == 0){
  sheet_write(df_speedtest_output_simple, gsheet, sheet = 1)
} else {
  sheet_append(gsheet, df_speedtest_output_simple)
}
  


