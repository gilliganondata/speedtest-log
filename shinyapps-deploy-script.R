# Use this script -- or some tweaked version of it -- to push the code
# to shinyapps.io. 
library(rsconnect)

# Deploy the apps. 
deployApp(appFiles = c("visualize-speedtest-flex.Rmd", "styles.css", "tracking.html"),
          appName = "speedtest-results",
          appTitle = "SpeedTest Results",
          forceUpdate = TRUE)