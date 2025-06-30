library(plumber)
library(tidyverse)
library(openxlsx)
library(lubridate)
library(readxl)

#* @apiTitle Email Calendar Cleaner

#* Enable CORS globally
#* @filter cors
function(req, res) {
  res$setHeader("Access-Control-Allow-Origin", "*")
  res$setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
  res$setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization")
  if (req$REQUEST_METHOD == "OPTIONS") {
    res$status <- 200
    return(list())
  }
  forward()
}

#* Health check endpoint
#* @get /ping
function() {
  list(status = "OK", time = Sys.time())
}

#* Clean and filter uploaded Excel file based on date range
#* @param startDate Start date in YYYY-MM-DD
#* @param endDate End date in YYYY-MM-DD
#* @param file The uploaded Excel file
#* @post /clean_email_data
#* @serializer contentType list(type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
function(startDate, endDate, file) {
  req_file <- file$datapath
  data <- read_excel(req_file)
  
  if ("Requester Region" %in% colnames(data)) {
    data <- data %>% filter(`Requester Region` != "EMEA" & `Requester Region` != "APAC")
  }
  
  if ("Short Description" %in% colnames(data)) {
    data <- data %>% filter(!grepl("JP|APJ|APAC|EMEA|KR", `Short Description`, ignore.case = TRUE))
  }
  
  user_start_date <- ymd(startDate)
  user_end_date <- ymd(endDate)
  multiple_dates <- seq(user_start_date, user_end_date, by = "days")
  
  data <- data %>%
    filter(`Standalone Email Date` %in% multiple_dates |
             `Invite 1 Date` %in% multiple_dates |
             `Invite 2 Date` %in% multiple_dates |
             `Invite 3 Date` %in% multiple_dates) %>%
    arrange(if_else(`Invite 2 Date` >= user_start_date & `Invite 2 Date` <= user_end_date,
                    `Invite 2 Date`, `Invite 1 Date`))
  
  date_cols <- c("Standalone Email Date", "Invite 1 Date", "Invite 2 Date", "Invite 3 Date")
  data[date_cols] <- lapply(data[date_cols], function(x) {
    x <- ymd(x)
    format(x, "%Y-%m-%d")
  })
  
  tmp_file <- tempfile(fileext = ".xlsx")
  write.xlsx(data, tmp_file, rowNames = FALSE)
  
  readBin(tmp_file, "raw", n = file.info(tmp_file)$size)
}

#* Run plumber API on Render
pr() %>%
  pr_run(host = "0.0.0.0", port = as.integer(Sys.getenv("PORT", unset = 8000)))
