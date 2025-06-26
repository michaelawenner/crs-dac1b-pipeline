library(dplyr)
library(stringr)
library(tidyr)    


source("R/utils.R")
source("R/process_data.R")
source("R/apply_rules.R")
source("R/post_processing.R")
source("R/fill_template.R")


# -------------------------------------------------------------------
# Constants and column name definitions
# -------------------------------------------------------------------

# Define the column names used throughout the pipeline
COL_RECEIVED    <- "Amounts_received_(for_loans:_only_principals)_1000_CHF"
COL_GEQ         <- "OECD_grant_equivalent_1000_CHF"
COL_EXTENDED    <- "Amounts_extended_1000_CHF"
COL_COMMITMENTS <- "Commitments_1000_CHF"
COL_MOBILIZED   <- "Amounts_mobilised_from_the_private_sector_1000_CHF"
COL_PURPOSE_CODE <- "Sector_Purpose_Code"
COL_CURRENCY <- "Currency"
COL_PSI_FLAG <- "PSI_flag"

# Define the placeholder used in the rules file
PLACEHOLDER <- "///////////////////"


# Column mapping: maps rule column names to CRS data column names
column_mapping <- list(
  "Bi Multi" = "Bi_Multi",
  "Type of flow" = "Type_of_flow",
  "Co-operation modality" = "Type_of_aid",
  "Channel Code" = "Channel_Code",
  "Channel Category" = "Channel_Parent_Category",
  "PSI flag" = "PSI_flag",
  "Investment" = "Investment_project",
  "PBA" = "PBA",
  "FTC" = "FTC",
  "Type of blended finance" = "Type_of_blended_finance",
  "Purpose code" = "Sector_Purpose_Code"
)


# Define paths and constants
template_path <- "template/2024_Table_DAC1b.xlsx"
output_path <- "output/2024_Table_DAC1b_filled.xlsx"
exchange_rate <- 0.8985

# Template for local currency in 1000 XX
sheet_LC <- "DAC1b_E_1000_LC"
# Template for mio USD
sheet_USD <- "DAC1b_E_Mio_USD"

# -------------------------------------------------------------------
# Load data
# -------------------------------------------------------------------

# Load rules and CRS data
rules <- load_rules("data/Rules2024.xlsx")
crs_data <- load_and_prepare_crs_data("data/CRS_data.csv", "data/Channel_DAC.csv")

# -------------------------------------------------------------------
# Filter and aggregate data
# -------------------------------------------------------------------

# Apply rules
result <- bind_rows(lapply(1:nrow(rules), function(i) apply_rules(rules[i, ], crs_data, column_mapping, PLACEHOLDER)))

# Post-process with additional transformations (partly related to Swiss specificies)
result <- post_process_result(result, crs_data)

# Save result
write.csv2(result, "output/result.csv", row.names = FALSE)

# -------------------------------------------------------------------
# Fill OECD Template
# -------------------------------------------------------------------

fill_excel_template(
  result_df = result,
  template_path = template_path,
  output_path = output_path,
  sheet_lc = sheet_LC,
  sheet_usd = sheet_USD,
  exchange_rate = exchange_rate
)
