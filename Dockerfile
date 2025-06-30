FROM rocker/plumber

# Install needed R packages
RUN R -e "install.packages(c('tidyverse', 'openxlsx', 'lubridate', 'readxl'))"

# Copy your plumber API
COPY plumber.R /plumber.R

# Expose port 8000
EXPOSE 8000

# Run the API
CMD ["R", "-e", "pr <- plumber::plumb('/plumber.R'); pr$run(host = '0.0.0.0', port = 8000)"]
